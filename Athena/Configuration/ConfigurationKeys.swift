//
//  ConfigurationKeys.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation

enum ConfigurationKey: String, CaseIterable {
    // AI Provider Keys (Secure - Keychain)
    case openaiAPIKey = "openai_api_key"
    case ollamaBaseURL = "ollama_base_url"
    case cartesiaAPIKey = "cartesia_api_key"
    
    // Google OAuth (Secure - Keychain)
    case googleAuthSession = "google_auth_session"
    case googleAuthScopes = "google_auth_scopes"
    
    // Provider Selection (UserDefaults)
    case selectedProvider = "selected_provider"
    case selectedModel = "selected_model"
    
    // Model Parameters (UserDefaults)
    case topP = "top_p"
    
    // UI Preferences (UserDefaults)
    case theme = "theme"
    case fontSize = "font_size"
    case showTimestamps = "show_timestamps"
    case enableAnimations = "enable_animations"
    
    // Window Settings (UserDefaults)
    case rememberWindowPosition = "remember_window_position"
    case startMinimized = "start_minimized"
    
    // Backend Configuration (UserDefaults)
    case pythonServiceURL = "python_service_url"
    case pythonServicePort = "python_service_port"
    case connectionTimeout = "connection_timeout"
    
    // Feature Flags (UserDefaults)
    case enableVoiceMode = "enable_voice_mode"
    case enableComputerUse = "enable_computer_use"
    case enableCalendarIntegration = "enable_calendar_integration"

    // Speech Settings (UserDefaults)
    case speechRecognitionLanguage = "speech_recognition_language"
    case autoSendVoiceTranscription = "auto_send_voice_transcription"
    case wakewordModeEnabled = "wakeword_mode_enabled"
    
    var defaultValue: Any {
        switch self {
        // Provider defaults
        case .ollamaBaseURL:
            return "http://localhost:11434"
        case .selectedProvider:
            return "openai"
        case .selectedModel:
            return "gpt-5-nano"
            
        // Model parameter defaults
        case .topP:
            return 1.0
            
        // UI defaults
        case .theme:
            return "system"
        case .fontSize:
            return 14
        case .showTimestamps:
            return true
        case .enableAnimations:
            return true
            
        // Window defaults
        case .rememberWindowPosition:
            return true
        case .startMinimized:
            return false
            
        // Backend defaults
        case .pythonServiceURL:
            return "http://localhost"
        case .pythonServicePort:
            return 8000
        case .connectionTimeout:
            return 30.0
            
        // Feature flag defaults
        case .enableVoiceMode:
            return false
        case .enableComputerUse:
            return false
        case .enableCalendarIntegration:
            return false

        // Speech settings defaults
        case .speechRecognitionLanguage:
            return "en-US"
        case .autoSendVoiceTranscription:
            return true
        case .wakewordModeEnabled:
            return true

        // Google OAuth defaults
        case .googleAuthScopes:
            return ""
            
        // Secure keys have no defaults
        case .openaiAPIKey, .cartesiaAPIKey, .googleAuthSession:
            return ""
        }
    }
    
    var isSecure: Bool {
        switch self {
        case .openaiAPIKey, .cartesiaAPIKey, .googleAuthSession:
            return true
        default:
            return false
        }
    }
    
    var category: ConfigurationCategory {
        switch self {
        case .openaiAPIKey, .cartesiaAPIKey, .ollamaBaseURL, .selectedProvider, .selectedModel:
            return .aiProvider
        case .googleAuthSession, .googleAuthScopes:
            return .authentication
        case .topP:
            return .modelParameters
        case .theme, .fontSize, .showTimestamps, .enableAnimations:
            return .userInterface
        case .rememberWindowPosition, .startMinimized:
            return .window
        case .pythonServiceURL, .pythonServicePort, .connectionTimeout:
            return .backend
        case .enableVoiceMode, .enableComputerUse, .enableCalendarIntegration:
            return .features
        case .speechRecognitionLanguage, .autoSendVoiceTranscription, .wakewordModeEnabled:
            return .speech
        }
    }
}

enum ConfigurationCategory: String, CaseIterable {
    case aiProvider = "AI Provider"
    case authentication = "Authentication"
    case modelParameters = "Model Parameters"
    case userInterface = "User Interface"
    case window = "Window"
    case backend = "Backend"
    case features = "Features"
    case speech = "Speech"
}

