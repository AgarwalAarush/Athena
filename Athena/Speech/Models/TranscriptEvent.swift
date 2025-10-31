//
//  TranscriptEvent.swift
//  Athena
//
//  Events emitted during speech transcription process.
//

import Foundation

/// Events emitted by transcription services during speech-to-text conversion
enum TranscriptEvent {
    /// Partial (interim) transcription result - may change as more audio is processed
    case partial(String)

    /// Final transcription result - this segment is complete
    /// The optional Double is the confidence score (0.0 - 1.0)
    case final(String, Double?)

    /// An error occurred during transcription
    case error(Error)

    /// Transcription stream has ended
    case ended
}

extension TranscriptEvent {
    /// Returns the text content if this event contains text (partial or final)
    var text: String? {
        switch self {
        case .partial(let text), .final(let text, _):
            return text
        case .error, .ended:
            return nil
        }
    }

    /// Returns true if this is a final result
    var isFinal: Bool {
        if case .final = self {
            return true
        }
        return false
    }
}
