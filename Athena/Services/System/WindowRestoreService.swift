//
//  WindowRestoreService.swift
//  Athena
//
//  Created by Claude on 11/4/25.
//

import Foundation
import AppKit
import CoreGraphics

/// Service for restoring windows using WindowDescriptors with Cursor workspace support
final class WindowRestoreService {
    static let shared = WindowRestoreService()

    // MARK: - Properties

    private let systemWindowManager: SystemWindowManaging
    private let accessibilityManager: AccessibilityManaging
    private let screenManager: ScreenManager
    private let windowRegistry: WindowRegistry
    private let cursorInference: CursorWorkspaceInference

    // MARK: - Initialization

    private init(
        systemWindowManager: SystemWindowManaging = SystemWindowManager.shared,
        accessibilityManager: AccessibilityManaging = AccessibilityManager.shared,
        screenManager: ScreenManager = ScreenManager.shared,
        windowRegistry: WindowRegistry = WindowRegistry.shared,
        cursorInference: CursorWorkspaceInference = CursorWorkspaceInference.shared
    ) {
        self.systemWindowManager = systemWindowManager
        self.accessibilityManager = accessibilityManager
        self.screenManager = screenManager
        self.windowRegistry = windowRegistry
        self.cursorInference = cursorInference
    }

    // MARK: - Public API

    /// Restores a set of window descriptors
    /// Returns the number of windows successfully restored
    func restoreWindows(_ descriptors: [WindowDescriptor]) async throws -> Int {
        // Group by application
        let grouped = Dictionary(grouping: descriptors, by: { $0.bundleID })

        var restoredCount = 0

        // Process each application's windows
        for (bundleID, windows) in grouped {
            do {
                let count = try await restoreWindowsForApp(bundleID: bundleID, windows: windows)
                restoredCount += count
            } catch {
                print("WindowRestoreService: Failed to restore windows for \(bundleID): \(error)")
            }
        }

        return restoredCount
    }

    // MARK: - Private - App-Level Restoration

    private func restoreWindowsForApp(bundleID: String, windows: [WindowDescriptor]) async throws -> Int {
        // Ensure app is running
        try await ensureAppRunning(bundleID: bundleID)

        var restoredCount = 0

        // Process each window
        for descriptor in windows {
            do {
                try await restoreWindow(descriptor)
                restoredCount += 1
            } catch {
                print("WindowRestoreService: Failed to restore window \(descriptor.shortID): \(error)")
            }
        }

        return restoredCount
    }

    // MARK: - Private - Window Restoration

    private func restoreWindow(_ descriptor: WindowDescriptor) async throws {
        // Strategy 1: Try to find existing matching window
        if let existingWindow = findMatchingWindow(descriptor) {
            try await moveWindow(existingWindow, to: descriptor)
            return
        }

        // Strategy 2: For Cursor windows with workspace, reopen via CLI
        if descriptor.isCursorOrVSCode, let workspaceURL = descriptor.workspaceURL {
            try await restoreCursorWindow(descriptor, workspaceURL: workspaceURL)
            return
        }

        // Strategy 3: Try to create a new window (app-specific)
        // For now, we only handle Cursor; other apps would need similar logic
        throw WindowRestoreError.cannotRestoreWindow("No matching window found and cannot create new window")
    }

    private func findMatchingWindow(_ descriptor: WindowDescriptor) -> WindowDescriptor? {
        // Try to find window by windowNumber (most reliable)
        if let match = windowRegistry.window(withNumber: descriptor.windowNumber) {
            return match
        }

        // Try to find by bundle + title + approximate frame
        let candidates = windowRegistry.windows(for: descriptor.bundleID)

        for candidate in candidates {
            // Match by title and approximate frame (within 50 pixels)
            if candidate.title == descriptor.title,
               abs(candidate.frame.origin.x - descriptor.frame.origin.x) < 50,
               abs(candidate.frame.origin.y - descriptor.frame.origin.y) < 50 {
                return candidate
            }
        }

        // For Cursor, also try matching by workspace URL
        if descriptor.isCursorOrVSCode, let workspaceURL = descriptor.workspaceURL {
            for candidate in candidates {
                if candidate.workspaceURL == workspaceURL {
                    return candidate
                }
            }
        }

        return nil
    }

    private func restoreCursorWindow(_ descriptor: WindowDescriptor, workspaceURL: URL) async throws {
        // Validate workspace still exists
        guard cursorInference.validateWorkspace(workspaceURL) else {
            throw WindowRestoreError.workspaceNotFound(workspaceURL)
        }

        // Open workspace via CLI
        cursorInference.openWorkspace(
            workspaceURL,
            bundleID: descriptor.bundleID,
            newWindow: true
        )

        // Wait for window to appear
        guard let newWindow = cursorInference.waitForWindow(
            matching: workspaceURL,
            bundleID: descriptor.bundleID,
            timeout: 10.0,
            registry: windowRegistry
        ) else {
            throw WindowRestoreError.windowDidNotAppear
        }

        // Wait a bit for window to fully load
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Move to saved position
        try await moveWindow(newWindow, to: descriptor)
    }

