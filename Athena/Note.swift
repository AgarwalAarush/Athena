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
@Model
final class Note {

    /// Unique identifier for this note.
    @Attribute(.unique) var id: UUID

    /// The note's text content.
    var content: String

    /// Timestamp when this note was created.
    var createdAt: Date

    /// Timestamp when this note was last modified.
    var modifiedAt: Date

    /// Initializes a new note with optional parameters.
    init(
        id: UUID = UUID(),
        content: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Updates the note's content and modification timestamp.
    func updateContent(_ newContent: String) {
        self.content = newContent
        self.modifiedAt = Date()
    }
}
