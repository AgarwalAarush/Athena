//
//  SpeechService.swift
//  Athena
//
//  Main service for speech recognition functionality.
//

import Foundation
import Combine
import Speech
import AVFoundation

/// Main service for managing speech recognition
@MainActor
final class SpeechService: ObservableObject {
    // MARK: - Singleton

    static let shared = SpeechService()

    // MARK: - Published Properties

    /// The speech pipeline managing audio and transcription
    @Published private(set) var pipeline: SpeechPipeline?

    /// Whether speech recognition is authorized
    @Published private(set) var isAuthorized: Bool = false

    /// Current authorization status
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    /// Current microphone permission status
    @Published private(set) var microphonePermission: MicrophonePermissionStatus = .undetermined

    // MARK: - Initialization

    private let configManager = ConfigurationManager.shared

    private init() {
        // Check initial authorization status
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        self.isAuthorized = (authorizationStatus == .authorized)
        self.microphonePermission = currentMicrophonePermission()

        if isAuthorized && hasMicrophonePermission {
            initializePipeline()
        }
    }

    // MARK: - Public Methods

    /// Request authorization for speech recognition
    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        authorizationStatus = status
        isAuthorized = (status == .authorized)

        // Initialize pipeline if authorized
        if isAuthorized && hasMicrophonePermission {
            initializePipeline()
        } else {
            pipeline = nil
        }
    }

    /// Request permission to use the microphone
    func requestMicrophonePermission() async {
        if hasMicrophonePermission {
            return
        }

        #if os(macOS)
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { _ in
                    continuation.resume()
                }
            }
        }
        microphonePermission = mapCapturePermission(AVCaptureDevice.authorizationStatus(for: .audio))
        #else
        let session = AVAudioSession.sharedInstance()
        if session.recordPermission == .undetermined {
            await withCheckedContinuation { continuation in
                session.requestRecordPermission { _ in
                    continuation.resume()
                }
            }
        }
        microphonePermission = mapMicrophonePermission(session.recordPermission)
        #endif

        if isAuthorized && hasMicrophonePermission {
            initializePipeline()
        }
    }

    /// Initialize or reinitialize the speech pipeline
    func initializePipeline() {
        guard hasMicrophonePermission else {
            pipeline = nil
            return
        }

        do {
            let localeIdentifier = configManager.getString(.speechRecognitionLanguage)
            let locale = Locale(identifier: localeIdentifier)
            pipeline = try SpeechPipeline.makeDefault(locale: locale)
        } catch {
            // Fallback to system default locale if the configured one is unavailable
            print("Failed to create speech pipeline for configured locale: \(error.localizedDescription). Falling back to system locale.")
            do {
                pipeline = try SpeechPipeline.makeDefault(locale: .current)
            } catch {
                pipeline = nil
                print("Failed to create speech pipeline with system locale: \(error.localizedDescription)")
            }
        }
    }

    /// Start listening for speech
    func startListening() async {
        if !hasMicrophonePermission {
            await requestMicrophonePermission()
        }

        if !isAuthorized {
            await requestAuthorization()
        }

        guard isAuthorized && hasMicrophonePermission else { return }

        if pipeline == nil {
            initializePipeline()
        }

        guard let pipeline else { return }
        await pipeline.startListening()
    }

    /// Stop listening and wait for final transcript
    func stopListening() async {
        await pipeline?.stopListening()
    }

    /// Cancel listening immediately
    func cancelListening() {
        pipeline?.cancelListening()
    }
    
    /// Check if currently listening or finishing
    var isActive: Bool {
        pipeline?.state.isActive ?? false
    }

    /// Reset the service (e.g., after errors)
    func reset() {
        pipeline?.cancelListening()
        pipeline = nil
        if isAuthorized {
            initializePipeline()
        }
    }
}

// MARK: - Authorization Helpers

extension SpeechService {
    /// Whether we can request authorization
    var canRequestAuthorization: Bool {
        return authorizationStatus == .notDetermined
    }

    /// Whether microphone permission has been granted
    var hasMicrophonePermission: Bool {
        microphonePermission == .granted
    }

    /// Combined authorization status description for UI feedback
    var authorizationStatusDescription: String {
        if !isAuthorized {
            switch authorizationStatus {
            case .notDetermined:
                return "Speech recognition permission not requested"
            case .denied:
                return "Speech recognition permission denied. Please enable in System Preferences."
            case .restricted:
                return "Speech recognition is restricted on this device"
            case .authorized:
                break
            @unknown default:
                return "Unknown authorization status"
            }
        }

        if !hasMicrophonePermission {
            switch microphonePermission {
            case .undetermined:
                return "Microphone permission not requested"
            case .denied:
                return "Microphone permission denied. Please enable in System Preferences."
            case .granted:
                break
            }
        }

        return "Speech recognition authorized"
    }
}

// MARK: - Microphone Permission Helpers

extension SpeechService {
    enum MicrophonePermissionStatus {
        case undetermined
        case denied
        case granted
    }

    private func currentMicrophonePermission() -> MicrophonePermissionStatus {
        #if os(macOS)
        return mapCapturePermission(AVCaptureDevice.authorizationStatus(for: .audio))
        #else
        return mapMicrophonePermission(AVAudioSession.sharedInstance().recordPermission)
        #endif
    }

    private func mapMicrophonePermission(_ permission: AVAudioSession.RecordPermission) -> MicrophonePermissionStatus {
        switch permission {
        case .undetermined:
            return .undetermined
        case .denied:
            return .denied
        case .granted:
            return .granted
        @unknown default:
            return .undetermined
        }
    }

    #if os(macOS)
    private func mapCapturePermission(_ status: AVAuthorizationStatus) -> MicrophonePermissionStatus {
        switch status {
        case .notDetermined:
            return .undetermined
        case .restricted, .denied:
            return .denied
        case .authorized, .limited:
            return .granted
        @unknown default:
            return .undetermined
        }
    }
    #endif
}
