//
//  NotesStore.swift
//  Protocol defining persistence operations for notes
//

import Foundation

/// Protocol for abstracting note persistence operations.
/// Enables swapping between SwiftData, SQLite, or other backends without touching UI.
protocol NotesStore {
    
    /// Saves a note (create or update).
    /// - Parameter note: The note to save
    /// - Throws: Persistence errors
    func save(_ note: NoteModel) async throws
    
    /// Fetches a single note by ID.
    /// - Parameter id: The note's unique identifier
    /// - Returns: The note if found, nil otherwise
    /// - Throws: Persistence errors
    func fetch(id: UUID) async throws -> NoteModel?
    
    /// Fetches all notes, sorted by modification date (descending).
    /// - Returns: Array of notes sorted by modifiedAt desc
    /// - Throws: Persistence errors
    func fetchAll() async throws -> [NoteModel]
    
    /// Deletes a note by ID.
    /// - Parameter id: The note's unique identifier
    /// - Throws: Persistence errors
    func delete(id: UUID) async throws
    
    /// Searches notes by query string (case-insensitive contains in title or body).
    /// - Parameter query: Search string
    /// - Returns: Array of matching notes
    /// - Throws: Persistence errors
    func search(query: String) async throws -> [NoteModel]
}

