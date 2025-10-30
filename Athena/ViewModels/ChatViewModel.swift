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
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let conversationService = ConversationService.shared
    private let configManager = ConfigurationManager.shared

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
    
    func sendMessage() async {
        guard canSendMessage else { return }

        let messageContent = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        isLoading = true
        errorMessage = nil

        do {
            // Get current provider and model
            let provider = AIProvider(rawValue: configManager.selectedProvider) ?? .openai
            let model = configManager.selectedModel
            let temperature = configManager.temperature

            // Send message (response is processed but not displayed)
            _ = try await conversationService.sendMessage(
                messageContent,
                provider: provider,
                model: model,
                temperature: temperature,
                streaming: false
            )

            // Note: AI response is logged in database but not displayed to user

        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            print("Error sending message: \(error)")
        }

        isLoading = false
    }


    func clearError() {
        errorMessage = nil
    }
}

