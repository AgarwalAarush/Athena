//
//  TabManager.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import Carbon

/// Concrete implementation of `TabManaging` using AppleScript / Apple Events.
final class TabManager: TabManaging {
    static let shared = TabManager()

    private let supportedBrowsers: [Browser] = [.safari, .chrome]

    private init() {}

    func listTabs(in browser: Browser) -> Result<[TabInfo], TabManagerError> {
        guard supportedBrowsers.contains(browser) else {
            return .failure(.unsupportedBrowser)
        }

        return execute(script: listTabsScript(for: browser))
            .flatMap { descriptor in
                parseTabList(from: descriptor, browser: browser)
            }
    }

    func activateTab(_ tab: TabInfo) -> Result<Void, TabManagerError> {
        guard supportedBrowsers.contains(tab.browser) else {
            return .failure(.unsupportedBrowser)
        }

        let script: String
        switch tab.browser {
        case .safari:
            script = """
            tell application "Safari"
              if (count of windows) >= \(tab.windowIndex) then
                tell window \(tab.windowIndex)
                  if (count of tabs) >= \(tab.tabIndex) then
                    set current tab to tab \(tab.tabIndex)
                    activate
                    return true
                  end if
                end tell
              end if
            end tell
            return false
            """
        case .chrome:
            script = """
            tell application "Google Chrome"
              if (count of windows) >= \(tab.windowIndex) then
                tell window \(tab.windowIndex)
                  if (count of tabs) >= \(tab.tabIndex) then
                    set active tab index to \(tab.tabIndex)
                    activate
                    return true
                  end if
                end tell
              end if
            end tell
            return false
            """
        case .edge, .firefox:
            return .failure(.unsupportedBrowser)
        }

        return execute(script: script).flatMap { descriptor in
            guard descriptor.descriptorType == typeBoolean else {
                return .success(())
            }

            return descriptor.booleanValue ? .success(()) : .failure(.tabNotFound)
        }
    }

    func closeTab(_ tab: TabInfo) -> Result<Void, TabManagerError> {
        guard supportedBrowsers.contains(tab.browser) else {
            return .failure(.unsupportedBrowser)
        }

        let script: String
        switch tab.browser {
        case .safari:
            script = """
            tell application "Safari"
              if (count of windows) >= \(tab.windowIndex) then
                tell window \(tab.windowIndex)
                  if (count of tabs) >= \(tab.tabIndex) then
                    close tab \(tab.tabIndex)
                    return true
                  end if
                end tell
              end if
            end tell
            return false
            """
        case .chrome:
            script = """
            tell application "Google Chrome"
              if (count of windows) >= \(tab.windowIndex) then
                tell window \(tab.windowIndex)
                  if (count of tabs) >= \(tab.tabIndex) then
                    close tab \(tab.tabIndex)
                    return true
                  end if
                end tell
              end if
            end tell
            return false
            """
        case .edge, .firefox:
            return .failure(.unsupportedBrowser)
        }

        return execute(script: script).flatMap { descriptor in
            descriptor.booleanValue ? .success(()) : .failure(.tabNotFound)
        }
    }

    func searchTabs(matching query: String) -> Result<[TabInfo], TabManagerError> {
        let loweredQuery = query.lowercased()
        var aggregatedTabs: [TabInfo] = []

        for browser in supportedBrowsers {
            switch listTabs(in: browser) {
            case .success(let tabs):
                aggregatedTabs.append(contentsOf: tabs)
            case .failure(let error):
                return .failure(error)
            }
        }

        let results = aggregatedTabs.filter { tab in
            tab.title.lowercased().contains(loweredQuery) ||
            tab.url.absoluteString.lowercased().contains(loweredQuery)
        }

        return .success(results)
    }

    // MARK: - Private Helpers

    private func execute(script: String) -> Result<NSAppleEventDescriptor, TabManagerError> {
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(.scriptExecutionFailed("Unable to compile AppleScript"))
        }

        var errorDictionary: NSDictionary?
        let descriptor = appleScript.executeAndReturnError(&errorDictionary)

        if let errorDictionary,
           let errorCode = errorDictionary[NSAppleScript.errorNumber] as? Int {
            if errorCode == -1743 {
                return .failure(.automationNotPermitted)
            } else {
                let errorMessage = errorDictionary[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                return .failure(.scriptExecutionFailed(errorMessage))
            }
        }

        return .success(descriptor)
    }

    private func parseTabList(from descriptor: NSAppleEventDescriptor, browser: Browser) -> Result<[TabInfo], TabManagerError> {
        guard descriptor.descriptorType == typeAEList else {
            return .failure(.scriptExecutionFailed("Unexpected AppleScript payload"))
        }

        var tabs: [TabInfo] = []
        for index in 1...descriptor.numberOfItems {
            guard
                let itemDescriptor = descriptor.atIndex(index),
                let listDescriptor = itemDescriptor.coerce(toDescriptorType: typeAEList),
                listDescriptor.numberOfItems >= 4,
                let windowIndexValue = listDescriptor.atIndex(1)?.int32Value,
                let tabIndexValue = listDescriptor.atIndex(2)?.int32Value,
                let title = listDescriptor.atIndex(3)?.stringValue,
                let urlString = listDescriptor.atIndex(4)?.stringValue,
                let url = URL(string: urlString)
            else { continue }

            let tab = TabInfo(
                browser: browser,
                windowIndex: Int(windowIndexValue),
                tabIndex: Int(tabIndexValue),
                title: title,
                url: url
            )
            tabs.append(tab)
        }

        return .success(tabs)
    }

    private func listTabsScript(for browser: Browser) -> String {
        switch browser {
        case .safari:
            return """
            tell application "Safari"
              set out to {}
              set windowIndex to 1
              repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                  set end of out to {windowIndex, tabIndex, name of t, URL of t}
                  set tabIndex to tabIndex + 1
                end repeat
                set windowIndex to windowIndex + 1
              end repeat
              return out
            end tell
            """
        case .chrome:
            return """
            tell application "Google Chrome"
              set out to {}
              set windowIndex to 1
              repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                  set end of out to {windowIndex, tabIndex, title of t, URL of t}
                  set tabIndex to tabIndex + 1
                end repeat
                set windowIndex to windowIndex + 1
              end repeat
              return out
            end tell
            """
        case .edge, .firefox:
            return ""
        }
    }
}
