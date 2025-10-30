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
        model: String,
        temperature: Double
    ) async throws -> String
    
    func streamMessage(
        _ message: String,
        conversationId: Int64,
        provider: AIProvider,
        model: String,
        temperature: Double
    ) -> AnyPublisher<String, Error>
    
    func testConnection(provider: AIProvider, apiKey: String) async throws -> Bool
}

