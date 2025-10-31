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
    private var audioTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?

    // MARK: - Initialization

    init(audioInput: AudioInput, transcriber: Transcriber) {
        self.audioInput = audioInput
        self.transcriber = transcriber
    }

    // MARK: - Public Methods

    /// Start listening and transcribing audio
    func startListening() async {
        guard state == .idle else {
            return
        }

        // Reset state
        partialTranscript = ""
        finalTranscript = nil

        state = .listening

        // Prepare transcript stream before starting recognizer so early events are captured
        let eventStream = transcriber.events()
        startTranscriptProcessing(with: eventStream)

        do {
            // Start transcriber
            try await transcriber.startStream(sampleRate: audioInput.sampleRate)

            // Start audio input
            try await audioInput.start()

            // Start forwarding audio frames to transcriber
            startAudioForwarding()

        } catch {
            audioInput.stop()
            transcriber.cancel()
            transcriptTask?.cancel()
            transcriptTask = nil
            state = .error(error.localizedDescription)
        }
    }

    /// Stop listening and wait for final transcription
    func stopListening() async {
        guard state == .listening else {
            return
        }

        state = .finishing

        // Stop audio input
        audioInput.stop()

        // Cancel audio forwarding
        audioTask?.cancel()
        audioTask = nil

        // Finish transcription (wait for final results)
        await transcriber.finish()
    }

    /// Cancel listening immediately without waiting for results
    func cancelListening() {
        guard state != .idle else {
            return
        }

        // Stop audio
        audioInput.stop()

        // Cancel tasks
        audioTask?.cancel()
        transcriptTask?.cancel()
        audioTask = nil
        transcriptTask = nil

        // Cancel transcriber
        transcriber.cancel()

        // Reset state
        partialTranscript = ""
        finalTranscript = nil
        state = .idle
    }

    // MARK: - Private Methods

    private func startAudioForwarding() {
        audioTask = Task {
            for await frame in audioInput.frames {
                guard !Task.isCancelled else { break }
                await transcriber.feed(frame)
            }
        }
    }

    private func startTranscriptProcessing(with stream: AsyncStream<TranscriptEvent>) {
        transcriptTask = Task { [weak self] in
            guard let self = self else { return }

            for await event in stream {
                guard !Task.isCancelled else { break }

                await self.handleTranscriptEvent(event)
            }
        }
    }

    private func handleTranscriptEvent(_ event: TranscriptEvent) async {
        switch event {
        case .partial(let text):
            partialTranscript = text

        case .final(let text, _):
            finalTranscript = text
            partialTranscript = ""

        case .error(let error):
            state = .error(error.localizedDescription)
            audioInput.stop()
            audioTask?.cancel()
            audioTask = nil
            transcriptTask?.cancel()
            transcriptTask = nil

        case .ended:
            // Transcription complete
            transcriptTask?.cancel()
            transcriptTask = nil
            state = .idle
        }
    }

}

// MARK: - Convenience Factory

extension SpeechPipeline {
    /// Create a pipeline with default Apple Speech implementation
    static func makeDefault(locale: Locale = .current) throws -> SpeechPipeline {
        let audioInput = EngineAudioInput()
        let transcriber = try AppleSpeechTranscriber(locale: locale)
        return SpeechPipeline(audioInput: audioInput, transcriber: transcriber)
    }
}
