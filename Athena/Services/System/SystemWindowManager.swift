//
//  SystemWindowManager.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

/// Default implementation of `SystemWindowManaging` that uses CoreGraphics and Accessibility APIs.
final class SystemWindowManager: SystemWindowManaging {
    static let shared = SystemWindowManager()

    private let accessibilityManager: AccessibilityManaging
    private let screenManager: ScreenManaging

    init(
        accessibilityManager: AccessibilityManaging = AccessibilityManager.shared,
        screenManager: ScreenManaging = ScreenManager.shared
    ) {
        self.accessibilityManager = accessibilityManager
        self.screenManager = screenManager
    }

    func listAllWindows() -> Result<[WindowInfo], WindowManagerError> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard
            let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else {
            return .failure(.operationFailed("Unable to fetch window list"))
        }

        let windows = windowList.compactMap(WindowInfo.init(from:))
        return .success(windows)
    }

    func frontmostWindow() -> Result<WindowInfo?, WindowManagerError> {
        switch listAllWindows() {
        case .success(let windows):
            return .success(windows.first)
        case .failure(let error):
            return .failure(error)
        }
    }

    func moveWindow(pid: pid_t, to origin: CGPoint, size: CGSize?) -> Result<Void, WindowManagerError> {
        print("[SystemWindowManager] moveWindow called with pid: \(pid), origin: \(origin), size: \(String(describing: size))")
        
        let elementResult = windowElement(for: pid)
        print("[SystemWindowManager] windowElement result: \(elementResult)")
        
        return elementResult.flatMap { windowElement in
            print("[SystemWindowManager] Got window element for pid \(pid), attempting to set position to \(origin)")
            
            let positionResult = accessibilityManager.setPoint(origin, for: kAXPositionAttribute as CFString, of: windowElement)
            print("[SystemWindowManager] setPoint result: \(positionResult)")
            
            return positionResult
                .mapError(self.mapAccessibilityError)
                .flatMap { _ in
                    print("[SystemWindowManager] Position set successfully, now checking size")
                    if let size {
                        print("[SystemWindowManager] Setting size to \(size)")
                        let sizeResult = accessibilityManager.setSize(size, for: kAXSizeAttribute as CFString, of: windowElement)
                        print("[SystemWindowManager] setSize result: \(sizeResult)")
                        return sizeResult.mapError(self.mapAccessibilityError)
                    } else {
                        print("[SystemWindowManager] No size specified, skipping resize")
                        return .success(())
                    }
                }
                .map { _ in
                    print("[SystemWindowManager] moveWindow completed successfully")
                    return ()
                }
        }
    }

    func resizeWindow(pid: pid_t, to size: CGSize) -> Result<Void, WindowManagerError> {
        windowElement(for: pid)
            .flatMap { windowElement in
                accessibilityManager.setSize(size, for: kAXSizeAttribute as CFString, of: windowElement)
                    .mapError(self.mapAccessibilityError)
            }
    }

    func focusWindow(pid: pid_t) -> Result<Void, WindowManagerError> {
        guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
            return .failure(.windowNotFound)
        }

        let success = runningApplication.activate(options: [.activateIgnoringOtherApps])
        return success ? .success(()) : .failure(.operationFailed("Unable to activate app with pid \(pid)"))
    }

    func tileWindow(
        pid: pid_t,
        position: TilePosition,
        screen: NSScreen?
    ) -> Result<Void, WindowManagerError> {
        guard let targetScreen = screen ?? NSScreen.main else {
            return .failure(.operationFailed("No available screen to tile window"))
        }

        let frame = targetScreen.visibleFrame
        let targetRect = rect(for: position, in: frame)
        let globalRect = screenManager.convertToCoreGraphics(rect: targetRect, from: targetScreen)

        return moveWindow(pid: pid, to: globalRect.origin, size: globalRect.size)
    }

    // MARK: - Private Helpers

    private func windowElement(for pid: pid_t) -> Result<AXUIElement, WindowManagerError> {
        print("[SystemWindowManager] windowElement: Getting window element for pid \(pid)")
        
        let appElement = accessibilityManager.applicationElement(for: pid)
        print("[SystemWindowManager] windowElement: Created app element for pid \(pid)")

        print("[SystemWindowManager] windowElement: Attempting to get focused window")
        switch accessibilityManager.focusedWindow(of: appElement) {
        case .success(let window):
            print("[SystemWindowManager] windowElement: Got focused window successfully")
            return .success(window)
        case .failure(let error):
            print("[SystemWindowManager] windowElement: Failed to get focused window, error: \(error)")
            print("[SystemWindowManager] windowElement: Trying to get all windows as fallback")
            // Try falling back to the first window in the list for any error type
            let allWindowsResult = accessibilityManager.allWindows(of: appElement)
            print("[SystemWindowManager] windowElement: allWindows result: \(allWindowsResult)")
            
            return allWindowsResult
                .mapError(mapAccessibilityError)
                .flatMap { windows in
                    print("[SystemWindowManager] windowElement: Got \(windows.count) windows")
                    guard let window = windows.first else {
                        print("[SystemWindowManager] windowElement: ERROR - No windows found")
                        return .failure(.windowNotFound)
                    }
                    print("[SystemWindowManager] windowElement: Using first window from list")
                    return .success(window)
                }
        }
    }

    private func mapAccessibilityError(_ error: AccessibilityError) -> WindowManagerError {
        switch error {
        case .permissionDenied:
            return .accessibilityDenied
        case .attributeMissing(let attribute):
            return .operationFailed("Missing accessibility attribute \(attribute)")
        case .conversionFailed:
            return .operationFailed("Failed to convert accessibility value")
        case .unexpectedType:
            return .operationFailed("Unexpected accessibility value type")
        case .operationFailed(let description):
            return .operationFailed(description)
        }
    }

    private func rect(for position: TilePosition, in frame: CGRect) -> CGRect {
        // Apply 8px padding on all sides
        let padding: CGFloat = 8
        let paddedFrame = frame.insetBy(dx: padding, dy: padding)
        
        let halfWidth = paddedFrame.width / 2
        let halfHeight = paddedFrame.height / 2

        switch position {
        case .maximized:
            return paddedFrame
        case .leftHalf:
            return CGRect(x: paddedFrame.origin.x, y: paddedFrame.origin.y, width: halfWidth, height: paddedFrame.height)
        case .rightHalf:
            return CGRect(x: paddedFrame.origin.x + halfWidth, y: paddedFrame.origin.y, width: halfWidth, height: paddedFrame.height)
        case .topHalf:
            return CGRect(x: paddedFrame.origin.x, y: paddedFrame.origin.y + halfHeight, width: paddedFrame.width, height: halfHeight)
        case .bottomHalf:
            return CGRect(x: paddedFrame.origin.x, y: paddedFrame.origin.y, width: paddedFrame.width, height: halfHeight)
        case .topLeft:
            return CGRect(x: paddedFrame.origin.x, y: paddedFrame.origin.y + halfHeight, width: halfWidth, height: halfHeight)
        case .topRight:
            return CGRect(x: paddedFrame.origin.x + halfWidth, y: paddedFrame.origin.y + halfHeight, width: halfWidth, height: halfHeight)
        case .bottomLeft:
            return CGRect(x: paddedFrame.origin.x, y: paddedFrame.origin.y, width: halfWidth, height: halfHeight)
        case .bottomRight:
            return CGRect(x: paddedFrame.origin.x + halfWidth, y: paddedFrame.origin.y, width: halfWidth, height: halfHeight)
        }
    }
}
