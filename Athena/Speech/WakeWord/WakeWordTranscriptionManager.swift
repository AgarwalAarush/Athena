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

    // Text accumulation across recognition sessions
    private var accumulatedText: String = ""
    private var lastSessionTranscript: String = ""

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
        print("[WakeWordTranscriptionManager] 🛑 Stopping wake word mode (current state: \(state))")

        detectorTask?.cancel()
        transcriberTask?.cancel()

        wakeWordDetector?.stop()
        vadTranscriber?.stop()

        stopAudioEngine()

        print("[WakeWordTranscriptionManager] ⚙️ Setting state to .idle and clearing transcripts")
        state = .idle
        partialTranscript = ""
        finalTranscript = nil
        accumulatedText = ""
        lastSessionTranscript = ""

        print("[WakeWordTranscriptionManager] ✅ Wake word mode stopped - state=\(state)")
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

        case .idle:
            // No processing during idle
            break

        case .cooldown:
            // No processing during cooldown
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
        print("[WakeWordTranscriptionManager] 🎤 Wake word detected! Transitioning to transcription mode...")
        print("[WakeWordTranscriptionManager] 📊 Current state: \(state)")

        // Stop wake word detection
        print("[WakeWordTranscriptionManager] 🛑 Stopping wake word detector")
        wakeWordDetector?.stop()
        detectorTask?.cancel()

        // Start full transcription with VAD
        do {
            print("[WakeWordTranscriptionManager] 🎬 Starting VAD transcription")
            try await startTranscription()
        } catch {
            print("[WakeWordTranscriptionManager] ❌ Error starting transcription: \(error)")
            // Fall back to wake word detection
            print("[WakeWordTranscriptionManager] 🔄 Falling back to wake word detection")
            try? await startWakeWordDetection()
        }
    }

    // MARK: - Private Methods - Transcription

    private func startTranscription() async throws {
        print("[WakeWordTranscriptionManager] 📝 Starting transcription with VAD")

        print("[WakeWordTranscriptionManager] 🔄 State transition: \(state) → .transcribing")
        state = .transcribing
        partialTranscript = ""
        finalTranscript = nil

        // Reset text accumulation for this new transcription session
        accumulatedText = ""
        lastSessionTranscript = ""
        print("[WakeWordTranscriptionManager] 🔄 Reset accumulated text - starting fresh transcription session")

        print("[WakeWordTranscriptionManager] 🏗️ Creating SimplifiedVADTranscriber")
        let transcriber = try SimplifiedVADTranscriber()
        self.vadTranscriber = transcriber

        print("[WakeWordTranscriptionManager] ▶️ Starting VAD transcriber")
        try transcriber.start()

        print("[WakeWordTranscriptionManager] 🎧 Starting event listener for transcription")
        // Listen for transcription events
        transcriberTask = Task { [weak self] in
            guard let self = self else { return }

            for await event in transcriber.events {
                await self.handleTranscriptEvent(event)
            }
        }

        print("[WakeWordTranscriptionManager] ✅ Transcription started - audio will now route to VAD")
    }

    private func handleTranscriptEvent(_ event: TranscriptEvent) async {
        switch event {
        case .partial(let text):
            // Detect if this is a new recognition session by checking if transcript got shorter
            // or doesn't start with accumulated content
            let isNewSession = !lastSessionTranscript.isEmpty &&
                               (text.count < lastSessionTranscript.count ||
                                !text.hasPrefix(lastSessionTranscript.prefix(min(text.count, lastSessionTranscript.count))))

            if isNewSession {
                // New recognition session detected - append last session to accumulated
                if !lastSessionTranscript.isEmpty {
                    if !accumulatedText.isEmpty {
                        accumulatedText += " " + lastSessionTranscript
                    } else {
                        accumulatedText = lastSessionTranscript
                    }
                    print("[WakeWordTranscriptionManager] 🔄 New recognition session detected - accumulated: '\(accumulatedText)'")
                }
                lastSessionTranscript = ""
            }

            // Update current session transcript
            lastSessionTranscript = text

            // Display accumulated + current partial
            let displayText = accumulatedText.isEmpty ? text : accumulatedText + " " + text
            print("[WakeWordTranscriptionManager] 📝 Partial: '\(text)' | Accumulated: '\(accumulatedText)' | Display: '\(displayText)'")
            partialTranscript = displayText

        case .final(let text, let confidence):
            let confidenceStr = confidence.map { String(format: "%.2f", $0) } ?? "N/A"
            print("[WakeWordTranscriptionManager] ✅ Final transcript from current session: '\(text)' (confidence: \(confidenceStr))")

            // Update last session transcript with final text
            lastSessionTranscript = text

            // Display accumulated + final
            let displayText = accumulatedText.isEmpty ? text : accumulatedText + " " + text
            print("[WakeWordTranscriptionManager] 📊 Display text: '\(displayText)'")
            partialTranscript = displayText

            // Note: Don't end transcription on final - wait for VAD silence detection

        case .silenceDetected:
            // Combine all accumulated text as the final transcript
            var fullTranscript = accumulatedText
            if !lastSessionTranscript.isEmpty {
                if !fullTranscript.isEmpty {
                    fullTranscript += " " + lastSessionTranscript
                } else {
                    fullTranscript = lastSessionTranscript
                }
            }

            print("[WakeWordTranscriptionManager] 🔇 Silence detected - ending transcription session")
            print("[WakeWordTranscriptionManager] 📊 Accumulated: '\(accumulatedText)', LastSession: '\(lastSessionTranscript)'")
            print("[WakeWordTranscriptionManager] 📊 Full transcript: '\(fullTranscript)'")

            finalTranscript = fullTranscript.isEmpty ? nil : fullTranscript
            await onSilenceDetected()

        case .error(let error):
            print("[WakeWordTranscriptionManager] ❌ Transcription error: \(error)")
            print("[WakeWordTranscriptionManager] 📊 State at error: \(state), accumulated: '\(accumulatedText)', lastSession: '\(lastSessionTranscript)'")
            await onTranscriptionEnded()

        case .ended:
            print("[WakeWordTranscriptionManager] 🏁 Transcription ended normally")
            print("[WakeWordTranscriptionManager] 📊 Accumulated: '\(accumulatedText)', LastSession: '\(lastSessionTranscript)'")
            await onTranscriptionEnded()
        }
    }

    private func onSilenceDetected() async {
        print("[WakeWordTranscriptionManager] 🔄 Transcription complete, returning to wake word detection")

        // Stop transcription
        print("[WakeWordTranscriptionManager] 🛑 Stopping transcription")
        stopTranscription()

        // Clear accumulated text for next session
        print("[WakeWordTranscriptionManager] 🧹 Clearing accumulated text for next wake word session")
        accumulatedText = ""
        lastSessionTranscript = ""

        // Small cooldown before restarting wake word detection
        print("[WakeWordTranscriptionManager] ⏸️ Entering cooldown period (0.5s)")
        state = .cooldown
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Return to wake word detection
        do {
            print("[WakeWordTranscriptionManager] 🔄 Restarting wake word detection after cooldown")
            try await startWakeWordDetection()
        } catch {
            print("[WakeWordTranscriptionManager] ❌ Error restarting wake word detection: \(error)")
            state = .idle
        }
    }

    private func onTranscriptionEnded() async {
        print("[WakeWordTranscriptionManager] 🔚 Transcription ended (error or completion), returning to wake word detection")

        print("[WakeWordTranscriptionManager] 🛑 Stopping transcription")
        stopTranscription()

        // Clear accumulated text for next session
        print("[WakeWordTranscriptionManager] 🧹 Clearing accumulated text for next wake word session")
        accumulatedText = ""
        lastSessionTranscript = ""

        // Return to wake word detection immediately (no cooldown on error)
        do {
            print("[WakeWordTranscriptionManager] 🔄 Restarting wake word detection")
            try await startWakeWordDetection()
        } catch {
            print("[WakeWordTranscriptionManager] ❌ Error restarting wake word detection: \(error)")
            state = .idle
        }
    }

    private func stopTranscription() {
        print("[WakeWordTranscriptionManager] 🧹 Cleaning up transcription resources")
        transcriberTask?.cancel()
        vadTranscriber?.stop()
        vadTranscriber = nil
    }

    // MARK: - Public Configuration

    /// Update the VAD silence timeout (in seconds)
    /// - Parameter timeout: Silence duration in seconds before ending transcription (e.g., 2.0 for 2 seconds)
    func setSilenceTimeout(_ timeout: TimeInterval) {
        print("[WakeWordTranscriptionManager] 🎛️ Updating VAD silence timeout to \(timeout)s")
        vadTranscriber?.setSilenceTimeout(timeout)
    }
}
