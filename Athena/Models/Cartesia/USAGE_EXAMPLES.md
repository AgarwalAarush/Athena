# Cartesia TTS Usage Examples

This document provides examples of how to use the Cartesia TTS infrastructure.

## Prerequisites

1. Set your Cartesia API key in the app settings or via ConfigurationManager:

```swift
let configManager = ConfigurationManager.shared
try configManager.setString("your-api-key-here", for: .cartesiaAPIKey)
```

## Basic Usage

### Simple Audio Generation (HTTP Bytes)

For simple, one-off audio generation:

```swift
let ttsService = CartesiaTTSService.shared

do {
    let audioData = try await ttsService.generateAudio(
        text: "Hello, world! I'm generating audio on Cartesia!",
        voiceId: CartesiaVoices.defaultVoice,
        modelId: "sonic-3",
        language: "en"
    )
    
    // audioData now contains WAV audio bytes
    // You can save to file, play with AVFoundation, etc.
    print("Generated \(audioData.count) bytes of audio")
    
} catch {
    print("Error generating audio: \(error)")
}
```

### Streaming Audio (WebSocket)

For real-time, low-latency streaming:

```swift
let ttsService = CartesiaTTSService.shared

let stream = ttsService.streamAudio(
    text: "This is streaming audio with very low latency!",
    voiceId: CartesiaVoices.defaultVoice,
    modelId: "sonic-3",
    language: "en"
)

do {
    for try await chunk in stream {
        // Process each audio chunk as it arrives
        print("Received chunk: \(chunk.audioData.count) bytes")
        
        // You can:
        // - Play audio immediately for low-latency playback
        // - Append to a buffer for continuous playback
        // - Process/transform the audio
        
        if chunk.isDone {
            print("Stream complete!")
        }
    }
} catch {
    print("Stream error: \(error)")
}
```

## Advanced Usage

### Custom Output Format

```swift
// High-quality WAV for archival
let highQualityFormat = CartesiaOutputFormat(
    container: .wav,
    encoding: .pcmS16le,
    sampleRate: 48000
)

let audioData = try await ttsService.generateAudio(
    text: "High quality audio",
    voiceId: CartesiaVoices.defaultVoice,
    outputFormat: highQualityFormat
)
```

### Streaming with Timestamps

```swift
let stream = ttsService.streamAudio(
    text: "Get word-level timestamps for this text",
    voiceId: CartesiaVoices.defaultVoice,
    addTimestamps: true  // Enable word timestamps
)

// Timestamp responses are logged automatically
// Future enhancement: expose timestamps via stream
```

### Context Continuation

For multi-turn conversations with consistent voice characteristics:

```swift
let contextId = "conversation-123"

// First utterance
let stream1 = ttsService.streamAudio(
    text: "Hello, how are you today?",
    voiceId: CartesiaVoices.defaultVoice,
    contextId: contextId
)

// Process stream1...

// Second utterance (continues context)
let stream2 = ttsService.streamAudio(
    text: "That's great to hear!",
    voiceId: CartesiaVoices.defaultVoice,
    contextId: contextId
)
```

### Cancel Active Stream

```swift
// Start streaming
let stream = ttsService.streamAudio(
    text: "This might be a long text that we want to interrupt...",
    voiceId: CartesiaVoices.defaultVoice
)

// Later, cancel if needed
ttsService.cancelStream()
```

## Voice Selection

### Using Pre-defined Voices

```swift
// Use the default example voice
let voice = CartesiaVoices.defaultVoice

// Future: Use categorized voices
// let voice = CartesiaVoices.Professional.corporateNarrator
```

### Using Custom Voice ID

```swift
let customVoiceId = "your-custom-voice-id"

// Validate format (optional)
if CartesiaVoices.isValidVoiceIdFormat(customVoiceId) {
    let audioData = try await ttsService.generateAudio(
        text: "Using a custom voice",
        voiceId: customVoiceId
    )
}
```

## Language Support

Cartesia supports multiple languages. Specify the language code:

```swift
// Spanish
let audioData = try await ttsService.generateAudio(
    text: "¡Hola! ¿Cómo estás?",
    voiceId: CartesiaVoices.defaultVoice,
    language: "es"
)

// French
let audioData2 = try await ttsService.generateAudio(
    text: "Bonjour! Comment allez-vous?",
    voiceId: CartesiaVoices.defaultVoice,
    language: "fr"
)

// Japanese
let audioData3 = try await ttsService.generateAudio(
    text: "こんにちは！お元気ですか？",
    voiceId: CartesiaVoices.defaultVoice,
    language: "ja"
)
```

## Error Handling

```swift
do {
    let audioData = try await ttsService.generateAudio(
        text: "Test",
        voiceId: CartesiaVoices.defaultVoice
    )
} catch CartesiaError.missingAPIKey {
    print("Please set your Cartesia API key in settings")
} catch CartesiaError.apiError(let statusCode, let message) {
    print("API error (\(statusCode)): \(message)")
} catch CartesiaError.invalidAudioData {
    print("Failed to decode audio data")
} catch {
    print("Unexpected error: \(error)")
}
```

## Performance Tips

1. **For real-time interactions**: Use `streamAudio()` for lowest latency
2. **For batch processing**: Use `generateAudio()` for simplicity
3. **Sample rate selection**: 
   - 24kHz for streaming (good balance of quality/latency)
   - 44.1kHz for final output (CD quality)
   - 48kHz for high-quality archival
4. **Context reuse**: Use `contextId` for multi-turn conversations to maintain voice consistency

## Integration Points

### With AVFoundation Playback

```swift
import AVFoundation

let audioData = try await ttsService.generateAudio(
    text: "Playing audio with AVFoundation",
    voiceId: CartesiaVoices.defaultVoice
)

// Create audio player
let player = try AVAudioPlayer(data: audioData)
player.play()
```

### With File Storage

```swift
let audioData = try await ttsService.generateAudio(
    text: "Save this to a file",
    voiceId: CartesiaVoices.defaultVoice
)

let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("speech.wav")

try audioData.write(to: fileURL)
```

## Next Steps

- Add more voice IDs to `CartesiaVoices.swift` as you discover them
- Integrate streaming audio playback for real-time speech
- Build a voice selection UI
- Implement audio caching for frequently used phrases

