//
//  AudioAmplitudeMonitor.swift
//  Athena
//
//  Monitors audio amplitude for real-time waveform visualization
//

import Foundation
import Combine

/// Monitors audio frames and computes amplitude levels for visualization
@MainActor
final class AudioAmplitudeMonitor: ObservableObject {
    // MARK: - Published Properties
    
    /// Array of amplitude values for each bar in the waveform (normalized 0.0 to 1.0)
    @Published private(set) var amplitudes: [Float] = []
    
    // MARK: - Private Properties

    /// Number of bars to display in the waveform
    private let barCount: Int = 30
    
    /// Smoothing factor (0.0 = no smoothing, 1.0 = maximum smoothing)
    private let smoothingFactor: Float = 0.7
    
    /// Minimum bar height (as fraction of max) for visual consistency
    private let minimumAmplitude: Float = 0.1
    
    /// Task for processing audio frames
    private var processingTask: Task<Void, Never>?
    
    /// Flag to track if monitoring is active
    private var isActive: Bool = false
    
    // MARK: - Initialization
    
    init() {
        // Initialize with minimum amplitude values
        self.amplitudes = Array(repeating: minimumAmplitude, count: barCount)
        print("[AudioAmplitudeMonitor] Initialized with \(barCount) bars")
    }
    
    // MARK: - Public Methods

    /// Start monitoring (without consuming a stream)
    func start() {
        print("[AudioAmplitudeMonitor] ⚡ Starting amplitude monitoring (isActive = true)")
        isActive = true
    }

    /// Start monitoring audio frames
    func start(frames: AsyncStream<AudioFrame>) {
        print("[AudioAmplitudeMonitor] Starting amplitude monitoring with frame stream")

        // Cancel any existing task
        stop()

        isActive = true

        // Process frames asynchronously
        processingTask = Task { [weak self] in
            guard let self = self else { return }

            var frameCount = 0
            for await frame in frames {
                guard !Task.isCancelled else {
                    print("[AudioAmplitudeMonitor] Processing task cancelled")
                    break
                }

                frameCount += 1
                self.processFrame(frame)

                // Log every 50 frames to avoid spam
                if frameCount % 50 == 0 {
                    print("[AudioAmplitudeMonitor] Processed \(frameCount) frames")
                }
            }

            print("[AudioAmplitudeMonitor] Frame processing ended after \(frameCount) frames")
        }
    }
    
    /// Process a single audio frame
    func process(_ frame: AudioFrame) async {
        guard isActive else {
            print("[AudioAmplitudeMonitor] ⚠️ WARNING: process() called but isActive=false - ignoring frame!")
            return
        }
        processFrame(frame)
    }
    
    /// Stop monitoring and reset amplitudes
    func stop() {
        print("[AudioAmplitudeMonitor] Stopping amplitude monitoring")
        
        isActive = false
        processingTask?.cancel()
        processingTask = nil
        
        // Reset to minimum amplitude values
        amplitudes = Array(repeating: minimumAmplitude, count: barCount)
    }
    
    // MARK: - Private Methods
    
    /// Process a single audio frame and update amplitudes
    private func processFrame(_ frame: AudioFrame) {
        let samples = frame.samples
        guard !samples.isEmpty else {
            print("[AudioAmplitudeMonitor] ⚠️ Received empty frame")
            return
        }

        // Compute RMS (root mean square) amplitude
        let sumOfSquares = samples.reduce(0.0) { $0 + ($1 * $1) }
        let rms = sqrt(sumOfSquares / Float(samples.count))

        // Normalize to 0.0-1.0 range (typical speech is around 0.1-0.3 RMS)
        // Scale by factor of 5 to make the visualization more visible
        let normalizedAmplitude = min(rms * 5.0, 1.0)

        // Apply minimum threshold
        let finalAmplitude = max(normalizedAmplitude, minimumAmplitude)

        // Update the amplitudes array with smoothing
        updateAmplitudes(with: finalAmplitude)
    }
    
    /// Frame counter for debug logging
    private var frameProcessedCount = 0

    /// Update amplitude values with smoothing
    private func updateAmplitudes(with newValue: Float) {
        // Shift existing values to the left (oldest value drops off)
        if amplitudes.count >= barCount {
            amplitudes.removeFirst()
        }

        // Apply smoothing to the new value based on the previous value
        let smoothedValue: Float
        if let lastValue = amplitudes.last {
            // Exponential moving average for smooth transitions
            smoothedValue = (smoothingFactor * lastValue) + ((1.0 - smoothingFactor) * newValue)
        } else {
            smoothedValue = newValue
        }

        // Append the new smoothed value
        amplitudes.append(smoothedValue)

        // Ensure we maintain the correct bar count
        while amplitudes.count > barCount {
            amplitudes.removeFirst()
        }

        // Pad with minimum amplitude if needed
        while amplitudes.count < barCount {
            amplitudes.append(minimumAmplitude)
        }

        // Debug logging every 50 frames
        frameProcessedCount += 1
        if frameProcessedCount % 50 == 0 {
            print("[AudioAmplitudeMonitor] 🎵 Updated amplitudes (frame #\(frameProcessedCount)): newValue=\(String(format: "%.4f", newValue)), smoothed=\(String(format: "%.4f", smoothedValue)), array=\(amplitudes.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
        }
    }
    
    deinit {
        print("[AudioAmplitudeMonitor] Deinitialized")
        processingTask?.cancel()
    }
}

