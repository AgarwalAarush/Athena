//
//  SwiftDataNotesStore.swift
//  SwiftData implementation of NotesStore protocol
//

import Foundation
import SwiftData

/// SwiftData-backed implementation of NotesStore.
/// Maps between NoteModel (view layer) and Note (SwiftData model).
@MainActor
final class SwiftDataNotesStore: NotesStore {
    
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    init() {
        do {
            let schema = Schema([Note.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    func save(_ note: NoteModel) async throws {
        // Try to find existing note
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == note.id }
        )
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            // Update existing
            existing.update(title: note.title, body: note.body)
        } else {
            // Create new
            let newNote = Note(
                id: note.id,
                title: note.title,
                body: note.body,
                createdAt: note.createdAt,
                modifiedAt: note.modifiedAt
            )
            modelContext.insert(newNote)
        }
        
        try modelContext.save()
    }
    
    func fetch(id: UUID) async throws -> NoteModel? {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == id }
        )
        guard let note = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return mapToModel(note)
    }
    
    func fetchAll() async throws -> [NoteModel] {
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        let notes = try modelContext.fetch(descriptor)
        return notes.map(mapToModel)
    }
    
    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == id }
        )
        if let note = try modelContext.fetch(descriptor).first {
            modelContext.delete(note)
            try modelContext.save()
        }
    }
    
    func search(query: String) async throws -> [NoteModel] {
        let lowercaseQuery = query.lowercased()
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        let allNotes = try modelContext.fetch(descriptor)
        
        // Filter in memory (SwiftData predicates don't support case-insensitive contains easily)
        let filtered = allNotes.filter { note in
            note.title.lowercased().contains(lowercaseQuery) ||
            note.body.lowercased().contains(lowercaseQuery)
        }
        
        return filtered.map(mapToModel)
    }
    
    // MARK: - Mapping
    
    private func mapToModel(_ note: Note) -> NoteModel {
        NoteModel(
            id: note.id,
            title: note.title,
            body: note.body,
            createdAt: note.createdAt,
            modifiedAt: note.modifiedAt
        )
    }
}

