//
//  ScreenManager.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import AppKit
import CoreGraphics
import IOKit

/// Concrete implementation of `ScreenManaging` leveraging `NSScreen` and `CoreGraphics`.
final class ScreenManager: ScreenManaging {
    static let shared = ScreenManager()

    private init() {}

    // MARK: - Display UUID Utilities

    /// Converts a CGDirectDisplayID to a stable UUID
    /// Returns nil if the UUID cannot be created (e.g., for virtual displays)
    func displayUUID(for displayID: CGDirectDisplayID) -> UUID? {
        guard let cfuuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return nil
        }
        return UUID(uuid: CFUUIDGetUUIDBytes(cfuuid))
    }

    /// Gets the display UUID for a given point in global coordinates
    func displayUUID(for point: CGPoint) -> UUID? {
        // Find which display contains this point
        let maxDisplays: UInt32 = 16
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let result = CGGetDisplaysWithPoint(point, maxDisplays, &displayIDs, &displayCount)
        guard result == .success, displayCount > 0 else {
            // Point not on any display; fall back to main display
            return displayUUID(for: CGMainDisplayID())
        }

        return displayUUID(for: displayIDs[0])
    }

    /// Gets the display UUID for a given rect (uses center point)
    func displayUUID(for rect: CGRect) -> UUID? {
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        return displayUUID(for: centerPoint)
    }

    func allScreens() -> Result<[DisplayInfo], ScreenManagerError> {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return .failure(.noScreensAvailable)
        }

        let displayInfos = screens.compactMap { screen -> DisplayInfo? in
            guard let idValue = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }

            let displayID = CGDirectDisplayID(truncating: idValue)
            let name = screen.localizedName
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let scaleFactor = screen.backingScaleFactor
            let isMain = (screen == NSScreen.main)
            let uuid = self.displayUUID(for: displayID)

            return DisplayInfo(
                id: displayID,
                uuid: uuid,
                name: name,
                frame: frame,
                visibleFrame: visibleFrame,
                scaleFactor: scaleFactor,
                isMain: isMain
            )
        }

        guard !displayInfos.isEmpty else {
            return .failure(.conversionFailure)
        }

        return .success(displayInfos)
    }

    func mainScreen() -> Result<DisplayInfo, ScreenManagerError> {
        switch allScreens() {
        case .success(let screens):
            if let main = screens.first(where: { $0.isMain }) {
                return .success(main)
            } else if let first = screens.first {
                return .success(first)
            } else {
                return .failure(.noScreensAvailable)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    func screen(containing point: CGPoint) -> Result<DisplayInfo?, ScreenManagerError> {
        switch allScreens() {
        case .success(let screens):
            let match = screens.first { $0.frame.contains(point) }
            return .success(match)
        case .failure(let error):
            return .failure(error)
        }
    }

    func convertToCoreGraphics(rect: CGRect, from screen: NSScreen) -> CGRect {
        // `NSScreen` coordinates are already expressed in the global display space with
        // a bottom-left origin, which matches the expectation for AX APIs.
        // We return the rect unchanged to make the intent explicit for callers.
        rect
    }
}
