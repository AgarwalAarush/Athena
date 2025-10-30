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
        ZStack {
            // Invisible button to capture keyboard shortcut
            Button(action: {
                if canSend && !isLoading {
                    onSend()
                }
            }) {
                EmptyView()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .hidden()

            ZStack(alignment: .topLeading) {
            // Invisible Text to calculate height
            Text(text.isEmpty ? " " : text)
                .font(.body)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                textHeight = min(max(geometry.size.height, minHeight), maxHeight)
                            }
                            .onChange(of: text) {
                                textHeight = min(max(geometry.size.height, minHeight), maxHeight)
                            }
                    }
                )
                .opacity(0)

            // Actual TextEditor with rounded style
            TextEditor(text: $text)
                .font(.body)
                .foregroundColor(.primary)
                .scrollContentBackground(.hidden)
                .frame(height: textHeight)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.15))
                .clipShape(Capsule())
                .focused($isFocused)
                .disabled(isLoading)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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

