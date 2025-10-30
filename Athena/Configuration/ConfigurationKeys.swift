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
    case anthropicAPIKey = "anthropic_api_key"
    case ollamaBaseURL = "ollama_base_url"
    
    // Provider Selection (UserDefaults)
    case selectedProvider = "selected_provider"
    case selectedModel = "selected_model"
    
    // Model Parameters (UserDefaults)
    case temperature = "temperature"
    case maxTokens = "max_tokens"
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
    
    var defaultValue: Any {
        switch self {
        // Provider defaults
        case .ollamaBaseURL:
            return "http://localhost:11434"
        case .selectedProvider:
            return "openai"
        case .selectedModel:
            return "gpt-5-nano-2025-08-07"
            
        // Model parameter defaults
        case .temperature:
            return 0.7
        case .maxTokens:
            return 2048
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
            
        // Secure keys have no defaults
        case .openaiAPIKey, .anthropicAPIKey:
            return ""
        }
    }
    
    var isSecure: Bool {
        switch self {
        case .openaiAPIKey, .anthropicAPIKey:
            return true
        default:
            return false
        }
    }
    
    var category: ConfigurationCategory {
        switch self {
        case .openaiAPIKey, .anthropicAPIKey, .ollamaBaseURL, .selectedProvider, .selectedModel:
            return .aiProvider
        case .temperature, .maxTokens, .topP:
            return .modelParameters
        case .theme, .fontSize, .showTimestamps, .enableAnimations:
            return .userInterface
        case .rememberWindowPosition, .startMinimized:
            return .window
        case .pythonServiceURL, .pythonServicePort, .connectionTimeout:
            return .backend
        case .enableVoiceMode, .enableComputerUse, .enableCalendarIntegration:
            return .features
        }
    }
}

enum ConfigurationCategory: String, CaseIterable {
    case aiProvider = "AI Provider"
    case modelParameters = "Model Parameters"
    case userInterface = "User Interface"
    case window = "Window"
    case backend = "Backend"
    case features = "Features"
}

