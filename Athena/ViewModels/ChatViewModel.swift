//
//  ChatViewModel.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine
import AppKit

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - DEBUG: Voice Transcription Behavior
    // 🔧 DEBUGGING FLAG: Set this to override config settings during development
    // - nil: Use config setting (default behavior)
    // - true: Always auto-send transcription to AI
    // - false: Only populate input field (don't auto-send)
    // Location of config setting: ConfigurationKeys.swift line 45 (.autoSendVoiceTranscription)
    private let DEBUG_OVERRIDE_AUTO_SEND: Bool? = false  // 🔧 DEBUG: Only populate input field

    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isRecording: Bool = false
    @Published var isProcessingTranscript: Bool = false
    @Published var wakewordModeEnabled: Bool = false

    private let conversationService = ConversationService.shared
    private let configManager = ConfigurationManager.shared
    private let speechService = SpeechService.shared
    private var wakeWordManager: WakeWordTranscriptionManager?
    private var cancellables = Set<AnyCancellable>()
    private var pipelineCancellables = Set<AnyCancellable>()
    private var wakeWordCancellables = Set<AnyCancellable>()
    private var preservedInputText: String?

    var currentConversation: Conversation? {
        conversationService.currentConversation
    }

    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading &&
        currentConversation != nil &&
        hasValidAPIKey
    }

    var hasValidAPIKey: Bool {
        let provider = configManager.selectedProvider
        return configManager.hasAPIKey(for: provider)
    }

    init() {
        subscribeToPipeline(speechService.pipeline)

        speechService.$pipeline
            .receive(on: RunLoop.main)
            .sink { [weak self] pipeline in
                self?.subscribeToPipeline(pipeline)
            }
            .store(in: &cancellables)

        // Subscribe to wakeword mode configuration changes
        wakewordModeEnabled = configManager.wakewordModeEnabled

        configManager.$wakewordModeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] (newValue: Bool) in
                guard let self = self else { return }
                self.wakewordModeEnabled = newValue

                if newValue {
                    // Start listening when wakeword mode is enabled
                    self.startVoiceInput()
                } else {
                    // Stop listening when wakeword mode is disabled
                    self.stopVoiceInput()
                }
            }
            .store(in: &cancellables)

        // Initialize wake word manager
        let manager = WakeWordTranscriptionManager()
        self.wakeWordManager = manager

        // Subscribe to wake word manager state
        manager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                // Map wake word states to isRecording
                self.isRecording = (state == .transcribing || state == .listeningForWakeWord)
            }
            .store(in: &wakeWordCancellables)

        // Subscribe to wake word manager partial transcripts
        manager.$partialTranscript
            .receive(on: RunLoop.main)
            .sink { [weak self] transcript in
                guard let self = self else { return }
                if !transcript.isEmpty {
                    self.inputText = transcript
                }
            }
            .store(in: &wakeWordCancellables)

        // Subscribe to wake word manager final transcripts
        manager.$finalTranscript
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] transcript in
                self?.handleFinalTranscript(transcript)
            }
            .store(in: &wakeWordCancellables)

        // Auto-start listening if wakeword mode is enabled
        if wakewordModeEnabled {
            Task {
                // Small delay to ensure everything is initialized
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                self.startVoiceInput()
            }
        }
    }

    private func subscribeToPipeline(_ pipeline: SpeechPipeline?) {
        pipelineCancellables.removeAll()

        guard let pipeline = pipeline else {
            isRecording = false
            return
        }

        pipeline.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }

                print("[ChatViewModel] Pipeline state changed to: \(state)")

                switch state {
                case .idle:
                    print("[ChatViewModel] State: idle - Setting isRecording=false, isProcessingTranscript=false")
                    self.isRecording = false
                    self.isProcessingTranscript = false
                    self.restoreInputAfterVoiceSession()
                    print("[ChatViewModel] State: idle - Final values: isRecording=\(self.isRecording), isProcessingTranscript=\(self.isProcessingTranscript)")
                case .listening:
                    print("[ChatViewModel] State: listening - Setting isRecording=true, isProcessingTranscript=false")
                    self.errorMessage = nil
                    self.isRecording = true
                    self.isProcessingTranscript = false
                    self.preserveInputForVoiceSessionIfNeeded()
                case .finishing:
                    print("[ChatViewModel] State: finishing - Setting isRecording=false, isProcessingTranscript=true")
                    self.isRecording = false  // Stop showing red recording state
                    self.isProcessingTranscript = true  // Show processing state
                case .error(let message):
                    print("[ChatViewModel] State: error - Setting isRecording=false, isProcessingTranscript=false")
                    self.isRecording = false
                    self.isProcessingTranscript = false
                    self.errorMessage = "Speech recognition error: \(message)"
                    self.restoreInputAfterVoiceSession()
                }
            }
            .store(in: &pipelineCancellables)

        pipeline.$partialTranscript
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] partial in
                guard let self = self else { return }
                self.inputText = partial
            }
            .store(in: &pipelineCancellables)

        pipeline.$finalTranscript
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] transcript in
                self?.handleFinalTranscript(transcript)
            }
            .store(in: &pipelineCancellables)
    }

    func sendMessage() async {
        guard canSendMessage else { return }

        let messageContent = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        isLoading = true
        errorMessage = nil

        do {
            // Get current provider and validate API key
            let provider = AIProvider(rawValue: configManager.selectedProvider) ?? .openai
            
            // Ensure API key exists for the provider
            guard configManager.hasAPIKey(for: provider.rawValue) else {
                errorMessage = "No API key configured for \(provider.displayName). Please configure in Settings."
                isLoading = false
                return
            }
            
            // Get model, fallback to provider default if invalid
            let selectedModel = configManager.selectedModel
            let model = provider.availableModels.contains(where: { $0.id == selectedModel }) 
                ? selectedModel 
                : provider.defaultModel

            // Send message (response is processed but not displayed)
            _ = try await conversationService.sendMessage(
                messageContent,
                provider: provider,
                model: model,
                streaming: false
            )

            // Note: AI response is logged in database but not displayed to user

        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            print("Error sending message: \(error)")
        }

        isLoading = false
    }

    private func sendVoiceTranscript(_ transcript: String) async {
        print("[ChatViewModel] sendVoiceTranscript: Starting to send transcript to chat: '\(transcript)'")

        // Use the same logic as sendMessage but with voice transcript
        let messageContent = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[ChatViewModel] sendVoiceTranscript: Trimmed message content: '\(messageContent)'")

        guard !messageContent.isEmpty, currentConversation != nil, hasValidAPIKey else {
            print("[ChatViewModel] sendVoiceTranscript: Guard failed - Empty: \(messageContent.isEmpty), HasConversation: \(currentConversation != nil), HasAPIKey: \(hasValidAPIKey)")
            return
        }

        print("[ChatViewModel] sendVoiceTranscript: All guards passed, starting message send")
        isLoading = true
        errorMessage = nil

        do {
            // Get current provider and validate API key
            let provider = AIProvider(rawValue: configManager.selectedProvider) ?? .openai
            print("[ChatViewModel] sendVoiceTranscript: Using provider: \(provider.displayName)")

            // Ensure API key exists for the provider
            guard configManager.hasAPIKey(for: provider.rawValue) else {
                let errorMsg = "No API key configured for \(provider.displayName). Please configure in Settings."
                errorMessage = errorMsg
                isLoading = false
                print("[ChatViewModel] sendVoiceTranscript: ERROR - \(errorMsg)")
                return
            }

            // Get model, fallback to provider default if invalid
            let selectedModel = configManager.selectedModel
            let model = provider.availableModels.contains(where: { $0.id == selectedModel })
                ? selectedModel
                : provider.defaultModel

            print("[ChatViewModel] sendVoiceTranscript: Sending message with model: \(model)")

            _ = try await conversationService.sendMessage(
                messageContent,
                provider: provider,
                model: model,
                streaming: false
            )

            print("[ChatViewModel] sendVoiceTranscript: SUCCESS - Message sent to chat")
        } catch {
            let errorMsg = "Failed to send message: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("[ChatViewModel] sendVoiceTranscript: ERROR - \(errorMsg)")
            print("Error sending voice message: \(error)")
        }

        isLoading = false
        print("[ChatViewModel] sendVoiceTranscript: Completed, isLoading = false")
    }

    func startVoiceInput() {
        Task {
            errorMessage = nil

            // Use wake word manager when in wakeword mode
            if wakewordModeEnabled, let manager = wakeWordManager {
                do {
                    try await manager.start()
                    print("[ChatViewModel] Wake word mode started")
                } catch {
                    errorMessage = "Failed to start wake word detection: \(error.localizedDescription)"
                    print("[ChatViewModel] Wake word start error: \(error)")
                }
            } else {
                // Use regular speech service
                await speechService.startListening()
                if !speechService.isAuthorized || !speechService.hasMicrophonePermission {
                    errorMessage = speechService.authorizationStatusDescription
                }
            }
        }
    }

    func stopVoiceInput() {
        Task {
            // Stop wake word manager if in wakeword mode
            if wakewordModeEnabled, let manager = wakeWordManager {
                manager.stop()
                print("[ChatViewModel] Wake word mode stopped")
            } else {
                // Use regular speech service
                // If pipeline is in listening state, stop gracefully
                // Otherwise, cancel immediately
                if let pipeline = speechService.pipeline, pipeline.state == .listening {
                    await speechService.stopListening()
                } else {
                    speechService.cancelListening()
                }
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private var shouldAutoSendVoiceTranscript: Bool {
        // Allow debug override for testing
        DEBUG_OVERRIDE_AUTO_SEND ?? configManager.autoSendVoiceTranscription
    }

    private func preserveInputForVoiceSessionIfNeeded() {
        if preservedInputText == nil {
            preservedInputText = inputText
        }
        // Don't clear inputText - keep existing text visible during recording
        // Partial transcripts will temporarily replace it, and it will be restored if cancelled
    }

    private func restoreInputAfterVoiceSession() {
        // Don't restore preserved text if we have a final transcript
        if speechService.pipeline?.finalTranscript != nil {
            print("[ChatViewModel] restoreInputAfterVoiceSession: Not restoring preserved text because final transcript exists")
            preservedInputText = nil  // Clear it so it doesn't interfere later
            return
        }

        guard let preserved = preservedInputText else { return }
        print("[ChatViewModel] restoreInputAfterVoiceSession: Restoring preserved text: '\(preserved)'")
        inputText = preserved
        preservedInputText = nil
    }

    private func handleFinalTranscript(_ transcript: String) {
        print("[ChatViewModel] handleFinalTranscript: RECEIVED FINAL TRANSCRIPT: '\(transcript)'")

        // ALWAYS populate the input field with the transcription
        print("[ChatViewModel] handleFinalTranscript: Setting inputText to transcript")
        inputText = transcript
        print("[ChatViewModel] handleFinalTranscript: inputText is now: '\(inputText)'")

        // Conditionally auto-send to AI based on config/debug setting
        // When shouldAutoSendVoiceTranscript is false, the transcript stays in the input field
        // for manual review/editing before sending
        print("[ChatViewModel] handleFinalTranscript: shouldAutoSendVoiceTranscript = \(shouldAutoSendVoiceTranscript)")
        guard shouldAutoSendVoiceTranscript else {
            print("[ChatViewModel] handleFinalTranscript: NOT auto-sending - transcript stays in input field for manual editing")

            // Note: In wake word mode with WakeWordTranscriptionManager,
            // the manager handles state transitions automatically via VAD.
            // We only restart manually if using the regular speech service.
            if wakewordModeEnabled && wakeWordManager == nil {
                print("[ChatViewModel] handleFinalTranscript: Wakeword mode enabled - restarting listening")
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    self.startVoiceInput()
                }
            }
            return
        }

        print("[ChatViewModel] handleFinalTranscript: Auto-sending transcript to chat")
        Task {
            await self.sendVoiceTranscript(transcript)

            // Note: In wake word mode with WakeWordTranscriptionManager,
            // the manager handles state transitions automatically via VAD.
            // We only restart manually if using the regular speech service.
            if self.wakewordModeEnabled && self.wakeWordManager == nil {
                print("[ChatViewModel] handleFinalTranscript: Wakeword mode enabled - restarting listening after send")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                self.startVoiceInput()
            }
        }
    }
}
