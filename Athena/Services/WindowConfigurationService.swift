//
//  WindowConfigurationService.swift
//  Athena
//
//  Created by Cursor on 11/4/25.
//

import Foundation
import AppKit

/// Service for managing window configurations (save, restore, list, delete)
final class WindowConfigurationService {
    static let shared = WindowConfigurationService()
    
    private let windowManager: SystemWindowManaging
    private let screenManager: ScreenManaging
    private let database: DatabaseManager
    private let systemTool: SystemTool
    private let accessibilityManager: AccessibilityManaging
    
    init(
        windowManager: SystemWindowManaging = SystemWindowManager.shared,
        screenManager: ScreenManaging = ScreenManager.shared,
        database: DatabaseManager = DatabaseManager.shared,
        systemTool: SystemTool = SystemTool.shared,
        accessibilityManager: AccessibilityManaging = AccessibilityManager.shared
    ) {
        self.windowManager = windowManager
        self.screenManager = screenManager
        self.database = database
        self.systemTool = systemTool
        self.accessibilityManager = accessibilityManager
    }
    
    // MARK: - Permission Management
    
    /// Checks if accessibility permissions are granted
    var hasAccessibilityPermission: Bool {
        accessibilityManager.isAccessibilityEnabled
    }
    
    /// Requests accessibility permissions with system prompt
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        print("[WindowConfigurationService] Requesting accessibility permission")
        let granted = accessibilityManager.requestAccessibilityPermissions(prompt: true)
        
        if granted {
            print("[WindowConfigurationService] Accessibility permission granted")
        } else {
            print("[WindowConfigurationService] Accessibility permission denied or pending")
        }
        
