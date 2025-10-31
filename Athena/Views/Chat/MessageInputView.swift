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
    let isRecording: Bool
    let onStartVoiceInput: () -> Void
    let onStopVoiceInput: () -> Void

    @FocusState private var isFocused: Bool
    @State private var textHeight: CGFloat = 32
    @State private var isPressingMic: Bool = false

    private let maxHeight: CGFloat = 120
    private let minHeight: CGFloat = 32
    
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

            HStack(alignment: .center, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    // Invisible Text to calculate height
                    Text(text.isEmpty ? " " : text)
                        .font(.body)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
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
                        .foregroundColor(.black)
                        .scrollContentBackground(.hidden)
                        .frame(height: textHeight)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.30))
                        .clipShape(Capsule())
                        .focused($isFocused)
                        .disabled(isLoading || isRecording)
                        .onSubmit {
                            if canSend {
                                onSend()
                            }
                        }
                }

                // Microphone button with both tap and press-and-hold
                microphoneButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear {
            isFocused = true
        }
    }

    private var microphoneButton: some View {
        Button(action: {
            // Toggle mode: tap to start/stop
            if isRecording {
                onStopVoiceInput()
            } else {
                onStartVoiceInput()
            }
        }) {
            ZStack {
                Circle()
                    .fill(micButtonColor)
                    .frame(width: 32, height: 32)

                Image(systemName: micIconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .simultaneousGesture(
            // Press-and-hold mode: hold to record, release to stop
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressingMic && !isRecording {
                        isPressingMic = true
                        onStartVoiceInput()
                    }
                }
                .onEnded { _ in
                    if isPressingMic {
                        isPressingMic = false
                        onStopVoiceInput()
                    }
                }
        )
    }

    private var micIconName: String {
        if isRecording {
            return "stop.circle.fill"
        } else {
            return "mic.circle.fill"
        }
    }

    private var micButtonColor: Color {
        if isRecording {
            return .red
        } else if isLoading {
            return .gray
        } else {
            return .blue
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
            onSend: {},
            isRecording: false,
            onStartVoiceInput: {},
            onStopVoiceInput: {}
        )
    }
    .frame(width: 470)
}

