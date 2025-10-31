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

    private let conversationService = ConversationService.shared
    private let configManager = ConfigurationManager.shared
    private let speechService = SpeechService.shared
    private var cancellables = Set<AnyCancellable>()
    private var pipelineCancellables = Set<AnyCancellable>()
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

                switch state {
                case .idle:
                    self.isRecording = false
                    self.restoreInputAfterVoiceSession()
                case .listening:
                    self.errorMessage = nil
                    self.isRecording = true
                    self.preserveInputForVoiceSessionIfNeeded()
                case .finishing:
                    self.isRecording = true
                case .error(let message):
                    self.isRecording = false
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
        // Use the same logic as sendMessage but with voice transcript
        let messageContent = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageContent.isEmpty, currentConversation != nil, hasValidAPIKey else {
            return
        }

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

            _ = try await conversationService.sendMessage(
                messageContent,
                provider: provider,
                model: model,
                streaming: false
            )
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            print("Error sending voice message: \(error)")
        }

        isLoading = false
    }

    func startVoiceInput() {
        Task {
            errorMessage = nil
            await speechService.startListening()
            if !speechService.isAuthorized || !speechService.hasMicrophonePermission {
                errorMessage = speechService.authorizationStatusDescription
            }
        }
    }

    func stopVoiceInput() {
        Task {
            // If pipeline is in listening state, stop gracefully
            // Otherwise, cancel immediately
            if let pipeline = speechService.pipeline, pipeline.state == .listening {
                await speechService.stopListening()
            } else {
                speechService.cancelListening()
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
        if inputText != "" {
            inputText = ""
        }
    }

    private func restoreInputAfterVoiceSession() {
        guard let preserved = preservedInputText else { return }
        inputText = preserved
        preservedInputText = nil
    }

    private func handleFinalTranscript(_ transcript: String) {
        // ALWAYS populate the input field with the transcription
        inputText = transcript

        // Conditionally auto-send to AI based on config/debug setting
        // When shouldAutoSendVoiceTranscript is false, the transcript stays in the input field
        // for manual review/editing before sending
        guard shouldAutoSendVoiceTranscript else { return }

        Task {
            await self.sendVoiceTranscript(transcript)
        }
    }
}
