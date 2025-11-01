//
//  ModernSpeechTranscriber.swift
//  Athena
//
//  Modern speech transcription using SpeechAnalyzer with SpeechDetector for VAD.
//  Available on macOS 26.0+
//

import Foundation
import Speech
import AVFoundation

/// Modern transcriber using SpeechAnalyzer with built-in VAD via SpeechDetector
@available(macOS 26.0, *)
final class ModernSpeechTranscriber: NSObject, @unchecked Sendable {

    // MARK: - Properties

    private var analyzer: SpeechAnalyzer?
    private var speechTranscriber: SpeechTranscriber?
    private var speechDetector: SpeechDetector?

    private let eventsContinuation: AsyncStream<TranscriptEvent>.Continuation
    private let eventsStream: AsyncStream<TranscriptEvent>

    private let locale: Locale
    private let enableVAD: Bool
    private let vadSensitivity: SpeechDetector.SensitivityLevel

    // Silence detection for ending transcription
    private var lastSpeechTime: Date?
    private var silenceTimer: Task<Void, Never>?
    private let silenceTimeout: TimeInterval = 2.0 // 2 seconds of silence

    // MARK: - Initialization

    init(locale: Locale = .current, enableVAD: Bool = true, vadSensitivity: SpeechDetector.SensitivityLevel = .medium) {
        self.locale = locale
        self.enableVAD = enableVAD
        self.vadSensitivity = vadSensitivity

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

    func start() async throws {
        print("[ModernSpeechTranscriber] Starting with VAD enabled: \(enableVAD)")

        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            throw TranscriberError.notAuthorized
        }

        // Stop any existing analyzer
        stop()

        // Create speech analyzer
        let analyzerConfig = SpeechAnalyzer.Configuration(locale: locale)
        let analyzer = SpeechAnalyzer(configuration: analyzerConfig)
        self.analyzer = analyzer

        // Create transcriber module
        let transcriber = SpeechTranscriber()
        self.speechTranscriber = transcriber

        // Create modules array
        var modules: [any SpeechModule] = [transcriber]

        // Add VAD detector if enabled
        if enableVAD {
            let detectorOptions = SpeechDetector.DetectionOptions(sensitivityLevel: vadSensitivity)
            let detector = SpeechDetector(detectionOptions: detectorOptions, reportResults: true)
            self.speechDetector = detector
            modules.append(detector)
        }

        // Set modules
        try await analyzer.setModules(modules)

        // Start listening to results
        Task { [weak self] in
            await self?.processResults(from: transcriber)
        }

        // Start analyzer
        try await analyzer.start()

        print("[ModernSpeechTranscriber] Started successfully")
    }

    func stop() {
        print("[ModernSpeechTranscriber] Stopping")
        silenceTimer?.cancel()
        silenceTimer = nil

        if let analyzer = analyzer {
            Task {
                await analyzer.stop()
            }
        }

        analyzer = nil
        speechTranscriber = nil
        speechDetector = nil
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async throws {
        guard let analyzer = analyzer else {
            throw TranscriberError.notInitialized
        }

        try await analyzer.process(buffer: buffer)

        // Update last speech time (we're receiving audio)
        lastSpeechTime = Date()

        // Start silence detection timer if not already running
        if silenceTimer == nil && enableVAD {
            startSilenceDetectionTimer()
        }
    }

    var events: AsyncStream<TranscriptEvent> {
        eventsStream
    }

    // MARK: - Private Methods

    private func processResults(from transcriber: SpeechTranscriber) async {
        for await result in transcriber.results {
            switch result {
            case .partial(let transcript):
                print("[ModernSpeechTranscriber] Partial: \(transcript)")
                eventsContinuation.yield(.partial(transcript))

                // Reset silence timer on new speech
                lastSpeechTime = Date()

            case .final(let transcript):
                print("[ModernSpeechTranscriber] Final: \(transcript)")
                eventsContinuation.yield(.final(transcript))

                // Reset silence timer
                lastSpeechTime = Date()
            }
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
                    print("[ModernSpeechTranscriber] Silence detected for \(silenceDuration)s, signaling end")
                    self.eventsContinuation.yield(.silenceDetected)
                    self.lastSpeechTime = nil
                    break
                }
            }
        }
    }
}

// MARK: - Error Extension

extension TranscriberError {
    static var notInitialized: TranscriberError {
        .recognizerUnavailable
    }
}
