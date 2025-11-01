//
//  OpenAIProvider.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

/// A provider for interacting with the OpenAI API.
///
/// This class implements the `BaseProvider` protocol and provides methods for making chat completions
/// and streaming responses from the OpenAI API.
final class OpenAIProvider: BaseProvider {
    let apiKey: String
    let providerName: String = "openai"
    
    private let baseURL = "https://api.openai.com/v1"
    
    private var models: [String] = [
        "gpt-5-nano-2025-08-07",
        "gpt-4-turbo-preview",
        "gpt-4",
        "gpt-3.5-turbo"
    ]
    
    /// Initializes a new OpenAI provider with the given API key.
    ///
    /// - Parameter apiKey: The API key for the OpenAI API.
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - BaseProvider Implementation
    
    /// Sends a chat completion request to the OpenAI API.
    ///
    /// - Parameters:
    ///   - messages: An array of `ChatMessage` objects representing the conversation history.
    ///   - model: The name of the model to use for the completion.
    ///   - temperature: The sampling temperature to use, between 0 and 2.
    ///   - maxTokens: The maximum number of tokens to generate in the completion.
    ///   - topP: The nucleus sampling probability.
    /// - Returns: A `ChatResponse` object containing the assistant's reply.
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
        
        // Convert messages to the format expected by the OpenAI API.
        let openaiMessages = messages.map { msg in
            [
                "role": msg.role.rawValue,
                "content": msg.content
            ]
        }
        
        // Construct the request body.
        let requestBody: [String: Any] = [
            "model": model,
            "messages": openaiMessages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "top_p": topP,
            "stream": false
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
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
    
    /// Streams a chat completion response from the OpenAI API.
    ///
    /// - Parameters:
    ///   - messages: An array of `ChatMessage` objects representing the conversation history.
    ///   - model: The name of the model to use for the completion.
    ///   - temperature: The sampling temperature to use, between 0 and 2.
    ///   - maxTokens: The maximum number of tokens to generate in the completion.
    ///   - topP: The nucleus sampling probability.
    /// - Returns: An `AsyncThrowingStream` of `StreamChunk` objects.
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
                    
                    // Convert messages to the format expected by the OpenAI API.
                    let openaiMessages = messages.map { msg in
                        [
                            "role": msg.role.rawValue,
                            "content": msg.content
                        ]
                    }
                    
                    // Construct the request body.
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
                    
                    // Process the Server-Sent Events (SSE) stream.
                    var buffer = ""
                    for try await byte in asyncBytes {
                        if let char = String(bytes: [byte], encoding: .utf8) {
                            buffer.append(char)
                            
                            // Process complete lines from the buffer.
                            while let lineRange = buffer.range(of: "\n") {
                                let line = String(buffer[..<lineRange.lowerBound])
                                buffer.removeSubrange(buffer.startIndex..<lineRange.upperBound)
                                
                                if line.hasPrefix("data: ") {
                                    let data = String(line.dropFirst(6))
                                    if data == "[DONE]" {
                                        continuation.finish()
                                        return
                                    }
                                    
                                    // Decode the JSON data from the event.
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
    
    /// Returns a list of available models for the OpenAI provider.
    ///
    /// - Returns: An array of strings representing the model names.
    func getModels() -> [String] {
        return models
    }
}

// MARK: - OpenAI Response Models

/// Represents the top-level response from the OpenAI chat completions API.
private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

/// Represents a single choice in the OpenAI chat completions response.
private struct OpenAIChoice: Codable {
    let message: OpenAIMessage?
    let finishReason: String?
    let delta: OpenAIMessage? // Used for streaming
    
    enum CodingKeys: String, CodingKey {
        case message, delta
        case finishReason = "finish_reason"
    }
}

/// Represents a message in the OpenAI chat completions response.
private struct OpenAIMessage: Codable {
    let content: String?
    let role: String?
}

/// Represents the token usage for a chat completion request.
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

