//
//  MessagingView.swift
//  Athena
//
//  Created by Cursor on 11/8/25.
//

import SwiftUI

/// Main messaging confirmation view where users can review and edit messages before sending
struct MessagingView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: MessagingViewModel
    @EnvironmentObject var appViewModel: AppViewModel
    @FocusState private var focusedField: Field?
    
    // MARK: - Field Focus Management
    
    private enum Field {
        case recipient
        case message
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with action buttons
            FormHeader(
                title: "Send Message",
                cancelAction: {
                    Task {
                        await viewModel.cancel()
                    }
                },
                primaryAction: {
                    Task {
                        await viewModel.sendMessage()
                    }
                },
                primaryLabel: "Send",
                isPrimaryEnabled: viewModel.isValid && !viewModel.isSending,
                isProcessing: viewModel.isSending
            )
            
            Divider()
                .opacity(0.3)
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Status banners
                    StatusBanner.error(viewModel.errorMessage)
                    StatusBanner.success(viewModel.successMessage)
                    
                    // Form fields
                    VStack(spacing: 12) {
                        // Recipient field
                        FormGroupContainer {
                            FormFieldRow(
                                icon: "person.circle.fill",
                                iconColor: .blue,
                                label: "To"
                            ) {
                                VStack(alignment: .leading, spacing: 2) {
                                    TextField("Recipient name or number", text: $viewModel.recipient)
                                        .textFieldStyle(.plain)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .focused($focusedField, equals: .recipient)
                                        .disabled(viewModel.isSending)
                                    
                                    if let resolved = viewModel.resolvedContact, resolved != viewModel.recipient {
                                        Text("→ \(resolved)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .recipient
                        }
                        
                        // Message field
                        FormGroupContainer {
                            VStack(alignment: .leading, spacing: 8) {
                                // Multi-line message input
                                MultiLineTextInput(
                                    text: $viewModel.message,
                                    placeholder: "Enter your message...",
                                    minHeight: 100,
                                    maxHeight: 200
                                )
                                .padding(.horizontal, AppMetrics.paddingLarge - 5)
                                .padding(.vertical, 12)
                                .focused($focusedField, equals: .message)
                                .disabled(viewModel.isSending)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .message
                        }
                    }
                    .padding(.horizontal, AppMetrics.padding)
                    .padding(.top, 8)
                }
                .padding(.vertical, AppMetrics.padding)
            }
        }
        .glassBackground(
            material: AppMaterial.primaryGlass,
            cornerRadius: AppMetrics.cornerRadiusLarge
        )
        .padding()
        .onAppear {
            // Focus recipient field on appear
            focusedField = .recipient
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = MessagingViewModel()
    viewModel.prepareMessage(recipient: "John Doe", message: "Hey, how are you?")
    
    return MessagingView(viewModel: viewModel)
        .environmentObject(AppViewModel())
        .frame(width: 600, height: 500)
}

