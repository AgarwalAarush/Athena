//
//  WakeWordDetector.swift
//  Athena
//
//  Detects the wake word "Athena" using continuous speech recognition
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Detects wake word "Athena" using lightweight continuous recognition
final class WakeWordDetector {

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let wakeWord = "athena"
    private let wakeWordAlternatives = ["athena", "athina", "athene", "athenna"] // Common misrecognitions

    // Events
    private let wakeWordDetectedContinuation: AsyncStream<Void>.Continuation
    private let wakeWordDetectedStream: AsyncStream<Void>

    private var isListening = false
    private let queue = DispatchQueue(label: "com.athena.wakeword", qos: .userInitiated)

    // MARK: - Initialization

    init(locale: Locale = Locale(identifier: "en-US")) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw WakeWordError.recognizerUnavailable
        }

        guard recognizer.isAvailable else {
            throw WakeWordError.recognizerUnavailable
        }

        self.speechRecognizer = recognizer

        var continuation: AsyncStream<Void>.Continuation!
        self.wakeWordDetectedStream = AsyncStream { continuation = $0 }
        self.wakeWordDetectedContinuation = continuation
    }

    deinit {
        wakeWordDetectedContinuation.finish()
    }

    // MARK: - Public Methods

    var events: AsyncStream<Void> {
        wakeWordDetectedStream
    }

    func start() throws {
        guard !isListening else {
            print("[WakeWordDetector] Already listening")
            return
        }

        print("[WakeWordDetector] Starting wake word detection for '\(wakeWord)'")

        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            throw WakeWordError.notAuthorized
        }

        // Cancel any ongoing task
        stop()

        // Create recognition request optimized for wake word detection
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Use on-device for low latency and privacy
        request.taskHint = .search // Optimize for short phrases

        self.recognitionRequest = request
        isListening = true

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }

        print("[WakeWordDetector] Wake word detection started")
    }

    func stop() {
        print("[WakeWordDetector] Stopping wake word detection")

        // Cancel and nil out the task
        recognitionTask?.cancel()
        recognitionTask = nil

        // End audio and nil out the request to clear buffer
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        isListening = false
        
        print("[WakeWordDetector] ✅ Stopped - buffer cleared, ready for fresh start")
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self = self, self.isListening, let request = self.recognitionRequest else {
                return
            }

            request.append(buffer)
        }
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("[WakeWordDetector] Recognition error: \(error.localizedDescription)")

            // Restart on certain errors
            let nsError = error as NSError
            if nsError.code != 203 { // Ignore "request ended" errors
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay before restart
                    try? self.start()
                }
            }
            return
        }

        guard let result = result else { return }

        let transcript = result.bestTranscription.formattedString.lowercased()
        print("[WakeWordDetector] Heard: \(transcript)")

        // Check if wake word is detected
        if containsWakeWord(in: transcript) {
            print("[WakeWordDetector] ✅ Wake word detected!")
            wakeWordDetectedContinuation.yield(())

            // Stop immediately to clear buffer - DO NOT restart
            // (Manager will restart us after transcription ends)
            stop()
        }
    }

    private func containsWakeWord(in text: String) -> Bool {
        let cleanedText = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for exact wake word
        if cleanedText.contains(wakeWord) {
            return true
        }

        // Check for common misrecognitions
        for alternative in wakeWordAlternatives {
            if cleanedText.contains(alternative) {
                return true
            }
        }

        // Check as individual word (not substring)
        let words = cleanedText.components(separatedBy: .whitespaces)
        if words.contains(wakeWord) {
            return true
        }

        for alternative in wakeWordAlternatives {
            if words.contains(alternative) {
                return true
            }
        }

        return false
    }
}

// MARK: - Errors

enum WakeWordError: Error, LocalizedError {
    case recognizerUnavailable
    case notAuthorized
    case audioEngineError

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .audioEngineError:
            return "Audio engine error"
        }
    }
}
