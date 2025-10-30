//
//  ConversationListView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showingSidebar = true
    
    var body: some View {
        HSplitView {
            // Sidebar
            if showingSidebar {
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $viewModel.searchText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Conversation List
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.filteredConversations) { conversation in
                                ConversationRowView(
                                    conversation: conversation,
                                    isSelected: viewModel.selectedConversation?.id == conversation.id,
                                    onSelect: {
                                        viewModel.selectConversation(conversation)
                                    },
                                    onDelete: {
                                        viewModel.deleteConversation(conversation)
                                    },
                                    onRename: { newTitle in
                                        viewModel.renameConversation(conversation, newTitle: newTitle)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                    
                    // New Conversation Button
                    Button(action: { viewModel.createNewConversation() }) {
                        Label("New Conversation", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
                .background(Color(NSColor.controlBackgroundColor))
            }
            
            // Main Content
            ChatView()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField("Search conversations...", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    ConversationListView()
        .frame(width: 700, height: 640)
}