    // MARK: - Private - Window Movement

    private func moveWindow(_ window: WindowDescriptor, to target: WindowDescriptor) async throws {
        // Compute target frame, adjusting for display changes if necessary
        let targetFrame = await computeTargetFrame(for: target)

        // Get AX element for window
        let axApp = accessibilityManager.applicationElement(for: window.pid)

        guard case .success(let axWindows) = accessibilityManager.allWindows(of: axApp) else {
            throw WindowRestoreError.cannotFindAXWindow
        }

        // Find matching AX window
        var matchingAXWindow: AXUIElement?
        for axWindow in axWindows {
            // Try to match by title
            var titleValue: AnyObject?
            if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue) == .success,
               let title = titleValue as? String,
               title == window.title {
                matchingAXWindow = axWindow
                break
            }
        }

        guard let axWindow = matchingAXWindow else {
            throw WindowRestoreError.cannotFindAXWindow
        }

        // Set position and size
        try await setWindowFrame(axWindow, to: targetFrame)
    }

    private func computeTargetFrame(for descriptor: WindowDescriptor) async -> CGRect {
        // If we have a display UUID, try to map to that display
        if let displayUUID = descriptor.displayUUID,
           case .success(let displays) = screenManager.allScreens(),
           let targetDisplay = displays.first(where: { $0.uuid == displayUUID }) {
            // Check if frame is still within display bounds
            if targetDisplay.frame.contains(descriptor.frame) {
                return descriptor.frame
            } else {
                // Frame is outside current display bounds; scale proportionally
                return scaleFrame(descriptor.frame, to: targetDisplay.frame)
            }
        }

        // Fallback: use original frame (may be on wrong display)
        return descriptor.frame
    }

    private func scaleFrame(_ frame: CGRect, to displayFrame: CGRect) -> CGRect {
        // Simple scaling: maintain relative position and size
        let relativeX = frame.origin.x / displayFrame.width
        let relativeY = frame.origin.y / displayFrame.height
        let relativeWidth = frame.width / displayFrame.width
        let relativeHeight = frame.height / displayFrame.height

        return CGRect(
            x: displayFrame.origin.x + (relativeX * displayFrame.width),
            y: displayFrame.origin.y + (relativeY * displayFrame.height),
            width: relativeWidth * displayFrame.width,
            height: relativeHeight * displayFrame.height
        )
    }

    private func setWindowFrame(_ axWindow: AXUIElement, to frame: CGRect) async throws {
        let position = frame.origin
        let size = frame.size

        // Set position
        if case .failure(let error) = accessibilityManager.setPoint(
            for: kAXPositionAttribute,
            of: axWindow,
            to: position
        ) {
            throw WindowRestoreError.axOperationFailed("setPosition", error)
        }

        // Set size
        if case .failure(let error) = accessibilityManager.setSize(
            for: kAXSizeAttribute,
            of: axWindow,
            to: size
        ) {
            throw WindowRestoreError.axOperationFailed("setSize", error)
        }

        // Some windows (especially Electron) resist immediate moves; retry once if needed
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify position
        if case .success(let actualPosition) = accessibilityManager.point(
            for: kAXPositionAttribute,
            of: axWindow
        ) {
            let tolerance: CGFloat = 10.0
            if abs(actualPosition.x - position.x) > tolerance ||
               abs(actualPosition.y - position.y) > tolerance {
                // Retry once
                _ = accessibilityManager.setPoint(
                    for: kAXPositionAttribute,
                    of: axWindow,
                    to: position
                )
            }
        }
    }

    // MARK: - Private - App Management

    private func ensureAppRunning(bundleID: String) async throws {
        // Check if app is already running
        let runningApps = NSWorkspace.shared.runningApplications
        if runningApps.contains(where: { $0.bundleIdentifier == bundleID }) {
            return
        }

        // Launch app
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw WindowRestoreError.appNotFound(bundleID)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false // Don't bring to front immediately

        try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)

        // Wait for app to initialize
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
}

// MARK: - Error Types

enum WindowRestoreError: Error, LocalizedError {
    case appNotFound(String)
    case workspaceNotFound(URL)
    case windowDidNotAppear
    case cannotFindAXWindow
    case cannotRestoreWindow(String)
    case axOperationFailed(String, AccessibilityError)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let bundleID):
            return "Application not found: \(bundleID)"
        case .workspaceNotFound(let url):
            return "Workspace not found: \(url.path)"
        case .windowDidNotAppear:
            return "Window did not appear after opening workspace"
        case .cannotFindAXWindow:
            return "Cannot find window via Accessibility API"
        case .cannotRestoreWindow(let reason):
            return "Cannot restore window: \(reason)"
        case .axOperationFailed(let operation, let error):
            return "Accessibility operation '\(operation)' failed: \(error)"
        }
    }
}
