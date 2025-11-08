//
//  FormGroupContainer.swift
//  Athena
//
//  Reusable container for grouping form fields with consistent styling
//

import SwiftUI

/// Container that wraps form fields with gray background and dividers
struct FormGroupContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
    }
}

/// Extension to help with dividers between fields
extension View {
    /// Adds a divider with leading padding for form groups
    func formDivider() -> some View {
        VStack(spacing: 0) {
            self
            Divider()
                .padding(.leading, AppMetrics.paddingLarge)
        }
    }
}

