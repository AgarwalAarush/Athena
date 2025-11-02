//
//  Note.swift
//  SwiftData model for notes with creation and modification tracking
//

import Foundation
import SwiftData

/// SwiftData model representing a single note.
///
/// Uses @Model for automatic persistence and @Attribute(.unique) on id for database uniqueness.
/// Tracks creation and modification timestamps for sorting and history.
/// Stores both title (derived from first line) and body for efficient querying and display.
@Model
final class Note {

    /// Unique identifier for this note.
    @Attribute(.unique) var id: UUID

    /// The note's title (derived from first line, stored for efficient queries).
    var title: String

    /// The note's body content (all lines after the first).
    var body: String

    /// Timestamp when this note was created.
    var createdAt: Date

    /// Timestamp when this note was last modified.
    var modifiedAt: Date

    /// Initializes a new note with optional parameters.
    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        body: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Updates the note's title, body, and modification timestamp.
    func update(title: String, body: String) {
        self.title = title
        self.body = body
        self.modifiedAt = Date()
    }
}
