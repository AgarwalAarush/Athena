//
//  AudioFrame.swift
//  Athena
//
//  Data structure representing a single frame of audio data.
//

import Foundation
import AVFoundation

/// A single frame of audio data with samples and metadata
struct AudioFrame {
    /// Audio samples as Float32 values (typically -1.0 to 1.0)
    let samples: [Float]

    /// Sample rate of the audio (e.g., 16000 Hz)
    let sampleRate: Double

    /// Timestamp of when this frame was captured
    let timestamp: AVAudioTime

    /// Duration of this frame in seconds
    var duration: TimeInterval {
        return Double(samples.count) / sampleRate
    }

    /// Number of samples in this frame
    var sampleCount: Int {
        return samples.count
    }
}
