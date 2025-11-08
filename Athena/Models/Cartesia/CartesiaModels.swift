//
//  CartesiaModels.swift
//  Athena
//
//  Cartesia TTS API request/response models
//

import Foundation

// MARK: - Voice Configuration

/// Voice configuration for Cartesia TTS
struct CartesiaVoice: Codable {
    let mode: VoiceMode
    let id: String?
    let embedding: [Double]?
    
    enum VoiceMode: String, Codable {
        case id
        case embedding
    }
    
    /// Create a voice configuration using a voice ID
    static func id(_ voiceId: String) -> CartesiaVoice {
        CartesiaVoice(mode: .id, id: voiceId, embedding: nil)
    }
    
    /// Create a voice configuration using a voice embedding
    static func embedding(_ embedding: [Double]) -> CartesiaVoice {
        CartesiaVoice(mode: .embedding, id: nil, embedding: embedding)
    }
}

// MARK: - Output Format

/// Audio output format configuration
struct CartesiaOutputFormat: Codable {
    let container: Container
    let encoding: Encoding
    let sampleRate: Int
    
    enum Container: String, Codable {
        case raw
        case wav
        case mp3
    }
    
    enum Encoding: String, Codable {
        case pcmF32le = "pcm_f32le"
        case pcmS16le = "pcm_s16le"
        case pcmMulaw = "pcm_mulaw"
    }
    
    enum CodingKeys: String, CodingKey {
        case container
        case encoding
        case sampleRate = "sample_rate"
    }
    
    /// Default streaming format: raw PCM 16-bit at 24kHz for low latency
    static let streamingDefault = CartesiaOutputFormat(
        container: .raw,
        encoding: .pcmS16le,
        sampleRate: 24000
    )
    
    /// Default bytes format: WAV PCM 16-bit at 44.1kHz for quality
    static let bytesDefault = CartesiaOutputFormat(
        container: .wav,
        encoding: .pcmS16le,
        sampleRate: 44100
    )
}

// MARK: - Generation Request

/// WebSocket generation request
struct CartesiaGenerationRequest: Codable {
    let modelId: String
    let transcript: String
    let voice: CartesiaVoice
    let language: String
    let contextId: String?
    let outputFormat: CartesiaOutputFormat
    let addTimestamps: Bool
    let `continue`: Bool
    
    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case transcript
        case voice
        case language
        case contextId = "context_id"
        case outputFormat = "output_format"
        case addTimestamps = "add_timestamps"
        case `continue`
    }
    
    init(
        modelId: String = "sonic-3",
        transcript: String,
        voice: CartesiaVoice,
        language: String = "en",
        contextId: String? = nil,
        outputFormat: CartesiaOutputFormat = .streamingDefault,
        addTimestamps: Bool = false,
        continue: Bool = false
    ) {
        self.modelId = modelId
        self.transcript = transcript
        self.voice = voice
        self.language = language
        self.contextId = contextId
        self.outputFormat = outputFormat
        self.addTimestamps = addTimestamps
        self.continue = `continue`
    }
}

/// WebSocket cancel request
struct CartesiaCancelRequest: Codable {
    let contextId: String
    let cancel: Bool
    
    enum CodingKeys: String, CodingKey {
        case contextId = "context_id"
        case cancel
    }
    
    init(contextId: String) {
        self.contextId = contextId
        self.cancel = true
    }
}

// MARK: - HTTP Bytes Request

/// HTTP bytes endpoint request
struct CartesiaBytesRequest: Codable {
    let modelId: String
    let transcript: String
    let voice: CartesiaVoice
    let language: String
    let outputFormat: CartesiaOutputFormat
    let save: Bool?
    let pronunciationDictId: String?
    
    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case transcript
        case voice
        case language
        case outputFormat = "output_format"
        case save
        case pronunciationDictId = "pronunciation_dict_id"
    }
    
    init(
        modelId: String = "sonic-3",
        transcript: String,
        voice: CartesiaVoice,
        language: String = "en",
        outputFormat: CartesiaOutputFormat = .bytesDefault,
        save: Bool? = nil,
        pronunciationDictId: String? = nil
    ) {
        self.modelId = modelId
        self.transcript = transcript
        self.voice = voice
        self.language = language
        self.outputFormat = outputFormat
        self.save = save
        self.pronunciationDictId = pronunciationDictId
    }
}

