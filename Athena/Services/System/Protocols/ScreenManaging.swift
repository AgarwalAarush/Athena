//
//  ScreenManaging.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import AppKit

enum ScreenManagerError: Error {
    case noScreensAvailable
    case conversionFailure
}

/// Protocol describing operations for working with connected displays.
protocol ScreenManaging {
    func allScreens() -> Result<[DisplayInfo], ScreenManagerError>
    func mainScreen() -> Result<DisplayInfo, ScreenManagerError>
    func screen(containing point: CGPoint) -> Result<DisplayInfo?, ScreenManagerError>

    /// Converts an AppKit (points, top-left origin) rect to CoreGraphics coordinates (pixels, bottom-left origin).
    func convertToCoreGraphics(rect: CGRect, from screen: NSScreen) -> CGRect
}
