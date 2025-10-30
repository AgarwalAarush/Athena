//
//  ConversationListViewModel.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import Combine

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var filteredConversations: [Conversation] = []
    @Published var showingNewConversationSheet = false
    @Published var selectedConversation: Conversation?
    
    private let conversationService = ConversationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var hasConversations: Bool {
        !conversationService.conversations.isEmpty
    }
    
    init() {
        // Observe conversation service changes
        conversationService.$conversations
            .combineLatest($searchText)
            .map { conversations, searchText in
                if searchText.isEmpty {
                    return conversations
                } else {
                    return conversations.filter { conversation in
                        conversation.title.localizedCaseInsensitiveContains(searchText)
                    }
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.filteredConversations, on: self)
            .store(in: &cancellables)
        
        conversationService.$currentConversation
            .receive(on: DispatchQueue.main)
            .assign(to: \.selectedConversation, on: self)
            .store(in: &cancellables)
    }
    
    func selectConversation(_ conversation: Conversation) {
        conversationService.selectConversation(conversation)
    }
    
    func createNewConversation() {
        do {
            let conversation = try conversationService.createConversation(title: "New Conversation")
            conversationService.selectConversation(conversation)
        } catch {
            print("Failed to create conversation: \(error)")
        }
    }
    
    func deleteConversation(_ conversation: Conversation) {
        do {
            try conversationService.deleteConversation(conversation)
        } catch {
            print("Failed to delete conversation: \(error)")
        }
    }
    
    func archiveConversation(_ conversation: Conversation) {
        do {
            try conversationService.archiveConversation(conversation)
        } catch {
            print("Failed to archive conversation: \(error)")
        }
    }
    
    func renameConversation(_ conversation: Conversation, newTitle: String) {
        do {
            try conversationService.updateConversationTitle(conversation, title: newTitle)
        } catch {
            print("Failed to rename conversation: \(error)")
        }
    }
}

