//
//  SettingsView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let settingsBackground = Color(hex: "#1B1C1D")
    static let settingsCard = Color(hex: "#2A2B2C")
    static let settingsBorder = Color(hex: "#3A3B3C")
    static let settingsTextSecondary = Color(hex: "#B0B0B0")
}

// MARK: - Custom Components

struct ModernCard<Content: View>: View {
    let title: String?
    let icon: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = title {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
            }
            content
        }
        .padding(20)
        .background(Color.settingsCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.settingsBorder, lineWidth: 1)
        )
    }
}

struct ModernButton: ButtonStyle {
    enum Style {
        case primary
        case secondary
        case danger
    }

    let style: Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: style == .primary ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch style {
        case .primary:
            return isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor
        case .secondary:
            return isPressed ? Color.settingsBorder : Color.clear
        case .danger:
            return isPressed ? Color.red.opacity(0.8) : Color.red
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .danger:
            return .white
        case .secondary:
            return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.clear
        case .secondary:
            return Color.settingsBorder
        case .danger:
            return Color.clear
        }
    }
}

struct ModernTextField: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(Color.settingsBackground)
            .foregroundColor(.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.settingsBorder, lineWidth: 1)
            )
    }
}

struct ModernSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .padding(10)
            .background(Color.settingsBackground)
            .foregroundColor(.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.settingsBorder, lineWidth: 1)
            )
    }
}

// MARK: - Main Settings View

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
            // Modern Header
            HStack {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Modern Tab Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 14, weight: .medium))
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                selectedTab == tab
                                    ? Color.accentColor
                                    : Color.settingsCard
                            )
                            .foregroundColor(
                                selectedTab == tab
                                    ? .white
                                    : .settingsTextSecondary
                            )
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        selectedTab == tab
                                            ? Color.clear
                                            : Color.settingsBorder,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)

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
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(Color.settingsBackground)
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
        VStack(alignment: .leading, spacing: 24) {
            Text("AI Provider Configuration")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            // OpenAI Settings
            ModernCard(title: "OpenAI", icon: "brain") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        if showOpenAIKey {
                            TextField("Enter API Key", text: $openaiKey)
                                .textFieldStyle(ModernTextField())
                        } else {
                            ModernSecureField(placeholder: "Enter API Key", text: $openaiKey)
                        }

                        Button(action: { showOpenAIKey.toggle() }) {
                            Image(systemName: showOpenAIKey ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.settingsTextSecondary)
                        }
                        .buttonStyle(.plain)
                        .help(showOpenAIKey ? "Hide key" : "Show key")
                    }

                    HStack(spacing: 12) {
                        if config.hasAPIKey(for: "openai") {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Key configured")
                            }
                            .foregroundColor(.green)
                            .font(.caption)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("No key configured")
                            }
                            .foregroundColor(.orange)
                            .font(.caption)
                        }

                        Spacer()

                        Button("Save Key") {
                            saveOpenAIKey()
                        }
                        .buttonStyle(ModernButton(style: .primary))
                        .disabled(openaiKey.isEmpty)
                        .opacity(openaiKey.isEmpty ? 0.5 : 1.0)

                        if config.hasAPIKey(for: "openai") {
                            Button("Remove") {
                                removeOpenAIKey()
                            }
                            .buttonStyle(ModernButton(style: .danger))
                        }
                    }
                }
            }

            // Anthropic Settings
            ModernCard(title: "Anthropic (Claude)", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        if showAnthropicKey {
                            TextField("Enter API Key", text: $anthropicKey)
                                .textFieldStyle(ModernTextField())
                        } else {
                            ModernSecureField(placeholder: "Enter API Key", text: $anthropicKey)
                        }

                        Button(action: { showAnthropicKey.toggle() }) {
                            Image(systemName: showAnthropicKey ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.settingsTextSecondary)
                        }
                        .buttonStyle(.plain)
                        .help(showAnthropicKey ? "Hide key" : "Show key")
                    }

                    HStack(spacing: 12) {
                        if config.hasAPIKey(for: "anthropic") {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Key configured")
                            }
                            .foregroundColor(.green)
                            .font(.caption)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("No key configured")
                            }
                            .foregroundColor(.orange)
                            .font(.caption)
                        }

                        Spacer()

                        Button("Save Key") {
                            saveAnthropicKey()
                        }
                        .buttonStyle(ModernButton(style: .primary))
                        .disabled(anthropicKey.isEmpty)
                        .opacity(anthropicKey.isEmpty ? 0.5 : 1.0)

                        if config.hasAPIKey(for: "anthropic") {
                            Button("Remove") {
                                removeAnthropicKey()
                            }
                            .buttonStyle(ModernButton(style: .danger))
                        }
                    }
                }
            }

            // Save Status
            if case .success = saveStatus {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Saved successfully")
                }
                .foregroundColor(.green)
                .font(.subheadline)
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if case .error(let message) = saveStatus {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text(message)
                }
                .foregroundColor(.red)
                .font(.subheadline)
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
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
        VStack(alignment: .leading, spacing: 24) {
            Text("Model Parameters")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            ModernCard {
                VStack(alignment: .leading, spacing: 24) {
                    // Provider Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Provider")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Model")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

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
                        .background(Color.settingsBorder)

                    // Temperature
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Temperature")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.2f", config.temperature))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(6)
                        }

                        Slider(value: Binding(
                            get: { config.temperature },
                            set: { config.set($0, for: .temperature) }
                        ), in: 0.0...2.0, step: 0.1)
                        .tint(.accentColor)

                        Text("Controls randomness in responses. Lower values are more focused and deterministic.")
                            .font(.caption)
                            .foregroundColor(.settingsTextSecondary)
                    }

                    // Max Tokens
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Max Tokens")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(config.getInt(.maxTokens))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(6)
                        }

                        Slider(value: Binding(
                            get: { Double(config.getInt(.maxTokens)) },
                            set: { config.set(Int($0), for: .maxTokens) }
                        ), in: 256...4096, step: 256)
                        .tint(.accentColor)

                        Text("Maximum length of the generated response.")
                            .font(.caption)
                            .foregroundColor(.settingsTextSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Interface Settings

struct InterfaceSettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Interface Preferences")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            ModernCard {
                VStack(alignment: .leading, spacing: 20) {
                    SettingToggleRow(
                        title: "Show timestamps",
                        description: "Display timestamps on messages",
                        isOn: Binding(
                            get: { config.getBool(.showTimestamps) },
                            set: { config.set($0, for: .showTimestamps) }
                        )
                    )

                    Divider()
                        .background(Color.settingsBorder)

                    SettingToggleRow(
                        title: "Enable animations",
                        description: "Smooth transitions and effects",
                        isOn: Binding(
                            get: { config.getBool(.enableAnimations) },
                            set: { config.set($0, for: .enableAnimations) }
                        )
                    )

                    Divider()
                        .background(Color.settingsBorder)

                    SettingToggleRow(
                        title: "Remember window position",
                        description: "Save window location on close",
                        isOn: Binding(
                            get: { config.getBool(.rememberWindowPosition) },
                            set: { config.set($0, for: .rememberWindowPosition) }
                        )
                    )
                }
            }
        }
    }
}

