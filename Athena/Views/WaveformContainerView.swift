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
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            Spacer()
            
            // Waveform visualization (centered)
            Group {
                if chatViewModel.isRecording, let monitor = chatViewModel.amplitudeMonitor {
                    WaveformView(monitor: monitor)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Idle state - show placeholder waveform bars
                    idleWaveformPlaceholder
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chatViewModel.isRecording)
            
            Spacer()
            
            // Wake word mode toggle button
            wakeWordToggleButton
        }
        .frame(height: 60)
        .padding(.horizontal, AppMetrics.padding)
        .background(AppMaterial.tertiaryGlass)
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

#Preview {
    WaveformContainerView(chatViewModel: ChatViewModel(appViewModel: AppViewModel(), notesViewModel: NotesViewModel(store: SwiftDataNotesStore())))
        .environmentObject(AppViewModel())
        .environmentObject(WindowManager())
        .frame(width: 450, height: 60)
}

