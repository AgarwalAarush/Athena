//
//  GlassButton.swift
//  Athena
//
//  A button with liquid glass styling
//

import SwiftUI

/// Full-width or inline button with glass styling
struct GlassButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    var style: ButtonStyleType = .primary
    var size: ButtonSizeType = .medium
    
    @State private var isHovering: Bool = false
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppMetrics.spacingSmall) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: fontSize, weight: .medium))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minWidth: minWidth)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppAnimations.hoverEasing) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    // MARK: - Computed Properties
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return isHovering ? AppColors.primary : AppColors.secondary
        case .destructive:
            return isHovering ? AppColors.error : AppColors.error.opacity(0.8)
        case .accent:
            return .white
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isHovering ? AppColors.accent.opacity(0.9) : AppColors.accent
        case .secondary:
            return isHovering ? AppColors.hoverOverlay : Color.clear
        case .destructive:
            return isHovering ? AppColors.error.opacity(0.15) : AppColors.error.opacity(0.08)
        case .accent:
            return isHovering ? AppColors.accent.opacity(0.9) : AppColors.accent
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .accent:
            return .clear
        case .secondary:
            return isHovering ? AppColors.border : AppColors.border.opacity(0.5)
        case .destructive:
            return AppColors.error.opacity(0.3)
        }
    }
    
    private var cornerRadius: CGFloat {
        switch size {
        case .small:
            return AppMetrics.cornerRadiusSmall
        case .medium:
            return AppMetrics.cornerRadiusMedium
        case .large:
            return AppMetrics.cornerRadiusMedium
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small:
            return AppMetrics.paddingSmall
        case .medium:
            return AppMetrics.paddingMedium
        case .large:
            return AppMetrics.padding
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small:
            return AppMetrics.spacingXSmall
        case .medium:
            return AppMetrics.spacingSmall
        case .large:
            return AppMetrics.spacingMedium
        }
    }
    
    private var fontSize: CGFloat {
        switch size {
        case .small:
            return 12
        case .medium:
            return 13
        case .large:
            return 14
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small:
            return AppMetrics.iconSizeXSmall
        case .medium:
            return AppMetrics.iconSizeSmall
        case .large:
            return AppMetrics.iconSize
        }
    }
    
    private var minWidth: CGFloat? {
        switch size {
        case .small:
            return nil
        case .medium:
            return 60
        case .large:
            return 80
        }
    }
}

// MARK: - Supporting Types

enum ButtonStyleType {
    case primary
    case secondary
    case destructive
    case accent
}

enum ButtonSizeType {
    case small
    case medium
    case large
}

#Preview {
    VStack(spacing: 16) {
        GlassButton(title: "Primary", systemImage: "checkmark", action: {}, style: .primary)
        GlassButton(title: "Secondary", systemImage: "arrow.right", action: {}, style: .secondary)
        GlassButton(title: "Destructive", systemImage: "trash", action: {}, style: .destructive)
        GlassButton(title: "Accent", systemImage: "star.fill", action: {}, style: .accent)
        
        Divider()
        
        HStack {
            GlassButton(title: "Small", systemImage: nil, action: {}, size: .small)
            GlassButton(title: "Medium", systemImage: nil, action: {}, size: .medium)
            GlassButton(title: "Large", systemImage: nil, action: {}, size: .large)
        }
    }
    .padding()
    .frame(width: 400)
    .background(AppMaterial.primaryGlass)
}

