//
//  SystemWindowManaging.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import AppKit

enum WindowManagerError: Error {
    case accessibilityDenied
    case windowNotFound
    case operationFailed(String)
}

/// Abstraction for managing system windows owned by other applications.
protocol SystemWindowManaging {
    func listAllWindows() -> Result<[WindowInfo], WindowManagerError>
    func frontmostWindow() -> Result<WindowInfo?, WindowManagerError>
    func moveWindow(pid: pid_t, to origin: CGPoint, size: CGSize?) -> Result<Void, WindowManagerError>
    func resizeWindow(pid: pid_t, to size: CGSize) -> Result<Void, WindowManagerError>
    func focusWindow(pid: pid_t) -> Result<Void, WindowManagerError>
    func tileWindow(
        pid: pid_t,
        position: TilePosition,
        screen: NSScreen?
    ) -> Result<Void, WindowManagerError>
}

/// Positions used for tiling windows quickly.
enum TilePosition: String, Codable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximized
}
