//
//  ConfigurationManager.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    private let keychain = KeychainManager.shared
    private let userDefaults = UserDefaults.standard
    
    // Publishers for configuration changes
    @Published private(set) var selectedProvider: String
    @Published private(set) var selectedModel: String
    @Published private(set) var speechRecognitionLanguage: String
    @Published private(set) var autoSendVoiceTranscription: Bool
    @Published private(set) var wakewordModeEnabled: Bool
    
    private init() {
        // Initialize published properties with defaults
        self.selectedProvider = ConfigurationKey.selectedProvider.defaultValue as! String
        self.selectedModel = ConfigurationKey.selectedModel.defaultValue as! String
        self.speechRecognitionLanguage = ConfigurationKey.speechRecognitionLanguage.defaultValue as! String
        self.autoSendVoiceTranscription = ConfigurationKey.autoSendVoiceTranscription.defaultValue as! Bool
        self.wakewordModeEnabled = ConfigurationKey.wakewordModeEnabled.defaultValue as! Bool

        // Load current values
        self.selectedProvider = getString(.selectedProvider)
        self.selectedModel = getString(.selectedModel)
        self.speechRecognitionLanguage = getString(.speechRecognitionLanguage)
        self.autoSendVoiceTranscription = getBool(.autoSendVoiceTranscription)
        self.wakewordModeEnabled = getBool(.wakewordModeEnabled)
    }
    
    // MARK: - Generic Getters
    
    func getString(_ key: ConfigurationKey) -> String {
        if key.isSecure {
            return (try? keychain.retrieveString(for: key.rawValue)) ?? (key.defaultValue as! String)
        } else {
            return userDefaults.string(forKey: key.rawValue) ?? (key.defaultValue as! String)
        }
    }
    
    func getInt(_ key: ConfigurationKey) -> Int {
        let value = userDefaults.integer(forKey: key.rawValue)
        if value == 0 && !userDefaults.bool(forKey: key.rawValue) {
            return key.defaultValue as! Int
        }
        return value
    }
    
    func getDouble(_ key: ConfigurationKey) -> Double {
        let value = userDefaults.double(forKey: key.rawValue)
        if value == 0.0 {
            return key.defaultValue as! Double
        }
        return value
    }
    
    func getBool(_ key: ConfigurationKey) -> Bool {
        if userDefaults.object(forKey: key.rawValue) == nil {
            return key.defaultValue as! Bool
        }
        return userDefaults.bool(forKey: key.rawValue)
    }
    
    // MARK: - Generic Setters
    
    func set(_ value: String, for key: ConfigurationKey) throws {
        if key.isSecure {
            try keychain.save(value, for: key.rawValue)
        } else {
            userDefaults.set(value, forKey: key.rawValue)
        }
        
        // Update published properties
        updatePublishedProperties(for: key)
    }
    
    func set(_ value: Int, for key: ConfigurationKey) {
        userDefaults.set(value, forKey: key.rawValue)
        updatePublishedProperties(for: key)
    }
    
    func set(_ value: Double, for key: ConfigurationKey) {
        userDefaults.set(value, forKey: key.rawValue)
        updatePublishedProperties(for: key)
    }
    
    func set(_ value: Bool, for key: ConfigurationKey) {
        userDefaults.set(value, forKey: key.rawValue)
        updatePublishedProperties(for: key)
    }
    
    // MARK: - Convenience Methods
    
    func hasAPIKey(for provider: String) -> Bool {
        switch provider.lowercased() {
        case "openai":
            return keychain.exists(for: ConfigurationKey.openaiAPIKey.rawValue)
        default:
            return false
        }
    }
    
    func getAPIKey(for provider: String) -> String? {
        switch provider.lowercased() {
        case "openai":
            return try? keychain.retrieveString(for: ConfigurationKey.openaiAPIKey.rawValue)
        default:
            return nil
        }
    }
    
    func setAPIKey(_ key: String, for provider: String) throws {
        switch provider.lowercased() {
        case "openai":
            try keychain.save(key, for: ConfigurationKey.openaiAPIKey.rawValue)
        default:
            throw NSError(domain: "ConfigurationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown provider"])
        }
    }
    
    func deleteAPIKey(for provider: String) throws {
        switch provider.lowercased() {
        case "openai":
            try keychain.delete(for: ConfigurationKey.openaiAPIKey.rawValue)
        default:
            throw NSError(domain: "ConfigurationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown provider"])
        }
    }
    
    // MARK: - Google OAuth Methods
    
    func hasGoogleAuth() -> Bool {
        return keychain.exists(for: ConfigurationKey.googleAuthSession.rawValue)
    }
    
    func getGoogleAuthSession() -> Data? {
        return try? keychain.retrieve(for: ConfigurationKey.googleAuthSession.rawValue)
    }
    
    func saveGoogleAuthSession(_ data: Data) throws {
        try keychain.save(data, for: ConfigurationKey.googleAuthSession.rawValue)
    }
    
    func deleteGoogleAuthSession() throws {
        try keychain.delete(for: ConfigurationKey.googleAuthSession.rawValue)
    }
    
    func getGoogleAuthScopes() -> String {
        return getString(.googleAuthScopes)
    }
    
    func saveGoogleAuthScopes(_ scopes: String) throws {
        try set(scopes, for: .googleAuthScopes)
    }
    
    // MARK: - Validation
    
    func validate(_ value: Any, for key: ConfigurationKey) -> Bool {
        switch key {
        case .topP:
            guard let topP = value as? Double else { return false }
            return topP >= 0.0 && topP <= 1.0
            
        case .connectionTimeout:
            guard let timeout = value as? Double else { return false }
            return timeout >= 5.0 && timeout <= 300.0
            
        case .pythonServicePort:
            guard let port = value as? Int else { return false }
            return port >= 1024 && port <= 65535
            
        default:
            return true
        }
    }
    
    // MARK: - Reset
    
    func reset(_ key: ConfigurationKey) throws {
        if key.isSecure {
            try keychain.delete(for: key.rawValue)
        } else {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        updatePublishedProperties(for: key)
    }
    
    func resetAll() throws {
        // Clear all keychain items
        try keychain.clearAll()
        
        // Clear all user defaults
        for key in ConfigurationKey.allCases {
            if !key.isSecure {
                userDefaults.removeObject(forKey: key.rawValue)
            }
        }
        
        // Reload published properties
        reloadPublishedProperties()
    }
    
    // MARK: - Private Helpers
    
    private func updatePublishedProperties(for key: ConfigurationKey) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch key {
            case .selectedProvider:
                self.selectedProvider = self.getString(.selectedProvider)
            case .selectedModel:
                self.selectedModel = self.getString(.selectedModel)
            case .speechRecognitionLanguage:
                self.speechRecognitionLanguage = self.getString(.speechRecognitionLanguage)
            case .autoSendVoiceTranscription:
                self.autoSendVoiceTranscription = self.getBool(.autoSendVoiceTranscription)
            case .wakewordModeEnabled:
                self.wakewordModeEnabled = self.getBool(.wakewordModeEnabled)
            default:
                break
            }
        }
    }
    
    private func reloadPublishedProperties() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.selectedProvider = self.getString(.selectedProvider)
            self.selectedModel = self.getString(.selectedModel)
            self.speechRecognitionLanguage = self.getString(.speechRecognitionLanguage)
            self.autoSendVoiceTranscription = self.getBool(.autoSendVoiceTranscription)
            self.wakewordModeEnabled = self.getBool(.wakewordModeEnabled)
        }
    }
}
