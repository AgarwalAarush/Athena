//
//  TabManaging.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation

enum TabManagerError: Error {
    case automationNotPermitted
    case unsupportedBrowser
    case scriptExecutionFailed(String)
    case tabNotFound
}

/// Protocol for interacting with browser tabs via Apple Events / Automation.
protocol TabManaging {
    func listTabs(in browser: Browser) -> Result<[TabInfo], TabManagerError>
    func activateTab(_ tab: TabInfo) -> Result<Void, TabManagerError>
    func closeTab(_ tab: TabInfo) -> Result<Void, TabManagerError>
    func searchTabs(matching query: String) -> Result<[TabInfo], TabManagerError>
}
