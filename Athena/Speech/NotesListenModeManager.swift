//
//  NotesListenModeManager.swift
//  Athena
//
//  Manages voice dictation mode for notes with automatic exit command detection
//

import Foundation
import Speech
import AVFoundation
import Combine

/// State machine for notes listen mode
enum NotesListenState: Equatable {
    case idle
    case listening
    case error(String)
}

/// Manages voice dictation with "Athena stop listening" detection
@MainActor
class NotesListenModeManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var state: NotesListenState = .idle
    @Published private(set) var partialTranscript: String = ""
    @Published private(set) var finalTranscript: String?
    
    // MARK: - Private Properties
    
    private var vadTranscriber: SimplifiedVADTranscriber?
    private var audioEngine: AVAudioEngine?
    private var audioInput: AVAudioInputNode?
    private var transcriberTask: Task<Void, Never>?
    
    // Current accumulated transcript
    private var currentTranscript: String = ""
    
    // Stop command detection
    private let stopCommandThreshold: Double = 0.7
    private var stopCommandDetected: Bool = false
    
    // MARK: - Initialization
    
    init() {
        print("[NotesListenModeManager] Initialized")
    }
    
    deinit {
        // Only cancel tasks - stop() should be called before deallocation
        transcriberTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func start() async throws {
        print("[NotesListenModeManager] 🎬 start() called - current state: \(state)")
        
        guard state == .idle else {
            print("[NotesListenModeManager] ⚠️ Cannot start - already running (state: \(state))")
            return
        }
        
        print("[NotesListenModeManager] ✅ State is idle, proceeding with start")
        
        // Check authorizations
        try await checkAuthorizations()
        
        // Reset state
        currentTranscript = ""
        partialTranscript = ""
        finalTranscript = nil
        stopCommandDetected = false
        
        // Start audio engine
        try startAudioEngine()
        
        // Start transcription with VAD (3 second timeout for dictation)
        try await startTranscription()
        
        state = .listening
        print("[NotesListenModeManager] 🎉 Listen mode fully started")
    }
    
    func stop() {
        print("[NotesListenModeManager] 🛑 Stopping listen mode (current state: \(state))")
        
        transcriberTask?.cancel()
        vadTranscriber?.stop()
        stopAudioEngine()
        
        // If we have a transcript and haven't already set final, set it now
        if finalTranscript == nil && !currentTranscript.isEmpty {
            let cleanedTranscript = stopCommandDetected ? removeStopCommand(from: currentTranscript) : currentTranscript
            finalTranscript = cleanedTranscript
            print("[NotesListenModeManager] 📝 Setting final transcript on manual stop: '\(cleanedTranscript)'")
        }
        
        print("[NotesListenModeManager] ⚙️ Setting state to .idle and clearing transcripts")
        state = .idle
        partialTranscript = ""
        currentTranscript = ""
        stopCommandDetected = false
        
        print("[NotesListenModeManager] ✅ Listen mode stopped - state=\(state)")
    }
    
    // MARK: - Private Methods - Authorization
    
    private func checkAuthorizations() async throws {
        // Check speech recognition authorization
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus != .authorized {
            throw NSError(domain: "NotesListenMode", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
        
        // Check microphone authorization
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus != .authorized {
            throw NSError(domain: "NotesListenMode", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone not authorized"])
        }
    }
    
    // MARK: - Private Methods - Audio Engine
    
    private func startAudioEngine() throws {
        stopAudioEngine()
        
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let bus = 0
        
        let format = inputNode.inputFormat(forBus: bus)
        
        // Install tap to process audio
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            Task { @MainActor [weak self] in
                await self?.processAudioBuffer(buffer)
            }
        }
        
        // Start engine
        try audioEngine.start()
        
        self.audioEngine = audioEngine
        self.audioInput = inputNode
        
        print("[NotesListenModeManager] Audio engine started")
    }
    
    private func stopAudioEngine() {
        if let inputNode = audioInput {
            inputNode.removeTap(onBus: 0)
        }
        
        audioEngine?.stop()
        audioEngine = nil
        audioInput = nil
        
        print("[NotesListenModeManager] Audio engine stopped")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard state == .listening else { return }
        vadTranscriber?.appendAudioBuffer(buffer)
    }
    
    // MARK: - Private Methods - Transcription
    
    private func startTranscription() async throws {
        print("[NotesListenModeManager] 📝 Starting transcription with VAD (3s timeout)")
        
        // Use 3 second timeout for dictation (users may pause between thoughts)
        let transcriber = try SimplifiedVADTranscriber(silenceTimeout: 3.0)
        self.vadTranscriber = transcriber
        
        print("[NotesListenModeManager] ▶️ Starting VAD transcriber")
        try transcriber.start()
        
        print("[NotesListenModeManager] 🎧 Starting event listener for transcription")
        // Listen for transcription events
        transcriberTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await event in transcriber.events {
                await self.handleTranscriptEvent(event)
            }
        }
        
        print("[NotesListenModeManager] ✅ Transcription started")
    }
    
    private func handleTranscriptEvent(_ event: TranscriptEvent) async {
        switch event {
        case .partial(let text):
            print("[NotesListenModeManager] 📝 Partial: '\(text)'")
            currentTranscript = text
            partialTranscript = text
            
            // Check for stop command in partial transcript
            if checkForStopCommand(in: text) {
                print("[NotesListenModeManager] 🛑 Stop command detected in partial transcript!")
                stopCommandDetected = true
                
                // Clean the transcript and set as final
                let cleanedTranscript = removeStopCommand(from: text)
                finalTranscript = cleanedTranscript
                
                // Stop listening
                await onTranscriptionEnded()
            }
            
        case .final(let text, let confidence):
            let confidenceStr = confidence.map { String(format: "%.2f", $0) } ?? "N/A"
            print("[NotesListenModeManager] ✅ Final transcript: '\(text)' (confidence: \(confidenceStr))")
            
            currentTranscript = text
            partialTranscript = text
            
            // Check for stop command in final transcript
            if checkForStopCommand(in: text) {
                print("[NotesListenModeManager] 🛑 Stop command detected in final transcript!")
                stopCommandDetected = true
                
                // Clean the transcript and set as final
                let cleanedTranscript = removeStopCommand(from: text)
                finalTranscript = cleanedTranscript
                
                // Stop listening
                await onTranscriptionEnded()
            }
            
        case .silenceDetected:
            print("[NotesListenModeManager] 🔇 Silence detected - ending transcription")
            print("[NotesListenModeManager] 📊 Full transcript: '\(currentTranscript)'")
            
            // If stop command was detected, transcript is already cleaned and set
            if !stopCommandDetected {
                finalTranscript = currentTranscript.isEmpty ? nil : currentTranscript
            }
            
            await onTranscriptionEnded()
            
        case .error(let error):
            print("[NotesListenModeManager] ❌ Transcription error: \(error)")
            state = .error(error.localizedDescription)
            await onTranscriptionEnded()
            
        case .ended:
            print("[NotesListenModeManager] 🏁 Transcription ended normally")
            await onTranscriptionEnded()
        }
    }
    
    private func onTranscriptionEnded() async {
        print("[NotesListenModeManager] 🔚 Transcription ended, cleaning up")
        stopTranscription()
        stopAudioEngine()
        
        // Only set state to idle if not already in error state
        if case .listening = state {
            state = .idle
        }
    }
    
    private func stopTranscription() {
        print("[NotesListenModeManager] 🧹 Cleaning up transcription resources")
        transcriberTask?.cancel()
        vadTranscriber?.stop()
        vadTranscriber = nil
    }
    
    // MARK: - Stop Command Detection
    
    /// Check if the transcript ends with "Athena stop listening" (fuzzy match on Athena)
    private func checkForStopCommand(in transcript: String) -> Bool {
        let words = transcript.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        // Need at least 3 words
        guard words.count >= 3 else { return false }
        
        // Get last 3 words
        let lastThreeWords = Array(words.suffix(3))
        
        // Check pattern: [fuzzy "athena"] "stop" "listening"
        let firstWord = lastThreeWords[0]
        let secondWord = lastThreeWords[1]
        let thirdWord = lastThreeWords[2]
        
        // Fuzzy match on first word (Athena)
        let athenaMatch = FuzzyStringMatcher.fuzzyMatch(firstWord, target: "athena", threshold: stopCommandThreshold)
        
        // Exact match on "stop" and "listening"
        let stopMatch = secondWord == "stop"
        let listeningMatch = thirdWord == "listening"
        
        let isMatch = athenaMatch && stopMatch && listeningMatch
        
        if isMatch {
            print("[NotesListenModeManager] 🎯 Stop command matched! Words: [\(firstWord), \(secondWord), \(thirdWord)]")
        }
        
        return isMatch
    }
    
    /// Remove the stop command from the transcript
    private func removeStopCommand(from transcript: String) -> String {
        let words = transcript.components(separatedBy: .whitespaces)
        
        // Remove last 3 words (the stop command)
        guard words.count > 3 else { return "" }
        
        let cleanedWords = Array(words.dropLast(3))
        let cleanedTranscript = cleanedWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        
        print("[NotesListenModeManager] 🧹 Removed stop command: '\(transcript)' → '\(cleanedTranscript)'")
        
        return cleanedTranscript
    }
}

