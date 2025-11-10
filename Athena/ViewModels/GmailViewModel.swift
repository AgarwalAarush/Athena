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
    
    /// Whether to show the authorization prompt
    @Published var showAuthPrompt: Bool = false
    
    /// Whether currently authenticating with Google
    @Published var isAuthenticating: Bool = false
    
    // MARK: - Dependencies
    
    private weak var appViewModel: AppViewModel?
    private let gmailService = GmailService.shared
    private let authService = GoogleAuthService.shared
    
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
                // Trigger authorization prompt instead of just showing error
                showAuthPrompt = true
                errorMessage = nil // Clear any previous error
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
    
    /// Requests Google authorization and retries sending email on success
    func requestAuthorization() async {
        guard !isAuthenticating else {
            print("[GmailViewModel] ⚠️ Already authenticating, skipping duplicate request")
            return
        }
        
        print("[GmailViewModel] 🔐 Starting authorization request...")
        isAuthenticating = true
        showAuthPrompt = false // Hide the prompt while authenticating
        errorMessage = nil
        
        do {
            // Get the main window for authorization
            print("[GmailViewModel] 🪟 Attempting to get presenting window...")
            
            guard let window = await MainActor.run(body: {
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let windowManager = appDelegate.windowManager {
                    print("[GmailViewModel] 🪟 Found windowManager")
                    if let window = windowManager.window {
                        print("[GmailViewModel] 🪟 Window exists: \(window)")
                        print("[GmailViewModel] 🪟 Window visible: \(window.isVisible)")
                        print("[GmailViewModel] 🪟 Window key: \(window.isKeyWindow)")
                        print("[GmailViewModel] 🪟 Window level: \(window.level)")
                        print("[GmailViewModel] 🪟 Window frame: \(window.frame)")
                        
                        // Ensure window is visible and key
                        if !window.isVisible {
                            print("[GmailViewModel] 🪟 Making window visible...")
                            window.makeKeyAndOrderFront(nil)
                        }
                        
                        // Activate the app to ensure proper focus
                        print("[GmailViewModel] 🎯 Activating application...")
                        NSApp.activate(ignoringOtherApps: true)
                        
                        return window
                    } else {
                        print("[GmailViewModel] ❌ windowManager.window is nil")
                    }
                } else {
                    print("[GmailViewModel] ❌ Could not get AppDelegate or windowManager")
                }
                return nil
            }) else {
                print("[GmailViewModel] ❌ Failed to get presenting window")
                errorMessage = "Unable to present authorization window. Please try again."
                isAuthenticating = false
                return
            }
            
            print("[GmailViewModel] 🚀 Requesting Google authorization for Gmail")
            print("[GmailViewModel] 📋 Scopes: \(GoogleOAuthScopes.allScopes.joined(separator: ", "))")
            
            // Request all scopes for full access
            _ = try await authService.authorize(
                scopes: GoogleOAuthScopes.allScopes,
                presentingWindow: window
            )
            
            print("[GmailViewModel] ✅ Authorization successful!")
            print("[GmailViewModel] 🔄 Retrying email send...")
            
            // Retry sending the email
            await sendEmail()
            
        } catch let error as GoogleAuthError {
            print("[GmailViewModel] ❌ Authorization failed with GoogleAuthError")
            print("[GmailViewModel] ❌ Error type: \(error)")
            print("[GmailViewModel] ❌ Error description: \(error.localizedDescription)")
            
            switch error {
            case .userCancelled:
                print("[GmailViewModel] 🚫 User cancelled the sign-in")
                errorMessage = "Sign-in was cancelled. Please try again to send email."
            case .networkError(let networkError):
                print("[GmailViewModel] 🌐 Network error: \(networkError)")
                errorMessage = "Network error: \(networkError.localizedDescription)"
            case .configurationMissing, .configurationInvalid:
                print("[GmailViewModel] ⚙️ Configuration error")
                errorMessage = "Google OAuth is not configured. Please contact support."
            default:
                print("[GmailViewModel] ⚠️ Other authorization error")
                errorMessage = "Authorization failed: \(error.localizedDescription)"
            }
        } catch {
            print("[GmailViewModel] ❌ Unexpected authorization error (not GoogleAuthError)")
            print("[GmailViewModel] ❌ Error: \(error)")
            print("[GmailViewModel] ❌ Error type: \(type(of: error))")
            errorMessage = "Failed to authorize: \(error.localizedDescription)"
        }
        
        print("[GmailViewModel] 🏁 Authorization flow completed, isAuthenticating = false")
        isAuthenticating = false
    }
    
    /// Cancels the email and returns to the previous view
    func cancel() async {
        print("[GmailViewModel] Canceling email")
        reset()
        
        // Collapse the content area and return to waveform view
        await MainActor.run {
            appViewModel?.collapseContent()
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
        showAuthPrompt = false
        isAuthenticating = false
    }
}

