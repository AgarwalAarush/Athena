//
//  AnthropicProvider.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

/// Anthropic (Claude) API provider implementation
final class AnthropicProvider: BaseProvider {
    let apiKey: String
    let providerName: String = "anthropic"
    
    private let baseURL = "https://api.anthropic.com/v1"
    private let apiVersion = "2023-06-01"
    
    private var models: [String] = [
        "claude-haiku-4-5-20251001",
        "claude-3-opus-20240229",
        "claude-3-sonnet-20240229",
        "claude-3-haiku-20240307"
    ]
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - BaseProvider Implementation
    
    func chat(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        maxTokens: Int,
        topP: Double
    ) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw NetworkError.invalidURL
        }
        
        // Extract system message if present
        var systemMessage: String?
        var chatMessages: [[String: String]] = []
        
        for msg in messages {
            if msg.role == .system {
                systemMessage = msg.content
            } else {
                chatMessages.append([
                    "role": msg.role.rawValue,
                    "content": msg.content
                ])
            }
        }
        
        var requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": chatMessages,
            "temperature": temperature,
            "top_p": topP
        ]
        
        if let systemMessage = systemMessage {
            requestBody["system"] = systemMessage
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        
        // Extract content from response
        var content = ""
        for block in response.content {
            if block.type == "text", let text = block.text {
                content += text
            }
        }
        
        return ChatResponse(
            content: content,
            role: .assistant,
            finishReason: response.stopReason,
            usage: response.usage.map { usage in
                ChatResponse.Usage(
                    promptTokens: usage.inputTokens,
                    completionTokens: usage.outputTokens,
                    totalTokens: usage.inputTokens + usage.outputTokens
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
                    guard let url = URL(string: "\(baseURL)/messages") else {
                        continuation.finish(throwing: NetworkError.invalidURL)
                        return
                    }
                    
                    // Extract system message if present
                    var systemMessage: String?
                    var chatMessages: [[String: String]] = []
                    
                    for msg in messages {
                        if msg.role == .system {
                            systemMessage = msg.content
                        } else {
                            chatMessages.append([
                                "role": msg.role.rawValue,
                                "content": msg.content
                            ])
                        }
                    }
                    
                    var requestBody: [String: Any] = [
                        "model": model,
                        "max_tokens": maxTokens,
                        "messages": chatMessages,
                        "temperature": temperature,
                        "top_p": topP,
                        "stream": true
                    ]
                    
                    if let systemMessage = systemMessage {
                        requestBody["system"] = systemMessage
                    }
                    
                    let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
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
                                    
                                    if let jsonData = data.data(using: .utf8),
                                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                        
                                        // Handle different event types
                                        if let type = json["type"] as? String {
                                            if type == "content_block_delta",
                                               let delta = json["delta"] as? [String: Any],
                                               let text = delta["text"] as? String {
                                                continuation.yield(StreamChunk(
                                                    delta: text,
                                                    finishReason: nil
                                                ))
                                            } else if type == "message_stop" {
                                                continuation.finish()
                                                return
                                            }
                                        }
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

// MARK: - Anthropic Response Models

private struct AnthropicResponse: Codable {
    let content: [AnthropicContentBlock]
    let stopReason: String?
    let usage: AnthropicUsage?
    
    enum CodingKeys: String, CodingKey {
        case content, usage
        case stopReason = "stop_reason"
    }
}

private struct AnthropicContentBlock: Codable {
    let type: String
    let text: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        text = try? container.decode(String.self, forKey: .text)
    }
}

private struct AnthropicUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}


