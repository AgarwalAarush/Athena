//
//  NoteModel.swift
//  Data model for notes with title derived from first line
//

import Foundation

/// Lightweight struct representing a note (for view model layer)
struct NoteModel: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var modifiedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        body: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

