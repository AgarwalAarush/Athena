//
//  GmailViewModel.swift
//  Athena
//
//  ViewModel for the Gmail compose view
//  Manages the state of a pending email before it's sent
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for the Gmail composition view
@MainActor
class GmailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The recipient email address
    @Published var recipient: String = ""
    
    /// The email subject
    @Published var subject: String = ""
    
    /// The email body content
    @Published var body: String = ""
    
    /// Whether the email is currently being sent
    @Published var isSending: Bool = false
    
    /// Error message to display if sending fails
    @Published var errorMessage: String?
    
    /// Success message to display after sending
    @Published var successMessage: String?
    
    // MARK: - Dependencies
    
    private weak var appViewModel: AppViewModel?
    private let gmailService = GmailService.shared
    
    // MARK: - Initialization
    
    init() {}
    
    /// Sets up the view model with dependencies
    func setup(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }
    
    // MARK: - Public Methods
    
    /// Prepares the view with initial data from voice command parsing
    /// - Parameters:
    ///   - recipient: The email address to send to
    ///   - subject: The email subject line
    ///   - body: The email body content
    func prepareEmail(recipient: String, subject: String, body: String) {
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.errorMessage = nil
        self.successMessage = nil
        self.isSending = false
    }
    
    /// Validates the current email state
    /// - Returns: True if the email is valid and can be sent
    var isValid: Bool {
        !recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Sends the email using GmailService
    func sendEmail() async {
        guard isValid else {
            errorMessage = "Please fill in all fields (recipient, subject, and message)"
            return
        }
        
        isSending = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // Send via GmailService
            print("[GmailViewModel] Sending email to \(recipient) with subject: \(subject)")
            try await gmailService.sendMessage(
                to: recipient.trimmingCharacters(in: .whitespacesAndNewlines),
                subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                isHTML: false
            )
            
            print("[GmailViewModel] ✅ Email sent successfully")
            successMessage = "Email sent to \(recipient)"
            
            // Wait a moment for user to see success, then close
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await cancel()
            
        } catch let error as GmailServiceError {
            print("[GmailViewModel] ❌ Failed to send email: \(error.localizedDescription)")
            
            // Provide specific error messages
            switch error {
            case .notAuthenticated:
                errorMessage = "Not signed in to Google. Please authenticate first."
            case .authorizationFailed(let authError):
                errorMessage = "Authorization failed: \(authError.localizedDescription)"
            case .sendFailed(let sendError):
                errorMessage = "Failed to send email: \(sendError.localizedDescription)"
            case .invalidMessageFormat:
                errorMessage = "Invalid email format. Please check your inputs."
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            print("[GmailViewModel] ❌ Unexpected error: \(error.localizedDescription)")
            errorMessage = "Failed to send email: \(error.localizedDescription)"
        }
        
        isSending = false
    }
    
    /// Cancels the email and returns to the previous view
    func cancel() async {
        print("[GmailViewModel] Canceling email")
        reset()
        
        // Collapse the content area and return to home
        await MainActor.run {
            appViewModel?.currentView = .home
            appViewModel?.isContentExpanded = false
        }
    }
    
    /// Resets the view model to its initial state
    func reset() {
        recipient = ""
        subject = ""
        body = ""
        isSending = false
        errorMessage = nil
        successMessage = nil
    }
}