        return granted
    }
    
    // MARK: - Public API
    
    /// Saves the current window configuration with the given name
    func saveConfiguration(name: String) throws -> WindowConfiguration {
        print("[WindowConfigurationService] Saving configuration '\(name)'")
        
        // Get all current windows
        let windowsResult = windowManager.listAllWindows()
        guard case .success(let currentWindows) = windowsResult else {
            if case .failure(let error) = windowsResult {
                throw error
            }
            throw NSError(domain: "WindowConfigurationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to list windows"])
        }
        
        // Get all screens to determine screen indices
        let screensResult = screenManager.allScreens()
        guard case .success(let screens) = screensResult else {
            if case .failure(let error) = screensResult {
                throw error
            }
            throw NSError(domain: "WindowConfigurationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get screens"])
        }
        
        // Convert windows to saved format
        let savedWindows = currentWindows.compactMap { window -> SavedWindowInfo? in
            // Determine which screen this window is on
            let screenIndex = screenIndex(for: window.bounds, in: screens)
            return SavedWindowInfo(from: window, screenIndex: screenIndex)
        }
        
        // Check if configuration with this name already exists
        if let existing = try? database.fetchWindowConfiguration(name: name) {
            // Delete the old one first
            try database.deleteWindowConfiguration(name: name)
        }
        
        // Save to database
        let configuration = try database.createWindowConfiguration(name: name, windows: savedWindows)
        
        print("[WindowConfigurationService] Saved '\(name)' with \(savedWindows.count) windows")
        return configuration
    }
    
    /// Restores a window configuration by name
    func restoreConfiguration(name: String) async throws {
        print("[WindowConfigurationService] Restoring configuration '\(name)'")
        
        // Check accessibility permission
        if !hasAccessibilityPermission {
            print("[WindowConfigurationService] Accessibility permission not granted, requesting...")
            requestAccessibilityPermission()
            
            // Check again after requesting
            guard hasAccessibilityPermission else {
                throw NSError(
                    domain: "WindowConfigurationService",
                    code: -2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Accessibility permission required to position windows. Please grant permission in System Settings > Privacy & Security > Accessibility and try again."
                    ]
                )
            }
        }
        
        // Fetch configuration from database
        guard let configuration = try database.fetchWindowConfiguration(name: name) else {
            throw NSError(domain: "WindowConfigurationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Configuration '\(name)' not found"])
        }
        
        print("[WindowConfigurationService] Found configuration with \(configuration.windows.count) windows")
        
        // Group windows by app
        let windowsByApp = Dictionary(grouping: configuration.windows, by: { $0.appName })
        
        // Get currently running apps
        let runningAppsResult = windowManager.listAllWindows()
        var runningAppNames: Set<String> = []
        if case .success(let windows) = runningAppsResult {
            runningAppNames = Set(windows.map { $0.ownerName })
        }
        
        // Launch apps that aren't running
        for (appName, _) in windowsByApp {
            if !runningAppNames.contains(appName) {
                print("[WindowConfigurationService] Launching '\(appName)'")
                let parameters = SystemTool.ToolParameters(
                    action: "open_app",
                    filePath: nil,
                    content: nil,
                    directory: nil,
                    pattern: nil,
                    brightness: nil,
                    volume: nil,
                    appName: appName
                )
                _ = try await systemTool.execute(parameters: parameters)
                
                // Wait for app to launch and create windows
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
        
        // Position each window
        for (index, savedWindow) in configuration.windows.enumerated() {
            print("[WindowConfigurationService] ========================================")
            print("[WindowConfigurationService] Processing window \(index + 1) of \(configuration.windows.count)")
            print("[WindowConfigurationService] App: \(savedWindow.appName)")
            print("[WindowConfigurationService] Title: \(savedWindow.windowTitle)")
            print("[WindowConfigurationService] Position: \(savedWindow.origin)")
            print("[WindowConfigurationService] Size: \(savedWindow.size)")
            print("[WindowConfigurationService] Screen Index: \(savedWindow.screenIndex)")
            print("[WindowConfigurationService] ========================================")
            
            // Find the window's PID
            if let pid = try await findPID(for: savedWindow.appName) {
                print("[WindowConfigurationService] Found PID: \(pid) for app '\(savedWindow.appName)'")
                
                // Move and resize the window
                print("[WindowConfigurationService] Calling moveWindow with:")
                print("  - pid: \(pid)")
                print("  - origin: \(savedWindow.origin)")
                print("  - size: \(savedWindow.size)")
                
                let moveResult = windowManager.moveWindow(
                    pid: pid,
                    to: savedWindow.origin,
                    size: savedWindow.size
                )
                
                switch moveResult {
                case .success:
                    print("[WindowConfigurationService] ✅ Successfully positioned window")
                case .failure(let error):
                    print("[WindowConfigurationService] ❌ Failed to position window - Error: \(error)")
                    // Continue with other windows even if one fails
                }
                
                // Small delay between positioning windows
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            } else {
                print("[WindowConfigurationService] ❌ Could not find PID for '\(savedWindow.appName)'")
            }
        }
        
        print("[WindowConfigurationService] Restore complete")
    }
    
    /// Lists all saved configurations
    func listConfigurations() throws -> [WindowConfiguration] {
        try database.fetchAllWindowConfigurations()
    }
    
    /// Deletes a configuration by name
    func deleteConfiguration(name: String) throws {
        try database.deleteWindowConfiguration(name: name)
        print("[WindowConfigurationService] Deleted configuration '\(name)'")
    }
    
    /// Renames a configuration
    func updateConfiguration(oldName: String, newName: String) throws {
        try database.updateWindowConfiguration(name: oldName, newName: newName)
        print("[WindowConfigurationService] Renamed configuration '\(oldName)' to '\(newName)'")
    }
    
    // MARK: - Private Helpers
    
    /// Determines which screen index a window bounds belongs to
    private func screenIndex(for bounds: CGRect, in screens: [DisplayInfo]) -> Int {
        // Find which screen contains the center of the window
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        for (index, screen) in screens.enumerated() {
            if screen.frame.contains(center) {
                return index
            }
        }
        
        // Default to main screen (index 0) if not found
        return 0
    }
    
    /// Finds the PID for a given app name
    private func findPID(for appName: String) async throws -> pid_t? {
        print("[WindowConfigurationService] findPID: Searching for app '\(appName)'")
        
        let windowsResult = windowManager.listAllWindows()
        guard case .success(let windows) = windowsResult else {
            print("[WindowConfigurationService] findPID: Failed to list windows")
            return nil
        }
        
        print("[WindowConfigurationService] findPID: Found \(windows.count) total windows")
        print("[WindowConfigurationService] findPID: Available apps: \(Set(windows.map { $0.ownerName }).sorted())")
        
        // Try exact match first
        if let window = windows.first(where: { $0.ownerName == appName }) {
            print("[WindowConfigurationService] findPID: Found exact match - PID: \(window.ownerPID)")
            return window.ownerPID
        }
        print("[WindowConfigurationService] findPID: No exact match for '\(appName)'")
        
        // Try case-insensitive match
        if let window = windows.first(where: { $0.ownerName.lowercased() == appName.lowercased() }) {
            print("[WindowConfigurationService] findPID: Found case-insensitive match '\(window.ownerName)' - PID: \(window.ownerPID)")
            return window.ownerPID
        }
        print("[WindowConfigurationService] findPID: No case-insensitive match")
        
        // Try partial match
        if let window = windows.first(where: { $0.ownerName.contains(appName) || appName.contains($0.ownerName) }) {
            print("[WindowConfigurationService] findPID: Found partial match '\(window.ownerName)' - PID: \(window.ownerPID)")
            return window.ownerPID
        }
        print("[WindowConfigurationService] findPID: No partial match")
        
        print("[WindowConfigurationService] findPID: Could not find app '\(appName)'")
        return nil
    }
}

