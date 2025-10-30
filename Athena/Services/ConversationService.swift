//
//  ConversationService.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

class ConversationService: ObservableObject {
    static let shared = ConversationService()
    
    private let database = DatabaseManager.shared
    private let aiService = AIService.shared
    
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var currentMessages: [Message] = []

    private init() {
        initializeSingleConversation()
    }

    // Initialize or load the single persistent conversation
    private func initializeSingleConversation() {
        do {
            // Try to load existing conversations
            let existingConversations = try database.fetchAllConversations()

            if let mainConversation = existingConversations.first {
                // Use existing conversation
                currentConversation = mainConversation
                loadMessages(for: mainConversation.id!)
            } else {
                // Create the main conversation
                let conversation = try database.createConversation(title: "Athena Session")
                currentConversation = conversation
            }

            // Keep conversations list for compatibility
            conversations = existingConversations
        } catch {
            print("Failed to initialize conversation: \(error)")
        }
    }
    
    // MARK: - Conversation Management
    
    func loadConversations() {
        do {
            conversations = try database.fetchAllConversations()
        } catch {
            print("Failed to load conversations: \(error)")
        }
    }
    
    func createConversation(title: String? = nil) throws -> Conversation {
        let conversationTitle = title ?? "New Conversation"
        let conversation = try database.createConversation(title: conversationTitle)
        loadConversations()
        return conversation
    }
    
    func selectConversation(_ conversation: Conversation) {
        currentConversation = conversation
        guard let id = conversation.id else {
            print("Warning: Conversation has no ID")
            return
        }
        loadMessages(for: id)
    }
    
    func deleteConversation(_ conversation: Conversation) throws {
        guard let id = conversation.id else { return }
        try database.deleteConversation(id: id)
        
        if currentConversation?.id == id {
            currentConversation = nil
            currentMessages = []
        }
        
        loadConversations()
    }
    
    func archiveConversation(_ conversation: Conversation) throws {
        guard let id = conversation.id else { return }
        try database.archiveConversation(id: id)
        loadConversations()
    }
    
    func updateConversationTitle(_ conversation: Conversation, title: String) throws {
        var updatedConversation = conversation
        updatedConversation.title = title
        try database.updateConversation(updatedConversation)
        loadConversations()
    }
    
    func searchConversations(query: String) -> [Conversation] {
        guard !query.isEmpty else { return conversations }
        
        do {
            return try database.searchConversations(query: query)
        } catch {
            print("Search failed: \(error)")
            return []
        }
    }
    
    // MARK: - Message Management
    
    func loadMessages(for conversationId: Int64) {
        do {
            currentMessages = try database.fetchMessages(forConversationId: conversationId)
        } catch {
            print("Failed to load messages: \(error)")
        }
    }
    
    func sendMessage(
        _ content: String,
        provider: AIProvider,
        model: String,
        temperature: Double,
        streaming: Bool = true
    ) async throws -> String {
        
        guard let conversationId = currentConversation?.id else {
            throw NSError(domain: "ConversationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No conversation selected"])
        }
        
        if streaming {
            return try await streamMessage(content, conversationId: conversationId, provider: provider, model: model, temperature: temperature)
        } else {
            return try await aiService.sendMessage(content, conversationId: conversationId, provider: provider, model: model, temperature: temperature)
        }
    }
    
    private func streamMessage(
        _ content: String,
        conversationId: Int64,
        provider: AIProvider,
        model: String,
        temperature: Double
    ) async throws -> String {
        
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = aiService.streamMessage(content, conversationId: conversationId, provider: provider, model: model, temperature: temperature)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { response in
                        continuation.resume(returning: response)
                    }
                )
        }
    }
    
    func deleteMessage(_ message: Message) throws {
        guard let id = message.id else { return }
        try database.deleteMessage(id: id)
        
        if let conversationId = currentConversation?.id {
            loadMessages(for: conversationId)
        }
    }
    
    // MARK: - Auto-Title Generation
    
    func generateConversationTitle() async {
        guard let conversation = currentConversation,
              conversation.messageCount == 2, // After first exchange
              let firstMessage = currentMessages.first else {
            return
        }
        
        // Use first message as basis for title (truncate if needed)
        let title = String(firstMessage.content.prefix(50))
        
        do {
            try updateConversationTitle(conversation, title: title)
        } catch {
            print("Failed to update title: \(error)")
        }
    }
}

