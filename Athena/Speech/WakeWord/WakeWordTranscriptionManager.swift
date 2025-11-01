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
    private var vadTranscriber: SimplifiedVADTranscriber?

    private var audioEngine: AVAudioEngine?
    private var audioInput: AVAudioInputNode?

    private var detectorTask: Task<Void, Never>?
    private var transcriberTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        print("[WakeWordTranscriptionManager] Initializing with simplified VAD")
    }

    deinit {
        detectorTask?.cancel()
        transcriberTask?.cancel()
        Task { @MainActor in
            self.stopAudioEngine()
        }
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

        wakeWordDetector?.stop()
        vadTranscriber?.stop()

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
            wakeWordDetector?.processAudioBuffer(buffer)

        case .transcribing:
            // Send audio to VAD transcriber
            vadTranscriber?.appendAudioBuffer(buffer)

        default:
            break
        }
    }

    // MARK: - Private Methods - Wake Word Detection

    private func startWakeWordDetection() async throws {
        print("[WakeWordTranscriptionManager] Starting wake word detection")

        let detector = try WakeWordDetector()
        self.wakeWordDetector = detector

        try detector.start()

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
        wakeWordDetector?.stop()
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

        let transcriber = try SimplifiedVADTranscriber()
        self.vadTranscriber = transcriber

        try transcriber.start()

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
        vadTranscriber?.stop()
        vadTranscriber = nil
    }
}
