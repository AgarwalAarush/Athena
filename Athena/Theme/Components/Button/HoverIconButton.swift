//
//  HoverIconButton.swift
//  Athena
//
//  A reusable icon button with hover effects
//

import SwiftUI

/// Icon button with liquid glass hover effects
struct HoverIconButton: View {
    let systemName: String
    let action: () -> Void
    var tint: Color = AppColors.secondary
    var hoverTint: Color = AppColors.primary
    var size: CGFloat = AppMetrics.buttonSize
    var iconSize: CGFloat = AppMetrics.iconSize
    var iconWeight: Font.Weight = .medium
    var cornerRadius: CGFloat = AppMetrics.cornerRadiusMedium
    var showBackground: Bool = true
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundStyle(isHovering ? hoverTint : tint)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if showBackground {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isHovering ? AppColors.hoverOverlay : Color.clear)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onHover { hovering in
            withAnimation(AppAnimations.hoverEasing) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Convenience Initializers

extension HoverIconButton {
    /// Destructive variant with red coloring
    init(
        systemName: String,
        action: @escaping () -> Void,
        destructive: Bool,
        size: CGFloat = AppMetrics.buttonSize,
        iconSize: CGFloat = AppMetrics.iconSize,
        iconWeight: Font.Weight = .medium,
        cornerRadius: CGFloat = AppMetrics.cornerRadiusMedium
    ) {
        self.systemName = systemName
        self.action = action
        self.tint = destructive ? AppColors.error.opacity(0.7) : AppColors.secondary
        self.hoverTint = destructive ? AppColors.error : AppColors.primary
        self.size = size
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.cornerRadius = cornerRadius
    }
    
    /// Accent variant with accent coloring
    init(
        systemName: String,
        action: @escaping () -> Void,
        accent: Bool,
        size: CGFloat = AppMetrics.buttonSize,
        iconSize: CGFloat = AppMetrics.iconSize,
        iconWeight: Font.Weight = .medium,
        cornerRadius: CGFloat = AppMetrics.cornerRadiusMedium
    ) {
        self.systemName = systemName
        self.action = action
        self.tint = accent ? AppColors.accent : AppColors.secondary
        self.hoverTint = accent ? AppColors.accent : AppColors.primary
        self.size = size
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.cornerRadius = cornerRadius
    }
}

#Preview {
    HStack(spacing: 16) {
        HoverIconButton(systemName: "gear", action: {})
        HoverIconButton(systemName: "trash", action: {}, destructive: true)
        HoverIconButton(systemName: "star.fill", action: {}, accent: true)
    }
    .padding()
    .background(AppMaterial.primaryGlass)
}

