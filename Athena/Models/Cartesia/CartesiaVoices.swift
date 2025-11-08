//
//  CartesiaVoices.swift
//  Athena
//
//  Catalog of commonly used Cartesia voice IDs
//

import Foundation

/// Catalog of pre-configured Cartesia voice IDs
///
/// Voice IDs can be discovered via the Cartesia web interface or API.
/// This provides convenient access to commonly used voices.
struct CartesiaVoices {
    
    // MARK: - Example Voices
    
    /// Example voice from Cartesia documentation
    /// A versatile default voice suitable for general purposes
    static let exampleVoice = "a0e99841-438c-4a64-b679-ae501e7d6091"
    
    // MARK: - Voice Categories
    
    /// Professional/Business voices
    struct Professional {
        // Add professional voice IDs here as they are discovered
        // Example:
        // static let corporateNarrator = "voice-id-here"
    }
    
    /// Conversational/Friendly voices
    struct Conversational {
        // Add conversational voice IDs here as they are discovered
        // Example:
        // static let friendlyAssistant = "voice-id-here"
    }
    
    /// Storytelling/Narrative voices
    struct Narrative {
        // Add narrative voice IDs here as they are discovered
        // Example:
        // static let storyteller = "voice-id-here"
    }
    
    // MARK: - Helper Methods
    
    /// Get a default voice ID for general use
    static var defaultVoice: String {
        return exampleVoice
    }
    
    /// Validate that a voice ID string has the expected format
    /// - Parameter voiceId: The voice ID to validate
    /// - Returns: true if the format appears valid
    static func isValidVoiceIdFormat(_ voiceId: String) -> Bool {
        // Cartesia voice IDs are UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        let uuidPattern = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: voiceId.utf16.count)
        return regex?.firstMatch(in: voiceId, options: [], range: range) != nil
    }
}

// MARK: - Voice Discovery Extension

extension CartesiaVoices {
    /// Information about a voice (for future voice browsing features)
    struct VoiceInfo {
        let id: String
        let name: String
        let description: String
        let language: String
        let gender: Gender?
        let ageRange: AgeRange?
        
        enum Gender: String {
            case male
            case female
            case neutral
        }
        
        enum AgeRange: String {
            case young
            case middleAged = "middle_aged"
            case mature
        }
    }
    
    // Future: Add methods to fetch and cache available voices from API
    // static func fetchAvailableVoices() async throws -> [VoiceInfo]
}

