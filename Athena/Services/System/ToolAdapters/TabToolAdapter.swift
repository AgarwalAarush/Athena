//
//  TabToolAdapter.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation

/// Bridges `TabManaging` functionality to the tool-call interface.
final class TabToolAdapter: ToolCallable {
    enum Action: String, Codable {
        case list
        case activate
        case close
        case search
    }

    struct Parameters: Codable {
        let action: Action
        let browser: Browser?
        let windowIndex: Int?
        let tabIndex: Int?
        let query: String?
    }

    struct Payload: Codable {
        var tabs: [TabInfo]?
        var message: String?

        init(tabs: [TabInfo]? = nil, message: String? = nil) {
            self.tabs = tabs
            self.message = message
        }
    }

    typealias ResultValue = Payload

    let toolIdentifier = "system.tabs"
    let toolDescription = "Query or manipulate browser tabs for supported browsers."

    private let tabManager: TabManaging

    init(tabManager: TabManaging = TabManager.shared) {
        self.tabManager = tabManager
    }

    func execute(parameters: Parameters) async throws -> ToolCallResult<Payload> {
        switch parameters.action {
        case .list:
            return listTabs(parameters: parameters)
        case .activate:
            return activateTab(parameters: parameters)
        case .close:
            return closeTab(parameters: parameters)
        case .search:
            return searchTabs(parameters: parameters)
        }
    }

    // MARK: - Actions

    private func listTabs(parameters: Parameters) -> ToolCallResult<Payload> {
        guard let browser = parameters.browser else {
            return ToolCallResult(success: false, error: "browser is required for list action")
        }

        switch tabManager.listTabs(in: browser) {
        case .success(let tabs):
            return ToolCallResult(success: true, result: Payload(tabs: tabs))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func activateTab(parameters: Parameters) -> ToolCallResult<Payload> {
        guard
            let browser = parameters.browser,
            let windowIndex = parameters.windowIndex,
            let tabIndex = parameters.tabIndex
        else {
            return ToolCallResult(success: false, error: "browser, windowIndex, and tabIndex are required for activate action")
        }

        switch lookupTab(browser: browser, windowIndex: windowIndex, tabIndex: tabIndex) {
        case .success(let tab):
            switch tabManager.activateTab(tab) {
            case .success:
                return ToolCallResult(success: true, result: Payload(message: "Tab activated"))
            case .failure(let error):
                return ToolCallResult(success: false, error: error.localizedDescription)
            }
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func closeTab(parameters: Parameters) -> ToolCallResult<Payload> {
        guard
            let browser = parameters.browser,
            let windowIndex = parameters.windowIndex,
            let tabIndex = parameters.tabIndex
        else {
            return ToolCallResult(success: false, error: "browser, windowIndex, and tabIndex are required for close action")
        }

        switch lookupTab(browser: browser, windowIndex: windowIndex, tabIndex: tabIndex) {
        case .success(let tab):
            switch tabManager.closeTab(tab) {
            case .success:
                return ToolCallResult(success: true, result: Payload(message: "Tab closed"))
            case .failure(let error):
                return ToolCallResult(success: false, error: error.localizedDescription)
            }
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    private func searchTabs(parameters: Parameters) -> ToolCallResult<Payload> {
        guard let query = parameters.query, !query.isEmpty else {
            return ToolCallResult(success: false, error: "query is required for search action")
        }

        switch tabManager.searchTabs(matching: query) {
        case .success(let tabs):
            return ToolCallResult(success: true, result: Payload(tabs: tabs))
        case .failure(let error):
            return ToolCallResult(success: false, error: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func lookupTab(browser: Browser, windowIndex: Int, tabIndex: Int) -> Result<TabInfo, TabManagerError> {
        tabManager.listTabs(in: browser)
            .flatMap { tabs in
                guard let tab = tabs.first(where: { $0.windowIndex == windowIndex && $0.tabIndex == tabIndex }) else {
                    return .failure(.tabNotFound)
                }
                return .success(tab)
            }
    }
}

private extension TabManagerError {
    var localizedDescription: String {
        switch self {
        case .automationNotPermitted:
            return "The app lacks Automation permissions for the selected browser."
        case .unsupportedBrowser:
            return "This browser is currently unsupported."
        case .scriptExecutionFailed(let message):
            return "AppleScript failed: \(message)"
        case .tabNotFound:
            return "Unable to locate the requested tab."
        }
    }
}
