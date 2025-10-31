//
//  BaseProvider.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

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

