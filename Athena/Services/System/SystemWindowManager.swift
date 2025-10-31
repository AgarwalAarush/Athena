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
        windowElement(for: pid)
            .flatMap { windowElement in
                accessibilityManager.setPoint(origin, for: kAXPositionAttribute as CFString, of: windowElement)
                    .mapError(self.mapAccessibilityError)
                    .flatMap { _ in
                        if let size {
                            return accessibilityManager.setSize(size, for: kAXSizeAttribute as CFString, of: windowElement)
                                .mapError(self.mapAccessibilityError)
                        } else {
                            return .success(())
                        }
                    }
                    .map { _ in () }
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
        let appElement = accessibilityManager.applicationElement(for: pid)

        switch accessibilityManager.focusedWindow(of: appElement) {
        case .success(let window):
            return .success(window)
        case .failure(let error):
            switch error {
            case .attributeMissing:
                // Try falling back to the first window in the list.
                return accessibilityManager.allWindows(of: appElement)
                    .mapError(mapAccessibilityError)
                    .flatMap { windows in
                        guard let window = windows.first else {
                            return .failure(.windowNotFound)
                        }
                        return .success(window)
                    }
            default:
                return .failure(mapAccessibilityError(error))
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
        let halfWidth = frame.width / 2
        let halfHeight = frame.height / 2

        switch position {
        case .maximized:
            return frame
        case .leftHalf:
            return CGRect(x: frame.origin.x, y: frame.origin.y, width: halfWidth, height: frame.height)
        case .rightHalf:
            return CGRect(x: frame.origin.x + halfWidth, y: frame.origin.y, width: halfWidth, height: frame.height)
        case .topHalf:
            return CGRect(x: frame.origin.x, y: frame.origin.y + halfHeight, width: frame.width, height: halfHeight)
        case .bottomHalf:
            return CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: halfHeight)
        case .topLeft:
            return CGRect(x: frame.origin.x, y: frame.origin.y + halfHeight, width: halfWidth, height: halfHeight)
        case .topRight:
            return CGRect(x: frame.origin.x + halfWidth, y: frame.origin.y + halfHeight, width: halfWidth, height: halfHeight)
        case .bottomLeft:
            return CGRect(x: frame.origin.x, y: frame.origin.y, width: halfWidth, height: halfHeight)
        case .bottomRight:
            return CGRect(x: frame.origin.x + halfWidth, y: frame.origin.y, width: halfWidth, height: halfHeight)
        }
    }
}
