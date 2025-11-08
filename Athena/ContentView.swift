//
//  ContentView.swift
//  Athena
//
//  Created by Aarush Agarwal on 10/29/25.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var windowManager: WindowManager
    @StateObject private var appViewModel: AppViewModel
    @StateObject private var chatViewModel: ChatViewModel

    init() {
        // Create a single AppViewModel instance
        let appVM = AppViewModel()
        
        // Set up NotesViewModel with AppViewModel reference
        appVM.notesViewModel.setAppViewModel(appVM)
        
        // Initialize StateObject wrappers with the same instance
        _appViewModel = StateObject(wrappedValue: appVM)
        
        // Create ChatViewModel with references to AppViewModel and NotesViewModel
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(
            appViewModel: appVM,
            notesViewModel: appVM.notesViewModel
        ))
    }

    var body: some View {
        ZStack {
            // Define the rounded shell shape once
            let shell = RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusXLarge, style: .continuous)

            // 1) Background shell with glass material and shadow
            shell
                .fill(AppMaterial.primaryGlass)
                .overlay(
                    shell.strokeBorder(AppColors.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)

            // 2) Content clipped to the shell shape
            VStack(spacing: 0) {
                // Title Bar
                TitleBarView(chatViewModel: chatViewModel)
                
                Divider()
                    .opacity(0.3)

                // Main Content Area
                Group {
                    switch appViewModel.currentView {
                    case .home:
                        HomeView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .chat:
                        ChatView(viewModel: chatViewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .calendar:
                        DayView(viewModel: appViewModel.dayViewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .notes:
                        NotesView(vm: appViewModel.notesViewModel)
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
        .alert(item: $appViewModel.alertInfo) { info in
            if let primaryButton = info.primaryButton, let secondaryButton = info.secondaryButton {
                Alert(
                    title: Text(info.title),
                    message: Text(info.message),
                    primaryButton: primaryButton,
                    secondaryButton: secondaryButton
                )
            } else if let primaryButton = info.primaryButton {
                Alert(
                    title: Text(info.title),
                    message: Text(info.message),
                    dismissButton: primaryButton
                )
            } else {
                Alert(
                    title: Text(info.title),
                    message: Text(info.message)
                )
            }
        }
        .onAppear {
            print("[ContentView] 🎬 onAppear called - setting up AppViewModel")
            // Get AppDelegate from NSApp
            if let appDelegate = NSApp.delegate as? AppDelegate {
                print("[ContentView] ✅ AppDelegate retrieved successfully")
                appViewModel.setup(windowManager: windowManager, appDelegate: appDelegate)
                print("[ContentView] ✅ AppViewModel setup completed with windowManager and appDelegate")
            } else {
                print("[ContentView] ❌ Failed to retrieve AppDelegate from NSApp.delegate")
            }
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
        HStack(spacing: AppMetrics.spacingMedium) {
            // Back button (visible in notes and calendar views)
            if appViewModel.currentView == .notes || appViewModel.currentView == .calendar {
                HoverIconButton(
                    systemName: "chevron.left",
                    action: { appViewModel.showHome() },
                    accent: true,
                    size: AppMetrics.buttonSizeSmall,
                    iconSize: AppMetrics.iconSizeSmall
                )
                .help("Back to Home")
            }

            Spacer()

            HStack(spacing: AppMetrics.spacingSmall) {
                // Animated Waveform (shown when voice is active)
                Group {
                    if chatViewModel.isRecording, let monitor = chatViewModel.amplitudeMonitor {
                        WaveformView(monitor: monitor)
                            .transition(.scale.combined(with: .opacity))
                            .padding(.trailing, AppMetrics.spacingXSmall)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chatViewModel.isRecording)
                
                // Wakeword Mode Toggle with pulse animation
                Button(action: {
                    let newValue = !config.wakewordModeEnabled
                    config.set(newValue, for: .wakewordModeEnabled)
                }) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: AppMetrics.iconSize, weight: .medium))
                        .foregroundColor(wakewordModeColor)
                        .frame(width: AppMetrics.buttonSizeSmall, height: AppMetrics.buttonSizeSmall)
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

                HoverIconButton(
                    systemName: "house",
                    action: { appViewModel.showHome() },
                    tint: appViewModel.currentView == .home ? AppColors.accent : AppColors.secondary,
                    hoverTint: appViewModel.currentView == .home ? AppColors.accent : AppColors.primary,
                    size: AppMetrics.buttonSizeSmall,
                    iconSize: AppMetrics.iconSizeSmall
                )
                .help("Home")

                HoverIconButton(
                    systemName: "calendar",
                    action: { appViewModel.showCalendar() },
                    tint: appViewModel.currentView == .calendar ? AppColors.accent : AppColors.secondary,
                    hoverTint: appViewModel.currentView == .calendar ? AppColors.accent : AppColors.primary,
                    size: AppMetrics.buttonSizeSmall,
                    iconSize: AppMetrics.iconSizeSmall
                )
                .help("Calendar")

                HoverIconButton(
                    systemName: "square.and.pencil",
                    action: { appViewModel.showNotes() },
                    tint: appViewModel.currentView == .notes ? AppColors.accent : AppColors.secondary,
                    hoverTint: appViewModel.currentView == .notes ? AppColors.accent : AppColors.primary,
                    size: AppMetrics.buttonSizeSmall,
                    iconSize: AppMetrics.iconSizeSmall
                )
                .help("Notes")

                HoverIconButton(
                    systemName: "message",
                    action: { appViewModel.showChat() },
                    tint: appViewModel.currentView == .chat ? AppColors.accent : AppColors.secondary,
                    hoverTint: appViewModel.currentView == .chat ? AppColors.accent : AppColors.primary,
                    size: AppMetrics.buttonSizeSmall,
                    iconSize: AppMetrics.iconSizeSmall
                )
                .help("Chat")

                HoverIconButton(
                    systemName: "gear",
                    action: { windowManager.openSettingsWindow() },
                    size: AppMetrics.buttonSizeSmall,
                    iconSize: AppMetrics.iconSizeSmall
                )
                .help("Settings")
            }
        }
        .padding(.horizontal, AppMetrics.padding)
        .padding(.vertical, AppMetrics.paddingMedium)
        .background(AppMaterial.tertiaryGlass)
    }

    private var wakewordModeColor: Color {
        let isEnabled = config.wakewordModeEnabled
        if !isEnabled {
            return AppColors.secondary
        }
        return chatViewModel.isRecording ? AppColors.success : AppColors.info
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
