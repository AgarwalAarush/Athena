//
//  Animations.swift
//  Athena
//
//  Animation timing and easing constants
//

import SwiftUI

/// Standard animation timings for consistent motion
enum AppAnimations {
    // MARK: - Durations
    
    /// Quick interactions (70ms)
    static let durationFast: Double = 0.07
    
    /// Standard transitions (150ms)
    static let durationMedium: Double = 0.15
    
    /// Slower, emphasizing transitions (250ms)
    static let durationSlow: Double = 0.25
    
    /// Very slow, dramatic transitions (400ms)
    static let durationVerySlow: Double = 0.4
    
    // MARK: - Animation Curves
    
    /// Fast easing for hover states
    static let hoverEasing = Animation.easeOut(duration: durationFast)
    
    /// Standard easing for UI transitions
    static let standardEasing = Animation.easeInOut(duration: durationMedium)
    
    /// Smooth spring for interactive elements
    static let springEasing = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Subtle spring for gentle motion
    static let subtleSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
}

