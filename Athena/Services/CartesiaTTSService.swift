//
//  CartesiaTTSService.swift
//  Athena
//
//  Service for Cartesia text-to-speech generation
//

import Foundation

/// Service for generating speech using Cartesia's TTS API
@MainActor
final class CartesiaTTSService {
    // MARK: - Singleton
    
    static let shared = CartesiaTTSService()
    
    // MARK: - Properties
    
    private let baseURL = "https://api.cartesia.ai"
    private let websocketURL = "wss://api.cartesia.ai/tts/websocket"
    private let apiVersion = "2025-04-16"
    
    private let configManager = ConfigurationManager.shared
    private var activeWebSocket: URLSessionWebSocketTask?
    
    // MARK: - Initialization
    
    private init() {
        print("[CartesiaTTSService] Initialized")
    }
    
    // MARK: - Public API
    
    /// Generate audio via HTTP bytes endpoint (simple, one-off generation)
    ///
    /// - Parameters:
    ///   - text: The text to convert to speech
    ///   - voiceId: The voice ID to use
    ///   - modelId: The model ID (default: "sonic-3")
    ///   - language: Language code (default: "en")
    ///   - outputFormat: Audio output format (default: WAV PCM 16-bit 44.1kHz)
    /// - Returns: Raw audio data
    func generateAudio(
        text: String,
        voiceId: String,
        modelId: String = "sonic-3",
        language: String = "en",
        outputFormat: CartesiaOutputFormat = .bytesDefault
    ) async throws -> Data {
        print("[CartesiaTTSService] Generating audio for text: \"\(text.prefix(50))...\"")
        
        guard let apiKey = getAPIKey() else {
            throw CartesiaError.missingAPIKey
        }
        
        // Construct request
        let request = CartesiaBytesRequest(
            modelId: modelId,
            transcript: text,
            voice: .id(voiceId),
            language: language,
            outputFormat: outputFormat
        )
        
        // Build URL
        guard let url = URL(string: "\(baseURL)/tts/bytes") else {
            throw CartesiaError.connectionFailed
        }
        
        // Create URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "Cartesia-Version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode body
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CartesiaError.connectionFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CartesiaError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        print("[CartesiaTTSService] Successfully generated \(data.count) bytes of audio")
        return data
    }
    
