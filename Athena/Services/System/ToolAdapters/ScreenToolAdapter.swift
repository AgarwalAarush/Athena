//
//  ScreenToolAdapter.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import CoreGraphics

/// Bridges `ScreenManaging` capabilities to the tool layer.
final class ScreenToolAdapter: ToolCallable {
    enum Action: String, Codable {
        case list
        case main
        case containingPoint
    }

    struct Parameters: Codable {
        let action: Action
        let point: CGPoint?
    }

    struct Payload: Codable {
        var screens: [DisplayInfo]?
        var screen: DisplayInfo?

        init(screens: [DisplayInfo]? = nil, screen: DisplayInfo? = nil) {
            self.screens = screens
            self.screen = screen
        }
    }

    typealias ResultValue = Payload

    let toolIdentifier = "system.screens"
    let toolDescription = "Retrieve information about connected displays."

    private let screenManager: ScreenManaging

    init(screenManager: ScreenManaging = ScreenManager.shared) {
        self.screenManager = screenManager
    }

    func execute(parameters: Parameters) async throws -> ToolCallResult<Payload> {
        switch parameters.action {
        case .list:
            return listScreens()
        case .main:
            return mainScreen()
        case .containingPoint:
            return screenContainingPoint(parameters: parameters)
        }
    }

    // MARK: - Actions

    private func listScreens() -> ToolCallResult<Payload> {
        switch screenManager.allScreens() {
        case .success(let screens):
            return ToolCallResult(success: true, result: Payload(screens: screens))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func mainScreen() -> ToolCallResult<Payload> {
        switch screenManager.mainScreen() {
        case .success(let screen):
            return ToolCallResult(success: true, result: Payload(screen: screen))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func screenContainingPoint(parameters: Parameters) -> ToolCallResult<Payload> {
        guard let point = parameters.point else {
            return ToolCallResult(success: false, error: "point is required for containingPoint action")
        }

        switch screenManager.screen(containing: point) {
        case .success(let screen):
            return ToolCallResult(success: true, result: Payload(screen: screen))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }
}

private extension ScreenManagerError {
    var localizedDescription: String {
        switch self {
        case .noScreensAvailable:
            return "No screens are currently available."
        case .conversionFailure:
            return "Failed to translate screen information."
        }
    }
}
