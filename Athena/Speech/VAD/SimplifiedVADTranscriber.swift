//
//  SimplifiedVADTranscriber.swift
//  Athena
//
//  Speech transcription with custom VAD (Voice Activity Detection)
//  Compatible with current macOS versions
//

import Foundation
import Speech
import AVFoundation

/// Simplified transcriber with custom VAD using existing Speech framework
final class SimplifiedVADTranscriber: NSObject {

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let eventsContinuation: AsyncStream<TranscriptEvent>.Continuation
    private let eventsStream: AsyncStream<TranscriptEvent>

    // VAD parameters
    private var lastSpeechTime: Date?
    private var silenceTimer: Task<Void, Never>?
    private let silenceTimeout: TimeInterval = 2.0 // 2 seconds

    private var isRunning = false

    // MARK: - Initialization

    init(locale: Locale = .current) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw TranscriberError.recognizerUnavailable
        }

        guard recognizer.isAvailable else {
            throw TranscriberError.recognizerUnavailable
        }

        self.speechRecognizer = recognizer

        var continuation: AsyncStream<TranscriptEvent>.Continuation!
        self.eventsStream = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation

        super.init()
    }

    deinit {
        eventsContinuation.finish()
        silenceTimer?.cancel()
    }

    // MARK: - Public Methods

    var events: AsyncStream<TranscriptEvent> {
        eventsStream
    }

    func start() throws {
        guard !isRunning else { return }

        print("[SimplifiedVADTranscriber] Starting with VAD")

        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            throw TranscriberError.notAuthorized
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        self.recognitionRequest = request
        isRunning = true

        // Reset VAD state
        lastSpeechTime = Date()
        startSilenceDetectionTimer()

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }

        print("[SimplifiedVADTranscriber] Started successfully")
    }

    func stop() {
        print("[SimplifiedVADTranscriber] Stopping")

        silenceTimer?.cancel()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        isRunning = false
    }

    func cancel() {
        stop()
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)

        // Update last speech time
        lastSpeechTime = Date()
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("[SimplifiedVADTranscriber] Recognition error: \(error.localizedDescription)")
            eventsContinuation.yield(.error(error))
            return
        }

        guard let result = result else { return }

        let transcript = result.bestTranscription.formattedString

        // Update last speech time on new results
        lastSpeechTime = Date()

        if result.isFinal {
            print("[SimplifiedVADTranscriber] Final: \(transcript)")
            let confidence = Double(result.bestTranscription.segments.first?.confidence ?? 0.0)
            eventsContinuation.yield(.final(transcript, confidence))
        } else {
            print("[SimplifiedVADTranscriber] Partial: \(transcript)")
            eventsContinuation.yield(.partial(transcript))
        }
    }

    private func startSilenceDetectionTimer() {
        silenceTimer?.cancel()

        silenceTimer = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5 seconds

                guard let lastSpeech = self.lastSpeechTime else { continue }

                let silenceDuration = Date().timeIntervalSince(lastSpeech)

                if silenceDuration >= self.silenceTimeout {
                    print("[SimplifiedVADTranscriber] Silence detected for \(silenceDuration)s")
                    self.eventsContinuation.yield(.silenceDetected)
                    self.lastSpeechTime = nil
                    break
                }
            }
        }
    }
}
