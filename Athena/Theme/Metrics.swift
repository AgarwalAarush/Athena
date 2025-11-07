//
//  Metrics.swift
//  Athena
//
//  Centralized spacing, sizing, and dimension constants
//

import SwiftUI

/// Spacing and sizing constants following macOS design guidelines
enum AppMetrics {
    // MARK: - Corner Radii
    
    /// Extra large corner radius for window shell (20pt)
    static let cornerRadiusXLarge: CGFloat = 20.0
    
    /// Standard corner radius for cards and containers (12pt)
    static let cornerRadiusLarge: CGFloat = 12.0
    
    /// Medium corner radius for buttons and smaller elements (8pt)
    static let cornerRadiusMedium: CGFloat = 8.0
    
    /// Small corner radius for compact elements (6pt)
    static let cornerRadiusSmall: CGFloat = 6.0
    
    /// Extra small corner radius for inline elements (4pt)
    static let cornerRadiusXSmall: CGFloat = 4.0
    
    // MARK: - Spacing
    
    /// Extra large spacing (24pt)
    static let spacingXLarge: CGFloat = 24.0
    
    /// Large spacing (20pt)
    static let spacingLarge: CGFloat = 20.0
    
    /// Standard spacing (16pt)
    static let spacing: CGFloat = 16.0
    
    /// Medium spacing (12pt)
    static let spacingMedium: CGFloat = 12.0
    
    /// Small spacing (8pt)
    static let spacingSmall: CGFloat = 8.0
    
    /// Extra small spacing (4pt)
    static let spacingXSmall: CGFloat = 4.0
    
    // MARK: - Icon Sizes
    
    /// Large icon size (20pt)
    static let iconSizeLarge: CGFloat = 20.0
    
    /// Standard icon size (16pt)
    static let iconSize: CGFloat = 16.0
    
    /// Small icon size (14pt)
    static let iconSizeSmall: CGFloat = 14.0
    
    /// Extra small icon size (12pt)
    static let iconSizeXSmall: CGFloat = 12.0
    
    // MARK: - Button Sizes
    
    /// Standard button size (32pt)
    static let buttonSize: CGFloat = 32.0
    
    /// Large button size (40pt)
    static let buttonSizeLarge: CGFloat = 40.0
    
    /// Small button size (28pt)
    static let buttonSizeSmall: CGFloat = 28.0
    
    // MARK: - Padding
    
    /// Standard padding (16pt)
    static let padding: CGFloat = 16.0
    
    /// Large padding (20pt)
    static let paddingLarge: CGFloat = 20.0
    
    /// Medium padding (12pt)
    static let paddingMedium: CGFloat = 12.0
    
    /// Small padding (8pt)
    static let paddingSmall: CGFloat = 8.0
}

