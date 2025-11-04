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
        migrator.registerMigration("v1") { db in
            try db.create(table: "conversations", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("messageCount", .integer).notNull().defaults(to: 0)
                t.column("isArchived", .boolean).notNull().defaults(to: false)
            }
            
            try db.create(table: "messages", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("conversationId", .integer).notNull()
                    .indexed()
                    .references("conversations", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("tokenCount", .integer)
                t.column("metadata", .text)
            }
        }
        
        // Migration v2: Create window configuration tables
        migrator.registerMigration("v2") { db in
            try db.create(table: "window_configurations") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().unique()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            
            try db.create(table: "window_configuration_windows") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("configId", .integer).notNull()
                    .indexed()
                    .references("window_configurations", onDelete: .cascade)
                t.column("appName", .text).notNull()
                t.column("windowTitle", .text).notNull()
                t.column("x", .double).notNull()
                t.column("y", .double).notNull()
                t.column("width", .double).notNull()
                t.column("height", .double).notNull()
                t.column("screenIndex", .integer).notNull()
                t.column("layer", .integer).notNull()
            }
        }
        
        return migrator
    }
    
    // MARK: - Database Access

    func reader<T>(_ block: (Database) throws -> T) throws -> T {
        try dbQueue.read(block)
    }

    func writer<T>(_ block: (Database) throws -> T) throws -> T {
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
        _ = try writer { db in
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
    
    // MARK: - Window Configuration Operations
    
    func createWindowConfiguration(name: String, windows: [SavedWindowInfo]) throws -> WindowConfiguration {
        try writer { db in
            var config = WindowConfiguration(name: name, windows: [])
            try config.insert(db)
            
            guard let configId = config.id else {
                throw NSError(domain: "DatabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get configuration ID"])
            }
            
            var savedWindows: [SavedWindowInfo] = []
            for var window in windows {
                window.configId = configId
                try window.insert(db)
                savedWindows.append(window)
            }
            
            config.windows = savedWindows
            return config
        }
    }
    
    func fetchWindowConfiguration(name: String) throws -> WindowConfiguration? {
        try reader { db in
            guard let config = try WindowConfiguration
                .filter(WindowConfiguration.Columns.name == name)
                .fetchOne(db) else {
                return nil
            }
            
            guard let configId = config.id else { return config }
            
            let windows = try SavedWindowInfo
                .filter(SavedWindowInfo.Columns.configId == configId)
                .fetchAll(db)
            
            var fullConfig = config
            fullConfig.windows = windows
            return fullConfig
        }
    }
    
    func fetchAllWindowConfigurations() throws -> [WindowConfiguration] {
        try reader { db in
            let configs = try WindowConfiguration
                .order(WindowConfiguration.Columns.updatedAt.desc)
                .fetchAll(db)
            
            return try configs.map { config in
                var fullConfig = config
                if let configId = config.id {
                    fullConfig.windows = try SavedWindowInfo
                        .filter(SavedWindowInfo.Columns.configId == configId)
                        .fetchAll(db)
                }
                return fullConfig
            }
        }
    }
    
    func updateWindowConfiguration(name: String, newName: String) throws {
        try writer { db in
            guard var config = try WindowConfiguration
                .filter(WindowConfiguration.Columns.name == name)
                .fetchOne(db) else {
                throw NSError(domain: "DatabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Configuration not found"])
            }
            
            config.name = newName
            config.updatedAt = Date()
            try config.update(db)
        }
    }
    
    func deleteWindowConfiguration(name: String) throws {
        try writer { db in
            _ = try WindowConfiguration
                .filter(WindowConfiguration.Columns.name == name)
                .deleteAll(db)
        }
    }
}

