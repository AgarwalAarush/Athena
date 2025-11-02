//
//  SettingsView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI
import AppKit
import EventKit

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

    static let settingsBackground = Color(NSColor.controlBackgroundColor)
    static let settingsCard = Color(NSColor.windowBackgroundColor)
    static let settingsBorder = Color(NSColor.separatorColor)
    static let settingsTextSecondary = Color(NSColor.secondaryLabelColor)
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
            .foregroundColor(Color(NSColor.labelColor))
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
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.30))
            .foregroundColor(Color(NSColor.labelColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ModernSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.30))
            .foregroundColor(Color(NSColor.labelColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// Settings-specific text field styles similar to ChatView input
struct SettingsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.6))
            .foregroundColor(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SettingsSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.6))
            .foregroundColor(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // AI Provider Configuration Section
                ProviderSettingsView()

                Divider()
                    .padding(.horizontal, 16)

                // Permissions Section
                PermissionsSettingsView()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Color(hex: "1E1E1E"))
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

            // Provider Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Provider")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))

                Picker("", selection: Binding(
                    get: { config.selectedProvider },
                    set: { try? config.set($0, for: .selectedProvider) }
                )) {
                    Text("OpenAI").tag("openai")
                    Text("Anthropic (Claude)").tag("anthropic")
                }
                .pickerStyle(.segmented)
            }

            // OpenAI Settings
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("OpenAI")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                HStack(spacing: 12) {
                    if showOpenAIKey {
                        TextField("Enter API Key", text: $openaiKey)
                            .textFieldStyle(SettingsTextFieldStyle())
                    } else {
                        SettingsSecureField(placeholder: "Enter API Key", text: $openaiKey)
                    }

                    Button(action: { showOpenAIKey.toggle() }) {
                        Image(systemName: showOpenAIKey ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.white.opacity(0.6))
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

            // Anthropic Settings
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Anthropic (Claude)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                HStack(spacing: 12) {
                    if showAnthropicKey {
                        TextField("Enter API Key", text: $anthropicKey)
                            .textFieldStyle(SettingsTextFieldStyle())
                    } else {
                        SettingsSecureField(placeholder: "Enter API Key", text: $anthropicKey)
                    }

                    Button(action: { showAnthropicKey.toggle() }) {
                        Image(systemName: showAnthropicKey ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.white.opacity(0.6))
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

            // Save Status
            if case .success = saveStatus {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Saved successfully")
                }
                .foregroundColor(.green)
                .font(.subheadline)
                .padding(12)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
            } else if case .error(let message) = saveStatus {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text(message)
                }
                .foregroundColor(.red)
                .font(.subheadline)
                .padding(12)
                .background(Color.red.opacity(0.2))
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

// MARK: - Permissions Settings

struct PermissionsSettingsView: View {
    @State private var calendarStatus: String = CalendarService.shared.authorizationStatusDescription
    @State private var isRequesting = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("App Permissions")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            // Calendar Permission Section
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Calendar Access")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Text("Athena needs access to your calendar to display and manage events.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                HStack(spacing: 12) {
                    // Status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(calendarStatus)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    // Action buttons
                    if CalendarService.shared.authorizationStatus == .notDetermined {
                        Button(action: requestCalendarAccess) {
                            if isRequesting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 20, height: 20)
                            } else {
                                Text("Grant Access")
                            }
                        }
                        .buttonStyle(ModernButton(style: .primary))
                        .disabled(isRequesting)
                    } else if CalendarService.shared.authorizationStatus == .denied {
                        Button("Open System Settings") {
                            CalendarService.shared.openCalendarPrivacySettings()
                        }
                        .buttonStyle(ModernButton(style: .primary))
                    } else if CalendarService.shared.authorizationStatus == .writeOnly {
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("Write-only access detected")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Button("Upgrade to Full Access") {
                                CalendarService.shared.openCalendarPrivacySettings()
                            }
                            .buttonStyle(ModernButton(style: .primary))
                        }
                    }
                }

                // macOS 14+ info
                if #available(macOS 14.0, *) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("On macOS Sonoma and later, 'Full Access' is required to read calendar events.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 8)
                }
            }

            // Privacy Section
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Privacy")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Text("Athena respects your privacy:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Calendar data stays on your device")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No calendar data is sent to external servers")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("You can revoke access anytime in System Settings")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .alert("Calendar Access", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var statusColor: Color {
        switch CalendarService.shared.authorizationStatus {
        case .fullAccess, .authorized:
            return .green
        case .writeOnly:
            return .orange
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    private func requestCalendarAccess() {
        isRequesting = true
        
        CalendarService.shared.requestAccessWithActivation { granted, error in
            isRequesting = false
            
            // Update status
            calendarStatus = CalendarService.shared.authorizationStatusDescription
            
            if let error = error {
                alertMessage = "Failed to request access: \(error.localizedDescription)"
                showAlert = true
            } else if granted {
                alertMessage = "Calendar access granted! You can now view and manage your events."
                showAlert = true
            } else {
                alertMessage = "Calendar access was denied. You can grant access later in System Settings > Privacy & Security > Calendars."
                showAlert = true
            }
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 600, height: 700)
}
