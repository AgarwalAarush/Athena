//
//  ConversationRowView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    
    @State private var isHovered = false
    @State private var showingRenameAlert = false
    @State private var newTitle = ""
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 20)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .accentColor : .primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(formatDate(conversation.updatedAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if conversation.messageCount > 0 {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("\(conversation.messageCount) messages")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Rename") {
                newTitle = conversation.title
                showingRenameAlert = true
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .alert("Rename Conversation", isPresented: $showingRenameAlert) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onRename(newTitle)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    VStack(spacing: 4) {
        ConversationRowView(
            conversation: Conversation(title: "Quick question about Swift", messageCount: 5),
            isSelected: true,
            onSelect: {},
            onDelete: {},
            onRename: { _ in }
        )
        
        ConversationRowView(
            conversation: Conversation(title: "Help with debugging", messageCount: 12),
            isSelected: false,
            onSelect: {},
            onDelete: {},
            onRename: { _ in }
        )
        
        ConversationRowView(
            conversation: Conversation(title: "Project planning discussion", messageCount: 3),
            isSelected: false,
            onSelect: {},
            onDelete: {},
            onRename: { _ in }
        )
    }
    .padding()
    .frame(width: 250)
}

