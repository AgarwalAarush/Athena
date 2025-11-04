

//
//  NotesViewModel.swift
//  Athena
//
//  Created by Aarush Agarwal on 11/02/25.
//

import Foundation
import Combine

/// State machine for notes listen mode
enum ListenModeState: Equatable {
    case idle
    case listening
    case processing  // LLM formatting
    case error(String)
}

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
    
    // MARK: - Listen Mode Properties
    
    @Published var listenModeState: ListenModeState = .idle
    @Published var listenModePartialTranscript: String = ""
    
    private var listenModeManager: NotesListenModeManager?
    private weak var appViewModel: AppViewModel?
    private var listenModeCancellables = Set<AnyCancellable>()

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
        // Stop listen mode if active
        if listenModeState != .idle {
            print("[NotesViewModel] 📝 Stopping listen mode on editor close")
            stopListenMode()
        }
        
        await saveCurrentNoteIfChanged()
        currentNote = nil
    }

    func onEditorBecameInactive() async {
        await saveCurrentNoteIfChanged()
    }

    func onAppBackgrounding() async {
        // Stop listen mode if active
        if listenModeState != .idle {
            print("[NotesViewModel] 📝 Stopping listen mode on app backgrounding")
            stopListenMode()
        }
        
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
    
    // MARK: - Listen Mode Methods
    
    /// Set the AppViewModel reference for wake word control
    func setAppViewModel(_ appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }
    
    /// Start listen mode for voice dictation
    func startListenMode() {
        print("[NotesViewModel] 🎤 Starting listen mode")
        
        guard listenModeState == .idle else {
            print("[NotesViewModel] ⚠️ Listen mode already active, ignoring")
            return
        }
        
        // Pause wake word mode
        appViewModel?.pauseWakeWord()
        
        // Create and start listen mode manager
        let manager = NotesListenModeManager()
        self.listenModeManager = manager
        
        // Subscribe to manager events
        manager.$state
            .sink { [weak self] state in
                guard let self = self else { return }
                
                switch state {
                case .idle:
                    if self.listenModeState != .processing {
                        self.listenModeState = .idle
                    }
                case .listening:
                    self.listenModeState = .listening
                case .error(let message):
                    self.listenModeState = .error(message)
                    // Resume wake word on error
                    self.appViewModel?.resumeWakeWord()
                }
            }
            .store(in: &listenModeCancellables)
        
        manager.$partialTranscript
            .sink { [weak self] transcript in
                self?.listenModePartialTranscript = transcript
            }
            .store(in: &listenModeCancellables)
        
        manager.$finalTranscript
            .compactMap { $0 }
            .sink { [weak self] transcript in
                self?.handleFinalTranscript(transcript)
            }
            .store(in: &listenModeCancellables)
        
        // Start the manager
        Task {
            do {
                try await manager.start()
                print("[NotesViewModel] ✅ Listen mode started")
            } catch {
                print("[NotesViewModel] ❌ Error starting listen mode: \(error)")
                listenModeState = .error(error.localizedDescription)
                appViewModel?.resumeWakeWord()
            }
        }
    }
    
    /// Stop listen mode manually (without transcript)
    func stopListenMode() {
        print("[NotesViewModel] 🛑 Stopping listen mode manually")
        
        guard listenModeState != .idle else {
            print("[NotesViewModel] ⚠️ Listen mode already idle")
            return
        }
        
        // Stop the manager
        listenModeManager?.stop()
        
        // Clean up
        cleanup()
    }
    
    /// Handle final transcript from listen mode
    private func handleFinalTranscript(_ transcript: String) {
        print("[NotesViewModel] 📝 Handling final transcript: '\(transcript)'")
        
        guard !transcript.isEmpty else {
            print("[NotesViewModel] ⚠️ Empty transcript, skipping formatting")
            cleanup()
            return
        }
        
        // Set state to processing
        listenModeState = .processing
        
        // Format and insert transcript
        Task {
            await formatAndInsertTranscript(transcript)
        }
    }
    
    /// Format transcript using LLM and insert into note
    private func formatAndInsertTranscript(_ transcript: String) async {
        print("[NotesViewModel] 🤖 Formatting transcript with LLM")
        
        let systemPrompt = """
        Format the following dictated text into well-structured note content. Add proper punctuation, paragraph breaks, and capitalization. Preserve the meaning and intent. Return only the formatted text without any preamble. The formatted text should be for a txt file, NO markdown formatting.
        
        Dictated text:
        \(transcript)
        """
        
        do {
            // Get the configured provider and model
            let configManager = ConfigurationManager.shared
            let providerName = configManager.getString(.selectedProvider)
            let modelName = configManager.getString(.selectedModel)
            
            guard let provider = AIProvider(rawValue: providerName) else {
                throw NSError(domain: "NotesViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid AI provider: \(providerName)"])
            }
            
            // Use AIService to get formatted text
            let formattedText = try await AIService.shared.getCompletion(
                prompt: systemPrompt,
                systemPrompt: nil,
                provider: provider,
                model: modelName
            )
            
            print("[NotesViewModel] ✅ LLM formatting complete")
            
            // Insert formatted text into note
            let trimmedText = formattedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            insertTextIntoNote(trimmedText)
            
        } catch {
            print("[NotesViewModel] ❌ Error formatting transcript: \(error)")
            
            // Fallback: insert raw transcript
            print("[NotesViewModel] 📝 Inserting raw transcript as fallback")
            insertTextIntoNote(transcript)
        }
        
        // Clean up and return to idle
        cleanup()
    }
    
    /// Insert text into the current note
    private func insertTextIntoNote(_ text: String) {
        print("[NotesViewModel] 📄 Inserting text into note")
        
        // Set flag to prevent auto-save triggering during programmatic update
        isProgrammaticSet = true
        
        // Append to note content with a newline separator
        if noteContent.isEmpty {
            noteContent = text
        } else {
            // Add newline if content doesn't end with one
            let separator = noteContent.hasSuffix("\n") ? "" : "\n"
            noteContent += separator + text
        }
        
        // Reset flag after a brief delay
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            self.isProgrammaticSet = false
        }
    }
    
    /// Clean up listen mode resources
    private func cleanup() {
        print("[NotesViewModel] 🧹 Cleaning up listen mode")
        
        // Set state to idle FIRST to prevent any state updates during cleanup
        listenModeState = .idle
        listenModePartialTranscript = ""
        
        // Remove subscriptions to stop listening to manager updates
        listenModeCancellables.removeAll()
        
        // Release the manager
        listenModeManager = nil
        
        // Resume wake word mode
        appViewModel?.resumeWakeWord()
        
        print("[NotesViewModel] ✅ Listen mode cleanup complete")
    }
}
