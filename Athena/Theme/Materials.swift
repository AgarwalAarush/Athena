//
//  Materials.swift
//  Athena
//
//  Centralized material and glass effect definitions
//

import SwiftUI

/// Semantic material styles for the app
enum AppMaterial {
    /// Primary glass effect for main containers
    static let primaryGlass: Material = .regularMaterial
    
    /// Lighter glass for nested elements
    static let secondaryGlass: Material = .thinMaterial
    
    /// Ultra-light glass for subtle overlays
    static let tertiaryGlass: Material = .ultraThinMaterial
    
    /// Thick glass for emphasis
    static let thickGlass: Material = .thickMaterial
}

/// Glass background modifier for consistent styling
struct GlassBackground: ViewModifier {
    var material: Material = AppMaterial.primaryGlass
    var cornerRadius: CGFloat = AppMetrics.cornerRadiusLarge
    var opacity: Double = 1.0
    
    func body(content: Content) -> some View {
        content
            .background(material)
            .opacity(opacity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Apply a glass background with rounded corners
    func glassBackground(
        material: Material = AppMaterial.primaryGlass,
        cornerRadius: CGFloat = AppMetrics.cornerRadiusLarge,
        opacity: Double = 1.0
    ) -> some View {
        modifier(GlassBackground(material: material, cornerRadius: cornerRadius, opacity: opacity))
    }
}

