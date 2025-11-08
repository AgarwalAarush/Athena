//
//  FormFieldRow.swift
//  Athena
//
//  Reusable form field row with icon, optional label, and content area
//

import SwiftUI

/// Reusable field row component with consistent styling
struct FormFieldRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let label: String?
    let showLabel: Bool
    let content: Content
    
    init(
        icon: String,
        iconColor: Color = .blue,
        label: String? = nil,
        showLabel: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.showLabel = showLabel
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            // Content area with optional label
            VStack(alignment: .leading, spacing: 2) {
                if showLabel, let label = label {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                content
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// Variant for inline text fields without separate label
struct FormFieldRowInline<Content: View>: View {
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(
        icon: String,
        iconColor: Color = .blue,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            content
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

