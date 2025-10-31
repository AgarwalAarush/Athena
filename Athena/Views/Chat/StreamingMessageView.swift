//
//  StreamingMessageView.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI

struct StreamingMessageView: View {
    let content: String
    @State private var cursorVisible = true
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Streaming Content
                HStack(alignment: .bottom, spacing: 4) {
                    Text(content)
                        .textSelection(.enabled)
                        .font(.apercu)
                        .foregroundColor(.primary)
                    
                    // Animated cursor
                    Text("▋")
                        .font(.apercu)
                        .foregroundColor(.accentColor)
                        .opacity(cursorVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: cursorVisible)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                
                // Status
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Generating response...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            
            Spacer(minLength: 60)
        }
        .onAppear {
            cursorVisible = true
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StreamingMessageView(content: "This is a streaming response that is being generated in real-time...")
        
        StreamingMessageView(content: "Here's another example with more text to show how the view handles longer content.")
    }
    .padding()
    .frame(width: 470)
}

