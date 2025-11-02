
//
//  NotesStore.swift
//  Athena
//
//  Created by Aarush Agarwal on 11/02/25.
//

import Foundation

protocol NotesStore {
    func bootstrap() async
    func fetchNotes() async throws -> [Note]
    func saveNote(_ note: Note) async throws
    func deleteNote(_ note: Note) async throws
}
