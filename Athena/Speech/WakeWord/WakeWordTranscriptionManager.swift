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
    
    private let _amplitudeMonitor = AudioAmplitudeMonitor()
    
    /// Public read-only access to amplitude monitor for UI visualization
    var amplitudeMonitor: AudioAmplitudeMonitor {
        _amplitudeMonitor
    }

    // Current transcript from the speech recognizer
    private var lastSessionTranscript: String = ""

    // Ring buffer for audio handoff (captures last ~1 second of audio)
    private var audioRingBuffer: [AVAudioPCMBuffer] = []
    private let maxRingBufferDuration: TimeInterval = 1.0 // 1 second of audio
    private var currentRingBufferDuration: TimeInterval = 0.0

    // Callback invoked when wake word is detected (e.g., to show hidden window)
    var onWakeWordDetectedCallback: (() -> Void)?

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
        print("[WakeWordTranscriptionManager] 🎬 start() called - current state: \(state)")

        guard state == .idle else {
            print("[WakeWordTranscriptionManager] ⚠️ Cannot start - already running (state: \(state))")
            print("[WakeWordTranscriptionManager] 💡 This usually means stop() wasn't called properly before starting again")
            return
        }

        print("[WakeWordTranscriptionManager] ✅ State is idle, proceeding with start")

        // Check authorizations
        try await checkAuthorizations()

        // Start audio engine
        try startAudioEngine()

        // Start amplitude monitor
        print("[WakeWordTranscriptionManager] ⚡ Starting amplitude monitor")
        _amplitudeMonitor.start()

        // Start listening for wake word
        try await startWakeWordDetection()

        print("[WakeWordTranscriptionManager] 🎉 Wake word mode fully started and listening")
    }

    func stop() {
        print("[WakeWordTranscriptionManager] 🛑 Stopping wake word mode (current state: \(state))")
        
        // CRITICAL: Set to idle FIRST to prevent start() from being blocked
        state = .idle
        print("[WakeWordTranscriptionManager] ⚙️ State immediately set to .idle")
        
        // Now do synchronous cleanup in proper order
        detectorTask?.cancel()
        transcriberTask?.cancel()
        
        wakeWordDetector?.stop()
        wakeWordDetector = nil  // Fully release
        
        vadTranscriber?.stop()
        vadTranscriber = nil  // Fully release
        
        // Stop amplitude monitor
        _amplitudeMonitor.stop()
        
        // Stop audio engine LAST (after all consumers are stopped)
        stopAudioEngine()
        
        // Clear all state
        partialTranscript = ""
        finalTranscript = nil
        lastSessionTranscript = ""
        clearRingBuffer()
        
        print("[WakeWordTranscriptionManager] ✅ Wake word mode stopped - fully cleaned up and ready for restart")
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

    private var bufferCount = 0

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        // Process amplitude for waveform visualization (in all active states)
        // CRITICAL: Use fire-and-forget Task to prevent blocking audio thread
        if state == .listeningForWakeWord || state == .transcribing {
            if let channelData = buffer.floatChannelData {
                let frameCount = Int(buffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

                let audioFrame = AudioFrame(
                    samples: samples,
                    sampleRate: buffer.format.sampleRate,
                    timestamp: AVAudioTime(hostTime: mach_absolute_time())
                )

                bufferCount += 1
                // Fire-and-forget: Don't await to prevent audio thread blocking
                Task { @MainActor in
                    if bufferCount % 50 == 0 {
                        print("[WakeWordTranscriptionManager] 🎵 Processing audio buffer #\(bufferCount) for amplitude monitor (samples: \(samples.count))")
                    }
                    await _amplitudeMonitor.process(audioFrame)
                }
            }
        }
        
        switch state {
        case .listeningForWakeWord:
            // Add to ring buffer for smooth handoff
            addToRingBuffer(buffer)
            
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

    // MARK: - Ring Buffer Management
    
    private func addToRingBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate duration of this buffer
        let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
        
        // Add new buffer
        audioRingBuffer.append(buffer)
        currentRingBufferDuration += bufferDuration
        
        // Remove old buffers to maintain ~1 second window
        while currentRingBufferDuration > maxRingBufferDuration && !audioRingBuffer.isEmpty {
            let oldBuffer = audioRingBuffer.removeFirst()
            let oldDuration = Double(oldBuffer.frameLength) / oldBuffer.format.sampleRate
            currentRingBufferDuration -= oldDuration
        }
    }
    
    private func clearRingBuffer() {
        audioRingBuffer.removeAll()
        currentRingBufferDuration = 0.0
    }
    
    private func feedRingBufferToTranscriber() {
        guard let transcriber = vadTranscriber else { return }
        
        let bufferCount = audioRingBuffer.count
        print("[WakeWordTranscriptionManager] 🔄 Feeding \(bufferCount) buffered audio frames (~\(String(format: "%.2f", currentRingBufferDuration))s) to transcriber")
        
        for buffer in audioRingBuffer {
            transcriber.appendAudioBuffer(buffer)
        }
        
        // Clear the ring buffer after feeding to transcriber
        clearRingBuffer()
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

        // Notify external listeners (e.g., to show hidden window)
        onWakeWordDetectedCallback?()

        // Stop wake word detection and clear its buffer
        print("[WakeWordTranscriptionManager] 🛑 Stopping wake word detector and clearing buffer")
        wakeWordDetector?.stop()
        detectorTask?.cancel()
        wakeWordDetector = nil // Fully release to clear buffer

        // Start full transcription with VAD
        do {
            print("[WakeWordTranscriptionManager] 🎬 Starting VAD transcription")
            try await startTranscription()
        } catch {
            print("[WakeWordTranscriptionManager] ❌ Error starting transcription: \(error)")
            // Clear ring buffer on error
            clearRingBuffer()
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

        // Reset transcript for this new transcription session
        lastSessionTranscript = ""
        print("[WakeWordTranscriptionManager] 🔄 Reset transcript - starting fresh transcription session")

        print("[WakeWordTranscriptionManager] 🏗️ Creating SimplifiedVADTranscriber with 1s silence timeout")
        let transcriber = try SimplifiedVADTranscriber(silenceTimeout: 1)
        self.vadTranscriber = transcriber

        print("[WakeWordTranscriptionManager] ▶️ Starting VAD transcriber")
        try transcriber.start()

        // Clear the ring buffer to avoid transcribing the wake word
        print("[WakeWordTranscriptionManager] 🧹 Clearing ring buffer to avoid transcribing wake word")
        clearRingBuffer()

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
            // Speech recognizer internally accumulates, so just use the latest transcript
            print("[WakeWordTranscriptionManager] 📝 Partial: '\(text)'")
            lastSessionTranscript = text
            partialTranscript = text

        case .final(let text, let confidence):
            let confidenceStr = confidence.map { String(format: "%.2f", $0) } ?? "N/A"
            print("[WakeWordTranscriptionManager] ✅ Final transcript: '\(text)' (confidence: \(confidenceStr))")
            
            lastSessionTranscript = text
            partialTranscript = text

            // Note: Don't end transcription on final - wait for VAD silence detection

        case .silenceDetected:
            print("[WakeWordTranscriptionManager] 🔇 Silence detected - ending transcription session")
            print("[WakeWordTranscriptionManager] 📊 Full transcript: '\(lastSessionTranscript)'")

            finalTranscript = lastSessionTranscript.isEmpty ? nil : lastSessionTranscript
            await onSilenceDetected()

        case .error(let error):
            print("[WakeWordTranscriptionManager] ❌ Transcription error: \(error)")
            print("[WakeWordTranscriptionManager] 📊 State at error: \(state), lastSession: '\(lastSessionTranscript)'")
            await onTranscriptionEnded()

        case .ended:
            print("[WakeWordTranscriptionManager] 🏁 Transcription ended normally")
            print("[WakeWordTranscriptionManager] 📊 LastSession: '\(lastSessionTranscript)'")
            await onTranscriptionEnded()
        }
    }

    private func onSilenceDetected() async {
        print("[WakeWordTranscriptionManager] 🔄 Transcription complete, returning to wake word detection")

        // Stop transcription
        print("[WakeWordTranscriptionManager] 🛑 Stopping transcription")
        stopTranscription()

        // Clear transcript for next session
        print("[WakeWordTranscriptionManager] 🧹 Clearing transcript for next wake word session")
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

        // Clear transcript for next session
        print("[WakeWordTranscriptionManager] 🧹 Clearing transcript for next wake word session")
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
