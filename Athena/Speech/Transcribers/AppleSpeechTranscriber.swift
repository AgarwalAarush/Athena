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
        print("[AppleSpeechTranscriber] startStream called with sampleRate: \(sampleRate)")

        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        print("[AppleSpeechTranscriber] Authorization status: \(authStatus)")
        guard authStatus == .authorized else {
            print("[AppleSpeechTranscriber] ERROR: Not authorized")
            throw TranscriberError.notAuthorized
        }

        // Cancel any ongoing task
        cancel()

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false // Use cloud recognition for better accuracy
        self.recognitionRequest = request
        print("[AppleSpeechTranscriber] Created recognition request")

        // Create audio format for the request (16kHz, mono, Int16 PCM)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("[AppleSpeechTranscriber] ERROR: Failed to create audio format")
            throw TranscriberError.audioFormatCreationFailed
        }
        self.audioFormat = format
        print("[AppleSpeechTranscriber] Created audio format: \(format)")

        // Start recognition task
        print("[AppleSpeechTranscriber] Starting recognition task")
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else {
                print("[AppleSpeechTranscriber] Recognition task callback: self is nil")
                return
            }

            if let error = error {
                print("[AppleSpeechTranscriber] Recognition task error: \(error.localizedDescription) (domain: \((error as NSError).domain), code: \((error as NSError).code))")

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

            guard let result = result else {
                print("[AppleSpeechTranscriber] Recognition task callback: no result")
                return
            }

            let transcription = result.bestTranscription.formattedString
            let confidence = result.bestTranscription.segments.last?.confidence
            print("[AppleSpeechTranscriber] Recognition result - isFinal: \(result.isFinal), transcription: '\(transcription)', confidence: \(confidence ?? 0)")

            if result.isFinal {
                // Check if final result is empty (no speech detected)
                if transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("[AppleSpeechTranscriber] Final result is empty - no speech detected")
                    self.eventsContinuation?.yield(.error(NSError(domain: "SpeechRecognition", code: -1, userInfo: [NSLocalizedDescriptionKey: "No speech detected. Please speak clearly and ensure your microphone is working."])))
                } else {
                    print("[AppleSpeechTranscriber] Yielding final transcript: '\(transcription)'")
                    self.eventsContinuation?.yield(.final(transcription, confidence.map(Double.init)))
                }
                print("[AppleSpeechTranscriber] Yielding ended event")
                self.eventsContinuation?.yield(.ended)
            } else {
                print("[AppleSpeechTranscriber] Yielding partial transcript: '\(transcription)'")
                self.eventsContinuation?.yield(.partial(transcription))
            }
        }
        print("[AppleSpeechTranscriber] Recognition task started successfully")
    }

    func feed(_ frame: AudioFrame) async {
        guard let request = recognitionRequest,
              let audioFormat = audioFormat else {
            print("[AppleSpeechTranscriber] feed: ERROR - No recognition request or audio format")
            return
        }

        print("[AppleSpeechTranscriber] feed: Received audio frame with \(frame.samples.count) samples")

        // Convert Float32 samples to Int16 PCM
        let int16Samples = floatToInt16(frame.samples)
        print("[AppleSpeechTranscriber] feed: Converted to \(int16Samples.count) Int16 samples")

        // Create PCM buffer with Int16 format
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(int16Samples.count)
        ) else {
            print("[AppleSpeechTranscriber] feed: ERROR - Failed to create PCM buffer")
            return
        }

        buffer.frameLength = buffer.frameCapacity

        // Copy Int16 samples to buffer
        guard let channelData = buffer.int16ChannelData else {
            print("[AppleSpeechTranscriber] feed: ERROR - No channel data in buffer")
            return
        }

        int16Samples.withUnsafeBufferPointer { srcBuffer in
            channelData[0].update(from: srcBuffer.baseAddress!, count: int16Samples.count)
        }

        // Append to recognition request
        print("[AppleSpeechTranscriber] feed: Appending buffer to recognition request")
        request.append(buffer)
        print("[AppleSpeechTranscriber] feed: Buffer appended successfully")
    }

    func events() -> AsyncStream<TranscriptEvent> {
        AsyncStream { continuation in
            self.eventsContinuation = continuation
        }
    }

    func finish() async {
        print("[AppleSpeechTranscriber] finish() called")
        recognitionRequest?.endAudio()
        print("[AppleSpeechTranscriber] finish: Called endAudio() on recognition request")

        // Wait a bit for final results
        print("[AppleSpeechTranscriber] finish: Waiting 0.5 seconds for final results")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        print("[AppleSpeechTranscriber] finish: Wait complete, cleaning up")

        // Clean up
        recognitionRequest = nil
        recognitionTask = nil
        eventsContinuation?.finish()
        eventsContinuation = nil
        print("[AppleSpeechTranscriber] finish: Cleanup complete")
    }

    func cancel() {
        print("[AppleSpeechTranscriber] cancel() called")
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        eventsContinuation?.finish()
        eventsContinuation = nil
        print("[AppleSpeechTranscriber] cancel: Cleanup complete")
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
