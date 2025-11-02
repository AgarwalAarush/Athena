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
        VStack {
            HStack {
                Text("Notes")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Button(action: {
                    vm.createNewNote()
                }) {
                    Image(systemName: "plus")
                }
            }
            .padding()

            List(vm.notes) { note in
                VStack(alignment: .leading) {
                    Text(note.title)
                        .font(.headline)
                    Text(note.body)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .onTapGesture {
                    vm.selectNote(note)
                }
            }
        }
    }
}