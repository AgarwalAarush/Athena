//
//  MessageBubbleView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    @ObservedObject var config = ConfigurationManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isFromUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // Message Content
                Text(message.content)
                    .textSelection(.enabled)
                    .font(.apercu)
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isFromUser ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    )
                
                // Timestamp
                if config.getBool(.showTimestamps) {
                    Text(formatTimestamp(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            
            if message.isFromAssistant {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(message: Message(
            conversationId: 1,
            role: .user,
            content: "Hello! How are you?"
        ))
        
        MessageBubbleView(message: Message(
            conversationId: 1,
            role: .assistant,
            content: "I'm doing well, thank you! I'm Athena, your AI assistant. How can I help you today?"
        ))
    }
    .padding()
    .frame(width: 470)
}

