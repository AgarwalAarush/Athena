//
//  GmailView.swift
//  Athena
//
//  Main Gmail composition view where users can compose and send emails
//

import SwiftUI

/// Main Gmail composition view with form-based interface
struct GmailView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: GmailViewModel
    @EnvironmentObject var appViewModel: AppViewModel
    @FocusState private var focusedField: Field?
    
    // MARK: - Field Focus Management
    
    private enum Field {
        case recipient
        case subject
        case body
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with action buttons
                FormHeader(
                    title: "Send Email",
                    cancelAction: {
                        Task {
                            await viewModel.cancel()
                        }
                    },
                    primaryAction: {
                        Task {
                            await viewModel.sendEmail()
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
                                icon: "envelope.fill",
                                iconColor: .blue,
                                label: "To"
                            ) {
                                TextField("recipient@example.com", text: $viewModel.recipient)
                                    .textFieldStyle(.plain)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .focused($focusedField, equals: .recipient)
                                    .disabled(viewModel.isSending)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .recipient
                        }
                        
                        // Subject field
                        FormGroupContainer {
                            FormFieldRow(
                                icon: "text.alignleft",
                                iconColor: .orange,
                                label: "Subject"
                            ) {
                                TextField("Email subject", text: $viewModel.subject)
                                    .textFieldStyle(.plain)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .focused($focusedField, equals: .subject)
                                    .disabled(viewModel.isSending)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .subject
                        }
                        
                        // Body field
                        FormGroupContainer {
                            VStack(alignment: .leading, spacing: 8) {
                                // Multi-line body input
                                MultiLineTextInput(
                                    text: $viewModel.body,
                                    placeholder: "Enter your email message...",
                                    minHeight: 100,
                                    maxHeight: 200
                                )
                                .padding(.horizontal, AppMetrics.paddingLarge - 5)
                                .padding(.vertical, 12)
                                .focused($focusedField, equals: .body)
                                .disabled(viewModel.isSending)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .body
                        }
                    }
                    .padding(.horizontal, AppMetrics.padding)
                    .padding(.top, 8)
                }
                .padding(.vertical, AppMetrics.padding)
            }
        }
        .onAppear {
            print("[GmailView] 🎬 View appeared - geometry size: \(geometry.size)")
        }
        .onDisappear {
            print("[GmailView] 👋 View disappeared")
        }
        .onChange(of: geometry.size) { newSize in
            print("[GmailView] 📐 Geometry size changed to: \(newSize)")
        }
        }
        .glassBackground(
            material: AppMaterial.primaryGlass,
            cornerRadius: AppMetrics.cornerRadiusLarge
        )
        .padding()
        .onAppear {
            print("[GmailView] 📧 Outer onAppear - focusing recipient field")
            // Focus recipient field on appear
            focusedField = .recipient
        }
        .alert("Google Sign-In Required", isPresented: $viewModel.showAuthPrompt) {
            Button("Sign In") {
                Task {
                    await viewModel.requestAuthorization()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.errorMessage = "Sign-in required to send emails. You can authorize from Settings."
            }
        } message: {
            Text("You need to sign in with Google to send emails. This will also enable access to Google Calendar and Google Drive.")
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = GmailViewModel()
    viewModel.prepareEmail(
        recipient: "john@example.com",
        subject: "Meeting Follow-up",
        body: "Hi John,\n\nThanks for the great meeting today. Here are the key takeaways..."
    )
    
    return GmailView(viewModel: viewModel)
        .environmentObject(AppViewModel())
        .frame(width: 600, height: 500)
}

