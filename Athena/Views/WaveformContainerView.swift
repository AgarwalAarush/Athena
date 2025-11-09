//
//  WaveformContainerView.swift
//  Athena
//
//  Container view for the always-visible waveform display at the top of the app
//

import SwiftUI

/// Container view for the waveform that remains visible at the top of the app
/// Shows animated waveform when recording, idle state otherwise
struct WaveformContainerView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject private var config = ConfigurationManager.shared
    
    @State private var cyclingTimer: Timer?
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            Spacer()
            
            // Waveform visualization (centered)
            Group {
                if let thinkingIndex = appViewModel.orchestratorThinkingIndex {
                    // Thinking state - show thinking message text with animated dots
                    HStack(spacing: 0) {
                        Text(getCurrentThinkingMessage(index: thinkingIndex))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        AnimatedDotsView()
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        startMessageCycling()
                    }
                    .onDisappear {
                        stopMessageCycling()
                    }
                } else if chatViewModel.isRecording, let monitor = chatViewModel.amplitudeMonitor {
                    // Recording state - show animated waveform
                    WaveformView(monitor: monitor)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Idle state - show placeholder waveform bars
                    idleWaveformPlaceholder
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chatViewModel.isRecording)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appViewModel.orchestratorThinkingIndex != nil)
            .onChange(of: appViewModel.orchestratorThinkingIndex) { newValue in
                if newValue != nil {
                    startMessageCycling()
                } else {
                    stopMessageCycling()
                }
            }
            
            Spacer()
            
            // Wake word mode toggle button
            wakeWordToggleButton
        }
        .frame(height: 60)
        .padding(.horizontal, AppMetrics.padding)
        .background(AppMaterial.tertiaryGlass)
    }
    
    /// Gets the current thinking message from the index
    private func getCurrentThinkingMessage(index: Int) -> String {
        guard !appViewModel.thinkingMessages.isEmpty else { return "Thinking" }
        let safeIndex = index % appViewModel.thinkingMessages.count
        return appViewModel.thinkingMessages[safeIndex]
    }
    
    /// Starts the message cycling timer
    private func startMessageCycling() {
        stopMessageCycling() // Clear any existing timer
        
        cyclingTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            guard let currentIndex = appViewModel.orchestratorThinkingIndex else { return }
            let messagesCount = appViewModel.thinkingMessages.count
            guard messagesCount > 0 else { return }
            
            // Generate random offset (1 to count-1) to ensure we get a different message
            let randomOffset = messagesCount > 1 ? Int.random(in: 1..<messagesCount) : 1
            appViewModel.orchestratorThinkingIndex = (currentIndex + randomOffset) % messagesCount
        }
    }
    
    /// Stops the message cycling timer
    private func stopMessageCycling() {
        cyclingTimer?.invalidate()
        cyclingTimer = nil
    }
    
    /// Toggle button for wake word mode
    private var wakeWordToggleButton: some View {
        Button(action: {
            let newValue = !config.wakewordModeEnabled
            print("[WaveformContainerView] 🔄 Toggling wake word mode: \(config.wakewordModeEnabled) -> \(newValue)")
            config.set(newValue, for: .wakewordModeEnabled)
        }) {
            Image(systemName: config.wakewordModeEnabled ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(config.wakewordModeEnabled ? AppColors.success : AppColors.secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white.opacity(config.wakewordModeEnabled ? 0.15 : 0.05))
                )
        }
        .buttonStyle(.plain)
        .help(config.wakewordModeEnabled ? "Wake Word Mode: ON\nClick to disable" : "Wake Word Mode: OFF\nClick to enable")
    }
    
    /// Idle placeholder showing static waveform bars
    private var idleWaveformPlaceholder: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<15, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 6, height: idleBarHeight(for: index))
            }
        }
        .frame(width: 120, height: 40)
    }
    
    /// Calculate idle bar heights to create a wave-like pattern
    private func idleBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 12
        let pattern: [CGFloat] = [0.3, 0.5, 0.7, 0.9, 1.0, 0.9, 0.7, 0.5, 0.3, 0.5, 0.7, 0.9, 0.7, 0.5, 0.3]
        let multiplier = pattern[index % pattern.count]
        return baseHeight + (maxHeight - baseHeight) * multiplier
    }
}

/// Animated dots view that cycles through 0-3 dots
struct AnimatedDotsView: View {
    @State private var dotCount: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .onAppear {
                startAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
    }
    
    private func startAnimation() {
        stopAnimation() // Clear any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    WaveformContainerView(chatViewModel: ChatViewModel(appViewModel: AppViewModel(), notesViewModel: NotesViewModel(store: SwiftDataNotesStore())))
        .environmentObject(AppViewModel())
        .environmentObject(WindowManager())
        .frame(width: 450, height: 60)
}

