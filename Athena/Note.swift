//
//  Note.swift
//  SwiftData model for notes with creation and modification tracking
//

import Foundation
import SwiftData

/// SwiftData model representing a single note.
///
/// Design rationale:
/// - @Model macro provides automatic persistence and change tracking
/// - @Attribute(.unique) on id ensures each note is uniquely identifiable in the database
/// - createdAt and modifiedAt support chronological sorting and modification tracking
/// - content stores the plain text representation (can be RTF/attributed text in future)
@Model
final class Note {

    /// Unique identifier for this note.
    /// @Attribute(.unique) prevents duplicate notes and enables efficient lookups.
    @Attribute(.unique) var id: UUID

    /// The note's text content (plain text representation).
    var content: String

    /// Timestamp when this note was created (immutable after initialization).
    var createdAt: Date

    /// Timestamp when this note was last modified.
    /// Updated via updateContent(_:) to ensure consistency.
    var modifiedAt: Date

    /// Convenience initializer with sensible defaults.
    /// Creates a new note with current timestamp and empty content.
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

    /// Updates the note's content and modification timestamp atomically.
    ///
    /// Design rationale: Centralizing content updates ensures modifiedAt
    /// is always updated when content changes, maintaining data integrity.
    func updateContent(_ newContent: String) {
        self.content = newContent
        self.modifiedAt = Date()
    }
}
