//
//  AudioAmplitudeMonitor.swift
//  Athena
//
//  Monitors audio amplitude for real-time waveform visualization using FFT
//

import Foundation
import Combine
import Accelerate

/// Monitors audio frames and computes frequency-based amplitude levels for visualization
/// This is a LIVE AUDIO VISUALIZER that shows current frequency spectrum (like an equalizer)
/// NOT a time-based history waveform
@MainActor
final class AudioAmplitudeMonitor: ObservableObject {
    // MARK: - Published Properties

    /// Array of amplitude values for each frequency band (normalized 0.0 to 1.0)
    /// Each element represents a different frequency band, ALL updated simultaneously
    @Published private(set) var amplitudes: [Float] = []

    // MARK: - Private Properties

    /// Number of frequency bands to display
    private let bandCount: Int = 30

    /// FFT size (must be power of 2)
    private let fftSize: Int = 512

    /// FFT setup object
    private let log2n: vDSP_Length
    private var fftSetup: FFTSetup?

    /// Sample accumulation buffer
    private var sampleBuffer: [Float] = []

    /// Hann window for FFT
    private var window: [Float]

    /// FFT buffers
    private var realBuffer: [Float]
    private var imagBuffer: [Float]

    /// Previous band magnitudes for smoothing
    private var previousBands: [Float]

    /// Smoothing factor (0.0 = no smoothing, 1.0 = maximum smoothing)
    private let smoothingFactor: Float = 0.6

    /// Minimum bar height (as fraction of max) for visual consistency
    private let minimumAmplitude: Float = 0.05

    /// Task for processing audio frames
    private var processingTask: Task<Void, Never>?

    /// Flag to track if monitoring is active
    private var isActive: Bool = false

    /// Frame counter for debug logging
    private var frameProcessedCount = 0

    // MARK: - Initialization

    init() {
        // Setup FFT
        let log2n = vDSP_Length(log2(Float(fftSize)))
        self.log2n = log2n
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Initialize buffers
        self.window = [Float](repeating: 0, count: fftSize)
        self.realBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.imagBuffer = [Float](repeating: 0, count: fftSize / 2)

        // Create Hann window to reduce spectral leakage
        vDSP_hann_window(&self.window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Initialize frequency bands
        self.amplitudes = Array(repeating: minimumAmplitude, count: bandCount)
        self.previousBands = Array(repeating: minimumAmplitude, count: bandCount)

        print("[AudioAmplitudeMonitor] Initialized with \(bandCount) frequency bands, FFT size \(fftSize)")
    }

    // MARK: - Public Methods

    /// Start monitoring (without consuming a stream)
    func start() {
        print("[AudioAmplitudeMonitor] ⚡ Starting frequency monitoring (isActive = true)")
        isActive = true
    }

    /// Start monitoring audio frames
    func start(frames: AsyncStream<AudioFrame>) {
        print("[AudioAmplitudeMonitor] Starting frequency monitoring with frame stream")

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
        print("[AudioAmplitudeMonitor] Stopping frequency monitoring")

        isActive = false
        processingTask?.cancel()
        processingTask = nil

        // Reset to minimum amplitude values
        amplitudes = Array(repeating: minimumAmplitude, count: bandCount)
        previousBands = Array(repeating: minimumAmplitude, count: bandCount)
        sampleBuffer.removeAll()
    }

    // MARK: - Private Methods

    /// Process a single audio frame and update frequency bands
    private func processFrame(_ frame: AudioFrame) {
        let samples = frame.samples
        guard !samples.isEmpty else {
            print("[AudioAmplitudeMonitor] ⚠️ Received empty frame")
            return
        }

        // Accumulate samples
        sampleBuffer.append(contentsOf: samples)

        // When we have enough samples, perform FFT analysis
        if sampleBuffer.count >= fftSize {
            // Take exactly fftSize samples
            let samples = Array(sampleBuffer.prefix(fftSize))

            // Perform FFT and get frequency bands
            if let frequencyBands = performFFTAnalysis(samples: samples) {
                updateFrequencyBands(with: frequencyBands)
            }

            // Remove processed samples (with 50% overlap for smoother updates)
            let removeCount = min(fftSize / 2, sampleBuffer.count)
            sampleBuffer.removeFirst(removeCount)
        }
    }

    /// Perform FFT analysis on audio samples and return frequency band magnitudes
    private func performFFTAnalysis(samples: [Float]) -> [Float]? {
        guard let fftSetup = fftSetup, samples.count == fftSize else { return nil }

        // Apply Hann window to reduce spectral leakage
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Convert to split complex format (separate real and imaginary parts)
        var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)

        // Pack real input into split complex format
        windowedSamples.withUnsafeBytes { ptr in
            let complexPtr = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(complexPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
        }

        // Perform forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitudes (sqrt(real^2 + imag^2))
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Convert to frequency bands (logarithmic distribution)
        return extractFrequencyBands(from: magnitudes)
    }

    /// Extract frequency bands from FFT magnitudes using logarithmic distribution
    private func extractFrequencyBands(from magnitudes: [Float]) -> [Float] {
        var bands = [Float](repeating: 0, count: bandCount)

        // Use logarithmic distribution for frequency bands (like audio equalizer)
        // Lower frequencies get fewer FFT bins, higher frequencies get more
        let binCount = magnitudes.count

        for bandIndex in 0..<bandCount {
            // Logarithmic mapping
            let minBin = Int(pow(Float(binCount), Float(bandIndex) / Float(bandCount)))
            let maxBin = Int(pow(Float(binCount), Float(bandIndex + 1) / Float(bandCount)))

            // Average magnitudes in this band
            if maxBin > minBin && maxBin <= binCount {
                let bandSlice = magnitudes[minBin..<min(maxBin, binCount)]
                let average = bandSlice.reduce(0, +) / Float(bandSlice.count)
                bands[bandIndex] = average
            }
        }

        // Normalize to 0.0-1.0 range
        if let maxMagnitude = bands.max(), maxMagnitude > 0 {
            bands = bands.map { min($0 / maxMagnitude, 1.0) }
        }

        // Apply minimum amplitude threshold
        bands = bands.map { max($0, minimumAmplitude) }

        return bands
    }

    /// Update all frequency bands simultaneously (NOT scrolling)
    private func updateFrequencyBands(with newBands: [Float]) {
        guard newBands.count == bandCount else { return }

        // Apply smoothing by blending with previous values
        var smoothedBands = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            smoothedBands[i] = (smoothingFactor * previousBands[i]) + ((1.0 - smoothingFactor) * newBands[i])
        }

        // Update all bands at once (this is the key difference from time-based scrolling)
        amplitudes = smoothedBands
        previousBands = smoothedBands

        // Debug logging every 50 frames
        frameProcessedCount += 1
        if frameProcessedCount % 50 == 0 {
            print("[AudioAmplitudeMonitor] 🎵 Updated frequency bands (frame #\(frameProcessedCount)): \(amplitudes.prefix(5).map { String(format: "%.2f", $0) }.joined(separator: ", "))...")
        }
    }

    deinit {
        print("[AudioAmplitudeMonitor] Deinitialized")
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
        processingTask?.cancel()
    }
}
