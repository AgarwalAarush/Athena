//
//  NotesViewModel.swift
//  View model for notes with debounced autosave and title/body splitting
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class NotesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var notes: [NoteModel] = []
    @Published var noteContent: String = ""
    @Published var currentNoteID: UUID?
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    fileprivate(set) var isProgrammaticSet = false
    private var currentNoteSnapshot: NoteModel?
    private let store: NotesStore
    
    // MARK: - Initialization
    
    init(store: NotesStore) {
        self.store = store
    }
    
    // MARK: - Lifecycle
    
    func bootstrap() async {
        await fetchNotes()
        if let first = notes.first {
            selectNote(first)
        }
    }
    
    func fetchNotes() async {
        do {
            notes = try await store.fetchAll()
        } catch {
            lastError = "\(error)"
            notes = []
        }
    }
    
    // MARK: - Note Selection
    
    func selectNote(_ note: NoteModel) {
        // Save current note before switching
        if currentNoteID != nil && currentNoteID != note.id {
            Task {
                await saveCurrentNoteIfChanged()
            }
        }
        
        currentNoteID = note.id
        currentNoteSnapshot = note
        isProgrammaticSet = true
        noteContent = note.body
        isProgrammaticSet = false
    }
    
    // MARK: - Note Creation
    
    func createNewNote() async {
        // Save current note first
        await saveCurrentNoteIfChanged()
        
        let now = Date()
        let note = NoteModel(
            id: UUID(),
            title: "Untitled",
            body: "",
            createdAt: now,
            modifiedAt: now
        )
        
        do {
            try await store.save(note)
            await fetchNotes()
            if let saved = try await store.fetch(id: note.id) {
                selectNote(saved)
            }
        } catch {
            lastError = "\(error)"
        }
    }
    
    // MARK: - Note Deletion
    
    func deleteNote(_ note: NoteModel) async {
        do {
            try await store.delete(id: note.id)
            await fetchNotes()
            
            if currentNoteID == note.id {
                currentNoteID = nil
                currentNoteSnapshot = nil
                isProgrammaticSet = true
                noteContent = ""
                isProgrammaticSet = false
            }
        } catch {
            lastError = "\(error)"
        }
    }
    
    // MARK: - Saving
    
    func saveCurrentNoteIfChanged() async {
        guard var snap = currentNoteSnapshot else { return }
        
        let (title, body) = Self.splitTitleBody(noteContent)
        
        // Only save if something changed
        guard title != snap.title || body != snap.body else { return }
        
        snap.title = title
        snap.body = body
        snap.modifiedAt = Date()
        
        do {
            try await store.save(snap)
            currentNoteSnapshot = snap
            
            // Update the note in the list to reflect new title
            if let index = notes.firstIndex(where: { $0.id == snap.id }) {
                notes[index] = snap
            }
        } catch {
            lastError = "\(error)"
        }
    }
    
    func onAppBackgrounding() async {
        await saveCurrentNoteIfChanged()
    }
    
    func onEditorBecameInactive() async {
        await saveCurrentNoteIfChanged()
    }
    
    // MARK: - Title/Body Splitting
    
    static func splitTitleBody(_ text: String) -> (title: String, body: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let rawTitle = lines.first.map(String.init) ?? ""
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : rawTitle
        let body = lines.dropFirst().joined(separator: "\n")
        return (title, body)
    }
}

