//
//  AudioInput.swift
//  Athena
//
//  Protocol for audio input sources that capture and stream audio data.
//

import Foundation
import AVFoundation

/// Protocol for audio input sources that capture microphone audio and stream it as frames
protocol AudioInput: AnyObject {
    /// The sample rate of the audio being captured
    var sampleRate: Double { get }

    /// AsyncStream of audio frames from the microphone
    var frames: AsyncStream<AudioFrame> { get }

    /// Start capturing audio from the microphone
    func start() async throws

    /// Stop capturing audio
    func stop()
}
