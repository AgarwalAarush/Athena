

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
    @Published var notes: [Note] = []
    @Published var currentNote: Note? {
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
        await store.bootstrap()
        await fetchNotes()
    }

    func fetchNotes() async {
        do {
            notes = try await store.fetchNotes()
        } catch {
            print("Error fetching notes: \(error)")
        }
    }

    func selectNote(_ note: Note) {
        currentNote = note
    }

    func createNewNote() {
        let newNote = Note(title: "Untitled Note", body: "")
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
        guard let note = currentNote else { return }

        let lines = noteContent.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let title = String(lines.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = lines.count > 1 ? String(lines[1]) : ""

        if note.title == title && note.body == body {
            return // No changes
        }

        note.update(title: title.isEmpty ? "Untitled Note" : title, body: body)

        do {
            try await store.saveNote(note)
            await fetchNotes()
        } catch {
            print("Error saving note: \(error)")
        }
    }

    func deleteNote(_ note: Note) async {
        do {
            try await store.deleteNote(note)
            if currentNote?.id == note.id {
                currentNote = nil
            }
            await fetchNotes()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
    
    func searchNotes(query: String) -> [Note] {
        return notes.filter { $0.title.lowercased().contains(query.lowercased()) }
    }
}
