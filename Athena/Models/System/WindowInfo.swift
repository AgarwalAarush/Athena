//
//  WindowInfo.swift
//  Athena
//
//  Created by Claude on 10/30/25.
//

import Foundation
import CoreGraphics

/// Represents information about a window in the system
struct WindowInfo: Codable, Identifiable, Hashable {
    /// Unique identifier for SwiftUI
    let id: UUID

    /// System window number
    let windowNumber: Int

    /// Name of the application that owns this window
    let ownerName: String

    /// Process ID of the window owner
    let ownerPID: pid_t

    /// Window title (may be empty for some windows)
    let title: String

    /// Window bounds in screen coordinates (origin is bottom-left in CoreGraphics)
    let bounds: CGRect

    /// Whether the window is currently visible on screen
    let isOnScreen: Bool

    /// Window layer (lower numbers are behind, higher are in front)
    let layer: Int

    /// Initialize from CoreGraphics window dictionary
    init?(from dict: [String: Any]) {
        guard
            let number = dict[kCGWindowNumber as String] as? Int,
            let owner = dict[kCGWindowOwnerName as String] as? String,
            let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
            let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDict),
            let layer = dict[kCGWindowLayer as String] as? Int
        else { return nil }

        self.id = UUID()
        self.windowNumber = number
        self.ownerName = owner
        self.ownerPID = pid
        self.title = (dict[kCGWindowName as String] as? String) ?? ""
        self.bounds = bounds
        self.isOnScreen = (dict[kCGWindowIsOnscreen as String] as? Bool) ?? false
        self.layer = layer
    }

    /// Manual initializer for testing or custom use
    init(
        id: UUID = UUID(),
        windowNumber: Int,
        ownerName: String,
        ownerPID: pid_t,
        title: String,
        bounds: CGRect,
        isOnScreen: Bool = true,
        layer: Int = 0
    ) {
        self.id = id
        self.windowNumber = windowNumber
        self.ownerName = ownerName
        self.ownerPID = ownerPID
        self.title = title
        self.bounds = bounds
        self.isOnScreen = isOnScreen
        self.layer = layer
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, windowNumber, ownerName, ownerPID, title
        case bounds, isOnScreen, layer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        windowNumber = try container.decode(Int.self, forKey: .windowNumber)
        ownerName = try container.decode(String.self, forKey: .ownerName)
        ownerPID = try container.decode(pid_t.self, forKey: .ownerPID)
        title = try container.decode(String.self, forKey: .title)
        isOnScreen = try container.decode(Bool.self, forKey: .isOnScreen)
        layer = try container.decode(Int.self, forKey: .layer)

        // Decode CGRect
        let boundsData = try container.decode(Data.self, forKey: .bounds)
        guard let decodedBounds = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: boundsData)?.rectValue else {
            throw DecodingError.dataCorruptedError(forKey: .bounds, in: container, debugDescription: "Invalid CGRect data")
        }
        bounds = decodedBounds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(windowNumber, forKey: .windowNumber)
        try container.encode(ownerName, forKey: .ownerName)
        try container.encode(ownerPID, forKey: .ownerPID)
        try container.encode(title, forKey: .title)
        try container.encode(isOnScreen, forKey: .isOnScreen)
        try container.encode(layer, forKey: .layer)

        // Encode CGRect
        let boundsData = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: bounds), requiringSecureCoding: true)
        try container.encode(boundsData, forKey: .bounds)
    }
}

// MARK: - CustomStringConvertible

extension WindowInfo: CustomStringConvertible {
    var description: String {
        "[\(windowNumber)] \(ownerName) (pid \(ownerPID)) \"\(title)\" \(bounds)"
    }
}

// MARK: - Convenience Properties

extension WindowInfo {
    /// Returns true if this window belongs to the specified application
    func belongsTo(application: String) -> Bool {
        ownerName.lowercased() == application.lowercased()
    }

    /// Returns true if this window is likely a utility window (small, no title)
    var isUtilityWindow: Bool {
        title.isEmpty && bounds.width < 200 && bounds.height < 200
    }

    /// Returns the center point of the window
    var center: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }
}
