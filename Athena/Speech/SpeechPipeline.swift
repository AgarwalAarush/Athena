//
//  SpeechPipeline.swift
//  Athena
//
//  Orchestrator that connects audio input to transcription and manages the pipeline lifecycle.
//

import Foundation
import Combine

/// Main orchestrator for the speech recognition pipeline
@MainActor
final class SpeechPipeline: ObservableObject {
    // MARK: - Published Properties

    /// Current state of the pipeline
    @Published private(set) var state: SpeechPipelineState = .idle

    /// Current partial transcript (updates in real-time as user speaks)
    @Published private(set) var partialTranscript: String = ""

    /// Final transcript when speech recognition completes
    @Published private(set) var finalTranscript: String?

    // MARK: - Private Properties

    private let audioInput: AudioInput
    private let transcriber: Transcriber
    private let _amplitudeMonitor = AudioAmplitudeMonitor()
    private var audioTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?

    /// Public read-only access to amplitude monitor for UI visualization
    var amplitudeMonitor: AudioAmplitudeMonitor {
        _amplitudeMonitor
    }

    // MARK: - Initialization

    init(audioInput: AudioInput, transcriber: Transcriber) {
        self.audioInput = audioInput
        self.transcriber = transcriber
        print("[SpeechPipeline] Initialized with audioInput: \(type(of: audioInput)), transcriber: \(type(of: transcriber)), sampleRate: \(audioInput.sampleRate)")
    }

    // MARK: - Public Methods

    /// Start listening and transcribing audio
    func startListening() async {
        print("[SpeechPipeline] startListening called, current state: \(state)")

        // If currently finishing, cancel first to reset to idle
        if state == .finishing {
            print("[SpeechPipeline] startListening: Currently finishing, cancelling first")
            cancelListening()
        }

        guard state == .idle else {
            print("[SpeechPipeline] startListening: Guard failed - not in idle state, current state: \(state)")
            return
        }

        print("[SpeechPipeline] startListening: Resetting state and starting pipeline")

        // Reset state
        partialTranscript = ""
        finalTranscript = nil

        state = .listening
        print("[SpeechPipeline] startListening: State set to listening")

        do {
            // Start transcriber FIRST so it cleans up any old state
            print("[SpeechPipeline] startListening: Starting transcriber with sampleRate: \(audioInput.sampleRate)")
            try await transcriber.startStream(sampleRate: audioInput.sampleRate)
            print("[SpeechPipeline] startListening: Transcriber started successfully")

            // NOW get the transcript stream (after cleanup) so we get a fresh continuation
            print("[SpeechPipeline] startListening: Getting transcript event stream")
            let eventStream = transcriber.events()
            startTranscriptProcessing(with: eventStream)
            print("[SpeechPipeline] startListening: Transcript processing started")

            // Start amplitude monitor
            print("[SpeechPipeline] startListening: Starting amplitude monitor")
            _amplitudeMonitor.start()
            print("[SpeechPipeline] startListening: Amplitude monitor started")

            // Start audio input
            print("[SpeechPipeline] startListening: Starting audio input")
            try await audioInput.start()
            print("[SpeechPipeline] startListening: Audio input started successfully")

            // Start forwarding audio frames to transcriber
            print("[SpeechPipeline] startListening: Starting audio forwarding")
            startAudioForwarding()
            print("[SpeechPipeline] startListening: Pipeline fully started")

        } catch {
            print("[SpeechPipeline] startListening: Error during startup: \(error.localizedDescription)")
            audioInput.stop()
            transcriber.cancel()
            transcriptTask?.cancel()
            transcriptTask = nil
            state = .error(error.localizedDescription)
            print("[SpeechPipeline] startListening: State set to error: \(error.localizedDescription)")
        }
    }

    /// Stop listening and wait for final transcription
    func stopListening() async {
        print("[SpeechPipeline] stopListening called, current state: \(state)")

        guard state == .listening else {
            print("[SpeechPipeline] stopListening: Guard failed - not in listening state, current state: \(state)")
            return
        }

        print("[SpeechPipeline] stopListening: Setting state to finishing")
        state = .finishing

        // Stop audio input
        print("[SpeechPipeline] stopListening: Stopping audio input")
        audioInput.stop()

        // Cancel audio forwarding
        print("[SpeechPipeline] stopListening: Cancelling audio forwarding task")
        audioTask?.cancel()
        audioTask = nil

        // Finish transcription (wait for final results)
        print("[SpeechPipeline] stopListening: Waiting for transcriber to finish")
        await transcriber.finish()
        print("[SpeechPipeline] stopListening: Transcriber finished")
    }

    /// Cancel listening immediately without waiting for results
    func cancelListening() {
        print("[SpeechPipeline] cancelListening called, current state: \(state)")

        guard state != .idle else {
            print("[SpeechPipeline] cancelListening: Guard failed - already in idle state")
            return
        }

        print("[SpeechPipeline] cancelListening: Stopping all components")

        // Stop audio
        print("[SpeechPipeline] cancelListening: Stopping audio input")
        audioInput.stop()

        // Cancel tasks
        print("[SpeechPipeline] cancelListening: Cancelling audio and transcript tasks")
        audioTask?.cancel()
        transcriptTask?.cancel()
        audioTask = nil
        transcriptTask = nil

        // Cancel transcriber
        print("[SpeechPipeline] cancelListening: Cancelling transcriber")
        transcriber.cancel()
        
        // Stop amplitude monitor
        print("[SpeechPipeline] cancelListening: Stopping amplitude monitor")
        _amplitudeMonitor.stop()

        // Reset state
        print("[SpeechPipeline] cancelListening: Resetting state to idle")
        partialTranscript = ""
        finalTranscript = nil
        state = .idle
    }

