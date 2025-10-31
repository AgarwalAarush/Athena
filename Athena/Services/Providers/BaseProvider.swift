//
//  BaseProvider.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

// Note: ChatMessage is defined in Models/ChatMessage.swift
// MessageRole is defined in Database/Models/Message.swift
// These are imported via module access

// Shared types for provider responses
struct ChatResponse: Codable {
    let content: String
    let role: MessageRole
    let finishReason: String?
    let usage: Usage?
    
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
    
    enum CodingKeys: String, CodingKey {
        case content, role
        case finishReason = "finish_reason"
        case usage
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

// MessageRole is already defined in Database/Models/Message.swift

/// Abstract base protocol for AI providers
protocol BaseProvider: AnyObject {
    var apiKey: String { get }
    var providerName: String { get }
    
    init(apiKey: String)
    
    /// Non-streaming chat completion
    func chat(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        maxTokens: Int,
        topP: Double
    ) async throws -> ChatResponse
    
    /// Streaming chat completion
    func stream(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        maxTokens: Int,
        topP: Double
    ) -> AsyncThrowingStream<StreamChunk, Error>
    
    /// Get available models for this provider
    func getModels() -> [String]
}

