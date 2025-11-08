//
//  SettingsView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI
import AppKit
import EventKit
import ApplicationServices
internal import Contacts

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

// MARK: - Window Styling

struct WindowStyler: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TitlebarConfigurator())
    }

    private struct TitlebarConfigurator: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                if let window = view.window {
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.isMovableByWindowBackground = true
                    window.styleMask.insert(.fullSizeContentView)
                    window.toolbarStyle = .unifiedCompact
                    window.isOpaque = false
                    window.backgroundColor = .clear
                }
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {}
    }
}

extension View {
    func unifiedTitlebar() -> some View {
        modifier(WindowStyler())
    }
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
        case neutral
        case calendarAction
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
        case .neutral:
            let base = Color(hex: "3A3A3A")
            return isPressed ? base.opacity(0.8) : base
        case .calendarAction:
            let base = Color(hex: "3A3A3A")
            return isPressed ? base.opacity(0.8) : base
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .danger, .neutral, .calendarAction:
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
        case .neutral, .calendarAction:
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

// Settings-specific text field components similar to ChatView input
struct SettingsTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onChange: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.white
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.delegate = context.coordinator

        // Remove extra padding
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        // Configure scroll view
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
            textView.textColor = NSColor.white
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SettingsTextField
        var textView: NSTextView?

        init(_ parent: SettingsTextField) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            if let textView = textView {
                parent.text = textView.string
                parent.onChange(textView.string)
            }
        }
    }
}

