//
//  NotesSplitView.swift
//  Split view combining note list sidebar and editor
//

import SwiftUI

struct NotesSplitView: View {
    @StateObject private var vm = NotesViewModel(store: SwiftDataNotesStore())
    
    var body: some View {
        NavigationSplitView {
            NoteListView(vm: vm)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            NotesView(vm: vm)
        }
        .task {
            await vm.bootstrap()
        }
    }
}

