//
//  ContentView.swift
//  Athena
//
//  Created by Aarush Agarwal on 10/29/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var windowManager: WindowManager
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var chatViewModel: ChatViewModel

    init() {
        let appViewModel = AppViewModel()
        _appViewModel = StateObject(wrappedValue: appViewModel)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(appViewModel: appViewModel))
    }

    var body: some View {
        ZStack {
            // Define the rounded shell shape once
            let shell = RoundedRectangle(cornerRadius: 12, style: .continuous)

            // 1) Background shell with shadow (NOT clipped)
            shell
                .fill(Color.white.opacity(0.85))
                .overlay(
                    shell.stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)

            // 2) Content clipped to the shell shape
            VStack(spacing: 0) {
                // Title Bar
                TitleBarView(chatViewModel: chatViewModel)

//                Divider()
//                    .opacity(0.5)

                // Main Content Area
                Group {
                    switch appViewModel.currentView {
                    case .chat:
                        ChatView(viewModel: chatViewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .calendar:
                        DayView(viewModel: appViewModel.dayViewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .notes:
                        NotesSplitView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .animation(nil, value: appViewModel.currentView)
                .transition(.identity)
            }
            .clipShape(shell)
            .compositingGroup()
        }
        .frame(width: windowManager.windowSize.width, height: windowManager.windowSize.height)
        .environmentObject(appViewModel)
        .onAppear {
            appViewModel.setup(windowManager: windowManager)
        }
    }
}

struct TitleBarView: View {
    @EnvironmentObject var windowManager: WindowManager
    @EnvironmentObject var appViewModel: AppViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject private var config = ConfigurationManager.shared

    @State private var isPulsing = false

    var body: some View {
        HStack {
            // Back button (visible in notes and calendar views)
            if appViewModel.currentView == .notes || appViewModel.currentView == .calendar {
                Button(action: { appViewModel.showChat() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Back to Chat")
            }

            Spacer()

            HStack(spacing: 12) {
                // Wakeword Mode Toggle
                Button(action: {
                    let newValue = !config.wakewordModeEnabled
                    config.set(newValue, for: .wakewordModeEnabled)
                }) {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(wakewordModeColor)
                        .scaleEffect(shouldPulse ? (isPulsing ? 1.15 : 1.0) : 1.0)
                        .animation(
                            shouldPulse ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                            value: isPulsing
                        )
                }
                .buttonStyle(.plain)
                .help(config.wakewordModeEnabled ? "Wakeword Mode: ON" : "Wakeword Mode: OFF")
                .onAppear {
                    if shouldPulse {
                        isPulsing = true
                    }
                }
                .onChange(of: shouldPulse) { newValue in
                    isPulsing = newValue
                }

                Button(action: { appViewModel.showChat() }) {
                    Image(systemName: "message")
                        .foregroundColor(appViewModel.currentView == .chat ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help("Chat")

                Button(action: { appViewModel.showCalendar() }) {
                    Image(systemName: "calendar")
                        .foregroundColor(appViewModel.currentView == .calendar ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help("Calendar")

                Button(action: { appViewModel.showNotes() }) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(appViewModel.currentView == .notes ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help("Notes")

                Button(action: { windowManager.openSettingsWindow() }) {
                    Image(systemName: "gear")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }

    private var wakewordModeColor: Color {
        let isEnabled = config.wakewordModeEnabled
        if !isEnabled {
            return .secondary
        }
        return chatViewModel.isRecording ? .green : .blue
    }

    private var shouldPulse: Bool {
        config.wakewordModeEnabled && chatViewModel.isRecording
    }
}



// Visual effect blur for transparent window background
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}