    /// Stream audio via WebSocket (real-time, low latency)
    ///
    /// - Parameters:
    ///   - text: The text to convert to speech
    ///   - voiceId: The voice ID to use
    ///   - modelId: The model ID (default: "sonic-3")
    ///   - language: Language code (default: "en")
    ///   - contextId: Optional context ID for continuation
    ///   - outputFormat: Audio output format (default: raw PCM 16-bit 24kHz)
    ///   - addTimestamps: Whether to include word timestamps (default: false)
    /// - Returns: AsyncThrowingStream of audio chunks
    func streamAudio(
        text: String,
        voiceId: String,
        modelId: String = "sonic-3",
        language: String = "en",
        contextId: String? = nil,
        outputFormat: CartesiaOutputFormat = .streamingDefault,
        addTimestamps: Bool = false
    ) -> AsyncThrowingStream<CartesiaAudioChunk, Error> {
        print("[CartesiaTTSService] Starting audio stream for text: \"\(text.prefix(50))...\"")
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Get API key
                    guard let apiKey = self.getAPIKey() else {
                        continuation.finish(throwing: CartesiaError.missingAPIKey)
                        return
                    }
                    
                    // Build WebSocket URL with query parameters
                    var components = URLComponents(string: self.websocketURL)
                    components?.queryItems = [
                        URLQueryItem(name: "cartesia_version", value: self.apiVersion),
                        URLQueryItem(name: "api_key", value: apiKey)
                    ]
                    
                    guard let url = components?.url else {
                        continuation.finish(throwing: CartesiaError.connectionFailed)
                        return
                    }
                    
                    // Create WebSocket connection
                    let webSocket = URLSession.shared.webSocketTask(with: url)
                    self.activeWebSocket = webSocket
                    webSocket.resume()
                    
                    print("[CartesiaTTSService] WebSocket connected")
                    
                    // Prepare generation request
                    let request = CartesiaGenerationRequest(
                        modelId: modelId,
                        transcript: text,
                        voice: .id(voiceId),
                        language: language,
                        contextId: contextId,
                        outputFormat: outputFormat,
                        addTimestamps: addTimestamps
                    )
                    
                    // Send generation request
                    let encoder = JSONEncoder()
                    let requestData = try encoder.encode(request)
                    let message = URLSessionWebSocketTask.Message.data(requestData)
                    try await webSocket.send(message)
                    
                    print("[CartesiaTTSService] Sent generation request")
                    
                    // Receive messages
                    var isComplete = false
                    
                    while !isComplete {
                        let message = try await webSocket.receive()
                        
                        switch message {
                        case .data(let data):
                            isComplete = try self.handleWebSocketData(data, continuation: continuation)
                            
                        case .string(let string):
                            guard let data = string.data(using: .utf8) else { continue }
                            isComplete = try self.handleWebSocketData(data, continuation: continuation)
                            
                        @unknown default:
                            print("[CartesiaTTSService] Unknown WebSocket message type")
                        }
                    }
                    
                    // Close connection
                    webSocket.cancel(with: .normalClosure, reason: nil)
                    self.activeWebSocket = nil
                    continuation.finish()
                    
                    print("[CartesiaTTSService] Stream completed successfully")
                    
                } catch {
                    print("[CartesiaTTSService] Stream error: \(error)")
                    self.activeWebSocket?.cancel(with: .abnormalClosure, reason: nil)
                    self.activeWebSocket = nil
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Cancel active streaming connection
    func cancelStream() {
        print("[CartesiaTTSService] Cancelling active stream")
        activeWebSocket?.cancel(with: .normalClosure, reason: nil)
        activeWebSocket = nil
    }
    
    // MARK: - Private Helpers
    
    /// Get API key from configuration
    private func getAPIKey() -> String? {
        do {
            let apiKey = try configManager.getString(.cartesiaAPIKey)
            return apiKey.isEmpty ? nil : apiKey
        } catch {
            print("[CartesiaTTSService] Failed to get API key: \(error)")
            return nil
        }
    }
    
    /// Handle WebSocket data response
    /// - Returns: true if stream is complete, false otherwise
    private func handleWebSocketData(
        _ data: Data,
        continuation: AsyncThrowingStream<CartesiaAudioChunk, Error>.Continuation
    ) throws -> Bool {
        let decoder = JSONDecoder()
        
        // Try to determine response type
        if let typeWrapper = try? decoder.decode(ResponseTypeWrapper.self, from: data) {
            switch typeWrapper.type {
            case .chunk:
                // Audio chunk
                let chunkResponse = try decoder.decode(CartesiaChunkResponse.self, from: data)
                let audioChunk = try CartesiaAudioChunk.from(chunkResponse)
                continuation.yield(audioChunk)
                return chunkResponse.done
                
            case .done:
                // Done signal
                let doneResponse = try decoder.decode(CartesiaDoneResponse.self, from: data)
                print("[CartesiaTTSService] Received done signal (status: \(doneResponse.statusCode))")
                return true
                
            case .flushDone:
                // Flush acknowledgment
                let flushResponse = try decoder.decode(CartesiaFlushDoneResponse.self, from: data)
                print("[CartesiaTTSService] Received flush done (id: \(flushResponse.flushId))")
                return false
                
            case .timestamps:
                // Timestamps (informational, don't yield)
                let timestampResponse = try decoder.decode(CartesiaTimestampResponse.self, from: data)
                print("[CartesiaTTSService] Received timestamps: \(timestampResponse.wordTimestamps?.words.count ?? 0) words")
                return false
                
            case .error:
                // Error response
                let errorResponse = try decoder.decode(CartesiaErrorResponse.self, from: data)
                throw CartesiaError.apiError(
                    statusCode: errorResponse.statusCode,
                    message: errorResponse.error
                )
            }
        } else {
            throw CartesiaError.decodingError(NSError(domain: "Unknown response format", code: -1))
        }
    }
}

// MARK: - Helper Types

/// Wrapper to decode response type field
private struct ResponseTypeWrapper: Codable {
    let type: CartesiaResponseType
}

