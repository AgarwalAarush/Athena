
//
//  SwiftDataNotesStore.swift
//  Athena
//
//  Created by Aarush Agarwal on 11/02/25.
//

import Foundation
import SwiftData

class SwiftDataNotesStore: NotesStore {
    private var modelContainer: ModelContainer?

    @MainActor
    func bootstrap() async {
        do {
            modelContainer = try ModelContainer(for: Note.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    func fetchNotes() async throws -> [Note] {
        guard let modelContainer = modelContainer else { throw NotesStoreError.notInitialized }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\Note.modifiedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func saveNote(_ note: Note) async throws {
        guard let modelContainer = modelContainer else { throw NotesStoreError.notInitialized }
        let context = ModelContext(modelContainer)
        context.insert(note)
        try context.save()
    }

    func deleteNote(_ note: Note) async throws {
        guard let modelContainer = modelContainer else { throw NotesStoreError.notInitialized }
        let context = ModelContext(modelContainer)
        context.delete(note)
        try context.save()
    }
}

enum NotesStoreError: Error {
    case notInitialized
}
