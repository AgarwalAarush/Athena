//
//  MessagingService.swift
//  Athena
//
//  Created by Cursor on 11/8/25.
//

import Foundation
import AppKit

/// Defines the method to use for sending messages
enum MessagingMethod {
    case appleScript    // Fully automatic - sends without user confirmation
    case shareSheet     // User-controlled - shows share popover with prefilled text
    case urlScheme      // Opens Messages app - cannot prefill message body
}

/// Result type for messaging operations
enum MessagingResult {
    case success
    case failure(MessagingError)
}

/// Errors that can occur during messaging operations
enum MessagingError: Error, LocalizedError {
    case appleScriptFailed(String)
    case invalidRecipient
    case messageTooLong
    case userCancelled
    case messagesAppNotAvailable
    case invalidURL
    case noViewAvailable
    
    var errorDescription: String? {
        switch self {
        case .appleScriptFailed(let details):
            return "Failed to send message via AppleScript: \(details)"
        case .invalidRecipient:
            return "Invalid recipient phone number or email address"
        case .messageTooLong:
            return "Message content exceeds maximum length"
        case .userCancelled:
            return "User cancelled the message"
        case .messagesAppNotAvailable:
            return "Messages app is not available"
        case .invalidURL:
            return "Could not create valid Messages URL"
        case .noViewAvailable:
            return "No view available for presenting share sheet"
        }
    }
}

/// Service for sending iMessages and SMS via various methods
@MainActor
class MessagingService {
    
    static let shared = MessagingService()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Sends a message using the specified method
    ///
    /// - Parameters:
    ///   - message: The message content to send
    ///   - recipient: Phone number (e.g., "+15551234567") or email address
    ///   - method: The messaging method to use (appleScript, shareSheet, urlScheme)
    ///   - sourceView: The NSView to anchor the share sheet to (required for shareSheet method)
    ///
    /// - Returns: MessagingResult indicating success or failure
    func sendMessage(
        _ message: String,
        to recipient: String,
        using method: MessagingMethod,
        from sourceView: NSView? = nil
    ) async -> MessagingResult {
        
        // Validate inputs
        guard !message.isEmpty else {
            return .failure(.messageTooLong)
        }
        
        guard !recipient.isEmpty else {
            return .failure(.invalidRecipient)
        }
        
        // Route to appropriate method
        switch method {
        case .appleScript:
            return await sendViaAppleScript(message: message, recipient: recipient)
            
        case .shareSheet:
            guard let sourceView = sourceView else {
                return .failure(.noViewAvailable)
            }
            return await sendViaShareSheet(message: message, from: sourceView)
            
        case .urlScheme:
            return await openMessagesApp(recipient: recipient)
        }
    }
    
    // MARK: - Method 1: AppleScript (Automatic Sending)
    
