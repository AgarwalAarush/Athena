//
//  ChatViewModel.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var streamingMessage: String = ""
    @Published var isStreaming: Bool = false
    
    private let conversationService = ConversationService.shared
    private let configManager = ConfigurationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    var currentConversation: Conversation? {
        conversationService.currentConversation
    }
    
    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading &&
        !isStreaming &&
        currentConversation != nil &&
        hasValidAPIKey
    }
    
    var hasValidAPIKey: Bool {
        let provider = configManager.selectedProvider
        return configManager.hasAPIKey(for: provider)
    }
    
    init() {
        // Observe conversation service changes
        conversationService.$currentMessages
            .receive(on: DispatchQueue.main)
            .assign(to: \.messages, on: self)
            .store(in: &cancellables)
    }
    
    func sendMessage() async {
        guard canSendMessage else { return }
        
        let messageContent = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        isLoading = true
        isStreaming = true
        streamingMessage = ""
        errorMessage = nil
        
        do {
            // Get current provider and model
            let provider = AIProvider(rawValue: configManager.selectedProvider) ?? .openai
            let model = configManager.selectedModel
            let temperature = configManager.temperature
            
            // Send message with streaming
            let response = try await conversationService.sendMessage(
                messageContent,
                provider: provider,
                model: model,
                temperature: temperature,
                streaming: true
            )
            
            streamingMessage = response
            
            // Reload messages
            if let conversationId = currentConversation?.id {
                conversationService.loadMessages(for: conversationId)
            }
            
            // Generate title if this is the first exchange
            await conversationService.generateConversationTitle()
            
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            print("Error sending message: \(error)")
        }
        
        isLoading = false
        isStreaming = false
        streamingMessage = ""
    }
    
    func deleteMessage(_ message: Message) {
        do {
            try conversationService.deleteMessage(message)
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
        }
    }
    
    func copyMessage(_ message: Message) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }
    
    func retryLastMessage() async {
        // Find the last user message
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else {
            return
        }
        
        inputText = lastUserMessage.content
        await sendMessage()
    }
    
    func clearError() {
        errorMessage = nil
    }
}

