//
//  ScreenManager.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import AppKit

/// Concrete implementation of `ScreenManaging` leveraging `NSScreen` and `CoreGraphics`.
final class ScreenManager: ScreenManaging {
    static let shared = ScreenManager()

    private init() {}

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

            return DisplayInfo(
                id: displayID,
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