    // MARK: - Private Methods

    private func startAudioForwarding() {
        print("[SpeechPipeline] startAudioForwarding: Starting audio forwarding task")
        audioTask = Task {
            print("[SpeechPipeline] startAudioForwarding: Audio forwarding task started")
            var frameCount = 0
            for await frame in audioInput.frames {
                guard !Task.isCancelled else {
                    print("[SpeechPipeline] startAudioForwarding: Task cancelled, stopping audio forwarding")
                    break
                }
                frameCount += 1
                let currentFrameCount = frameCount // Capture for Task closure
                if frameCount % 50 == 0 { // Log every 50 frames to avoid spam
                    print("[SpeechPipeline] startAudioForwarding: Processed \(frameCount) audio frames")
                }
                await transcriber.feed(frame)

                // Feed audio to amplitude monitor for waveform visualization
                // Fire-and-forget: Don't await to prevent audio stream backpressure
                Task { @MainActor in
                    if currentFrameCount % 50 == 0 {
                        print("[SpeechPipeline] 🎵 Forwarding frame #\(currentFrameCount) to amplitude monitor (samples: \(frame.samples.count))")
                    }
                    await _amplitudeMonitor.process(frame)
                }
            }
            print("[SpeechPipeline] startAudioForwarding: Audio forwarding task ended (processed \(frameCount) frames)")
        }
    }

    private func startTranscriptProcessing(with stream: AsyncStream<TranscriptEvent>) {
        print("[SpeechPipeline] startTranscriptProcessing: Starting transcript processing task")
        transcriptTask = Task { [weak self] in
            guard let self = self else {
                print("[SpeechPipeline] startTranscriptProcessing: Self is nil, ending task")
                return
            }

            print("[SpeechPipeline] startTranscriptProcessing: Transcript processing task started")
            var eventCount = 0
            for await event in stream {
                eventCount += 1
                print("[SpeechPipeline] startTranscriptProcessing: Processing event #\(eventCount): \(event)")
                guard !Task.isCancelled else {
                    print("[SpeechPipeline] startTranscriptProcessing: Task cancelled, stopping transcript processing")
                    break
                }

                await self.handleTranscriptEvent(event)
                print("[SpeechPipeline] startTranscriptProcessing: Finished processing event #\(eventCount)")
            }
            print("[SpeechPipeline] startTranscriptProcessing: Transcript processing task ended after \(eventCount) events")
        }
    }

    private func handleTranscriptEvent(_ event: TranscriptEvent) async {
        print("[SpeechPipeline] handleTranscriptEvent: Received event: \(event)")

        switch event {
        case .partial(let text):
            print("[SpeechPipeline] handleTranscriptEvent: Partial transcript: '\(text)'")
            partialTranscript = text

        case .final(let text, _):
            print("[SpeechPipeline] handleTranscriptEvent: FINAL TRANSCRIPT RECEIVED: '\(text)'")
            finalTranscript = text
            partialTranscript = ""
            print("[SpeechPipeline] handleTranscriptEvent: Final transcript stored, pipeline will notify listeners")

        case .error(let error):
            print("[SpeechPipeline] handleTranscriptEvent: ERROR - Error event: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
            print("[SpeechPipeline] handleTranscriptEvent: Stopping audio input due to error")
            audioInput.stop()
            print("[SpeechPipeline] handleTranscriptEvent: Cancelling tasks due to error")
            audioTask?.cancel()
            audioTask = nil
            transcriptTask?.cancel()
            transcriptTask = nil
            print("[SpeechPipeline] handleTranscriptEvent: Stopping amplitude monitor due to error")
            _amplitudeMonitor.stop()

        case .ended:
            print("[SpeechPipeline] handleTranscriptEvent: Transcription session ended - RECEIVED .ended EVENT")
            // Transcription complete
            transcriptTask?.cancel()
            transcriptTask = nil
            print("[SpeechPipeline] handleTranscriptEvent: Setting state to idle after .ended event")
            state = .idle
            print("[SpeechPipeline] handleTranscriptEvent: State set to idle, pipeline should notify listeners")

        case .silenceDetected:
            print("[SpeechPipeline] handleTranscriptEvent: Silence detected by VAD")
            // Note: This is primarily used by WakeWordTranscriptionManager
            // For regular pipeline usage, we can treat it similar to .ended
            // but keep the final transcript if one exists
        }
    }

}

// MARK: - Convenience Factory

extension SpeechPipeline {
    /// Create a pipeline with default Apple Speech implementation
    static func makeDefault(locale: Locale = .current) throws -> SpeechPipeline {
        print("[SpeechPipeline] makeDefault: Creating default pipeline with locale: \(locale.identifier)")

        print("[SpeechPipeline] makeDefault: Creating EngineAudioInput")
        let audioInput = EngineAudioInput()

        print("[SpeechPipeline] makeDefault: Creating AppleSpeechTranscriber")
        let transcriber = try AppleSpeechTranscriber(locale: locale)

        print("[SpeechPipeline] makeDefault: Creating SpeechPipeline instance")
        let pipeline = SpeechPipeline(audioInput: audioInput, transcriber: transcriber)

        print("[SpeechPipeline] makeDefault: Pipeline creation completed successfully")
        return pipeline
    }
}
