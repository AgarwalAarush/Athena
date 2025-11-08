//
//  StatusBanner.swift
//  Athena
//
//  Reusable status banner for displaying errors, success, and warnings
//

import SwiftUI

/// Status banner component for displaying feedback messages
struct StatusBanner: View {
    enum BannerType {
        case error
        case success
        case warning
        
        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .error: return .orange
            case .success: return .green
            case .warning: return .yellow
            }
        }
    }
    
    let message: String
    let type: BannerType
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(type.color.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(type.color.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, AppMetrics.padding)
    }
}

// MARK: - Convenience Initializers

extension StatusBanner {
    /// Creates an error banner
    static func error(_ message: String?) -> some View {
        Group {
            if let message = message {
                StatusBanner(message: message, type: .error)
            }
        }
    }
    
    /// Creates a success banner
    static func success(_ message: String?) -> some View {
        Group {
            if let message = message {
                StatusBanner(message: message, type: .success)
            }
        }
    }
    
    /// Creates a warning banner
    static func warning(_ message: String?) -> some View {
        Group {
            if let message = message {
                StatusBanner(message: message, type: .warning)
            }
        }
    }
}

