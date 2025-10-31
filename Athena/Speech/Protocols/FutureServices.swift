//
//  FutureServices.swift
//  Athena
//
//  Protocol definitions for future wake-word and VAD services.
//  These are not implemented yet but define the interfaces for future expansion.
//

import Foundation

/// Protocol for wake-word detection services
/// Future implementation will listen to audio stream and detect wake words
protocol WakeWordService: AnyObject {
    /// Stream of wake-word detection events
    var events: AsyncStream<Void> { get }

    /// Start listening for wake words in the audio stream
    func start(with frames: AsyncStream<AudioFrame>) async

    /// Stop wake-word detection
    func stop()
}

/// Protocol for Voice Activity Detection (VAD) services
/// Future implementation will detect when speech starts and ends
protocol VADService: AnyObject {
    /// Stream of speech started events
    var speechStarted: AsyncStream<Void> { get }

    /// Stream of speech ended events
    var speechEnded: AsyncStream<Void> { get }

    /// Start voice activity detection on the audio stream
    func start(with frames: AsyncStream<AudioFrame>) async

    /// Stop voice activity detection
    func stop()
}
