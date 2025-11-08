//
//  FormHeader.swift
//  Athena
//
//  Reusable header section for form views with action buttons
//

import SwiftUI

/// Standard header for form views with title and action buttons
struct FormHeader: View {
    let title: String
    let cancelAction: () -> Void
    let primaryAction: () -> Void
    let primaryLabel: String
    let isPrimaryEnabled: Bool
    let isProcessing: Bool
    
    init(
        title: String,
        cancelAction: @escaping () -> Void,
        primaryAction: @escaping () -> Void,
        primaryLabel: String = "Send",
        isPrimaryEnabled: Bool = true,
        isProcessing: Bool = false
    ) {
        self.title = title
        self.cancelAction = cancelAction
        self.primaryAction = primaryAction
        self.primaryLabel = primaryLabel
        self.isPrimaryEnabled = isPrimaryEnabled
        self.isProcessing = isProcessing
    }
    
    var body: some View {
        HStack(spacing: AppMetrics.spacing) {
            // Title
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            // Cancel button
            Button(action: cancelAction) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            
            // Primary action button
            Button(action: primaryAction) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    }
                    Text(isProcessing ? "\(primaryLabel)ing..." : primaryLabel)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isPrimaryEnabled && !isProcessing ? Color.blue : Color.gray)
                .cornerRadius(AppMetrics.cornerRadiusMedium)
            }
            .buttonStyle(.plain)
            .disabled(!isPrimaryEnabled || isProcessing)
        }
        .padding(AppMetrics.padding)
    }
}

