//
//  AIServiceProtocol.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

protocol AIServiceProtocol {
    func sendMessage(
        _ message: String,
        conversationId: Int64,
        provider: AIProvider,
        model: String
    ) async throws -> String
    
    func streamMessage(
        _ message: String,
        conversationId: Int64,
        provider: AIProvider,
        model: String
    ) -> AnyPublisher<String, Error>
    
    func testConnection(provider: AIProvider, apiKey: String) async throws -> Bool
    
    func getCompletion(
        prompt: String,
        systemPrompt: String?,
        provider: AIProvider,
        model: String
    ) async throws -> String
}

