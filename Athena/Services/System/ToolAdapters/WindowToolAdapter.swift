//
//  WindowToolAdapter.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import AppKit

/// Bridges `SystemWindowManaging` capabilities into a tool-callable surface.
final class WindowToolAdapter: ToolCallable {
    enum Action: String, Codable {
        case list
        case frontmost
        case move
        case resize
        case focus
        case tile
    }

    struct Parameters: Codable {
        let action: Action
        let pid: pid_t?
        let origin: CGPoint?
        let size: CGSize?
        let tilePosition: TilePosition?
        let screenIndex: Int?
    }

    struct Payload: Codable {
        var windows: [WindowInfo]?
        var window: WindowInfo?
        var message: String?

        init(
            windows: [WindowInfo]? = nil,
            window: WindowInfo? = nil,
            message: String? = nil
        ) {
            self.windows = windows
            self.window = window
            self.message = message
        }
    }

    typealias ResultValue = Payload

    let toolIdentifier = "system.window"
    let toolDescription = "List or manipulate macOS application windows."

    private let windowManager: SystemWindowManaging

    init(windowManager: SystemWindowManaging = SystemWindowManager.shared) {
        self.windowManager = windowManager
    }

    func execute(parameters: Parameters) async throws -> ToolCallResult<Payload> {
        switch parameters.action {
        case .list:
            return listWindows()
        case .frontmost:
            return frontmostWindow()
        case .move:
            return moveWindow(parameters: parameters)
        case .resize:
            return resizeWindow(parameters: parameters)
        case .focus:
            return focusWindow(parameters: parameters)
        case .tile:
            return tileWindow(parameters: parameters)
        }
    }

    // MARK: - Actions

    private func listWindows() -> ToolCallResult<Payload> {
        switch windowManager.listAllWindows() {
        case .success(let windows):
            return ToolCallResult(success: true, result: Payload(windows: windows))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func frontmostWindow() -> ToolCallResult<Payload> {
        switch windowManager.frontmostWindow() {
        case .success(let window):
            return ToolCallResult(success: true, result: Payload(window: window))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func moveWindow(parameters: Parameters) -> ToolCallResult<Payload> {
        guard let pid = parameters.pid, let origin = parameters.origin else {
            return ToolCallResult(success: false, error: "pid and origin are required for move action")
        }

        switch windowManager.moveWindow(pid: pid, to: origin, size: parameters.size) {
        case .success:
            return ToolCallResult(success: true, result: Payload(message: "Window moved"))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func resizeWindow(parameters: Parameters) -> ToolCallResult<Payload> {
        guard let pid = parameters.pid, let size = parameters.size else {
            return ToolCallResult(success: false, error: "pid and size are required for resize action")
        }

        switch windowManager.resizeWindow(pid: pid, to: size) {
        case .success:
            return ToolCallResult(success: true, result: Payload(message: "Window resized"))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func focusWindow(parameters: Parameters) -> ToolCallResult<Payload> {
        guard let pid = parameters.pid else {
            return ToolCallResult(success: false, error: "pid is required for focus action")
        }

        switch windowManager.focusWindow(pid: pid) {
        case .success:
            return ToolCallResult(success: true, result: Payload(message: "Window focused"))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func tileWindow(parameters: Parameters) -> ToolCallResult<Payload> {
        guard let pid = parameters.pid, let position = parameters.tilePosition else {
            return ToolCallResult(success: false, error: "pid and tilePosition are required for tile action")
        }

        let screen = screen(for: parameters.screenIndex)
        switch windowManager.tileWindow(pid: pid, position: position, screen: screen) {
        case .success:
            return ToolCallResult(success: true, result: Payload(message: "Window tiled"))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func screen(for index: Int?) -> NSScreen? {
        guard let index else { return nil }
        let screens = NSScreen.screens
        guard screens.indices.contains(index) else { return nil }
        return screens[index]
    }
}

private extension WindowManagerError {
    var localizedDescription: String {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permissions are required to control other windows."
        case .windowNotFound:
            return "Unable to locate the requested window."
        case .operationFailed(let message):
            return message
        }
    }
}
