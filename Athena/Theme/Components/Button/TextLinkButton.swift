//
//  TextLinkButton.swift
//  Athena
//
//  A minimal text link button with hover effects
//

import SwiftUI

/// Minimal text link button with icon and hover effects
struct TextLinkButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    var tint: Color = AppColors.secondary
    var hoverTint: Color = AppColors.accent
    var fontSize: CGFloat = 13
    var iconSize: CGFloat = 11
    var spacing: CGFloat = 4
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: spacing) {
                Text(title)
                    .font(.system(size: fontSize, weight: .medium))
                
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: iconSize, weight: .semibold))
                }
            }
            .foregroundStyle(isHovering ? hoverTint : tint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppAnimations.hoverEasing) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Convenience Initializers

extension TextLinkButton {
    /// View all variant with chevron
    init(
        viewAll action: @escaping () -> Void,
        tint: Color = AppColors.secondary,
        hoverTint: Color = AppColors.accent
    ) {
        self.title = "View All"
        self.systemImage = "chevron.right"
        self.action = action
        self.tint = tint
        self.hoverTint = hoverTint
        self.fontSize = 13
        self.iconSize = 10
        self.spacing = 4
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Section Title")
                .font(.headline)
            Spacer()
            TextLinkButton(viewAll: {})
        }
        
        HStack {
            Text("Custom Link")
                .font(.headline)
            Spacer()
            TextLinkButton(
                title: "Show More",
                systemImage: "arrow.right",
                action: {}
            )
        }
        
        HStack {
            Text("No Icon")
                .font(.headline)
            Spacer()
            TextLinkButton(
                title: "Learn More",
                systemImage: nil,
                action: {}
            )
        }
    }
    .padding()
    .frame(width: 400)
    .background(AppMaterial.primaryGlass)
}

