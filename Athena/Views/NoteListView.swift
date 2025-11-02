//
//  NoteListView.swift
//  Sidebar list of notes with selection and context menu
//

import SwiftUI

struct NoteListView: View {
    @ObservedObject var vm: NotesViewModel
    
    var body: some View {
        List(selection: Binding(
            get: { vm.currentNoteID },
            set: { newID in
                if let id = newID, let note = vm.notes.first(where: { $0.id == id }) {
                    vm.selectNote(note)
                }
            }
        )) {
            ForEach(vm.notes) { note in
                HStack {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .lineLimit(1)
                    Spacer()
                    Text(note.modifiedAt, style: .relative)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .tag(note.id)
                .contextMenu {
                    Button("Delete") {
                        Task {
                            await vm.deleteNote(note)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