// MARK: - WebSocket Responses

/// Base response type discriminator
enum CartesiaResponseType: String, Codable {
    case chunk
    case done
    case flushDone = "flush_done"
    case timestamps
    case error
}

/// Audio chunk response from WebSocket
struct CartesiaChunkResponse: Codable {
    let type: CartesiaResponseType
    let data: String
    let done: Bool
    let statusCode: Int
    let stepTime: Int?
    let contextId: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
        case done
        case statusCode = "status_code"
        case stepTime = "step_time"
        case contextId = "context_id"
    }
}

/// Flush acknowledgment response
struct CartesiaFlushDoneResponse: Codable {
    let type: CartesiaResponseType
    let done: Bool
    let flushDone: Bool
    let flushId: Int
    let statusCode: Int
    let contextId: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case done
        case flushDone = "flush_done"
        case flushId = "flush_id"
        case statusCode = "status_code"
        case contextId = "context_id"
    }
}

/// Completion response
struct CartesiaDoneResponse: Codable {
    let type: CartesiaResponseType
    let done: Bool
    let statusCode: Int
    let contextId: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case done
        case statusCode = "status_code"
        case contextId = "context_id"
    }
}

/// Word timestamps response
struct CartesiaTimestampResponse: Codable {
    let type: CartesiaResponseType
    let done: Bool
    let statusCode: Int
    let contextId: String?
    let wordTimestamps: WordTimestamps?
    let phonemeTimestamps: PhonemeTimestamps?
    
    struct WordTimestamps: Codable {
        let words: [String]
        let start: [Double]
        let end: [Double]
    }
    
    struct PhonemeTimestamps: Codable {
        let phonemes: [String]
        let start: [Double]
        let end: [Double]
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case done
        case statusCode = "status_code"
        case contextId = "context_id"
        case wordTimestamps = "word_timestamps"
        case phonemeTimestamps = "phoneme_timestamps"
    }
}

/// Error response
struct CartesiaErrorResponse: Codable {
    let type: String
    let done: Bool
    let error: String
    let statusCode: Int
    let contextId: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case done
        case error
        case statusCode = "status_code"
        case contextId = "context_id"
    }
}

// MARK: - Streaming Data Wrapper

/// Audio chunk with decoded data for streaming
struct CartesiaAudioChunk {
    let audioData: Data
    let contextId: String?
    let stepTime: Int?
    let isDone: Bool
    
    /// Decode base64 audio data from chunk response
    static func from(_ response: CartesiaChunkResponse) throws -> CartesiaAudioChunk {
        guard let data = Data(base64Encoded: response.data) else {
            throw CartesiaError.invalidAudioData
        }
        
        return CartesiaAudioChunk(
            audioData: data,
            contextId: response.contextId,
            stepTime: response.stepTime,
            isDone: response.done
        )
    }
}

// MARK: - Errors

enum CartesiaError: Error, LocalizedError {
    case invalidAudioData
    case invalidVoiceConfiguration
    case missingAPIKey
    case websocketError(String)
    case apiError(statusCode: Int, message: String)
    case decodingError(Error)
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidAudioData:
            return "Failed to decode audio data"
        case .invalidVoiceConfiguration:
            return "Invalid voice configuration"
        case .missingAPIKey:
            return "Cartesia API key not found"
        case .websocketError(let message):
            return "WebSocket error: \(message)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .connectionFailed:
            return "Failed to connect to Cartesia API"
        }
    }
}

