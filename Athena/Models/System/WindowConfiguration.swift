//
//  WindowConfiguration.swift
//  Athena
//
//  Created by Cursor on 11/4/25.
//

import Foundation
import GRDB
import CoreGraphics

/// Represents a saved window configuration that can be restored later
struct WindowConfiguration: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var windows: [SavedWindowInfo]
    
    static let databaseTableName = "window_configurations"
    
    // Define columns for type-safe queries
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
    
    // Relationship to windows
    static let configurationWindows = hasMany(SavedWindowInfo.self)
    
    // Default initializer
    init(
        id: Int64? = nil,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        windows: [SavedWindowInfo] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.windows = windows
    }
    
    // Custom coding keys to exclude windows from direct persistence
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case updatedAt
    }
    
    // Custom decoder to handle the structure
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        windows = [] // Default to an empty array, as it's not in the encoded data
    }

    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Convenience Methods
extension WindowConfiguration {
    mutating func updateTimestamp() {
        updatedAt = Date()
    }
    
    var windowCount: Int {
        windows.count
    }
}

/// Simplified window information optimized for database storage
struct SavedWindowInfo: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var configId: Int64?
    var appName: String
    var bundleID: String?
    var windowTitle: String
    var windowNumber: Int?
    var axIdentifier: String?
    var workspaceURL: String?  // Stored as string for database compatibility
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var screenIndex: Int  // Kept for backward compatibility
    var displayUUID: String?  // New: stable display identifier
    var layer: Int

    static let databaseTableName = "window_configuration_windows"

    // Define columns for type-safe queries
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let configId = Column(CodingKeys.configId)
        static let appName = Column(CodingKeys.appName)
        static let bundleID = Column(CodingKeys.bundleID)
        static let windowTitle = Column(CodingKeys.windowTitle)
        static let windowNumber = Column(CodingKeys.windowNumber)
        static let axIdentifier = Column(CodingKeys.axIdentifier)
        static let workspaceURL = Column(CodingKeys.workspaceURL)
        static let x = Column(CodingKeys.x)
        static let y = Column(CodingKeys.y)
        static let width = Column(CodingKeys.width)
        static let height = Column(CodingKeys.height)
        static let screenIndex = Column(CodingKeys.screenIndex)
        static let displayUUID = Column(CodingKeys.displayUUID)
        static let layer = Column(CodingKeys.layer)
    }

    // Relationship to configuration
    static let configuration = belongsTo(WindowConfiguration.self)

    // Initialize from WindowDescriptor
    init(from descriptor: WindowDescriptor) {
        self.id = nil
        self.configId = nil
        self.appName = descriptor.bundleID.components(separatedBy: ".").last ?? descriptor.bundleID
        self.bundleID = descriptor.bundleID
        self.windowTitle = descriptor.title ?? ""
        self.windowNumber = descriptor.windowNumber
        self.axIdentifier = descriptor.axIdentifier
        self.workspaceURL = descriptor.workspaceURL?.absoluteString
        self.x = descriptor.frame.origin.x
        self.y = descriptor.frame.origin.y
        self.width = descriptor.frame.width
        self.height = descriptor.frame.height
        self.screenIndex = 0  // Default for backward compatibility
        self.displayUUID = descriptor.displayUUID?.uuidString
        self.layer = descriptor.layer
    }

    // Initialize from WindowInfo (backward compatibility)
    init(from windowInfo: WindowInfo, screenIndex: Int) {
        self.id = nil
        self.configId = nil
        self.appName = windowInfo.ownerName
        self.bundleID = nil
        self.windowTitle = windowInfo.title
        self.windowNumber = windowInfo.windowNumber
        self.axIdentifier = nil
        self.workspaceURL = nil
        self.x = windowInfo.bounds.origin.x
        self.y = windowInfo.bounds.origin.y
        self.width = windowInfo.bounds.width
        self.height = windowInfo.bounds.height
        self.screenIndex = screenIndex
        self.displayUUID = nil
        self.layer = windowInfo.layer
    }

    // Full initializer
    init(
        id: Int64? = nil,
        configId: Int64? = nil,
        appName: String,
        bundleID: String? = nil,
        windowTitle: String,
        windowNumber: Int? = nil,
        axIdentifier: String? = nil,
        workspaceURL: String? = nil,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        screenIndex: Int,
        displayUUID: String? = nil,
        layer: Int
    ) {
        self.id = id
        self.configId = configId
        self.appName = appName
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.windowNumber = windowNumber
        self.axIdentifier = axIdentifier
        self.workspaceURL = workspaceURL
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.screenIndex = screenIndex
        self.displayUUID = displayUUID
        self.layer = layer
    }
    
    var bounds: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    
    var origin: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

// MARK: - CustomStringConvertible
extension SavedWindowInfo: CustomStringConvertible {
    var description: String {
        "\(appName) - \"\(windowTitle)\" at (\(Int(x)), \(Int(y))) size \(Int(width))x\(Int(height))"
    }
}

// MARK: - Conversion to WindowDescriptor
extension SavedWindowInfo {
    /// Converts SavedWindowInfo to WindowDescriptor
    /// Note: PID will be 0 and needs to be resolved when restoring
    func toWindowDescriptor() -> WindowDescriptor {
        return WindowDescriptor(
            bundleID: bundleID ?? appName,
            pid: 0,  // Will be resolved during restore
            windowNumber: windowNumber ?? -1,
            axIdentifier: axIdentifier,
            title: windowTitle.isEmpty ? nil : windowTitle,
            workspaceURL: workspaceURL.flatMap { URL(string: $0) },
            frame: CGRect(x: x, y: y, width: width, height: height),
            displayUUID: displayUUID.flatMap { UUID(uuidString: $0) },
            spaceHint: nil,
            layer: layer,
            timestamp: Date()
        )
    }
}

