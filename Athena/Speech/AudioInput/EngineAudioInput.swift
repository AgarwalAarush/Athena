//
//  EngineAudioInput.swift
//  Athena
//
//  Audio input implementation using AVAudioEngine for macOS.
//

import Foundation
import AVFoundation

/// Audio input implementation using AVAudioEngine to capture microphone audio
final class EngineAudioInput: AudioInput {
    // MARK: - Properties

    // Lazy initialization: Create AVAudioEngine only when needed (when start() is called)
    // This avoids XPC connection errors during early app launch when Core Audio services
    // may not be fully initialized yet
    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var lastInputFormat: AVAudioFormat?
    private var framesContinuation: AsyncStream<AudioFrame>.Continuation?
    private var framesStream: AsyncStream<AudioFrame>?
    private var isTapInstalled = false
    private var audioSessionConfigured = false
    private var isAudioSessionActive = false

    /// Target sample rate for output audio (16kHz is standard for speech recognition)
    let sampleRate: Double = 16000.0

    /// Number of channels (mono for speech recognition)
    private let channelCount: AVAudioChannelCount = 1

    /// AsyncStream of audio frames
    var frames: AsyncStream<AudioFrame> {
        if let framesStream = framesStream {
            return framesStream
        }

        let stream = AsyncStream<AudioFrame> { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }
            self.framesContinuation = continuation
        }

        self.framesStream = stream
        return stream
    }

    // MARK: - AudioInput Protocol

    func start() async throws {
        // Create audio engine lazily on first use
        // This avoids XPC initialization errors during early app launch
        if engine == nil {
            engine = AVAudioEngine()
        }

        guard let engine = engine else {
            throw AudioInputError.engineCreationFailed
        }

        guard !engine.isRunning else {
            return
        }

        // Ensure the system audio session is configured and active before installing taps
        do {
            try activateAudioSessionIfNeeded()
        } catch {
            throw AudioInputError.sessionConfigurationFailed(error.localizedDescription)
        }

        // Ensure a fresh stream exists for this run
        _ = frames

        // Create target output format: 16kHz, mono, Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw AudioInputError.formatCreationFailed
        }
        self.outputFormat = targetFormat

        let inputNode = engine.inputNode

        // Buffer size for tap (1024 samples at input rate)
        let bufferSize: AVAudioFrameCount = 1024

        // Install tap to receive audio buffers
        // IMPORTANT: Use format: nil to let the engine use the hardware's native format
        // This avoids "kAudioUnitErr_InvalidElement" errors when querying format too early
        // The actual format will be available in the buffer parameter of the callback
        do {
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, time in
                guard let self = self else { return }
                self.processAudioBuffer(buffer, time: time)
            }
            isTapInstalled = true

            // Prepare the engine to allocate resources
            engine.prepare()

            // Start the engine
            try engine.start()
        } catch {
            // Clean up on failure
            if isTapInstalled {
                inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            deactivateAudioSessionIfNeeded()
            throw error
        }
    }

    func stop() {
        guard let engine = engine else {
            // Engine was never created, just clean up state
            framesContinuation?.finish()
            framesContinuation = nil
            framesStream = nil
            return
        }

        // Stop the engine if running
        if engine.isRunning {
            engine.stop()
        }

        // Remove tap if installed
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        // Reset the engine to clean up internal state
        // This ensures a fresh start for the next recording session
        engine.reset()

        // Deactivate audio session after stopping
        deactivateAudioSessionIfNeeded()

        // Clean up stream and converter
        framesContinuation?.finish()
        framesContinuation = nil
        framesStream = nil
        converter = nil
        outputFormat = nil
        lastInputFormat = nil
    }

    // MARK: - Private Methods

    private func activateAudioSessionIfNeeded() throws {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        return
        #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()

        if !audioSessionConfigured {
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setPreferredSampleRate(sampleRate)
            audioSessionConfigured = true
        }

        if !isAudioSessionActive {
            try session.setActive(true)
            isAudioSessionActive = true
        }
        #endif
    }

    private func deactivateAudioSessionIfNeeded() {
        guard isAudioSessionActive else { return }

        #if os(macOS) && !targetEnvironment(macCatalyst)
        return
        #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        #endif

        isAudioSessionActive = false
    }

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        time: AVAudioTime
    ) {
        guard let framesContinuation = framesContinuation else { return }
        guard let outputFormat = outputFormat else { return }

        // Get the actual hardware format from the buffer
        let inputFormat = buffer.format

        // Create or recreate converter if input format changed
        // This handles the case where hardware format is not available until runtime
        if converter == nil || lastInputFormat != inputFormat {
            guard let newConverter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                // If converter creation fails, log and skip this buffer
                print("Failed to create audio converter from \(inputFormat) to \(outputFormat)")
                return
            }
            self.converter = newConverter
            self.lastInputFormat = inputFormat
        }

        guard let converter = converter else { return }

        // Calculate output buffer capacity
        let inputFrameCount = buffer.frameLength
        let outputCapacity = AVAudioFrameCount(
            Double(inputFrameCount) * outputFormat.sampleRate / inputFormat.sampleRate
        )

        // Create output buffer
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputCapacity
        ) else {
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        // Convert the audio
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if error != nil {
            print("Audio conversion error: \(error!.localizedDescription)")
            return
        }

        // Extract Float32 samples
        guard let channelData = convertedBuffer.floatChannelData else {
            return
        }

        let frameCount = Int(convertedBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        // Create and yield audio frame
        let audioFrame = AudioFrame(
            samples: samples,
            sampleRate: outputFormat.sampleRate,
            timestamp: time
        )

        framesContinuation.yield(audioFrame)
    }

    deinit {
        stop()
    }
}

// MARK: - Errors

enum AudioInputError: LocalizedError {
    case engineCreationFailed
    case formatCreationFailed
    case converterCreationFailed
    case sessionConfigurationFailed(String)

    var errorDescription: String? {
        switch self {
        case .engineCreationFailed:
            return "Failed to create audio engine"
        case .formatCreationFailed:
            return "Failed to create audio format for recording"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .sessionConfigurationFailed(let message):
            return "Failed to configure audio session: \(message)"
        }
    }
}
