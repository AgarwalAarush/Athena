//
//  Message.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import GRDB

enum MessageRole: String, Codable, DatabaseValueConvertible {
    case user
    case assistant
    case system
}

struct Message: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var conversationId: Int64
    var role: MessageRole
    var content: String
    var createdAt: Date
    var tokenCount: Int?
    var metadata: String? // JSON string for additional metadata
    
    static let databaseTableName = "messages"
    
    // Define columns for type-safe queries
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let conversationId = Column(CodingKeys.conversationId)
        static let role = Column(CodingKeys.role)
        static let content = Column(CodingKeys.content)
        static let createdAt = Column(CodingKeys.createdAt)
        static let tokenCount = Column(CodingKeys.tokenCount)
        static let metadata = Column(CodingKeys.metadata)
    }
    
    // Relationship to conversation
    static let conversation = belongsTo(Conversation.self)
    
    // Default initializer
    init(id: Int64? = nil, conversationId: Int64, role: MessageRole, content: String, createdAt: Date = Date(), tokenCount: Int? = nil, metadata: String? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.tokenCount = tokenCount
        self.metadata = metadata
    }
}

// MARK: - Convenience Methods
extension Message {
    var isFromUser: Bool {
        role == .user
    }
    
    var isFromAssistant: Bool {
        role == .assistant
    }
}

