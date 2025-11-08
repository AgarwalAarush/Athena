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
    
    /// Returns the active amplitude monitor for waveform visualization
    var amplitudeMonitor: AudioAmplitudeMonitor? {
        if wakewordModeEnabled, let manager = wakeWordManager {
            return manager.amplitudeMonitor
        } else if let pipeline = speechService.pipeline {
            return pipeline.amplitudeMonitor
        }
        return nil
    }

    private let appViewModel: AppViewModel
    private weak var notesViewModel: NotesViewModel?

    init(appViewModel: AppViewModel, notesViewModel: NotesViewModel? = nil) {
        self.appViewModel = appViewModel
        self.notesViewModel = notesViewModel

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

                // Capture the OLD value before updating
                let wasInWakewordMode = self.wakewordModeEnabled
                print("[ChatViewModel] 🔄 Wakeword mode config changed: \(wasInWakewordMode) -> \(newValue)")

                // Handle transition based on OLD and NEW states
                if wasInWakewordMode && !newValue {
                    print("[ChatViewModel] ❌ Switching FROM wakeword mode to manual mode")

                    // Explicitly stop wake word manager BEFORE updating flag
                    if let manager = self.wakeWordManager {
                        print("[ChatViewModel] 🛑 Explicitly stopping wake word manager")
                        manager.stop()
                    }

                    // Reset wake word subscriptions so they reactivate cleanly on the next enable
                    self.rebindWakeWordManagerSubscriptions()

                    // CRITICAL: Explicitly reset recording state when leaving wakeword mode
                    self.isRecording = false
                    self.isProcessingTranscript = false
                    print("[ChatViewModel] 🔴 Explicitly reset isRecording=false, isProcessingTranscript=false")

                    // Now update the flag
                    self.wakewordModeEnabled = newValue

                } else if !wasInWakewordMode && newValue {
                    print("[ChatViewModel] ✅ Switching TO wakeword mode from manual mode")

                    // Stop any manual mode listening first
                    print("[ChatViewModel] 🛑 Stopping manual mode speech service")
                    self.speechService.cancelListening()

                    // Update the flag
                    self.wakewordModeEnabled = newValue

                    // Start wakeword mode
                    self.startVoiceInput()

                } else {
                    // No actual mode change (e.g., both true or both false)
                    // Just update the flag
                    print("[ChatViewModel] ⚠️ No mode change detected: \(wasInWakewordMode) -> \(newValue)")
                    self.wakewordModeEnabled = newValue
                }
            }
            .store(in: &cancellables)

        // Initialize wake word manager
        let manager = WakeWordTranscriptionManager()
        self.wakeWordManager = manager
        
        // Set wake word manager reference in AppViewModel for pause/resume
        appViewModel.setWakeWordManager(manager)

        rebindWakeWordManagerSubscriptions()

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
            // Initialize Orchestrator with AppViewModel
            let orchestrator = Orchestrator(appViewModel: appViewModel)
            try await orchestrator.route(prompt: messageContent, context: appViewModel.currentView)

        } catch {
            errorMessage = "Failed to process message: \(error.localizedDescription)"
            print("Error processing message: \(error)")
        }

        isLoading = false
    }

    func startVoiceInput() {
        print("[ChatViewModel] 🎬 startVoiceInput called - wakewordModeEnabled=\(wakewordModeEnabled)")

        Task {
            errorMessage = nil

            // Use wake word manager when in wakeword mode
            if wakewordModeEnabled, let manager = wakeWordManager {
                print("[ChatViewModel] 🎤 Starting WAKE WORD mode")
                do {
                    try await manager.start()
                    print("[ChatViewModel] ✅ Wake word mode started successfully")
                } catch {
                    errorMessage = "Failed to start wake word detection: \(error.localizedDescription)"
                    print("[ChatViewModel] ❌ Wake word start error: \(error)")
                }
            } else {
                print("[ChatViewModel] 🎤 Starting MANUAL mode (regular speech service)")
                // Use regular speech service
                await speechService.startListening()
                if !speechService.isAuthorized || !speechService.hasMicrophonePermission {
                    errorMessage = speechService.authorizationStatusDescription
                    print("[ChatViewModel] ❌ Speech service authorization failed")
                } else {
                    print("[ChatViewModel] ✅ Manual mode started successfully")
                }
            }
        }
    }

    func stopVoiceInput() {
        print("[ChatViewModel] 🛑 stopVoiceInput called - wakewordModeEnabled=\(wakewordModeEnabled), isRecording=\(isRecording)")

        Task {
            // Stop wake word manager if in wakeword mode
            if wakewordModeEnabled, let manager = wakeWordManager {
                print("[ChatViewModel] 🛑 Stopping WAKE WORD mode")
                manager.stop()
                print("[ChatViewModel] ✅ Wake word mode stopped")
            } else {
                print("[ChatViewModel] 🛑 Stopping MANUAL mode")
                // Use regular speech service
                // If pipeline is in listening state, stop gracefully
                // Otherwise, cancel immediately
                if let pipeline = speechService.pipeline, pipeline.state == .listening {
                    print("[ChatViewModel] 🛑 Pipeline in listening state - stopping gracefully")
                    await speechService.stopListening()
                } else {
                    print("[ChatViewModel] 🛑 Pipeline not listening - canceling")
                    speechService.cancelListening()
                }
                print("[ChatViewModel] ✅ Manual mode stopped")
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func rebindWakeWordManagerSubscriptions() {
        wakeWordCancellables.removeAll()

        guard let manager = wakeWordManager else {
            print("[ChatViewModel] ⚠️ Wake word manager not available - subscriptions cleared")
            return
        }

        // Subscribe to wake word manager state updates
        manager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }

                guard self.wakewordModeEnabled else {
                    print("[ChatViewModel] ⚠️ Wake word state update ignored - not in wakeword mode (state=\(state))")
                    return
                }

                let newRecordingState = (state == .transcribing || state == .listeningForWakeWord)
                print("[ChatViewModel] 🎙️ Wake word state changed: \(state) -> isRecording=\(newRecordingState)")
                self.isRecording = newRecordingState
            }
            .store(in: &wakeWordCancellables)

        // Subscribe to partial transcripts only while wakeword mode is active
        manager.$partialTranscript
            .receive(on: RunLoop.main)
            .sink { [weak self] transcript in
                guard let self = self else { return }
                guard self.wakewordModeEnabled else { return }

                if !transcript.isEmpty {
                    self.inputText = transcript
                }
            }
            .store(in: &wakeWordCancellables)

        // Subscribe to final transcripts only while wakeword mode is active
        manager.$finalTranscript
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] transcript in
                guard let self = self else { return }
                guard self.wakewordModeEnabled else { return }
                self.handleFinalTranscript(transcript)
            }
            .store(in: &wakeWordCancellables)
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

        // Validate transcript is not empty before processing
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            print("[ChatViewModel] handleFinalTranscript: Ignoring empty transcript")
            return
        }
        
        // Check for "Athena listen" command for notes dictation
        if checkForListenCommand(in: trimmedTranscript) {
            print("[ChatViewModel] 🎤 'Athena listen' detected!")
            
            // Check if we're in notes view with editor open
            if appViewModel.currentView == .notes,
               let notesVM = notesViewModel,
               notesVM.showingEditor {
                print("[ChatViewModel] ✅ In notes editor - starting listen mode")
                notesVM.startListenMode()
                return // Don't process as chat command
            } else {
                print("[ChatViewModel] ⚠️ 'listen' command detected but not in notes editor")
                // Fall through to normal processing
            }
        }

        // ALWAYS populate the input field with the transcription
        print("[ChatViewModel] handleFinalTranscript: Setting inputText to transcript")
        inputText = transcript
        print("[ChatViewModel] handleFinalTranscript: inputText is now: '\(inputText)'")

        // Get current view to determine routing behavior
        let currentView = appViewModel.currentView
        print("[ChatViewModel] handleFinalTranscript: Current view is \(currentView)")

        // HOME/CALENDAR/NOTES VIEWS: Always auto-send to orchestrator (bypass config)
        if currentView == .home || currentView == .calendar || currentView == .notes {
            print("[ChatViewModel] handleFinalTranscript: In home/calendar/notes view - auto-sending to orchestrator")
            Task {
                do {
                    let orchestrator = Orchestrator(appViewModel: appViewModel)
                    try await orchestrator.route(prompt: transcript, context: currentView)
                    print("[ChatViewModel] handleFinalTranscript: Successfully routed to orchestrator with context \(currentView)")
                } catch {
                    print("[ChatViewModel] handleFinalTranscript: Error routing to orchestrator: \(error)")
                    errorMessage = "Failed to process command: \(error.localizedDescription)"
                }

                // Note: WakeWordTranscriptionManager handles state transitions automatically via VAD
                // No need to restart listening manually
            }
            return
        }

        // CHAT VIEW: Use existing config-based behavior
        print("[ChatViewModel] handleFinalTranscript: In chat view - using config-based behavior")
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
            await self.sendMessage()

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
    
    // MARK: - Listen Command Detection
    
    /// Check if transcript starts with "listen" (fuzzy match)
    private func checkForListenCommand(in transcript: String) -> Bool {
        let words = transcript.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        // Need at least one word
        guard let firstWord = words.first else { return false }
        
        // Fuzzy match on "listen" with 70% threshold
        let isMatch = FuzzyStringMatcher.fuzzyMatch(firstWord, target: "listen", threshold: 0.7)
        
        if isMatch {
            print("[ChatViewModel] 🎯 Listen command matched! First word: '\(firstWord)'")
        }
        
        return isMatch
    }
}
