//
//  WindowRegistry.swift
//  Athena
//
//  Created by Claude on 11/4/25.
//

import Foundation
import AppKit
import CoreGraphics

/// Continuously tracks windows across all applications using Accessibility notifications
/// Maintains a registry of WindowDescriptors with stable IDs and workspace information
final class WindowRegistry {
    static let shared = WindowRegistry()

    // MARK: - Properties

    /// Current registry of windows, keyed by windowNumber
    private(set) var windows: [Int: WindowDescriptor] = [:]

    /// Observed applications, keyed by PID
    private var observedApps: [pid_t: AXUIElement] = [:]

    /// Observation callbacks (for AX notifications)
    private var observers: [pid_t: AXObserver] = [:]

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Whether tracking is currently active
    private(set) var isTracking = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Lifecycle

    /// Starts tracking windows across all applications
    func startTracking() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isTracking else { return }

        // Check accessibility permissions
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
            throw WindowRegistryError.accessibilityPermissionDenied
        }

        // Build initial state from running apps
        try buildInitialState()

        // Set up workspace notifications for app launches/terminations
        setupWorkspaceNotifications()

        isTracking = true
    }

    /// Stops tracking windows
    func stopTracking() {
        lock.lock()
        defer { lock.unlock() }

        guard isTracking else { return }

        // Remove all observers
        for (_, observer) in observers {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        observers.removeAll()
        observedApps.removeAll()

        // Remove workspace notifications
        NSWorkspace.shared.notificationCenter.removeObserver(self)

        isTracking = false
    }

    // MARK: - Registry Access

    /// Gets all tracked windows
    func allWindows() -> [WindowDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return Array(windows.values)
    }

    /// Gets windows for a specific application
    func windows(for bundleID: String) -> [WindowDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return windows.values.filter { $0.bundleID == bundleID }
    }

    /// Gets a specific window by windowNumber
    func window(withNumber windowNumber: Int) -> WindowDescriptor? {
        lock.lock()
        defer { lock.unlock() }
        return windows[windowNumber]
    }

    /// Refreshes all window positions/sizes (useful after display changes)
    func refresh() {
        lock.lock()
        defer { lock.unlock() }

        for (windowNumber, descriptor) in windows {
            // Try to update position/size from AX
            if let app = observedApps[descriptor.pid],
               let axWindow = findAXWindow(for: descriptor, in: app) {
                if let updatedDescriptor = createDescriptor(from: axWindow, pid: descriptor.pid, bundleID: descriptor.bundleID) {
                    windows[windowNumber] = updatedDescriptor
                }
            }
        }
    }

    // MARK: - Private - Initial State

    private func buildInitialState() throws {
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy != .prohibited }

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier,
                  let pid = app.processIdentifier as pid_t? else {
                continue
            }

            do {
                try observeApplication(pid: pid, bundleID: bundleID)
            } catch {
                // Log error but continue with other apps
                print("WindowRegistry: Failed to observe app \(bundleID): \(error)")
            }
        }
    }

    private func setupWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            self,
            selector: #selector(applicationLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(applicationTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    // MARK: - Private - Application Observation

    private func observeApplication(pid: pid_t, bundleID: String) throws {
        guard observedApps[pid] == nil else { return }

        let axApp = AXUIElementCreateApplication(pid)

        // Get initial windows
        switch AccessibilityManager.shared.allWindows(of: axApp) {
        case .success(let axWindows):
            for axWindow in axWindows {
                if let descriptor = createDescriptor(from: axWindow, pid: pid, bundleID: bundleID) {
                    windows[descriptor.windowNumber] = descriptor
                }
            }
        case .failure:
            // Non-fatal; app may not have AX windows yet
            break
        }

        // Create observer for notifications
        var observer: AXObserver?
        let result = AXObserverCreate(pid, axObserverCallback, &observer)
        guard result == .success, let observer = observer else {
            throw WindowRegistryError.observerCreationFailed
        }

        // Add notifications
        let notifications: [CFString] = [
            kAXWindowCreatedNotification,
            kAXUIElementDestroyedNotification,
            kAXFocusedWindowChangedNotification,
            kAXMovedNotification,
            kAXResizedNotification,
            kAXTitleChangedNotification
        ]

        let context = Unmanaged.passUnretained(self).toOpaque()
        for notification in notifications {
            AXObserverAddNotification(observer, axApp, notification, context)
        }

        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observedApps[pid] = axApp
        observers[pid] = observer
    }

    private func removeObserver(for pid: pid_t) {
        guard let observer = observers[pid] else { return }

        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers.removeValue(forKey: pid)
        observedApps.removeValue(forKey: pid)

        // Remove all windows for this PID
        windows = windows.filter { $0.value.pid != pid }
    }

    // MARK: - Private - Workspace Notifications

    @objc private func applicationLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier,
              let pid = app.processIdentifier as pid_t? else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.lock.lock()
            defer { self?.lock.unlock() }

            do {
                try self?.observeApplication(pid: pid, bundleID: bundleID)
            } catch {
                print("WindowRegistry: Failed to observe launched app \(bundleID): \(error)")
            }
        }
    }

    @objc private func applicationTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let pid = app.processIdentifier as pid_t? else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        removeObserver(for: pid)
    }

    // MARK: - Private - AX Notification Handling

    private func handleAXNotification(
        _ notification: CFString,
        element: AXUIElement,
        for pid: pid_t,
        bundleID: String
    ) {
        lock.lock()
        defer { lock.unlock() }

        let notifName = notification as String

        switch notifName {
        case kAXWindowCreatedNotification as String,
             kAXFocusedWindowChangedNotification as String:
            // New window or focus change - create/update descriptor
            if let descriptor = createDescriptor(from: element, pid: pid, bundleID: bundleID) {
                windows[descriptor.windowNumber] = descriptor
            }

        case kAXUIElementDestroyedNotification as String:
            // Window destroyed - find and remove
            if let existingDescriptor = findDescriptor(for: element, pid: pid) {
                windows.removeValue(forKey: existingDescriptor.windowNumber)
            }

        case kAXMovedNotification as String,
             kAXResizedNotification as String,
             kAXTitleChangedNotification as String:
            // Window changed - update descriptor
            if let descriptor = createDescriptor(from: element, pid: pid, bundleID: bundleID) {
                windows[descriptor.windowNumber] = descriptor
            }

        default:
            break
        }
    }

    // MARK: - Private - Descriptor Creation

    private func createDescriptor(
        from axWindow: AXUIElement,
        pid: pid_t,
        bundleID: String
    ) -> WindowDescriptor? {
        // Get AX attributes
        let title = axString(axWindow, kAXTitleAttribute)
        let axIdentifier = axString(axWindow, kAXIdentifierAttribute)
        let axFrame = axFrame(axWindow)

        guard let frame = axFrame else { return nil }

        // Match to CG window to get windowNumber
        guard let cgWindowNumber = findCGWindowNumber(for: pid, frame: frame) else {
            return nil
        }

        // Get layer from CG
        let layer = getCGWindowLayer(windowNumber: cgWindowNumber) ?? 0

        // Infer workspace URL for Cursor/VS Code
        let workspaceURL = inferWorkspaceURL(bundleID: bundleID, title: title, axWindow: axWindow)

        // Get display UUID
        let displayUUID = ScreenManager.shared.displayUUID(for: frame)

        return WindowDescriptor(
            bundleID: bundleID,
            pid: pid,
            windowNumber: cgWindowNumber,
            axIdentifier: axIdentifier,
            title: title,
            workspaceURL: workspaceURL,
            frame: frame,
            displayUUID: displayUUID,
            spaceHint: nil,
            layer: layer,
            timestamp: Date()
        )
    }

    // MARK: - Private - Helper Methods

    private func findDescriptor(for axWindow: AXUIElement, pid: pid_t) -> WindowDescriptor? {
        let axFrame = self.axFrame(axWindow)
        return windows.values.first { descriptor in
            descriptor.pid == pid && axFrame != nil && descriptor.frame == axFrame
        }
    }

    private func findAXWindow(for descriptor: WindowDescriptor, in axApp: AXUIElement) -> AXUIElement? {
        guard case .success(let axWindows) = AccessibilityManager.shared.allWindows(of: axApp) else {
            return nil
        }

        // Try to match by title and frame
        for axWindow in axWindows {
            let title = axString(axWindow, kAXTitleAttribute)
            let frame = axFrame(axWindow)

            if title == descriptor.title && frame == descriptor.frame {
                return axWindow
            }
        }

        return nil
    }

    private func axString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let string = value as? String else {
            return nil
        }
        return string
    }

    private func axFrame(_ element: AXUIElement) -> CGRect? {
        guard case .success(let position) = AccessibilityManager.shared.point(for: kAXPositionAttribute, of: element),
              case .success(let size) = AccessibilityManager.shared.size(for: kAXSizeAttribute, of: element) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func findCGWindowNumber(for pid: pid_t, frame: CGRect) -> Int? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Find CG window with matching PID and closest frame
        let candidates = windowList.compactMap { dict -> (windowNumber: Int, frame: CGRect)? in
            guard let windowPID = dict[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid,
                  let windowNumber = dict[kCGWindowNumber as String] as? Int,
                  let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                return nil
            }
            return (windowNumber, bounds)
        }

        // Find best match by frame proximity (allow small differences due to coordinate system conversions)
        return candidates
            .min(by: { abs($0.frame.midX - frame.midX) + abs($0.frame.midY - frame.midY) <
                       abs($1.frame.midX - frame.midX) + abs($1.frame.midY - frame.midY) })?
            .windowNumber
    }

    private func getCGWindowLayer(windowNumber: Int) -> Int? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for dict in windowList {
            if let num = dict[kCGWindowNumber as String] as? Int, num == windowNumber,
               let layer = dict[kCGWindowLayer as String] as? Int {
                return layer
            }
        }

        return nil
    }

    private func inferWorkspaceURL(bundleID: String, title: String?, axWindow: AXUIElement) -> URL? {
        guard bundleID.contains("cursor") || bundleID.contains("vscode") || bundleID.contains("code-oss") else {
            return nil
        }

        // Get PID from AX element
        var pid: pid_t = 0
        guard AXUIElementGetPid(axWindow, &pid) == .success else {
            return nil
        }

        return CursorWorkspaceInference.shared.inferWorkspaceURL(
            bundleID: bundleID,
            pid: pid,
            title: title,
            axWindow: axWindow
        )
    }
}

// MARK: - AX Observer Callback

private func axObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context = context else { return }

    let registry = Unmanaged<WindowRegistry>.fromOpaque(context).takeUnretainedValue()

    // Get PID from element
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return }

    // Get bundleID from PID
    guard let app = NSRunningApplication(processIdentifier: pid),
          let bundleID = app.bundleIdentifier else {
        return
    }

    registry.handleAXNotification(notification, element: element, for: pid, bundleID: bundleID)
}

// MARK: - Error Types

enum WindowRegistryError: Error {
    case accessibilityPermissionDenied
    case observerCreationFailed
    case windowNotFound
    case invalidState
}
