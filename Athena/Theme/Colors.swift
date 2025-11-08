//
//  Colors.swift
//  Athena
//
//  Semantic color definitions for consistent theming
//

import SwiftUI

/// Semantic color palette for the app
enum AppColors {
    // MARK: - Primary Colors
    
    /// Primary content color (adapts to light/dark mode)
    static let primary = Color.primary
    
    /// Secondary content color
    static let secondary = Color.secondary
    
    /// Accent color for interactive elements
    static let accent = Color.accentColor
    
    // MARK: - Glass Tints
    
    /// Light tint for glass backgrounds
    static let glassTintLight = Color.white.opacity(0.85)
    
    /// Medium tint for glass backgrounds
    static let glassTintMedium = Color.white.opacity(0.6)
    
    /// Dark tint for glass backgrounds
    static let glassTintDark = Color.black.opacity(0.05)
    
    // MARK: - Interaction States
    
    /// Hover state overlay
    static let hoverOverlay = Color.secondary.opacity(0.12)
    
    /// Active/pressed state overlay
    static let activeOverlay = Color.secondary.opacity(0.20)
    
    /// Selection overlay
    static let selectionOverlay = Color.accentColor.opacity(0.15)
    
    // MARK: - Status Colors
    
    /// Error/destructive color
    static let error = Color.red
    
    /// Warning color
    static let warning = Color.orange
    
    /// Success color
    static let success = Color.green
    
    /// Info color
    static let info = Color.blue
    
    // MARK: - Surface Colors
    
    /// Card background with subtle opacity
    static let cardBackground = Color.gray.opacity(0.08)
    
    /// Divider color
    static let divider = Color.gray.opacity(0.2)
    
    /// Border color
    static let border = Color.gray.opacity(0.15)
}

