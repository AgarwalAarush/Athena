//
//  WakeWordTranscriptionManager.swift
//  Athena
//
//  Manages wake word detection and automatic transcription with VAD
//

import Foundation
import Speech
import AVFoundation
import Combine

/// State machine for wake word + transcription workflow
enum WakeWordState {
    case idle
    case listeningForWakeWord
    case transcribing
    case cooldown
}

/// Manages the complete wake word → transcribe → VAD → repeat cycle
@MainActor
class WakeWordTranscriptionManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var state: WakeWordState = .idle
    @Published private(set) var partialTranscript: String = ""
    @Published private(set) var finalTranscript: String?

    // MARK: - Private Properties

    private var wakeWordDetector: WakeWordDetector?
    private var modernTranscriber: Any? // ModernSpeechTranscriber (iOS 26.0+)
    private var fallbackTranscriber: AppleSpeechTranscriber? // Fallback for older OS

    private var audioEngine: AVAudioEngine?
    private var audioInput: AVAudioInputNode?

    private var detectorTask: Task<Void, Never>?
    private var transcriberTask: Task<Void, Never>?

    private let useModernAPI: Bool

    // MARK: - Initialization

    init() {
        // Check if modern API is available
        if #available(macOS 26.0, *) {
            self.useModernAPI = true
            print("[WakeWordTranscriptionManager] Using modern Speech API with SpeechDetector")
        } else {
            self.useModernAPI = false
            print("[WakeWordTranscriptionManager] Using fallback API (modern Speech API not available)")
        }
    }

    deinit {
        detectorTask?.cancel()
        transcriberTask?.cancel()
        stopAudioEngine()
    }

    // MARK: - Public Methods

    func start() async throws {
        print("[WakeWordTranscriptionManager] Starting wake word mode")

        guard state == .idle else {
            print("[WakeWordTranscriptionManager] Already running (state: \(state))")
            return
        }

        // Check authorizations
        try await checkAuthorizations()

        // Start audio engine
        try startAudioEngine()

        // Start listening for wake word
        try await startWakeWordDetection()
    }

    func stop() {
        print("[WakeWordTranscriptionManager] Stopping wake word mode")

        detectorTask?.cancel()
        transcriberTask?.cancel()

        Task {
            if let detector = wakeWordDetector {
                await detector.stop()
            }
        }

        if useModernAPI {
            if #available(macOS 26.0, *) {
                if let transcriber = modernTranscriber as? ModernSpeechTranscriber {
                    transcriber.stop()
                }
            }
        } else {
            fallbackTranscriber?.cancel()
        }

        stopAudioEngine()

        state = .idle
        partialTranscript = ""
        finalTranscript = nil
    }

    // MARK: - Private Methods - Authorization

    private func checkAuthorizations() async throws {
        // Check speech recognition authorization
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus != .authorized {
            throw WakeWordError.notAuthorized
        }

        // Check microphone authorization
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus != .authorized {
            throw WakeWordError.notAuthorized
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

        print("[WakeWordTranscriptionManager] Audio engine started")
    }

    private func stopAudioEngine() {
        if let inputNode = audioInput {
            inputNode.removeTap(onBus: 0)
        }

        audioEngine?.stop()
        audioEngine = nil
        audioInput = nil

        print("[WakeWordTranscriptionManager] Audio engine stopped")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        switch state {
        case .listeningForWakeWord:
            // Send audio to wake word detector
            if let detector = wakeWordDetector {
                await detector.processAudioBuffer(buffer)
            }

        case .transcribing:
            // Send audio to transcriber
            if useModernAPI {
                if #available(macOS 26.0, *) {
                    if let transcriber = modernTranscriber as? ModernSpeechTranscriber {
                        try? await transcriber.processAudioBuffer(buffer)
                    }
                }
            } else {
                // Fallback transcriber uses its own audio engine, so we don't need to send buffers
            }

        default:
            break
        }
    }

    // MARK: - Private Methods - Wake Word Detection

    private func startWakeWordDetection() async throws {
        print("[WakeWordTranscriptionManager] Starting wake word detection")

        let detector = try WakeWordDetector()
        self.wakeWordDetector = detector

        try await detector.start()

        state = .listeningForWakeWord

        // Listen for wake word events
        detectorTask = Task { [weak self] in
            guard let self = self else { return }

            for await _ in detector.events {
                await self.onWakeWordDetected()
            }
        }
    }

    private func onWakeWordDetected() async {
        print("[WakeWordTranscriptionManager] 🎤 Wake word detected! Starting transcription...")

        // Stop wake word detection
        if let detector = wakeWordDetector {
            await detector.stop()
        }
        detectorTask?.cancel()

        // Start full transcription with VAD
        do {
            try await startTranscription()
        } catch {
            print("[WakeWordTranscriptionManager] Error starting transcription: \(error)")
            // Fall back to wake word detection
            try? await startWakeWordDetection()
        }
    }

    // MARK: - Private Methods - Transcription

    private func startTranscription() async throws {
        print("[WakeWordTranscriptionManager] Starting transcription with VAD")

        state = .transcribing
        partialTranscript = ""
        finalTranscript = nil

        if useModernAPI {
            if #available(macOS 26.0, *) {
                try await startModernTranscription()
            }
        } else {
            try await startFallbackTranscription()
        }
    }

    @available(macOS 26.0, *)
    private func startModernTranscription() async throws {
        let transcriber = ModernSpeechTranscriber(enableVAD: true, vadSensitivity: .medium)
        self.modernTranscriber = transcriber

        try await transcriber.start()

        // Listen for transcription events
        transcriberTask = Task { [weak self] in
            guard let self = self else { return }

            for await event in transcriber.events {
                await self.handleTranscriptEvent(event)
            }
        }
    }

    private func startFallbackTranscription() async throws {
        let transcriber = try AppleSpeechTranscriber()
        self.fallbackTranscriber = transcriber

        try await transcriber.startStream(sampleRate: 16000)

        // Listen for transcription events
        transcriberTask = Task { [weak self] in
            guard let self = self else { return }

            for await event in transcriber.events {
                await self.handleTranscriptEvent(event)
            }
        }
    }

    private func handleTranscriptEvent(_ event: TranscriptEvent) async {
        switch event {
        case .partial(let text):
            print("[WakeWordTranscriptionManager] Partial: \(text)")
            partialTranscript = text

        case .final(let text, _):
            print("[WakeWordTranscriptionManager] Final: \(text)")
            finalTranscript = text
            partialTranscript = ""

            // Note: Don't end transcription on final - wait for VAD silence detection

        case .silenceDetected:
            print("[WakeWordTranscriptionManager] 🔇 Silence detected - ending transcription")
            await onSilenceDetected()

        case .error(let error):
            print("[WakeWordTranscriptionManager] Transcription error: \(error)")
            await onTranscriptionEnded()

        case .ended:
            print("[WakeWordTranscriptionManager] Transcription ended")
            await onTranscriptionEnded()
        }
    }

    private func onSilenceDetected() async {
        print("[WakeWordTranscriptionManager] Transcription complete, returning to wake word detection")

        // Stop transcription
        stopTranscription()

        // Small cooldown before restarting wake word detection
        state = .cooldown
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Return to wake word detection
        do {
            try await startWakeWordDetection()
        } catch {
            print("[WakeWordTranscriptionManager] Error restarting wake word detection: \(error)")
            state = .idle
        }
    }

    private func onTranscriptionEnded() async {
        print("[WakeWordTranscriptionManager] Transcription ended, returning to wake word detection")

        stopTranscription()

        // Return to wake word detection
        do {
            try await startWakeWordDetection()
        } catch {
            print("[WakeWordTranscriptionManager] Error restarting wake word detection: \(error)")
            state = .idle
        }
    }

    private func stopTranscription() {
        transcriberTask?.cancel()

        if useModernAPI {
            if #available(macOS 26.0, *) {
                if let transcriber = modernTranscriber as? ModernSpeechTranscriber {
                    transcriber.stop()
                }
            }
        } else {
            fallbackTranscriber?.cancel()
        }

        modernTranscriber = nil
        fallbackTranscriber = nil
    }
}
