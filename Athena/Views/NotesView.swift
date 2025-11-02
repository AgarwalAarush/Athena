//
//  NotesView.swift
//  Main notes editor with debounced autosave
//

import SwiftUI
import Combine

struct NotesView: View {
    @ObservedObject var vm: NotesViewModel
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: {
                    Task {
                        await vm.createNewNote()
                    }
                }) {
                    Label("New Note", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                Spacer()
            }
            .background(Color.clear)
            
            Divider()
            
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
            .padding()
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
