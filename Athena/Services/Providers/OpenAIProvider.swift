//
//  OpenAIProvider.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

/// OpenAI API provider implementation
final class OpenAIProvider: BaseProvider {
    let apiKey: String
    let providerName: String = "openai"
    
    private let networkClient: NetworkClient
    private let baseURL = "https://api.openai.com/v1"
    
    private var models: [String] = [
        "gpt-5-nano-2025-08-07",
        "gpt-4-turbo-preview",
        "gpt-4",
        "gpt-3.5-turbo"
    ]
    
    init(apiKey: String) {
        self.apiKey = apiKey
        self.networkClient = NetworkClient.shared
    }
    
    // MARK: - BaseProvider Implementation
    
    func chat(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        maxTokens: Int,
        topP: Double
    ) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        // Convert messages to OpenAI format
        let openaiMessages = messages.map { msg in
            [
                "role": msg.role.rawValue,
                "content": msg.content
            ]
        }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": openaiMessages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "top_p": topP,
            "stream": false
        ]
        
        let encoder = JSONEncoder()
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        let response: OpenAIResponse = try await networkClient.request(
            url: url,
            method: .post,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ],
            body: bodyData
        )
        
        guard let choice = response.choices.first,
              let message = choice.message else {
            throw NetworkError.noData
        }
        
        return ChatResponse(
            content: message.content ?? "",
            role: .assistant,
            finishReason: choice.finishReason,
            usage: response.usage.map { usage in
                ChatResponse.Usage(
                    promptTokens: usage.promptTokens,
                    completionTokens: usage.completionTokens,
                    totalTokens: usage.totalTokens
                )
            }
        )
    }
    
    func stream(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        maxTokens: Int,
        topP: Double
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: "\(baseURL)/chat/completions") else {
                        continuation.finish(throwing: NetworkError.invalidURL)
                        return
                    }
                    
                    // Convert messages to OpenAI format
                    let openaiMessages = messages.map { msg in
                        [
                            "role": msg.role.rawValue,
                            "content": msg.content
                        ]
                    }
                    
                    let requestBody: [String: Any] = [
                        "model": model,
                        "messages": openaiMessages,
                        "temperature": temperature,
                        "max_tokens": maxTokens,
                        "top_p": topP,
                        "stream": true
                    ]
                    
                    let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = bodyData
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: NetworkError.httpError(statusCode: 0, message: "Stream failed"))
                        return
                    }
                    
                    var buffer = ""
                    for try await byte in asyncBytes {
                        if let char = String(bytes: [byte], encoding: .utf8) {
                            buffer.append(char)
                            
                            // Process SSE format
                            while let lineRange = buffer.range(of: "\n") {
                                let line = String(buffer[..<lineRange.lowerBound])
                                buffer.removeSubrange(buffer.startIndex..<lineRange.upperBound)
                                
                                if line.hasPrefix("data: ") {
                                    let data = String(line.dropFirst(6))
                                    if data == "[DONE]" {
                                        continuation.finish()
                                        return
                                    }
                                    
                                    if let jsonData = data.data(using: .utf8),
                                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                       let choices = json["choices"] as? [[String: Any]],
                                       let firstChoice = choices.first,
                                       let delta = firstChoice["delta"] as? [String: Any],
                                       let content = delta["content"] as? String {
                                        continuation.yield(StreamChunk(
                                            delta: content,
                                            finishReason: firstChoice["finish_reason"] as? String
                                        ))
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func getModels() -> [String] {
        return models
    }
}

// MARK: - OpenAI Response Models

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
    
    enum CodingKeys: String, CodingKey {
        case choices, usage
    }
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage?
    let finishReason: String?
    let delta: OpenAIMessage?
    
    enum CodingKeys: String, CodingKey {
        case message, delta
        case finishReason = "finish_reason"
    }
}

private struct OpenAIMessage: Codable {
    let content: String?
    let role: String?
}

private struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

