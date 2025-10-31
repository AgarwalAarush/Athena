//
//  SpeechService.swift
//  Athena
//
//  Main service for speech recognition functionality.
//

import Foundation
import Combine
import Speech

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

    // MARK: - Initialization

    private let configManager = ConfigurationManager.shared

    private init() {
        // Check initial authorization status
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        self.isAuthorized = (authorizationStatus == .authorized)

        if isAuthorized {
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
        if isAuthorized {
            initializePipeline()
        } else {
            pipeline = nil
        }
    }

    /// Initialize or reinitialize the speech pipeline
    func initializePipeline() {
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
        if !isAuthorized {
            await requestAuthorization()
        }

        guard isAuthorized else { return }

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
    /// User-friendly description of authorization status
    var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Speech recognition permission not requested"
        case .denied:
            return "Speech recognition permission denied. Please enable in System Preferences."
        case .restricted:
            return "Speech recognition is restricted on this device"
        case .authorized:
            return "Speech recognition authorized"
        @unknown default:
            return "Unknown authorization status"
        }
    }

    /// Whether we can request authorization
    var canRequestAuthorization: Bool {
        return authorizationStatus == .notDetermined
    }
}
