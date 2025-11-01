//
//  AIService.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

// Note: ChatResponse, StreamChunk, ChatMessage, and MessageRole are now defined in BaseProvider.swift
// to be shared between providers and AIService

class AIService: AIServiceProtocol {
    static let shared = AIService()
    
    private let config = ConfigurationManager.shared
    private let database = DatabaseManager.shared
    
    // Provider cache
    private var providers: [String: BaseProvider] = [:]
    
    private init() {}
    
    // MARK: - Provider Management
    
    private func getProvider(for provider: AIProvider) throws -> BaseProvider {
        guard let apiKey = config.getAPIKey(for: provider.rawValue) else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No API key configured for \(provider.displayName)"])
        }
        
        // Create cache key
        let cacheKey = "\(provider.rawValue):\(String(apiKey.prefix(8)))"
        
        // Return cached provider if available
        if let cachedProvider = providers[cacheKey] {
            return cachedProvider
        }
        
        // Create new provider
        let newProvider: BaseProvider
        switch provider {
        case .openai:
            newProvider = OpenAIProvider(apiKey: apiKey)
        case .anthropic:
            newProvider = AnthropicProvider(apiKey: apiKey)
        }
        
        // Cache provider
        providers[cacheKey] = newProvider
        
        return newProvider
    }
    
    // MARK: - Non-Streaming Chat
    
    func sendMessage(
        _ message: String,
        conversationId: Int64,
        provider: AIProvider,
        model: String
    ) async throws -> String {
        
        // Get conversation history
        let messages = try await getConversationMessages(conversationId: conversationId)
        
        // Add new user message
        var allMessages = messages
        allMessages.append(ChatMessage(role: .user, content: message))
        
        // Save user message to database
        _ = try database.createMessage(conversationId: conversationId, role: .user, content: message)
        
        // Get provider
        let aiProvider = try getProvider(for: provider)
        
        // Make API call directly through provider
        let response = try await aiProvider.chat(
            messages: allMessages,
            model: model,
            temperature: 0.7,
            maxTokens: 2048,
            topP: config.getDouble(.topP)
        )
        
        // Save assistant response to database
        _ = try database.createMessage(conversationId: conversationId, role: .assistant, content: response.content)
        
        return response.content
    }
    
    // MARK: - Streaming Chat
    
    func streamMessage(
        _ message: String,
        conversationId: Int64,
        provider: AIProvider,
        model: String
    ) -> AnyPublisher<String, Error> {
        
        return Future<String, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            Task {
                do {
                    // Get conversation history
                    let messages = try await self.getConversationMessages(conversationId: conversationId)
                    
                    // Add new user message
                    var allMessages = messages
                    allMessages.append(ChatMessage(role: .user, content: message))
                    
                    // Save user message to database
                    _ = try self.database.createMessage(conversationId: conversationId, role: .user, content: message)
                    
                    // Get provider
                    let aiProvider = try self.getProvider(for: provider)
                    
                    // Stream response directly through provider
                    var fullResponse = ""
                    
                    let stream = aiProvider.stream(
                        messages: allMessages,
                        model: model,
                        temperature: 0.7,
                        maxTokens: 2048,
                        topP: self.config.getDouble(.topP)
                    )
                    
                    for try await chunk in stream {
                        fullResponse += chunk.delta
                    }
                    
                    // Save complete assistant response
                    _ = try self.database.createMessage(conversationId: conversationId, role: .assistant, content: fullResponse)
                    
                    promise(.success(fullResponse))
                    
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Test Connection
    
    func testConnection(provider: AIProvider, apiKey: String) async throws -> Bool {
        // Create a temporary provider with the test API key
        let testProvider: BaseProvider
        switch provider {
        case .openai:
            testProvider = OpenAIProvider(apiKey: apiKey)
        case .anthropic:
            testProvider = AnthropicProvider(apiKey: apiKey)
        }
        
        // Try a minimal request
        let testMessages = [
            ChatMessage(role: .user, content: "Hello")
        ]
        
        let defaultModel = provider.defaultModel
        
        do {
            // Make test request with minimal tokens
            _ = try await testProvider.chat(
                messages: testMessages,
                model: defaultModel,
                temperature: 0.7,
                maxTokens: 5,
                topP: 1.0
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - General Purpose Completion
    
    func getCompletion(
        prompt: String,
        systemPrompt: String?,
        provider: AIProvider,
        model: String
    ) async throws -> String {
        
        var messages: [ChatMessage] = []
        if let systemPrompt = systemPrompt {
            messages.append(ChatMessage(role: .system, content: systemPrompt))
        }
        messages.append(ChatMessage(role: .user, content: prompt))
        
        let aiProvider = try getProvider(for: provider)
        
        // Note: We are not using the 'chat' method from the provider here.
        // We are assuming a similar method exists for direct completion,
        // or that the 'chat' method can be used this way.
        // This will be fully implemented in the provider next.
        let response = try await aiProvider.chat(
            messages: messages,
            model: model,
            temperature: 0.0, // Deterministic for classification
            maxTokens: 50,    // Small response for classification
            topP: 1.0
        )
        
        return response.content
    }
    
    // MARK: - Helper Methods
    
    private func getConversationMessages(conversationId: Int64) async throws -> [ChatMessage] {
        let dbMessages = try database.fetchMessages(forConversationId: conversationId)
        
        return dbMessages.map { dbMessage in
            ChatMessage(role: dbMessage.role, content: dbMessage.content)
        }
    }
}

