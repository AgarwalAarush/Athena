//
//  WaveformView.swift
//  Athena
//
//  Animated waveform visualization for audio input
//

import SwiftUI

/// Real-time audio waveform visualization with animated vertical bars
struct WaveformView: View {
    // MARK: - Properties

    @ObservedObject var monitor: AudioAmplitudeMonitor

    /// Width of the waveform view
    private let width: CGFloat = 120

    /// Height of the waveform view
    private let height: CGFloat = 40

    /// Minimum bar height (in points)
    private let minBarHeight: CGFloat = 4

    /// State to track render count for debugging
    @State private var renderCount = 0

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(monitor.amplitudes.enumerated()), id: \.offset) { index, amplitude in
                Capsule()
                    .fill(Color.white)
                    .frame(
                        width: barWidth,
                        height: barHeight(for: amplitude)
                    )
                    .animation(
                        .spring(response: 0.15, dampingFraction: 0.6),
                        value: amplitude
                    )
            }
        }
        .frame(width: width, height: height)
        .onAppear {
            print("[WaveformView] 👁️ View appeared, initial amplitudes count: \(monitor.amplitudes.count)")
        }
        .onChange(of: monitor.amplitudes) { newAmplitudes in
            renderCount += 1
            if renderCount % 20 == 0 {
                print("[WaveformView] 🎨 Amplitudes changed (render #\(renderCount)): \(newAmplitudes.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
            }
        }
    }
    
    // MARK: - Private Computed Properties
    
    /// Width of each bar
    private var barWidth: CGFloat {
        let barCount = CGFloat(monitor.amplitudes.count)
        let totalSpacing = 2 * (barCount - 1)
        return (width - totalSpacing) / barCount
    }
    
    /// Calculate bar height based on amplitude
    private func barHeight(for amplitude: Float) -> CGFloat {
        // Convert amplitude (0.0-1.0) to bar height
        let normalizedHeight = CGFloat(amplitude) * height
        // Ensure minimum height for visual consistency
        return max(normalizedHeight, minBarHeight)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Static preview with sample data
        WaveformView(monitor: {
            let monitor = AudioAmplitudeMonitor()
            // Simulate some amplitude values for preview
            // Note: In real usage, these would be updated by audio processing
            return monitor
        }())
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(AppMetrics.cornerRadiusSmall)
    }
    .frame(width: 200, height: 200)
}

