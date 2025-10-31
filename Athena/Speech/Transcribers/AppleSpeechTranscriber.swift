//
//  AppleSpeechTranscriber.swift
//  Athena
//
//  Speech transcription using Apple's Speech Recognition framework.
//

import Foundation
import Combine
import Speech
import AVFoundation

/// Transcriber implementation using Apple's SFSpeechRecognizer
final class AppleSpeechTranscriber: Transcriber {
    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var eventsContinuation: AsyncStream<TranscriptEvent>.Continuation?
    private var audioFormat: AVAudioFormat?

    // MARK: - Initialization

    init(locale: Locale = .current) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw TranscriberError.recognizerUnavailable
        }

        guard recognizer.isAvailable else {
            throw TranscriberError.recognizerUnavailable
        }

        self.speechRecognizer = recognizer
    }

    // MARK: - Transcriber Protocol

    func startStream(sampleRate: Double) async throws {
        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            throw TranscriberError.notAuthorized
        }

        // Cancel any ongoing task
        cancel()

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false // Use cloud recognition for better accuracy
        self.recognitionRequest = request

        // Create audio format for the request (16kHz, mono, Int16 PCM)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw TranscriberError.audioFormatCreationFailed
        }
        self.audioFormat = format

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                // Handle specific Speech framework errors
                let nsError = error as NSError
                let errorCode = nsError.code
                let errorDomain = nsError.domain
                
                // Check for specific error codes
                if errorDomain == kCFErrorDomainCFNetwork as String {
                    // Network-related error
                    let errorMessage = "Network error during speech recognition: \(error.localizedDescription)"
                    self.eventsContinuation?.yield(.error(NSError(domain: errorDomain, code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else if errorCode == 216 || errorCode == 1700 {
                    // Error codes that might indicate no speech detected or recognition issues
                    let errorMessage = error.localizedDescription.isEmpty ? "No speech detected. Please speak clearly and ensure your microphone is working." : error.localizedDescription
                    self.eventsContinuation?.yield(.error(NSError(domain: errorDomain, code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    // Generic error
                    self.eventsContinuation?.yield(.error(error))
                }
                return
            }

            guard let result = result else { return }

            let transcription = result.bestTranscription.formattedString
            let confidence = result.bestTranscription.segments.last?.confidence

            if result.isFinal {
                // Check if final result is empty (no speech detected)
                if transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.eventsContinuation?.yield(.error(NSError(domain: "SpeechRecognition", code: -1, userInfo: [NSLocalizedDescriptionKey: "No speech detected. Please speak clearly and ensure your microphone is working."])))
                } else {
                    self.eventsContinuation?.yield(.final(transcription, confidence.map(Double.init)))
                }
                self.eventsContinuation?.yield(.ended)
            } else {
                self.eventsContinuation?.yield(.partial(transcription))
            }
        }
    }

    func feed(_ frame: AudioFrame) async {
        guard let request = recognitionRequest,
              let audioFormat = audioFormat else {
            return
        }

        // Convert Float32 samples to Int16 PCM
        let int16Samples = floatToInt16(frame.samples)

        // Create PCM buffer with Int16 format
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(int16Samples.count)
        ) else {
            return
        }

        buffer.frameLength = buffer.frameCapacity

        // Copy Int16 samples to buffer
        guard let channelData = buffer.int16ChannelData else {
            return
        }

        int16Samples.withUnsafeBufferPointer { srcBuffer in
            channelData[0].update(from: srcBuffer.baseAddress!, count: int16Samples.count)
        }

        // Append to recognition request
        request.append(buffer)
    }

    func events() -> AsyncStream<TranscriptEvent> {
        AsyncStream { continuation in
            self.eventsContinuation = continuation
        }
    }

    func finish() async {
        recognitionRequest?.endAudio()

        // Wait a bit for final results
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Clean up
        recognitionRequest = nil
        recognitionTask = nil
        eventsContinuation?.finish()
        eventsContinuation = nil
    }

    func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        eventsContinuation?.finish()
        eventsContinuation = nil
    }

    // MARK: - Private Helpers

    private func floatToInt16(_ floatSamples: [Float]) -> [Int16] {
        floatSamples.map { sample in
            // Clamp to [-1.0, 1.0] and convert to Int16 range
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }
    }

    deinit {
        cancel()
    }
}

// MARK: - Errors

enum TranscriberError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized
    case audioFormatCreationFailed

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available for this locale"
        case .notAuthorized:
            return "Speech recognition is not authorized. Please grant permission in System Preferences."
        case .audioFormatCreationFailed:
            return "Failed to create audio format for speech recognition"
        }
    }
}
