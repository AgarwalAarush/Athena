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

    // MARK: - Initialization

    init() {
        print("[EngineAudioInput] Initialized with sampleRate: \(sampleRate), channelCount: \(channelCount)")
    }

    /// AsyncStream of audio frames
    var frames: AsyncStream<AudioFrame> {
        if let framesStream = framesStream {
            print("[EngineAudioInput] frames: Returning existing stream")
            return framesStream
        }

        print("[EngineAudioInput] frames: Creating new AsyncStream")
        let stream = AsyncStream<AudioFrame> { [weak self] continuation in
            guard let self = self else {
                print("[EngineAudioInput] frames: AsyncStream continuation - self is nil, finishing")
                continuation.finish()
                return
            }
            print("[EngineAudioInput] frames: AsyncStream continuation - storing continuation")
            self.framesContinuation = continuation
        }

        self.framesStream = stream
        print("[EngineAudioInput] frames: New AsyncStream created and stored")
        return stream
    }

    // MARK: - AudioInput Protocol

    func start() async throws {
        print("[EngineAudioInput] start() called")

        // Create audio engine lazily on first use
        // This avoids XPC initialization errors during early app launch
        if engine == nil {
            print("[EngineAudioInput] Creating new AVAudioEngine")
            engine = AVAudioEngine()
        }

        guard let engine = engine else {
            print("[EngineAudioInput] Failed to create AVAudioEngine")
            throw AudioInputError.engineCreationFailed
        }

        guard !engine.isRunning else {
            print("[EngineAudioInput] Engine is already running, returning")
            return
        }

        print("[EngineAudioInput] Engine created successfully, activating audio session")

        // Ensure the system audio session is configured and active before installing taps
        do {
            try activateAudioSessionIfNeeded()
            print("[EngineAudioInput] Audio session activated successfully")
        } catch {
            print("[EngineAudioInput] Audio session activation failed: \(error.localizedDescription)")
            throw AudioInputError.sessionConfigurationFailed(error.localizedDescription)
        }

        // Ensure a fresh stream exists for this run
        print("[EngineAudioInput] Ensuring fresh audio frame stream")
        _ = frames

        // Create target output format: 16kHz, mono, Float32
        print("[EngineAudioInput] Creating target output format: \(sampleRate)Hz, \(channelCount) channels")
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            print("[EngineAudioInput] Failed to create target output format")
            throw AudioInputError.formatCreationFailed
        }
        self.outputFormat = targetFormat
        print("[EngineAudioInput] Target format created successfully")

        let inputNode = engine.inputNode
        print("[EngineAudioInput] Got input node from engine")

        // Buffer size for tap (1024 samples at input rate)
        let bufferSize: AVAudioFrameCount = 1024
        print("[EngineAudioInput] Installing tap on input node with buffer size: \(bufferSize)")

        // Install tap to receive audio buffers
        // IMPORTANT: Use format: nil to let the engine use the hardware's native format
        // This avoids "kAudioUnitErr_InvalidElement" errors when querying format too early
        // The actual format will be available in the buffer parameter of the callback
        do {
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, time in
                guard let self = self else {
                    print("[EngineAudioInput] Tap callback: self is nil")
                    return
                }
                self.processAudioBuffer(buffer, time: time)
            }
            isTapInstalled = true
            print("[EngineAudioInput] Tap installed successfully")

            // Prepare the engine to allocate resources
            print("[EngineAudioInput] Preparing engine")
            engine.prepare()
            print("[EngineAudioInput] Engine prepared successfully")

            // Start the engine
            print("[EngineAudioInput] Starting engine")
            try engine.start()
            print("[EngineAudioInput] Engine started successfully")
        } catch {
            print("[EngineAudioInput] Failed to start engine: \(error.localizedDescription)")

            // Clean up on failure
            if isTapInstalled {
                print("[EngineAudioInput] Removing tap due to failure")
                inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            deactivateAudioSessionIfNeeded()
            throw error
        }
    }

    func stop() {
        print("[EngineAudioInput] stop() called")

        guard let engine = engine else {
            print("[EngineAudioInput] stop(): No engine exists, just cleaning up state")
            // Engine was never created, just clean up state
            framesContinuation?.finish()
            framesContinuation = nil
            framesStream = nil
            return
        }

        print("[EngineAudioInput] stop(): Engine exists, stopping components")

        // Stop the engine if running
        if engine.isRunning {
            print("[EngineAudioInput] stop(): Stopping running engine")
            engine.stop()
        } else {
            print("[EngineAudioInput] stop(): Engine was not running")
        }

        // Remove tap if installed
        if isTapInstalled {
            print("[EngineAudioInput] stop(): Removing tap from input node")
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        } else {
            print("[EngineAudioInput] stop(): No tap was installed")
        }

        // Reset the engine to clean up internal state
        // This ensures a fresh start for the next recording session
        print("[EngineAudioInput] stop(): Resetting engine")
        engine.reset()

        // Deactivate audio session after stopping
        print("[EngineAudioInput] stop(): Deactivating audio session")
        deactivateAudioSessionIfNeeded()

        // Clean up stream and converter
        print("[EngineAudioInput] stop(): Cleaning up stream and converter")
        framesContinuation?.finish()
        framesContinuation = nil
        framesStream = nil
        converter = nil
        outputFormat = nil
        lastInputFormat = nil

        print("[EngineAudioInput] stop(): Stop completed")
    }

    // MARK: - Private Methods

    private func activateAudioSessionIfNeeded() throws {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        print("[EngineAudioInput] activateAudioSessionIfNeeded: Checking macOS microphone permission")
        // On macOS, verify microphone permission before accessing audio hardware
        // This prevents kAudioUnitErr_InvalidElement (-10877) errors when trying to
        // access inputNode without proper authorization
        let permission = AVAudioApplication.shared.recordPermission
        print("[EngineAudioInput] activateAudioSessionIfNeeded: Current permission status: \(permission)")

        guard permission == .granted else {
            let errorMessage: String
            if permission == .denied {
                errorMessage = "Microphone access denied. Please grant permission in System Preferences > Security & Privacy > Microphone."
            } else {
                errorMessage = "Microphone permission not requested. Please request microphone access first."
            }
            print("[EngineAudioInput] activateAudioSessionIfNeeded: Permission check failed: \(errorMessage)")
            throw AudioInputError.microphonePermissionDenied(errorMessage)
        }
        print("[EngineAudioInput] activateAudioSessionIfNeeded: Microphone permission granted")
        return
        #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || targetEnvironment(macCatalyst)
        print("[EngineAudioInput] activateAudioSessionIfNeeded: Configuring iOS audio session")
        let session = AVAudioSession.sharedInstance()

        if !audioSessionConfigured {
            print("[EngineAudioInput] activateAudioSessionIfNeeded: Setting audio session category to record")
            try session.setCategory(.record, mode: .measurement, options: [])
            print("[EngineAudioInput] activateAudioSessionIfNeeded: Setting preferred sample rate to \(sampleRate)")
            try session.setPreferredSampleRate(sampleRate)
            audioSessionConfigured = true
            print("[EngineAudioInput] activateAudioSessionIfNeeded: Audio session configured")
        }

        if !isAudioSessionActive {
            print("[EngineAudioInput] activateAudioSessionIfNeeded: Activating audio session")
            try session.setActive(true)
            isAudioSessionActive = true
            print("[EngineAudioInput] activateAudioSessionIfNeeded: Audio session activated")
        }
        #endif
    }

    private func deactivateAudioSessionIfNeeded() {
        guard isAudioSessionActive else { return }

        #if os(macOS) && !targetEnvironment(macCatalyst)
        // No audio session to deactivate on macOS
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
        guard let framesContinuation = framesContinuation else {
            print("[EngineAudioInput] processAudioBuffer: ERROR - No frames continuation, skipping")
            return
        }
        guard let outputFormat = outputFormat else {
            print("[EngineAudioInput] processAudioBuffer: ERROR - No output format, skipping")
            return
        }

        // Get the actual hardware format from the buffer
        let inputFormat = buffer.format

        // Create or recreate converter if input format changed
        // This handles the case where hardware format is not available until runtime
        if converter == nil || lastInputFormat != inputFormat {
            guard let newConverter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                // If converter creation fails, log and skip this buffer
                print("[EngineAudioInput] processAudioBuffer: ERROR - Failed to create audio converter from \(inputFormat) to \(outputFormat)")
                return
            }
            self.converter = newConverter
            self.lastInputFormat = inputFormat
        }

        guard let converter = converter else {
            print("[EngineAudioInput] processAudioBuffer: ERROR - No converter available, skipping")
            return
        }

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
            print("[EngineAudioInput] processAudioBuffer: ERROR - Failed to create output buffer")
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
            print("[EngineAudioInput] processAudioBuffer: ERROR - Audio conversion error: \(error!.localizedDescription)")
            return
        }

        // Extract Float32 samples
        guard let channelData = convertedBuffer.floatChannelData else {
            print("[EngineAudioInput] processAudioBuffer: ERROR - No channel data in converted buffer")
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
        print("[EngineAudioInput] deinit called")
        stop()
    }
}

// MARK: - Errors

enum AudioInputError: LocalizedError {
    case engineCreationFailed
    case formatCreationFailed
    case converterCreationFailed
    case sessionConfigurationFailed(String)
    case microphonePermissionDenied(String)

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
        case .microphonePermissionDenied(let message):
            return message
        }
    }
}
