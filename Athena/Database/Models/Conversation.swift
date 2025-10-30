//
//  Conversation.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import GRDB

struct Conversation: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messageCount: Int
    var isArchived: Bool
    
    static let databaseTableName = "conversations"
    
    // Define columns for type-safe queries
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let messageCount = Column(CodingKeys.messageCount)
        static let isArchived = Column(CodingKeys.isArchived)
    }
    
    // Relationship to messages
    static let messages = hasMany(Message.self)
    
    // Default initializer
    init(id: Int64? = nil, title: String, createdAt: Date = Date(), updatedAt: Date = Date(), messageCount: Int = 0, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.isArchived = isArchived
    }
}

// MARK: - Convenience Methods
extension Conversation {
    mutating func updateTimestamp() {
        updatedAt = Date()
    }
    
    mutating func incrementMessageCount() {
        messageCount += 1
    }
}

