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
    private var silenceTimeout: TimeInterval = 2.0 // Configurable silence timeout
    private var hasReceivedFirstTranscript = false
    private var restartAttempts = 0
    private let maxRestartAttempts = 3

    private var isRunning = false

    // MARK: - Initialization

    init(locale: Locale = .current, silenceTimeout: TimeInterval = 2.0) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw TranscriberError.recognizerUnavailable
        }

        guard recognizer.isAvailable else {
            throw TranscriberError.recognizerUnavailable
        }

        self.speechRecognizer = recognizer
        self.silenceTimeout = silenceTimeout

        var continuation: AsyncStream<TranscriptEvent>.Continuation!
        self.eventsStream = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation

        super.init()

        print("[SimplifiedVADTranscriber] 🎛️ Initialized with silence timeout: \(silenceTimeout)s")
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
        guard !isRunning else {
            print("[SimplifiedVADTranscriber] ⚠️ Already running, ignoring start request")
            return
        }

        print("[SimplifiedVADTranscriber] 🎬 Starting VAD transcriber (silence timeout: \(silenceTimeout)s, restart attempts: \(restartAttempts)/\(maxRestartAttempts))")

        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            print("[SimplifiedVADTranscriber] ❌ Not authorized")
            throw TranscriberError.notAuthorized
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // ✅ Use on-device for better silence tolerance
        request.taskHint = .dictation // Optimize for longer speech

        print("[SimplifiedVADTranscriber] 🔧 Recognition request configured: on-device=true, taskHint=dictation")

        self.recognitionRequest = request
        isRunning = true

        // Reset VAD state - DON'T start timer yet!
        lastSpeechTime = nil
        hasReceivedFirstTranscript = false
        print("[SimplifiedVADTranscriber] 🔇 VAD state reset - waiting for first speech before starting silence detection")

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }

        print("[SimplifiedVADTranscriber] ✅ Recognition task started successfully")
    }

    func stop() {
        print("[SimplifiedVADTranscriber] 🛑 Stopping VAD transcriber (isRunning: \(isRunning))")

        silenceTimer?.cancel()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        isRunning = false
        hasReceivedFirstTranscript = false
        lastSpeechTime = nil
        restartAttempts = 0

        print("[SimplifiedVADTranscriber] ✅ Stopped - all state reset, ready for next session")
    }

    func cancel() {
        stop()
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRunning, recognitionRequest != nil else {
            print("[SimplifiedVADTranscriber] ⚠️ Received audio buffer but not running or no request")
            return
        }

        recognitionRequest?.append(buffer)

        // Update last speech time whenever we receive audio
        let now = Date()
        if let last = lastSpeechTime {
            let gap = now.timeIntervalSince(last)
            if gap > 0.5 { // Log if there's a noticeable gap
                print("[SimplifiedVADTranscriber] 🔊 Audio buffer received after \(String(format: "%.2f", gap))s gap")
            }
        } else {
            print("[SimplifiedVADTranscriber] 🔊 First audio buffer received")
        }
        lastSpeechTime = now
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("[SimplifiedVADTranscriber] ❌ Recognition error: \(error.localizedDescription)")
            eventsContinuation.yield(.error(error))
            return
        }

        guard let result = result else { return }

        let transcript = result.bestTranscription.formattedString

        // Start silence detection on FIRST transcript received
        if !hasReceivedFirstTranscript {
            hasReceivedFirstTranscript = true
            lastSpeechTime = Date()
            startSilenceDetectionTimer()
            print("[SimplifiedVADTranscriber] 🎤 First speech detected! Starting silence timer NOW (2s timeout)")
        } else {
            // Update last speech time on subsequent results
            lastSpeechTime = Date()
        }

        if result.isFinal {
            print("[SimplifiedVADTranscriber] ✅ Final: '\(transcript)'")
            let confidence = Double(result.bestTranscription.segments.first?.confidence ?? 0.0)
            eventsContinuation.yield(.final(transcript, confidence))
        } else {
            print("[SimplifiedVADTranscriber] 📝 Partial: '\(transcript)' (resetting silence timer)")
            eventsContinuation.yield(.partial(transcript))
        }
    }

    private func startSilenceDetectionTimer() {
        silenceTimer?.cancel()

        print("[SimplifiedVADTranscriber] 🔔 Silence detection timer STARTED - checking every 0.5s for \(silenceTimeout)s of silence")

        silenceTimer = Task { [weak self] in
            guard let self = self else { return }

            var checkCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5 seconds
                checkCount += 1

                guard let lastSpeech = self.lastSpeechTime else {
                    print("[SimplifiedVADTranscriber] ⏸️ Check #\(checkCount): No lastSpeechTime set, continuing...")
                    continue
                }

                let silenceDuration = Date().timeIntervalSince(lastSpeech)
                print("[SimplifiedVADTranscriber] 🔍 Check #\(checkCount): Silence duration = \(String(format: "%.1f", silenceDuration))s / \(self.silenceTimeout)s")

                if silenceDuration >= self.silenceTimeout {
                    print("[SimplifiedVADTranscriber] 🔇 SILENCE DETECTED! \(String(format: "%.1f", silenceDuration))s of silence - ending transcription")
                    self.eventsContinuation.yield(.silenceDetected)
                    self.lastSpeechTime = nil
                    break
                }
            }

            print("[SimplifiedVADTranscriber] 🛑 Silence detection timer STOPPED after \(checkCount) checks")
        }
    }
}
