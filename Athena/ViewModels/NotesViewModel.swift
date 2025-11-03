

//
//  NotesViewModel.swift
//  Athena
//
//  Created by Aarush Agarwal on 11/02/25.
//

import Foundation
import Combine

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [NoteModel] = []
    @Published var currentNote: NoteModel? {
        didSet {
            if let note = currentNote {
                noteContent = "\(note.title)\n\(note.body)"
                showingEditor = true
            } else {
                noteContent = ""
                showingEditor = false
            }
        }
    }
    @Published var noteContent: String = ""
    @Published var showingEditor = false
    @Published var isProgrammaticSet = false

    private let store: NotesStore

    init(store: NotesStore) {
        self.store = store
    }

    func bootstrap() async {
        await fetchNotes()
    }

    func fetchNotes() async {
        do {
            notes = try await store.fetchAll()
        } catch {
            print("Error fetching notes: \(error)")
        }
    }

    func selectNote(_ note: NoteModel) {
        currentNote = note
    }

    func createNewNote() {
        let newNote = NoteModel(title: "Untitled Note", body: "")
        currentNote = newNote
    }

    func closeEditor() async {
        await saveCurrentNoteIfChanged()
        currentNote = nil
    }

    func onEditorBecameInactive() async {
        await saveCurrentNoteIfChanged()
    }

    func onAppBackgrounding() async {
        await saveCurrentNoteIfChanged()
    }

    func saveCurrentNoteIfChanged() async {
        guard var note = currentNote else { return }

        let lines = noteContent.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let title = String(lines.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = lines.count > 1 ? String(lines[1]) : ""

        if note.title == title && note.body == body {
            return // No changes
        }

        // Update the note (NoteModel is a struct, so we need to create a new one)
        note = NoteModel(
            id: note.id,
            title: title.isEmpty ? "Untitled Note" : title,
            body: body,
            createdAt: note.createdAt,
            modifiedAt: Date()
        )
        currentNote = note

        do {
            try await store.save(note)
            await fetchNotes()
        } catch {
            print("Error saving note: \(error)")
        }
    }

    func deleteNote(_ note: NoteModel) async {
        do {
            try await store.delete(id: note.id)
            if currentNote?.id == note.id {
                currentNote = nil
            }
            await fetchNotes()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
    
    func searchNotes(query: String) -> [NoteModel] {
        return notes.filter { $0.title.lowercased().contains(query.lowercased()) }
    }
}
