//
//  NoteListView.swift
//  List of notes with white 0.6 opacity background
//

import SwiftUI

struct NoteListView: View {
    @ObservedObject var vm: NotesViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with note count and new note button
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await vm.createNewNote()
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("New Note")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Notes list
                VStack(spacing: 1) {
                    ForEach(vm.notes) { note in
                        NoteRowView(note: note, vm: vm)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.white.opacity(0.6)
                .cornerRadius(8)
        )
        .padding()
    }
}

struct NoteRowView: View {
    let note: NoteModel
    @ObservedObject var vm: NotesViewModel
    
    var body: some View {
        Button(action: {
            vm.selectNote(note)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.headline)
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    Text(note.modifiedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .contextMenu {
            Button("Delete", role: .destructive) {
                Task {
                    await vm.deleteNote(note)
                }
            }
        }
    }
}

