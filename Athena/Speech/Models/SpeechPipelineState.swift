//
//  SpeechPipelineState.swift
//  Athena
//
//  State machine for the speech recognition pipeline.
//

import Foundation

/// States of the speech recognition pipeline
enum SpeechPipelineState: Equatable {
    /// Not currently recording or processing
    case idle

    /// Actively recording and transcribing audio
    case listening

    /// Recording stopped, waiting for final transcription results
    case finishing

    /// An error occurred with the error message
    case error(String)

    static func == (lhs: SpeechPipelineState, rhs: SpeechPipelineState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.listening, .listening), (.finishing, .finishing):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }

    /// Returns true if the pipeline is active (not idle)
    var isActive: Bool {
        switch self {
        case .idle:
            return false
        case .listening, .finishing, .error:
            return true
        }
    }
}