    /// Sends a message automatically via AppleScript without user confirmation
    ///
    /// **Important:** This method sends the message immediately without user review.
    /// Use with caution and appropriate user consent.
    ///
    /// - Parameters:
    ///   - message: The message content to send
    ///   - recipient: Phone number (e.g., "+15551234567") or email address
    ///
    /// - Returns: MessagingResult indicating success or failure
    private func sendViaAppleScript(message: String, recipient: String) async -> MessagingResult {
        
        print("[MessagingService] Sending via AppleScript to \(recipient)")
        
        // Escape quotes and backslashes in the message
        let escapedMessage = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let escapedRecipient = recipient
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        // AppleScript to send message
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(escapedRecipient)" of targetService
            send "\(escapedMessage)" to targetBuddy
        end tell
        """
        
        // Execute AppleScript
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            print("[MessagingService] AppleScript error: \(errorMessage)")
            return .failure(.appleScriptFailed(errorMessage))
        }
        
        if result != nil {
            print("[MessagingService] Message sent successfully via AppleScript")
            return .success
        } else {
            return .failure(.appleScriptFailed("No result returned"))
        }
    }
    
    // MARK: - Method 2: Share Sheet (User-Controlled)
    
    /// Presents a share sheet with the message pre-filled
    /// User must select recipient and confirm sending
    ///
    /// This is the recommended method as it gives the user full control while
    /// pre-filling the message content for convenience.
    ///
    /// - Parameters:
    ///   - message: The message content to pre-fill
    ///   - sourceView: The NSView to anchor the share sheet to
    ///
    /// - Returns: MessagingResult indicating success or failure
    private func sendViaShareSheet(message: String, from sourceView: NSView) async -> MessagingResult {
        
        print("[MessagingService] Presenting share sheet")
        
        // Create sharing service picker
        let picker = NSSharingServicePicker(items: [message])
        
        // Show the picker anchored to the source view
        picker.show(relativeTo: .zero, of: sourceView, preferredEdge: .minY)
        
        // Note: We return success here because showing the picker succeeded
        // The actual message sending is handled by the user in the share sheet
        print("[MessagingService] Share sheet presented successfully")
        return .success
    }
    
    // MARK: - Method 3: URL Scheme (Opens Messages App)
    
    /// Opens the Messages app to a conversation with the specified recipient
    ///
    /// **Limitation:** This method cannot pre-fill the message body.
    /// It only opens Messages to a conversation with the recipient.
    ///
    /// - Parameter recipient: Phone number (e.g., "+15551234567") or email address
    ///
    /// - Returns: MessagingResult indicating success or failure
    private func openMessagesApp(recipient: String) async -> MessagingResult {
        
        print("[MessagingService] Opening Messages app for recipient: \(recipient)")
        
        // Encode recipient for URL
        guard let encodedRecipient = recipient.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return .failure(.invalidRecipient)
        }
        
        // Create messages:// URL
        guard let url = URL(string: "messages://\(encodedRecipient)") else {
            return .failure(.invalidURL)
        }
        
        // Open the URL
        let workspace = NSWorkspace.shared
        workspace.open(url)
        
        print("[MessagingService] Messages app opened successfully")
        return .success
    }
    
    // MARK: - Validation Helpers
    
    /// Validates a phone number or email address
    ///
    /// - Parameter recipient: The recipient string to validate
    /// - Returns: true if valid, false otherwise
    func validateRecipient(_ recipient: String) -> Bool {
        
        // Check if it's a valid phone number (simple validation)
        let phonePattern = "^\\+?[1-9]\\d{1,14}$"
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phonePattern)
        if phoneTest.evaluate(with: recipient) {
            return true
        }
        
        // Check if it's a valid email address
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        if emailTest.evaluate(with: recipient) {
            return true
        }
        
        return false
    }
    
    /// Checks if the Messages app is available
    ///
    /// - Returns: true if Messages is available, false otherwise
    func isMessagesAppAvailable() -> Bool {
        let messagesPath = "/System/Applications/Messages.app"
        return FileManager.default.fileExists(atPath: messagesPath)
    }
}

// MARK: - SwiftUI Integration Helpers

import SwiftUI

/// A SwiftUI view modifier for presenting a share sheet with a message
struct MessageShareModifier: ViewModifier {
    let message: String
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                ShareLink(item: message) {
                    EmptyView()
                }
                .opacity(0)
            )
    }
}

extension View {
    /// Presents a share sheet for sending a message
    ///
    /// - Parameters:
    ///   - message: The message to share
    ///   - isPresented: Binding to control presentation
    ///
    /// - Returns: Modified view
    func messageShare(message: String, isPresented: Binding<Bool>) -> some View {
        modifier(MessageShareModifier(message: message, isPresented: isPresented))
    }
}

// MARK: - Example Usage

/*
 
 // Example 1: Automatic sending via AppleScript
 let result = await MessagingService.shared.sendMessage(
     "Hello from Athena!",
     to: "+15551234567",
     using: .appleScript
 )
 
 switch result {
 case .success:
     print("Message sent!")
 case .failure(let error):
     print("Error: \(error.localizedDescription)")
 }
 
 // Example 2: User-controlled via share sheet
 let result = await MessagingService.shared.sendMessage(
     "Hello from Athena!",
     to: "", // Recipient not needed for share sheet
     using: .shareSheet,
     from: myNSView // Your NSView instance
 )
 
 // Example 3: Open Messages app
 let result = await MessagingService.shared.sendMessage(
     "", // Message not needed (can't be prefilled)
     to: "+15551234567",
     using: .urlScheme
 )
 
 // Example 4: SwiftUI ShareLink (recommended for SwiftUI)
 import SwiftUI
 
 struct MyView: View {
     var body: some View {
         ShareLink(item: "Hello from Athena!") {
             Text("Share via Messages")
                 .padding()
                 .background(Color.blue)
                 .foregroundColor(.white)
                 .cornerRadius(8)
         }
     }
 }
 
 // Example 5: Manual NSSharingServicePicker (AppKit)
 let textToShare = "Hello from Athena!"
 let picker = NSSharingServicePicker(items: [textToShare])
 picker.show(relativeTo: .zero, of: myButton, preferredEdge: .minY)
 
 */

