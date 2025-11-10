//
//  NoteListView.swift
//  Athena
//
//  Created by Aarush Agarwal on 11/02/25.
//

import SwiftUI

struct NoteListView: View {
    @ObservedObject var vm: NotesViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notes")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    Task {
                        await vm.createNewNote()
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // Notes list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.notes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title.isEmpty ? "Untitled" : note.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            if !note.body.isEmpty {
                                Text(note.body)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .onTapGesture {
                            vm.selectNote(note)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task {
                                    await vm.deleteNote(note)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}