struct SettingToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.settingsTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Advanced Settings")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            ModernCard(title: "Backend Configuration", icon: "server.rack") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Python Service URL")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        TextField("URL", text: Binding(
                            get: { config.getString(.pythonServiceURL) },
                            set: { try? config.set($0, for: .pythonServiceURL) }
                        ))
                        .textFieldStyle(ModernTextField())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Port")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        TextField("Port", value: Binding(
                            get: { config.getInt(.pythonServicePort) },
                            set: { config.set($0, for: .pythonServicePort) }
                        ), formatter: NumberFormatter())
                        .textFieldStyle(ModernTextField())
                    }
                }
            }

            ModernCard(title: "Feature Flags (Beta)", icon: "flag.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Voice Mode")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.settingsTextSecondary)
                            Text("Coming soon")
                                .font(.caption)
                                .foregroundColor(.settingsTextSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { config.getBool(.enableVoiceMode) },
                            set: { config.set($0, for: .enableVoiceMode) }
                        ))
                        .labelsHidden()
                        .disabled(true)
                    }

                    Divider()
                        .background(Color.settingsBorder)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Computer Use")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.settingsTextSecondary)
                            Text("Coming soon")
                                .font(.caption)
                                .foregroundColor(.settingsTextSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { config.getBool(.enableComputerUse) },
                            set: { config.set($0, for: .enableComputerUse) }
                        ))
                        .labelsHidden()
                        .disabled(true)
                    }

                    Divider()
                        .background(Color.settingsBorder)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Calendar Integration")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.settingsTextSecondary)
                            Text("Coming soon")
                                .font(.caption)
                                .foregroundColor(.settingsTextSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { config.getBool(.enableCalendarIntegration) },
                            set: { config.set($0, for: .enableCalendarIntegration) }
                        ))
                        .labelsHidden()
                        .disabled(true)
                    }
                }
            }

            ModernCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Danger Zone")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("This action cannot be undone")
                                .font(.caption)
                                .foregroundColor(.settingsTextSecondary)
                        }
                    }

                    Button(action: { showResetConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Reset All Settings")
                        }
                    }
                    .buttonStyle(ModernButton(style: .danger))
                    .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            try? config.resetAll()
                        }
                    } message: {
                        Text("This will delete all API keys and reset all settings to defaults. This action cannot be undone.")
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 600, height: 700)
}
