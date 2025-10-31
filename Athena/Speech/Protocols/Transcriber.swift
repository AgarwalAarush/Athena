//
//  Transcriber.swift
//  Athena
//
//  Protocol for speech transcription services that convert audio to text.
//

import Foundation

/// Protocol for speech transcription services that consume audio and emit transcript events
protocol Transcriber: AnyObject {
    /// Start a new transcription stream with the specified sample rate
    func startStream(sampleRate: Double) async throws

    /// Feed an audio frame to the transcriber
    func feed(_ frame: AudioFrame) async

    /// Get the stream of transcript events (partial results, final results, errors)
    func events() -> AsyncStream<TranscriptEvent>

    /// Finish the current transcription stream and wait for final results
    func finish() async

    /// Cancel the current transcription immediately without waiting for results
    func cancel()
}
