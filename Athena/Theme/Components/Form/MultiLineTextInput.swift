//
//  MultiLineTextInput.swift
//  Athena
//
//  Reusable multi-line text input with placeholder support
//

import SwiftUI

/// Multi-line text editor with placeholder and consistent styling
struct MultiLineTextInput: View {
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    
    init(
        text: Binding<String>,
        placeholder: String = "Enter text...",
        minHeight: CGFloat = 100,
        maxHeight: CGFloat = 200
    ) {
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            // Text editor
            TextEditor(text: $text)
                .font(.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
        }
    }
}

