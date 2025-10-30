//
//  MessageInputView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let canSend: Bool
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var textHeight: CGFloat = 36
    
    private let maxHeight: CGFloat = 120
    private let minHeight: CGFloat = 36
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                // Text Input
                ZStack(alignment: .topLeading) {
                    // Invisible Text to calculate height
                    Text(text.isEmpty ? " " : text)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        textHeight = min(max(geometry.size.height, minHeight), maxHeight)
                                    }
                                    .onChange(of: text) { _ in
                                        textHeight = min(max(geometry.size.height, minHeight), maxHeight)
                                    }
                            }
                        )
                        .opacity(0)
                    
                    // Actual TextEditor
                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(height: textHeight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .focused($isFocused)
                        .disabled(isLoading)
                        .onSubmit {
                            if canSend && !text.contains("\n") {
                                onSend()
                            }
                        }
                }
                
                // Send Button
                Button(action: onSend) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(canSend ? .accentColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend || isLoading)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Helper Text
            HStack {
                Text("⌘↩ to send")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(text.count) characters")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    VStack {
        Spacer()
        MessageInputView(
            text: .constant(""),
            isLoading: false,
            canSend: true,
            onSend: {}
        )
    }
    .frame(width: 470)
}

