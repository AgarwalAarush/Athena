//
//  DatabaseManager.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var dbQueue: DatabaseQueue!
    
    private init() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let athenaDirectory = appSupportURL.appendingPathComponent("Athena", isDirectory: true)
            try fileManager.createDirectory(at: athenaDirectory, withIntermediateDirectories: true)
            
            let dbPath = athenaDirectory.appendingPathComponent("athena.sqlite").path
            dbQueue = try DatabaseQueue(path: dbPath)
            
            try migrator.migrate(dbQueue)
            
            print("Database initialized at: \(dbPath)")
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }
    
    // MARK: - Migrations
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // Migration v1: Create conversations and messages tables
        migrator.registerMigration("v1_initial_schema") { db in
            // Create conversations table
            try db.create(table: "conversations") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("messageCount", .integer).notNull().defaults(to: 0)
                t.column("isArchived", .boolean).notNull().defaults(to: false)
            }
            
            // Create messages table
            try db.create(table: "messages") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("conversationId", .integer)
                    .notNull()
                    .indexed()
                    .references("conversations", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("tokenCount", .integer)
                t.column("metadata", .text)
            }
            
            // Create indices for better query performance
            try db.create(index: "idx_conversations_updated_at", on: "conversations", columns: ["updatedAt"])
            try db.create(index: "idx_messages_conversation_id", on: "messages", columns: ["conversationId"])
            try db.create(index: "idx_messages_created_at", on: "messages", columns: ["createdAt"])
        }
        
        return migrator
    }
    
    // MARK: - Database Access
    
    func reader<T>(_ block: (Database) throws -> T) rethrows -> T {
        try dbQueue.read(block)
    }
    
    func writer<T>(_ block: (Database) throws -> T) rethrows -> T {
        try dbQueue.write(block)
    }
    
    // MARK: - Conversation Operations
    
    func createConversation(title: String) throws -> Conversation {
        try writer { db in
            var conversation = Conversation(title: title)
            try conversation.insert(db)
            return conversation
        }
    }
    
    func fetchAllConversations(includeArchived: Bool = false) throws -> [Conversation] {
        try reader { db in
            var query = Conversation.order(Conversation.Columns.updatedAt.desc)
            if !includeArchived {
                query = query.filter(Conversation.Columns.isArchived == false)
            }
            return try query.fetchAll(db)
        }
    }
    
    func fetchConversation(id: Int64) throws -> Conversation? {
        try reader { db in
            try Conversation.fetchOne(db, key: id)
        }
    }
    
    func updateConversation(_ conversation: Conversation) throws {
        try writer { db in
            try conversation.update(db)
        }
    }
    
    func deleteConversation(id: Int64) throws {
        try writer { db in
            try Conversation.deleteOne(db, key: id)
        }
    }
    
    func archiveConversation(id: Int64) throws {
        try writer { db in
            var conversation = try Conversation.fetchOne(db, key: id)
            conversation?.isArchived = true
            try conversation?.update(db)
        }
    }
    
    func searchConversations(query: String) throws -> [Conversation] {
        try reader { db in
            let pattern = "%\(query)%"
            return try Conversation
                .filter(Conversation.Columns.title.like(pattern))
                .order(Conversation.Columns.updatedAt.desc)
                .fetchAll(db)
        }
    }
    
    // MARK: - Message Operations
    
    func createMessage(conversationId: Int64, role: MessageRole, content: String) throws -> Message {
        try writer { db in
            var message = Message(conversationId: conversationId, role: role, content: content)
            try message.insert(db)
            
            // Update conversation's message count and timestamp
            if var conversation = try Conversation.fetchOne(db, key: conversationId) {
                conversation.incrementMessageCount()
                conversation.updateTimestamp()
                try conversation.update(db)
            }
            
            return message
        }
    }
    
    func fetchMessages(forConversationId conversationId: Int64) throws -> [Message] {
        try reader { db in
            try Message
                .filter(Message.Columns.conversationId == conversationId)
                .order(Message.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }
    
    func fetchRecentMessages(forConversationId conversationId: Int64, limit: Int) throws -> [Message] {
        try reader { db in
            try Message
                .filter(Message.Columns.conversationId == conversationId)
                .order(Message.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
                .reversed()
        }
    }
    
    func deleteMessage(id: Int64) throws {
        try writer { db in
            // Get message before deleting to update conversation count
            if let message = try Message.fetchOne(db, key: id) {
                try Message.deleteOne(db, key: id)
                
                // Update conversation's message count
                if var conversation = try Conversation.fetchOne(db, key: message.conversationId) {
                    conversation.messageCount = max(0, conversation.messageCount - 1)
                    try conversation.update(db)
                }
            }
        }
    }
    
    func searchMessages(query: String, inConversationId conversationId: Int64? = nil) throws -> [Message] {
        try reader { db in
            let pattern = "%\(query)%"
            var messageQuery = Message.filter(Message.Columns.content.like(pattern))
            
            if let conversationId = conversationId {
                messageQuery = messageQuery.filter(Message.Columns.conversationId == conversationId)
            }
            
            return try messageQuery
                .order(Message.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }
}

