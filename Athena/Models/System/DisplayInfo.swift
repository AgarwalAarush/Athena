//
//  DisplayInfo.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import CoreGraphics

/// Serializable representation of an attached macOS display
struct DisplayInfo: Codable, Identifiable, Hashable {
    /// Backing identifier provided by CoreGraphics
    let id: CGDirectDisplayID

    /// Human-readable name, if available
    let name: String

    /// Full frame of the display in CoreGraphics coordinates (origin bottom-left)
    let frame: CGRect

    /// Visible frame excluding menu bar and dock (if reported)
    let visibleFrame: CGRect

    /// Backing scale factor for point-to-pixel conversion
    let scaleFactor: CGFloat

    /// Indicates whether this is the primary display
    let isMain: Bool

    init(
        id: CGDirectDisplayID,
        name: String,
        frame: CGRect,
        visibleFrame: CGRect,
        scaleFactor: CGFloat,
        isMain: Bool
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scaleFactor = scaleFactor
        self.isMain = isMain
    }
}
