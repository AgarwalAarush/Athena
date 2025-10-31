//
//  MessageInputView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI
import AppKit
import CoreText

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
                        .font(.apercu)
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
                    CustomTextEditor(text: $text, isFocused: isFocused)
                        .frame(height: textHeight)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                        .background(Color.white.opacity(0.30))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .disabled(isLoading || isRecording)
                        .onTapGesture {
                            isFocused = true
                        }
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
                    .font(.apercu(size: 16))
                    .foregroundColor(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .simultaneousGesture(
            // Press-and-hold mode: only active when NOT recording (tap takes priority when recording)
            !isRecording ? DragGesture(minimumDistance: 0)
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
            : nil
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

// Custom TextEditor wrapper that removes extra padding
struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isFocused: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view with Apercu font
        textView.font = NSFont.apercu(size: 14)
        // Use black text color for visibility on light background
        textView.textColor = NSColor.black
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.delegate = context.coordinator
        
        // Remove extra padding - this is key to eliminating the extra line
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // Configure scroll view
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        // Store coordinator
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
            // Update focus
            if isFocused {
                let currentResponder = textView.window?.firstResponder
                if currentResponder != textView {
                    textView.window?.makeFirstResponder(textView)
                }
            }
            // Keep text color black for visibility on light background
            textView.textColor = NSColor.black
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        var textView: NSTextView?
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = textView {
                parent.text = textView.string
            }
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