struct SettingsSecureField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onChange: (String) -> Void

    func makeNSView(context: Context) -> NSSecureTextField {
        let textField = NSSecureTextField()

        textField.font = NSFont.systemFont(ofSize: 14)
        textField.textColor = NSColor.white
        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.focusRingType = .none
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator

        return textField
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SettingsSecureField

        init(_ parent: SettingsSecureField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSSecureTextField {
                parent.text = textField.stringValue
                parent.onChange(textField.stringValue)
            }
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared

    var body: some View {
        ZStack {
            Color(hex: "1E1E1E")
                .ignoresSafeArea(.container, edges: .top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // AI Provider Configuration Section
                    ProviderSettingsView()

                    Divider()
                        .padding(.horizontal, 16)

                    // Permissions Section
                    PermissionsSettingsView()
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Calendar Selection Section
                    CalendarSelectionSettingsView()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
        .unifiedTitlebar()
    }
}

// MARK: - Provider Settings

struct ProviderSettingsView: View {
    @ObservedObject var config = ConfigurationManager.shared
    @State private var openaiKey: String = ""
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
            VStack(alignment: .leading, spacing: 16) {
                // Title with status indicator
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("OpenAI")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

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
                }

                // Input field with remove button
                HStack(alignment: .center, spacing: 12) {
                    SettingsSecureField(
                        text: $openaiKey,
                        placeholder: "Enter API Key",
                        onChange: { newValue in
                            if !newValue.isEmpty {
                                saveOpenAIKey()
                            }
                        }
                    )
                    .frame(height: 32)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                    .background(Color(hex: "303030"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if config.hasAPIKey(for: "openai") {
                        Button("Remove") {
                            removeOpenAIKey()
                        }
                        .buttonStyle(ModernButton(style: .neutral))
                        .frame(height: 32)
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
}

// MARK: - Permissions Settings

struct PermissionsSettingsView: View {
    @State private var calendarStatus: String = CalendarService.shared.authorizationStatusDescription
    @State private var accessibilityStatus: String = AccessibilityManager.shared.isAccessibilityEnabled ? "Granted" : "Not Granted"
    @State private var contactsStatus: String = "Unknown"
    @State private var messagingStatus: String = "Unknown"
    
    @State private var isRequestingCalendar = false
    @State private var isRequestingAccessibility = false
    @State private var isRequestingContacts = false
    @State private var isRequestingMessaging = false
    
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("App Permissions")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            // Calendar Permission Section
            PermissionSectionView(
                icon: "calendar",
                title: "Calendar Access",
                status: calendarStatus,
                statusColor: calendarStatusColor,
                isRequesting: isRequestingCalendar
            ) {
                calendarPermissionActions
            }

            // Accessibility Permission Section
            PermissionSectionView(
                icon: "cursorarrow.click.badge.clock",
                title: "Accessibility Access",
                status: accessibilityStatus,
                statusColor: accessibilityStatusColor,
                isRequesting: isRequestingAccessibility
            ) {
                accessibilityPermissionActions
            }

            // Contacts Permission Section
            PermissionSectionView(
                icon: "person.2",
                title: "Contacts Access",
                status: contactsStatus,
                statusColor: contactsStatusColor,
                isRequesting: isRequestingContacts
            ) {
                contactsPermissionActions
            }
            
            // Messaging (Apple Events) Permission Section
            PermissionSectionView(
                icon: "message",
                title: "Messages Automation",
                status: messagingStatus,
                statusColor: messagingStatusColor,
                isRequesting: isRequestingMessaging
            ) {
                messagingPermissionActions
            }
        }
        .onAppear {
            updateAllStatuses()
        }
        .alert("Permission Request", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Permission Actions
    
    @ViewBuilder
    private var calendarPermissionActions: some View {
        if CalendarService.shared.authorizationStatus == .notDetermined {
            HStack(spacing: 12) {
                Spacer()
                Button(action: requestCalendarAccess) {
                    if isRequestingCalendar {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Text("Grant Access")
                    }
                }
                .buttonStyle(ModernButton(style: .primary))
                .disabled(isRequestingCalendar)
            }
        } else if CalendarService.shared.authorizationStatus == .denied {
            HStack(spacing: 12) {
                Spacer()
                Button("Open System Settings") {
                    CalendarService.shared.openCalendarPrivacySettings()
                }
                .buttonStyle(ModernButton(style: .secondary))
            }
        } else if CalendarService.shared.authorizationStatus == .writeOnly {
            HStack(spacing: 12) {
                Spacer()
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
    }
    
    @ViewBuilder
    private var accessibilityPermissionActions: some View {
        if !AccessibilityManager.shared.isAccessibilityEnabled {
            HStack(spacing: 12) {
                Spacer()
                Button(action: requestAccessibilityAccess) {
                    if isRequestingAccessibility {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Text("Grant Access")
                    }
                }
                .buttonStyle(ModernButton(style: .primary))
                .disabled(isRequestingAccessibility)
            }
        }
    }
    
    @ViewBuilder
    private var contactsPermissionActions: some View {
        let permissionManager = ContactsPermissionManager.shared
        
        if permissionManager.canRequestDirectly {
            HStack(spacing: 12) {
                Spacer()
                Button(action: requestContactsAccess) {
                    if isRequestingContacts {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Text("Grant Access")
                    }
                }
                .buttonStyle(ModernButton(style: .primary))
                .disabled(isRequestingContacts)
            }
        } else if permissionManager.requiresSystemSettings {
            HStack(spacing: 12) {
                Spacer()
                Button("Open System Settings") {
                    permissionManager.openSystemSettings()
                }
                .buttonStyle(ModernButton(style: .secondary))
            }
        }
    }
    
    @ViewBuilder
    private var messagingPermissionActions: some View {
        let permissionManager = MessagingPermissionManager.shared
        
        if permissionManager.canRequestDirectly {
            HStack(spacing: 12) {
                Spacer()
                Button(action: requestMessagingAccess) {
                    if isRequestingMessaging {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Text("Grant Access")
                    }
                }
                .buttonStyle(ModernButton(style: .primary))
                .disabled(isRequestingMessaging)
            }
        } else if permissionManager.requiresSystemSettings {
            HStack(spacing: 12) {
                Spacer()
                Button("Open System Settings") {
                    permissionManager.openSystemSettings()
                }
                .buttonStyle(ModernButton(style: .secondary))
            }
        }
    }
    
    // MARK: - Status Colors
    
    private var calendarStatusColor: Color {
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

    private var accessibilityStatusColor: Color {
        AccessibilityManager.shared.isAccessibilityEnabled ? .green : .red
    }
    
    private var contactsStatusColor: Color {
        statusColorForPermission(ContactsPermissionManager.shared.authorizationStatus)
    }
    
    private var messagingStatusColor: Color {
        statusColorForPermission(MessagingPermissionManager.shared.authorizationStatus)
    }
    
    private func statusColorForPermission(_ status: PermissionStatus) -> Color {
        switch status {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .gray
        }
    }
    
    // MARK: - Request Functions
    
    private func requestCalendarAccess() {
        isRequestingCalendar = true

        CalendarService.shared.requestAccessWithActivation { granted, error in
            isRequestingCalendar = false
            updateAllStatuses()
            
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

    private func requestAccessibilityAccess() {
        isRequestingAccessibility = true

        let granted = AccessibilityManager.shared.requestAccessibilityPermissions(prompt: true)

        isRequestingAccessibility = false
        updateAllStatuses()

        if granted {
            alertMessage = "Accessibility access granted! Athena can now move and position windows."
            showAlert = true
        } else {
            alertMessage = "Accessibility access was denied. You can grant access later in System Settings > Privacy & Security > Accessibility."
            showAlert = true
        }
    }
    
    private func requestContactsAccess() {
        isRequestingContacts = true
        
        Task {
            let result = await ContactsPermissionManager.shared.requestAuthorization()
            
            isRequestingContacts = false
            updateAllStatuses()
            
            switch result {
            case .granted:
                alertMessage = "Contacts access granted! Athena can now look up contact information."
                showAlert = true
            case .denied:
                alertMessage = "Contacts access was denied. You can grant access later in System Settings > Privacy & Security > Contacts."
                showAlert = true
            case .requiresSystemSettings:
                alertMessage = "Please enable Contacts access in System Settings > Privacy & Security > Contacts."
                showAlert = true
            case .error(let error):
                alertMessage = "Failed to request access: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func requestMessagingAccess() {
        isRequestingMessaging = true
        
        Task {
            let result = await MessagingPermissionManager.shared.requestAuthorization()
            
            isRequestingMessaging = false
            updateAllStatuses()
            
            switch result {
            case .granted:
                alertMessage = "Messages automation access granted! Athena can now send messages on your behalf."
                showAlert = true
            case .denied:
                alertMessage = "Messages automation was denied. You can grant access later in System Settings > Privacy & Security > Automation."
                showAlert = true
            case .requiresSystemSettings:
                alertMessage = "Please enable Automation for Athena in System Settings > Privacy & Security > Automation."
                showAlert = true
            case .error(let error):
                alertMessage = "Failed to request access: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func updateAllStatuses() {
        calendarStatus = CalendarService.shared.authorizationStatusDescription
        accessibilityStatus = AccessibilityManager.shared.isAccessibilityEnabled ? "Granted" : "Not Granted"
        contactsStatus = ContactsPermissionManager.shared.authorizationStatus.displayString
        messagingStatus = MessagingPermissionManager.shared.authorizationStatus.displayString
    }
}

// MARK: - Permission Section View

struct PermissionSectionView<Actions: View>: View {
    let icon: String
    let title: String
    let status: String
    let statusColor: Color
    let isRequesting: Bool
    @ViewBuilder let actions: () -> Actions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(status)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            
            actions()
        }
    }
}

// MARK: - Calendar Selection Settings

struct CalendarSelectionSettingsView: View {
    @ObservedObject var calendarService = CalendarService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Calendar Selection")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if !calendarService.hasReadAccess {
                accessRequiredView
            } else if calendarService.allEventCalendars.isEmpty {
                noCalendarsView
            } else {
                calendarListView
            }
        }
    }
    
    private var accessRequiredView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundColor(.orange)
                Text("Calendar access is required to select calendars")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("Please grant calendar access in the Permissions section above.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var noCalendarsView: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundColor(.gray)
            Text("No calendars found. Please add calendars in the System Calendar app.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var calendarListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selection summary with bulk actions
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(.white)
                Text("\(calendarService.selectedCalendarIDs.count) of \(calendarService.allEventCalendars.count) calendars selected")
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Select All") {
                    calendarService.selectAllCalendars()
                }
                .buttonStyle(ModernButton(style: .calendarAction))
                
                Button("Deselect All") {
                    calendarService.deselectAllCalendars()
                }
                .buttonStyle(ModernButton(style: .calendarAction))
            }
            .font(.body)
            
            // Calendar list in a scrollable container
            VStack(alignment: .leading, spacing: 0) {
                ForEach(calendarService.allEventCalendars, id: \.calendarIdentifier) { calendar in
                    CalendarToggleRow(calendar: calendar, calendarService: calendarService)
                        .padding(.vertical, 8)
                    
                    if calendar.calendarIdentifier != calendarService.allEventCalendars.last?.calendarIdentifier {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// MARK: - Calendar Toggle Row

struct CalendarToggleRow: View {
    let calendar: EKCalendar
    @ObservedObject var calendarService: CalendarService
    
    private var isSelected: Bool {
        calendarService.selectedCalendarIDs.contains(calendar.calendarIdentifier)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { calendarService.setCalendar(calendar, enabled: $0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            // Calendar color indicator
            Circle()
                .fill(Color(nsColor: calendar.color))
                .frame(width: 12, height: 12)
            
            // Calendar title
            Text(calendar.title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            // Calendar source badge (e.g., iCloud, Google)
            if let source = calendar.source {
                Text(source.title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 600, height: 700)
}

