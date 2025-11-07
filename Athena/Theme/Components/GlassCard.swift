//
//  GlassCard.swift
//  Athena
//
//  Reusable card component with liquid glass styling
//

import SwiftUI

/// A card container with glass material and rounded corners
struct GlassCard<Content: View>: View {
    let content: Content
    var material: Material = AppMaterial.secondaryGlass
    var cornerRadius: CGFloat = AppMetrics.cornerRadiusMedium
    var padding: CGFloat = AppMetrics.padding
    var borderColor: Color = AppColors.border
    var showBorder: Bool = true
    
    init(
        material: Material = AppMaterial.secondaryGlass,
        cornerRadius: CGFloat = AppMetrics.cornerRadiusMedium,
        padding: CGFloat = AppMetrics.padding,
        borderColor: Color = AppColors.border,
        showBorder: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.material = material
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.borderColor = borderColor
        self.showBorder = showBorder
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    }
                }
            )
    }
}

/// A hoverable card that scales on hover
struct HoverableGlassCard<Content: View>: View {
    let content: Content
    var material: Material = AppMaterial.secondaryGlass
    var cornerRadius: CGFloat = AppMetrics.cornerRadiusMedium
    var padding: CGFloat = AppMetrics.padding
    var action: (() -> Void)?
    
    @State private var isHovering = false
    
    init(
        material: Material = AppMaterial.secondaryGlass,
        cornerRadius: CGFloat = AppMetrics.cornerRadiusMedium,
        padding: CGFloat = AppMetrics.padding,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.material = material
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.action = action
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(AppAnimations.springEasing) {
                isHovering = hovering
            }
        }
    }
    
    private var cardContent: some View {
        content
            .padding(padding)
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isHovering ? AppColors.accent.opacity(0.3) : AppColors.border,
                        lineWidth: 1
                    )
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Standard Glass Card")
                    .font(.headline)
                Text("This is a reusable card component with glass styling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        HoverableGlassCard(action: {
            print("Card tapped")
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hoverable Glass Card")
                    .font(.headline)
                Text("This card scales on hover and can be tapped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .frame(width: 400)
    .background(AppMaterial.primaryGlass)
}

