//
//  ChatView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject var conversationService = ConversationService.shared
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            if conversationService.currentConversation == nil {
                EmptyConversationView()
            } else {
                // Messages Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                                    .contextMenu {
                                        Button("Copy") {
                                            viewModel.copyMessage(message)
                                        }
                                        
                                        if message.role == .user {
                                            Button("Delete") {
                                                viewModel.deleteMessage(message)
                                            }
                                        }
                                    }
                            }
                            
                            // Streaming message indicator
                            if viewModel.isStreaming && !viewModel.streamingMessage.isEmpty {
                                StreamingMessageView(content: viewModel.streamingMessage)
                                    .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        scrollToBottom()
                    }
                    .onChange(of: viewModel.streamingMessage) { _ in
                        scrollToBottom()
                    }
                }
                
                Divider()
                
                // Error Banner
                if let error = viewModel.errorMessage {
                    ErrorBannerView(message: error) {
                        viewModel.clearError()
                    }
                }
                
                // Input Area
                MessageInputView(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    canSend: viewModel.canSendMessage
                ) {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            }
        }
    }
    
    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                if viewModel.isStreaming {
                    scrollProxy?.scrollTo("streaming", anchor: .bottom)
                } else if let lastMessage = viewModel.messages.last {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

struct EmptyConversationView: View {
    @ObservedObject var conversationService = ConversationService.shared
    @ObservedObject var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Welcome to Athena")
                    .font(.title)
                    .fontWeight(.semibold)
                
                if !config.hasAPIKey(for: config.selectedProvider) {
                    Text("Configure your API keys in Settings to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    Text("Start a new conversation to begin")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            if config.hasAPIKey(for: config.selectedProvider) {
                Button(action: {
                    do {
                        let conversation = try conversationService.createConversation()
                        conversationService.selectConversation(conversation)
                    } catch {
                        print("Failed to create conversation: \(error)")
                    }
                }) {
                    Label("New Conversation", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
    }
}

#Preview {
    ChatView()
        .frame(width: 470, height: 640)
}

