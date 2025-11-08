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
//        print("[SpeechService] Initializing SpeechService")

        // Check initial authorization status
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        self.isAuthorized = (authorizationStatus == .authorized)
        self.microphonePermission = currentMicrophonePermission()

//        print("[SpeechService] Initial status - Speech auth: \(authorizationStatus), Microphone: \(microphonePermission), Combined authorized: \(isAuthorized && hasMicrophonePermission)")

        if isAuthorized && hasMicrophonePermission {
            print("[SpeechService] Both permissions granted, initializing pipeline")
            initializePipeline()
        } else {
            print("[SpeechService] Permissions not granted - Speech: \(isAuthorized), Mic: \(hasMicrophonePermission)")
        }
    }

    // MARK: - Public Methods

    /// Request authorization for speech recognition
    func requestAuthorization() async {
        print("[SpeechService] Requesting speech recognition authorization...")

        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        authorizationStatus = status
        isAuthorized = (status == .authorized)

//        print("[SpeechService] Speech authorization result: \(status), isAuthorized: \(isAuthorized)")

        // Initialize pipeline if authorized
        if isAuthorized && hasMicrophonePermission {
            print("[SpeechService] Both permissions now granted after speech auth, initializing pipeline")
            initializePipeline()
        } else {
            print("[SpeechService] Clearing pipeline - Speech auth: \(isAuthorized), Mic permission: \(hasMicrophonePermission)")
            pipeline = nil
        }
    }

    /// Request permission to use the microphone
    func requestMicrophonePermission() async {
//        print("[SpeechService] Requesting microphone permission...")

        if hasMicrophonePermission {
            print("[SpeechService] Microphone permission already granted")
            return
        }

        #if os(macOS)
        let currentPermission = AVAudioApplication.shared.recordPermission
        print("[SpeechService] macOS - Current mic permission before request: \(currentPermission)")

        if currentPermission == .undetermined {
            print("[SpeechService] Requesting microphone permission via AVAudioApplication...")
            // Request permission - this is a class method that returns a Bool indicating if granted
            let granted = await AVAudioApplication.requestRecordPermission()
            print("[SpeechService] AVAudioApplication.requestRecordPermission() returned: \(granted)")
        }

        let finalPermission = AVAudioApplication.shared.recordPermission
        microphonePermission = mapAudioApplicationPermission(finalPermission)
        print("[SpeechService] Final macOS mic permission: \(finalPermission) -> mapped to: \(microphonePermission)")
        #else
        let session = AVAudioSession.sharedInstance()
        print("[SpeechService] iOS - Current mic permission before request: \(session.recordPermission)")

        if session.recordPermission == .undetermined {
            print("[SpeechService] Requesting microphone permission via AVAudioSession...")
            await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    print("[SpeechService] AVAudioSession.requestRecordPermission callback with granted: \(granted)")
                    continuation.resume()
                }
            }
        }

        let finalPermission = session.recordPermission
        microphonePermission = mapMicrophonePermission(finalPermission)
        print("[SpeechService] Final iOS mic permission: \(finalPermission) -> mapped to: \(microphonePermission)")
        #endif

        if isAuthorized && hasMicrophonePermission {
            print("[SpeechService] Both permissions now granted after mic auth, initializing pipeline")
            initializePipeline()
        } else {
            print("[SpeechService] Pipeline not initialized - Speech auth: \(isAuthorized), Mic permission: \(hasMicrophonePermission)")
        }
    }

    /// Initialize or reinitialize the speech pipeline
    func initializePipeline() {
//        print("[SpeechService] initializePipeline called")

        guard hasMicrophonePermission else {
            print("[SpeechService] initializePipeline: No microphone permission, clearing pipeline")
            pipeline = nil
            return
        }

//        print("[SpeechService] initializePipeline: Microphone permission granted, creating pipeline")

        do {
            let localeIdentifier = configManager.getString(.speechRecognitionLanguage)
            let locale = Locale(identifier: localeIdentifier)
//            print("[SpeechService] initializePipeline: Creating pipeline with locale: \(localeIdentifier)")

            pipeline = try SpeechPipeline.makeDefault(locale: locale)
//            print("[SpeechService] initializePipeline: Successfully created pipeline with configured locale")
        } catch {
            // Fallback to system default locale if the configured one is unavailable
            print("[SpeechService] initializePipeline: Failed to create speech pipeline for configured locale: \(error.localizedDescription). Falling back to system locale.")
            do {
                print("[SpeechService] initializePipeline: Attempting fallback with system locale")
                pipeline = try SpeechPipeline.makeDefault(locale: .current)
                print("[SpeechService] initializePipeline: Successfully created pipeline with system locale")
            } catch {
                pipeline = nil
                print("[SpeechService] initializePipeline: Failed to create speech pipeline with system locale: \(error.localizedDescription)")
            }
        }

        print("[SpeechService] initializePipeline: Pipeline creation complete, pipeline is \(pipeline == nil ? "nil" : "not nil")")
    }

    /// Start listening for speech
    func startListening() async {
//        print("[SpeechService] startListening called")

        if !hasMicrophonePermission {
//            print("[SpeechService] startListening: Requesting microphone permission")
            await requestMicrophonePermission()
        } else {
//            print("[SpeechService] startListening: Microphone permission already granted")
        }

        if !isAuthorized {
//            print("[SpeechService] startListening: Requesting speech authorization")
            await requestAuthorization()
        } else {
//            print("[SpeechService] startListening: Speech authorization already granted")
        }

        guard isAuthorized && hasMicrophonePermission else {
//            print("[SpeechService] startListening: Guard failed - Speech auth: \(isAuthorized), Mic permission: \(hasMicrophonePermission)")
            return
        }

//        print("[SpeechService] startListening: Both permissions granted")

        if pipeline == nil {
//            print("[SpeechService] startListening: Pipeline is nil, initializing...")
            initializePipeline()
        } else {
//            print("[SpeechService] startListening: Pipeline already exists")
        }

        guard let pipeline else {
//            print("[SpeechService] startListening: Pipeline is still nil after initialization, aborting")
            return
        }

//        print("[SpeechService] startListening: Calling pipeline.startListening()")
        await pipeline.startListening()
//        print("[SpeechService] startListening: pipeline.startListening() completed")
    }

    /// Stop listening and wait for final transcript
    func stopListening() async {
//        print("[SpeechService] stopListening called")
        await pipeline?.stopListening()
//        print("[SpeechService] stopListening completed")
    }

    /// Cancel listening immediately
    func cancelListening() {
//        print("[SpeechService] cancelListening called")
        pipeline?.cancelListening()
//        print("[SpeechService] cancelListening completed")
    }

    /// Check if currently listening or finishing
    var isActive: Bool {
        let active = pipeline?.state.isActive ?? false
//        print("[SpeechService] isActive queried: \(active)")
        return active
    }

    /// Reset the service (e.g., after errors)
    func reset() {
//        print("[SpeechService] reset called")
        pipeline?.cancelListening()
        pipeline = nil
//        print("[SpeechService] reset: Pipeline cleared")

        if isAuthorized {
//            print("[SpeechService] reset: Reinitializing pipeline since authorized")
            initializePipeline()
        } else {
//            print("[SpeechService] reset: Not reinitializing pipeline - not authorized")
        }
//        print("[SpeechService] reset completed")
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
        let permission = AVAudioApplication.shared.recordPermission
        let mapped = mapAudioApplicationPermission(permission)
//        print("[SpeechService] currentMicrophonePermission (macOS): \(permission) -> \(mapped)")
        return mapped
        #else
        let permission = AVAudioSession.sharedInstance().recordPermission
        let mapped = mapMicrophonePermission(permission)
//        print("[SpeechService] currentMicrophonePermission (iOS): \(permission) -> \(mapped)")
        return mapped
        #endif
    }

    #if !os(macOS)
    private func mapMicrophonePermission(_ permission: AVAudioSession.recordPermission) -> MicrophonePermissionStatus {
//        print("[SpeechService] mapMicrophonePermission (iOS): mapping \(permission)")
        switch permission {
        case .undetermined:
            return .undetermined
        case .denied:
            return .denied
        case .granted:
            return .granted
        @unknown default:
            print("[SpeechService] mapMicrophonePermission (iOS): unknown permission value: \(permission)")
            return .undetermined
        }
    }
    #endif

    #if os(macOS)
    private func mapAudioApplicationPermission(_ permission: AVAudioApplication.recordPermission) -> MicrophonePermissionStatus {
        print("[SpeechService] mapAudioApplicationPermission (macOS): mapping \(permission)")
        if permission == .granted {
            print("[SpeechService] mapAudioApplicationPermission (macOS): mapped to granted")
            return .granted
        } else if permission == .denied {
            print("[SpeechService] mapAudioApplicationPermission (macOS): mapped to denied")
            return .denied
        } else {
            print("[SpeechService] mapAudioApplicationPermission (macOS): mapped to undetermined (value: \(permission))")
            return .undetermined
        }
    }
    #endif
}
