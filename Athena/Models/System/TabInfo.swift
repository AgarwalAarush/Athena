//
//  TabInfo.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation

/// Supported browsers for tab operations
enum Browser: String, Codable, CaseIterable {
    case safari
    case chrome
    case edge
    case firefox
}

/// Represents metadata for a single browser tab
struct TabInfo: Codable, Identifiable, Hashable {
    /// Stable identifier for SwiftUI diffing
    let id: UUID

    /// Browser that owns the tab
    let browser: Browser

    /// Index of the window within the owning browser
    let windowIndex: Int

    /// Index of the tab within the window
    let tabIndex: Int

    /// User-facing title of the tab
    let title: String

    /// URL currently loaded in the tab
    let url: URL

    init(
        id: UUID = UUID(),
        browser: Browser,
        windowIndex: Int,
        tabIndex: Int,
        title: String,
        url: URL
    ) {
        self.id = id
        self.browser = browser
        self.windowIndex = windowIndex
        self.tabIndex = tabIndex
        self.title = title
        self.url = url
    }
}
