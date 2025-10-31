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

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var framesContinuation: AsyncStream<AudioFrame>.Continuation?
    private var framesStream: AsyncStream<AudioFrame>?
    private var isTapInstalled = false

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
        guard !engine.isRunning else {
            return
        }

        // Request microphone permission if not already granted
        let micPermission = await requestMicrophonePermission()
        guard micPermission else {
            throw AudioInputError.microphonePermissionDenied
        }

        // Note: On macOS, AVAudioEngine doesn't require explicit audio session configuration
        // The system handles audio routing automatically. AVAudioSession is iOS-only.

        // Ensure a fresh stream exists for this run
        _ = frames

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create output format: 16kHz, mono, Float32
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw AudioInputError.formatCreationFailed
        }

        // Create converter from input format to our target format
        guard let audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioInputError.converterCreationFailed
        }
        self.converter = audioConverter

        // Buffer size for tap (1024 samples at input rate)
        let bufferSize: AVAudioFrameCount = 1024

        // Install tap to receive audio buffers
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            self.processAudioBuffer(buffer, time: time, converter: audioConverter, outputFormat: outputFormat)
        }
        isTapInstalled = true

        // Start the engine
        try engine.start()
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
        }

        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        // Note: On macOS, no need to deactivate audio session (AVAudioSession is iOS-only)

        framesContinuation?.finish()
        framesContinuation = nil
        framesStream = nil
        converter = nil
    }

    // MARK: - Permission Handling

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Private Methods

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        time: AVAudioTime,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) {
        guard let framesContinuation = framesContinuation else { return }

        // Calculate output buffer capacity
        let inputFrameCount = buffer.frameLength
        let outputCapacity = AVAudioFrameCount(
            Double(inputFrameCount) * outputFormat.sampleRate / buffer.format.sampleRate
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
    case formatCreationFailed
    case converterCreationFailed
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return "Failed to create audio format for recording"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .microphonePermissionDenied:
            return "Microphone permission denied. Please grant permission in System Settings."
        }
    }
}
