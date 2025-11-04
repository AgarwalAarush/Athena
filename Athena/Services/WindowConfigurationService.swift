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
    private let windowRegistry: WindowRegistry
    private let windowRestoreService: WindowRestoreService

    init(
        windowManager: SystemWindowManaging = SystemWindowManager.shared,
        screenManager: ScreenManaging = ScreenManager.shared,
        database: DatabaseManager = DatabaseManager.shared,
        systemTool: SystemTool = SystemTool.shared,
        windowRegistry: WindowRegistry = WindowRegistry.shared,
        windowRestoreService: WindowRestoreService = WindowRestoreService.shared
    ) {
        self.windowManager = windowManager
        self.screenManager = screenManager
        self.database = database
        self.systemTool = systemTool
        self.windowRegistry = windowRegistry
        self.windowRestoreService = windowRestoreService

        // Start tracking windows if not already tracking
        do {
            try windowRegistry.startTracking()
        } catch {
            print("[WindowConfigurationService] Warning: Could not start window tracking: \(error)")
        }
    }
    
    // MARK: - Public API
    
    /// Saves the current window configuration with the given name
    func saveConfiguration(name: String) throws -> WindowConfiguration {
        print("[WindowConfigurationService] Saving configuration '\(name)'")

        // Get all tracked windows from WindowRegistry
        // Refresh first to ensure we have latest positions
        windowRegistry.refresh()
        let windowDescriptors = windowRegistry.allWindows()

        // Convert WindowDescriptors to SavedWindowInfo
        let savedWindows = windowDescriptors.map { descriptor in
            SavedWindowInfo(from: descriptor)
        }

        // Check if configuration with this name already exists
        if let existing = try? database.fetchWindowConfiguration(name: name) {
            // Delete the old one first
            try database.deleteWindowConfiguration(name: name)
        }

        // Save to database
        let configuration = try database.createWindowConfiguration(name: name, windows: savedWindows)

        print("[WindowConfigurationService] Saved '\(name)' with \(savedWindows.count) windows")
        print("[WindowConfigurationService] Including \(savedWindows.filter { $0.workspaceURL != nil }.count) Cursor/VS Code workspaces")
        return configuration
    }
    
    /// Restores a window configuration by name
    func restoreConfiguration(name: String) async throws {
        print("[WindowConfigurationService] Restoring configuration '\(name)'")

        // Fetch configuration from database
        guard let configuration = try database.fetchWindowConfiguration(name: name) else {
            throw NSError(domain: "WindowConfigurationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Configuration '\(name)' not found"])
        }

        print("[WindowConfigurationService] Found configuration with \(configuration.windows.count) windows")

        // Convert SavedWindowInfo to WindowDescriptors
        let descriptors = configuration.windows.map { $0.toWindowDescriptor() }

        // Count Cursor workspaces
        let workspaceCount = descriptors.filter { $0.hasWorkspace }.count
        if workspaceCount > 0 {
            print("[WindowConfigurationService] Restoring \(workspaceCount) Cursor/VS Code workspaces")
        }

        // Use WindowRestoreService for restoration
        let restoredCount = try await windowRestoreService.restoreWindows(descriptors)

        print("[WindowConfigurationService] Restore complete - restored \(restoredCount)/\(descriptors.count) windows")
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
}

