//
//  NotesView.swift
//  Main container for notes - shows list or editor
//

import SwiftUI
import Combine

struct NotesView: View {
    @ObservedObject var vm: NotesViewModel
    
    var body: some View {
        ZStack {
            if vm.showingEditor {
                NoteEditorView(vm: vm)
            } else {
                NoteListView(vm: vm)
            }
        }
        .task {
            await vm.bootstrap()
        }
    }
}

struct NoteEditorView: View {
    @ObservedObject var vm: NotesViewModel
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and listen buttod
            HStack {
                // Back button
                Button(action: {
                    Task {
                        await vm.closeEditor()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.accentColor)
                    Text("Back").foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Spacer()
                
                // Listen mode button
                Button(action: {
                    toggleListenMode()
                }) {
                    listenModeIcon
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.clear)
            
            // Rich text editor
            ZStack(alignment: .bottom) {
                RichTextEditor(
                    content: $vm.noteContent,
                    onFocusLost: {
                        Task {
                            await vm.onEditorBecameInactive()
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal)
                .padding(.bottom)
                
                // Transcript overlay (shown when listening)
                if case .listening = vm.listenModeState {
                    transcriptOverlay
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onReceive(
            vm.$noteContent
                .dropFirst()
                .debounce(for: .seconds(1.2), scheduler: RunLoop.main)
        ) { _ in
            guard !vm.isProgrammaticSet else { return }
            Task {
                await vm.saveCurrentNoteIfChanged()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                Task {
                    await vm.onAppBackgrounding()
                }
            }
        }
    }
    
    // MARK: - Listen Mode UI Components
    
    /// Icon for listen mode button (changes based on state)
    private var listenModeIcon: some View {
        Group {
            switch vm.listenModeState {
            case .idle:
                Image(systemName: "mic.fill")
                    .foregroundColor(.gray)
            case .listening:
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, options: .repeating)
            case .processing:
                ProgressView()
                    .scaleEffect(0.8)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
            }
        }
        .frame(width: 24, height: 24)
    }
    
    /// Transcript overlay shown during listening
    private var transcriptOverlay: some View {
        VStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Listening...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !vm.listenModePartialTranscript.isEmpty {
                    Text(vm.listenModePartialTranscript)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                
                Text("Say 'Athena stop listening' or tap mic to finish")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding()
        }
    }
    
    // MARK: - Actions
    
    /// Toggle listen mode on/off
    private func toggleListenMode() {
        switch vm.listenModeState {
        case .idle:
            vm.startListenMode()
        case .listening:
            vm.stopListenMode()
        case .processing, .error:
            // Do nothing while processing or in error state
            break
        }
    }
}
