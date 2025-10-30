//
//  SettingsView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared
    @State private var selectedTab: SettingsTab = .provider
    
    enum SettingsTab: String, CaseIterable {
        case provider = "Provider"
        case model = "Model"
        case interface = "Interface"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .provider: return "network"
            case .model: return "brain"
            case .interface: return "paintbrush"
            case .advanced: return "gearshape.2"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Selection
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18))
                            Text(tab.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content Area
            ScrollView {
                Group {
                    switch selectedTab {
                    case .provider:
                        ProviderSettingsView()
                    case .model:
                        ModelSettingsView()
                    case .interface:
                        InterfaceSettingsView()
                    case .advanced:
                        AdvancedSettingsView()
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Provider Settings

struct ProviderSettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared
    @State private var openaiKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var showOpenAIKey: Bool = false
    @State private var showAnthropicKey: Bool = false
    @State private var saveStatus: SaveStatus = .none
    
    enum SaveStatus {
        case none, saving, success, error(String)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI Provider Configuration")
                .font(.headline)
            
            // OpenAI Settings
            GroupBox(label: Label("OpenAI", systemImage: "brain")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if showOpenAIKey {
                            TextField("API Key", text: $openaiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("API Key", text: $openaiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button(action: { showOpenAIKey.toggle() }) {
                            Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        if config.hasAPIKey(for: "openai") {
                            Label("Key configured", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("No key configured", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Button("Save Key") {
                            saveOpenAIKey()
                        }
                        .disabled(openaiKey.isEmpty)
                        
                        if config.hasAPIKey(for: "openai") {
                            Button("Remove") {
                                removeOpenAIKey()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(8)
            }
            
            // Anthropic Settings
            GroupBox(label: Label("Anthropic (Claude)", systemImage: "sparkles")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if showAnthropicKey {
                            TextField("API Key", text: $anthropicKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("API Key", text: $anthropicKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button(action: { showAnthropicKey.toggle() }) {
                            Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        if config.hasAPIKey(for: "anthropic") {
                            Label("Key configured", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("No key configured", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Button("Save Key") {
                            saveAnthropicKey()
                        }
                        .disabled(anthropicKey.isEmpty)
                        
                        if config.hasAPIKey(for: "anthropic") {
                            Button("Remove") {
                                removeAnthropicKey()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(8)
            }
            
            // Save Status
            if case .success = saveStatus {
                Label("Saved successfully", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else if case .error(let message) = saveStatus {
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func saveOpenAIKey() {
        do {
            try config.setAPIKey(openaiKey, for: "openai")
            openaiKey = ""
            saveStatus = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus = .none
            }
        } catch {
            saveStatus = .error("Failed to save key: \(error.localizedDescription)")
        }
    }
    
    private func removeOpenAIKey() {
        do {
            try config.deleteAPIKey(for: "openai")
            saveStatus = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus = .none
            }
        } catch {
            saveStatus = .error("Failed to remove key: \(error.localizedDescription)")
        }
    }
    
    private func saveAnthropicKey() {
        do {
            try config.setAPIKey(anthropicKey, for: "anthropic")
            anthropicKey = ""
            saveStatus = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus = .none
            }
        } catch {
            saveStatus = .error("Failed to save key: \(error.localizedDescription)")
        }
    }
    
    private func removeAnthropicKey() {
        do {
            try config.deleteAPIKey(for: "anthropic")
            saveStatus = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus = .none
            }
        } catch {
            saveStatus = .error("Failed to remove key: \(error.localizedDescription)")
        }
    }
}

// MARK: - Model Settings

struct ModelSettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Model Parameters")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                // Provider Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Provider")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { config.selectedProvider },
                        set: { try? config.set($0, for: .selectedProvider) }
                    )) {
                        Text("OpenAI").tag("openai")
                        Text("Anthropic (Claude)").tag("anthropic")
                    }
                    .pickerStyle(.segmented)
                }
                
                // Model Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if config.selectedProvider == "openai" {
                        Picker("", selection: Binding(
                            get: { config.selectedModel },
                            set: { try? config.set($0, for: .selectedModel) }
                        )) {
                            Text("GPT-5 Nano").tag("gpt-5-nano-2025-08-07")
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("", selection: Binding(
                            get: { config.selectedModel },
                            set: { try? config.set($0, for: .selectedModel) }
                        )) {
                            Text("Claude Haiku 4.5").tag("claude-haiku-4-5-20251001")
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Divider()
                
                // Temperature
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Temperature")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f", config.temperature))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    Slider(value: Binding(
                        get: { config.temperature },
                        set: { config.set($0, for: .temperature) }
                    ), in: 0.0...2.0, step: 0.1)
                    
                    Text("Controls randomness in responses. Lower values are more focused and deterministic.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Max Tokens
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Tokens")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(config.getInt(.maxTokens))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(config.getInt(.maxTokens)) },
                        set: { config.set(Int($0), for: .maxTokens) }
                    ), in: 256...4096, step: 256)
                    
                    Text("Maximum length of the generated response.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Interface Settings

struct InterfaceSettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Interface Preferences")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Show timestamps", isOn: Binding(
                    get: { config.getBool(.showTimestamps) },
                    set: { config.set($0, for: .showTimestamps) }
                ))
                
                Toggle("Enable animations", isOn: Binding(
                    get: { config.getBool(.enableAnimations) },
                    set: { config.set($0, for: .enableAnimations) }
                ))
                
                Toggle("Remember window position", isOn: Binding(
                    get: { config.getBool(.rememberWindowPosition) },
                    set: { config.set($0, for: .rememberWindowPosition) }
                ))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared
    @State private var showResetConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced Settings")
                .font(.headline)
            
            GroupBox(label: Text("Backend Configuration")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Python Service URL:")
                        TextField("URL", text: Binding(
                            get: { config.getString(.pythonServiceURL) },
                            set: { try? config.set($0, for: .pythonServiceURL) }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Port:")
                        TextField("Port", value: Binding(
                            get: { config.getInt(.pythonServicePort) },
                            set: { config.set($0, for: .pythonServicePort) }
                        ), formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(8)
            }
            
            GroupBox(label: Text("Feature Flags (Beta)")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Voice Mode", isOn: Binding(
                        get: { config.getBool(.enableVoiceMode) },
                        set: { config.set($0, for: .enableVoiceMode) }
                    ))
                    .disabled(true)
                    
                    Toggle("Enable Computer Use", isOn: Binding(
                        get: { config.getBool(.enableComputerUse) },
                        set: { config.set($0, for: .enableComputerUse) }
                    ))
                    .disabled(true)
                    
                    Toggle("Enable Calendar Integration", isOn: Binding(
                        get: { config.getBool(.enableCalendarIntegration) },
                        set: { config.set($0, for: .enableCalendarIntegration) }
                    ))
                    .disabled(true)
                    
                    Text("These features are coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            
            Divider()
            
            Button(action: { showResetConfirmation = true }) {
                Label("Reset All Settings", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    try? config.resetAll()
                }
            } message: {
                Text("This will delete all API keys and reset all settings to defaults. This action cannot be undone.")
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
        .frame(width: 470, height: 640)
}

