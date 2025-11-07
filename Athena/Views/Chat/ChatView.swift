//
//  ChatView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var conversationService = ConversationService.shared

    var body: some View {
        ZStack {
            if conversationService.currentConversation == nil {
                EmptyConversationView()
            } else {
                VStack(spacing: 0) {
                    Spacer()

                    // Error Banner
                    if let error = viewModel.errorMessage {
                        ErrorBannerView(message: error) {
                            viewModel.clearError()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    // Input Area
                    MessageInputView(
                        text: $viewModel.inputText,
                        isLoading: viewModel.isLoading,
                        canSend: viewModel.canSendMessage,
                        onSend: {
                            Task {
                                await viewModel.sendMessage()
                            }
                        },
                        isRecording: viewModel.isRecording,
                        isProcessingTranscript: viewModel.isProcessingTranscript,
                        onStartVoiceInput: {
                            viewModel.startVoiceInput()
                        },
                        onStopVoiceInput: {
                            viewModel.stopVoiceInput()
                        },
                        wakewordModeEnabled: viewModel.wakewordModeEnabled,
                        amplitudeMonitor: viewModel.amplitudeMonitor
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct EmptyConversationView: View {
    @ObservedObject var config = ConfigurationManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundColor(.primary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Welcome to Athena")
                    .font(.apercu(size: 24))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if !config.hasAPIKey(for: config.selectedProvider) {
                    Text("Configure your API keys in Settings to get started")
                        .font(.apercu)
                        .foregroundColor(.primary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    Text("Type your query below")
                        .font(.apercu)
                        .foregroundColor(.primary.opacity(0.6))
                }
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
    ChatView(viewModel: ChatViewModel(appViewModel: AppViewModel()))
        .frame(width: 470, height: 640)
}
