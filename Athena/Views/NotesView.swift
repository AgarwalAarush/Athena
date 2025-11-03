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
            // Back button
            HStack {
                Button(action: {
                    Task {
                        await vm.closeEditor()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Spacer()
            }
            .background(Color.clear)
            
            // Rich text editor
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
}
