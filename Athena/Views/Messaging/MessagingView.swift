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
            headerSection
            
            Divider()
                .opacity(0.3)
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Status messages
                    if let error = viewModel.errorMessage {
                        errorBanner(message: error)
                    }
                    
                    if let success = viewModel.successMessage {
                        successBanner(message: success)
                    }
                    
                    // Form fields
                    VStack(spacing: 12) {
                        // Group 1: Recipient
                        recipientSection
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        // Group 2: Message
                        messageSection
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: AppMetrics.spacing) {
            // Title
            Text("Send Message")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            // Cancel button
            Button(action: {
                Task {
                    await viewModel.cancel()
                }
            }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSending)
            
            // Send button
            Button(action: {
                Task {
                    await viewModel.sendMessage()
                }
            }) {
                HStack(spacing: 6) {
                    if viewModel.isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    }
                    Text(viewModel.isSending ? "Sending..." : "Send")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(viewModel.isValid && !viewModel.isSending ? Color.blue : Color.gray)
                .cornerRadius(AppMetrics.cornerRadiusMedium)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isValid || viewModel.isSending)
        }
        .padding(AppMetrics.padding)
    }
    
    // MARK: - Recipient Section
    
    private var recipientSection: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("To")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
            
            Spacer()
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = .recipient
        }
    }
    
    // MARK: - Message Section
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: AppMetrics.spacingMedium) {
                Image(systemName: "message.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .frame(width: 24)
                
                Text("Message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, AppMetrics.paddingLarge)
            .padding(.top, 12)
            
            // Multi-line message input
            ZStack(alignment: .topLeading) {
                if viewModel.message.isEmpty {
                    Text("Enter your message...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppMetrics.paddingLarge)
                        .padding(.top, 4)
                }
                
                TextEditor(text: $viewModel.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 100, maxHeight: 200)
                    .padding(.horizontal, AppMetrics.paddingLarge - 5)
                    .focused($focusedField, equals: .message)
                    .disabled(viewModel.isSending)
            }
            .padding(.bottom, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = .message
        }
    }
    
    // MARK: - Status Banners
    
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, AppMetrics.padding)
    }
    
    private func successBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(message)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, AppMetrics.padding)
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

