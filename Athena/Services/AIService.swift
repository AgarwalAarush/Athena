//
//  AIService.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

struct ChatRequest: Codable {
    let provider: String
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let topP: Double
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case provider, model, messages, temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case stream
    }
}

struct ChatResponse: Codable {
    let content: String
    let role: MessageRole
    let finishReason: String?
    let usage: Usage?
    
    enum CodingKeys: String, CodingKey {
        case content, role
        case finishReason = "finish_reason"
        case usage
    }
    
    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct StreamChunk: Codable {
    let delta: String
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

class AIService: AIServiceProtocol {
    static let shared = AIService()
    
    private let networkClient = NetworkClient.shared
    private let config = ConfigurationManager.shared
    private let database = DatabaseManager.shared
    
    private var baseURL: String {
        let url = config.getString(.pythonServiceURL)
        let port = config.getInt(.pythonServicePort)
        return "\(url):\(port)"
    }
    
    private init() {}
    
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
        
        // Get API key
        guard let apiKey = config.getAPIKey(for: provider.rawValue) else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No API key configured for \(provider.displayName)"])
        }
        
        // Create request with hardcoded values (set by developer)
        let request = ChatRequest(
            provider: provider.rawValue,
            model: model,
            messages: allMessages,
            temperature: 0.7,
            maxTokens: 2048,
            topP: config.getDouble(.topP),
            stream: false
        )
        
        // Make API call
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw NetworkError.invalidURL
        }
        
        let response: ChatResponse = try await networkClient.post(
            url: url,
            body: request,
            headers: ["X-API-Key": apiKey]
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
                    
                    // Get API key
                    guard let apiKey = self.config.getAPIKey(for: provider.rawValue) else {
                        throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No API key configured for \(provider.displayName)"])
                    }
                    
                    // Create request with hardcoded values (set by developer)
                    let request = ChatRequest(
                        provider: provider.rawValue,
                        model: model,
                        messages: allMessages,
                        temperature: 0.7,
                        maxTokens: 2048,
                        topP: self.config.getDouble(.topP),
                        stream: true
                    )
                    
                    guard let url = URL(string: "\(self.baseURL)/chat/stream") else {
                        throw NetworkError.invalidURL
                    }
                    
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    let bodyData = try encoder.encode(request)
                    
                    var fullResponse = ""
                    
                    try await self.networkClient.streamRequest(
                        url: url,
                        method: .post,
                        headers: ["X-API-Key": apiKey],
                        body: bodyData
                    ) { chunkData in
                        if let data = chunkData.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) {
                            fullResponse += chunk.delta
                        }
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
        guard let url = URL(string: "\(baseURL)/test-connection?provider=\(provider.rawValue)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return (200...299).contains(httpResponse.statusCode)
    }
    
    // MARK: - Helper Methods
    
    private func getConversationMessages(conversationId: Int64) async throws -> [ChatMessage] {
        let dbMessages = try database.fetchMessages(forConversationId: conversationId)
        
        return dbMessages.map { dbMessage in
            ChatMessage(role: dbMessage.role, content: dbMessage.content)
        }
    }
}

