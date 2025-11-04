//
//  WindowDescriptor.swift
//  Athena
//
//  Created by Claude on 11/4/25.
//

import Foundation
import CoreGraphics

/// Comprehensive descriptor for a window with stable identifiers and workspace tracking
/// Designed for reliable window tracking, restoration, and Cursor workspace management
struct WindowDescriptor: Codable, Hashable, Identifiable {
    /// Unique identifier for SwiftUI and tracking
    let id: UUID

    /// Application bundle identifier (e.g., "com.todesktop.230313mzl4w4u92" for Cursor)
    let bundleID: String

    /// Process ID of the window owner
    let pid: pid_t

    /// CoreGraphics window number (kCGWindowNumber) - stable across moves/resizes
    let windowNumber: Int

    /// Accessibility identifier (if available) - used for AX-based control
    let axIdentifier: String?

    /// Window title from AXTitle attribute
    let title: String?

    /// Workspace URL for Cursor/VS Code windows (folder or .code-workspace file)
    /// This is the key to reopening the exact same Cursor window
    let workspaceURL: URL?

    /// Window frame in global screen coordinates (CoreGraphics coords, origin at top-left of main screen)
    let frame: CGRect

    /// Stable display UUID (from CGDirectDisplayID → UUID)
    /// More reliable than screen index when displays are added/removed
    let displayUUID: UUID?

    /// Optional space identifier hint (for future private API integration)
    let spaceHint: String?

    /// Window layer (z-order)
    let layer: Int

    /// When this descriptor was captured
    let timestamp: Date

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        bundleID: String,
        pid: pid_t,
        windowNumber: Int,
        axIdentifier: String? = nil,
        title: String? = nil,
        workspaceURL: URL? = nil,
        frame: CGRect,
        displayUUID: UUID? = nil,
        spaceHint: String? = nil,
        layer: Int = 0,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.bundleID = bundleID
        self.pid = pid
        self.windowNumber = windowNumber
        self.axIdentifier = axIdentifier
        self.title = title
        self.workspaceURL = workspaceURL
        self.frame = frame
        self.displayUUID = displayUUID
        self.spaceHint = spaceHint
        self.layer = layer
        self.timestamp = timestamp
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, bundleID, pid, windowNumber, axIdentifier, title
        case workspaceURL, frame, displayUUID, spaceHint, layer, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        pid = try container.decode(pid_t.self, forKey: .pid)
        windowNumber = try container.decode(Int.self, forKey: .windowNumber)
        axIdentifier = try container.decodeIfPresent(String.self, forKey: .axIdentifier)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        workspaceURL = try container.decodeIfPresent(URL.self, forKey: .workspaceURL)
        displayUUID = try container.decodeIfPresent(UUID.self, forKey: .displayUUID)
        spaceHint = try container.decodeIfPresent(String.self, forKey: .spaceHint)
        layer = try container.decode(Int.self, forKey: .layer)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        // Decode CGRect
        let frameData = try container.decode(Data.self, forKey: .frame)
        guard let decodedFrame = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: frameData)?.rectValue else {
            throw DecodingError.dataCorruptedError(forKey: .frame, in: container, debugDescription: "Invalid CGRect data")
        }
        frame = decodedFrame
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(pid, forKey: .pid)
        try container.encode(windowNumber, forKey: .windowNumber)
        try container.encodeIfPresent(axIdentifier, forKey: .axIdentifier)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(workspaceURL, forKey: .workspaceURL)
        try container.encodeIfPresent(displayUUID, forKey: .displayUUID)
        try container.encodeIfPresent(spaceHint, forKey: .spaceHint)
        try container.encode(layer, forKey: .layer)
        try container.encode(timestamp, forKey: .timestamp)

        // Encode CGRect
        let frameData = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: frame), requiringSecureCoding: true)
        try container.encode(frameData, forKey: .frame)
    }
}

// MARK: - CustomStringConvertible

extension WindowDescriptor: CustomStringConvertible {
    var description: String {
        var parts = ["[WinNum:\(windowNumber)]", bundleID]
        if let title = title {
            parts.append("\"\(title)\"")
        }
        if let workspace = workspaceURL {
            parts.append("workspace:\(workspace.lastPathComponent)")
        }
        parts.append("frame:\(frame)")
        return parts.joined(separator: " ")
    }
}

// MARK: - Convenience Properties

extension WindowDescriptor {
    /// Returns true if this is a Cursor or VS Code window
    var isCursorOrVSCode: Bool {
        bundleID.contains("cursor") ||
        bundleID.contains("vscode") ||
        bundleID.contains("code-oss")
    }

    /// Returns true if this window has a workspace URL (e.g., for Cursor)
    var hasWorkspace: Bool {
        workspaceURL != nil
    }

    /// Returns the center point of the window
    var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    /// Returns a short identifier for debugging
    var shortID: String {
        "[\(windowNumber)]"
    }
}
