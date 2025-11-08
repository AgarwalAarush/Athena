//
//  MessagingViewModel.swift
//  Athena
//
//  Created by Cursor on 11/8/25.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for the messaging confirmation view
/// Manages the state of a pending message before it's sent
class MessagingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The recipient of the message (contact name or phone number)
    @Published var recipient: String = ""
    
    /// The message content to send
    @Published var message: String = ""
    
    /// Whether the message is currently being sent
    @Published var isSending: Bool = false
    
    /// Error message to display if sending fails
    @Published var errorMessage: String?
    
    /// Success message to display after sending
    @Published var successMessage: String?
    
    /// Resolved contact information (after lookup)
    @Published var resolvedContact: String?
    
    // MARK: - Dependencies
    
    private weak var appViewModel: AppViewModel?
    
    // MARK: - Initialization
    
    init() {}
    
    /// Sets up the view model with dependencies
    func setup(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }
    
    // MARK: - Public Methods
    
    /// Prepares the view with initial data from voice command parsing
    /// - Parameters:
    ///   - recipient: The parsed recipient (contact name or phone number)
    ///   - message: The parsed message content
    func prepareMessage(recipient: String, message: String) {
        self.recipient = recipient
        self.message = message
        self.errorMessage = nil
        self.successMessage = nil
        self.resolvedContact = nil
        self.isSending = false
    }
    
    /// Validates the current message state
    /// - Returns: True if the message is valid and can be sent
    var isValid: Bool {
        !recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Sends the message after resolving the recipient
    func sendMessage() async {
        guard isValid else {
            errorMessage = "Please enter both a recipient and a message"
            return
        }
        
        isSending = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // 1. Resolve recipient (contact name or phone number)
            var phoneNumber: String
            
            do {
                phoneNumber = try await ContactsService.shared.lookupPhoneNumber(for: recipient)
                resolvedContact = phoneNumber
                print("[MessagingViewModel] Resolved '\(recipient)' to phone number: \(phoneNumber)")
            } catch ContactsError.authorizationDenied {
                print("[MessagingViewModel] ❌ Contacts access denied")
                errorMessage = "Contacts access denied. Please grant permission in System Settings."
                isSending = false
                return
            } catch ContactsError.contactNotFound(let name) {
                print("[MessagingViewModel] ❌ Contact '\(name)' not found")
                errorMessage = "Contact '\(name)' not found in your contacts"
                isSending = false
                return
            } catch ContactsError.noPhoneNumber(let name) {
                print("[MessagingViewModel] ❌ Contact '\(name)' has no phone number")
                errorMessage = "'\(name)' has no phone number in contacts"
                isSending = false
                return
            } catch {
                print("[MessagingViewModel] ⚠️ Contact lookup failed, using recipient as-is: \(error.localizedDescription)")
                phoneNumber = recipient
            }
            
            // 2. Send the message via MessagingService
            print("[MessagingViewModel] Sending message to \(phoneNumber)...")
            let messagingResult = await MessagingService.shared.sendMessage(
                message,
                to: phoneNumber,
                using: .appleScript
            )
            
            // 3. Handle the result
            switch messagingResult {
            case .success:
                print("[MessagingViewModel] ✅ Message sent successfully")
                successMessage = "Message sent to \(recipient)"
                
                // Wait a moment for user to see success, then close
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                await cancel()
                
            case .failure(let error):
                print("[MessagingViewModel] ❌ Failed to send message: \(error.localizedDescription)")
                
                // Provide specific error messages
                switch error {
                case .appleScriptFailed(let details):
                    errorMessage = "Failed to send: AppleScript error - \(details)"
                case .invalidRecipient:
                    errorMessage = "Invalid recipient '\(phoneNumber)'"
                case .messagesAppNotAvailable:
                    errorMessage = "Messages app not available"
                default:
                    errorMessage = "Failed to send: \(error.localizedDescription)"
                }
            }
            
        } catch {
            print("[MessagingViewModel] ❌ Unexpected error: \(error.localizedDescription)")
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
        
        isSending = false
    }
    
    /// Cancels the message and returns to the previous view
    func cancel() async {
        print("[MessagingViewModel] Canceling message")
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
        message = ""
        isSending = false
        errorMessage = nil
        successMessage = nil
        resolvedContact = nil
    }
}

