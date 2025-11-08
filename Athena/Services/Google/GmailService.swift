//
//  GmailService.swift
//  Athena
//
//  Created by Claude Code on 11/7/25.
//

import Foundation
import GoogleAPIClientForREST_Gmail
import GTMAppAuth

/// Errors that can occur during Gmail operations
enum GmailServiceError: Error, LocalizedError {
    case notAuthenticated
    case authorizationFailed(Error)
    case messageNotFound
    case sendFailed(Error)
    case fetchFailed(Error)
    case invalidMessageFormat
    case attachmentError(Error)
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Google. Please sign in first."
        case .authorizationFailed(let error):
            return "Gmail authorization failed: \(error.localizedDescription)"
        case .messageNotFound:
            return "The requested email message was not found."
        case .sendFailed(let error):
            return "Failed to send email: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch emails: \(error.localizedDescription)"
        case .invalidMessageFormat:
            return "Invalid email message format."
        case .attachmentError(let error):
            return "Failed to process attachment: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Unknown Gmail error: \(error.localizedDescription)"
        }
    }
}

/// Service for managing Gmail operations
@MainActor
class GmailService {
    static let shared = GmailService()

    // MARK: - Properties

    private let authService = GoogleAuthService.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Gmail Service Setup

    /// Creates and configures a GTLRGmailService instance with current authorization
    /// - Returns: Configured GTLRGmailService
    /// - Throws: GmailServiceError if authorization fails
    private func getGmailService() throws -> GTLRGmailService {
        // Get authorization from GoogleAuthService
        guard let authorization = try? authService.getAuthorization() else {
            throw GmailServiceError.notAuthenticated
        }

        // Create Gmail service
        let service = GTLRGmailService()

        // Assign authorizer (GTMAppAuthFetcherAuthorization)
        service.authorizer = authorization

        return service
    }

    // MARK: - List & Fetch Messages

    /// Fetches a list of messages from the inbox
    /// - Parameters:
    ///   - maxResults: Maximum number of messages to fetch (default: 10)
    ///   - query: Optional search query (e.g., "is:unread", "from:example@gmail.com")
    /// - Returns: Array of GTLRGmail_Message objects
    /// - Throws: GmailServiceError on failure
    func listMessages(maxResults: Int = 10, query: String? = nil) async throws -> [GTLRGmail_Message] {
        let service = try getGmailService()

        // Create query to list messages
        let listQuery = GTLRGmailQuery_UsersMessagesList.query(withUserId: "me")
        listQuery.maxResults = UInt(maxResults)
        if let query = query {
            listQuery.q = query
        }

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(listQuery) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GmailServiceError.fetchFailed(error))
                        return
                    }

                    guard let messageList = result as? GTLRGmail_ListMessagesResponse else {
                        continuation.resume(returning: [])
                        return
                    }

                    // If we have message IDs, fetch full message details
                    guard let messages = messageList.messages, !messages.isEmpty else {
                        continuation.resume(returning: [])
                        return
                    }

                    // Fetch full details for each message
                    Task {
                        do {
                            let fullMessages = try await self.fetchMessageDetails(
                                messageIds: messages.compactMap { $0.identifier }
                            )
                            continuation.resume(returning: fullMessages)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    /// Fetches full details for multiple messages
    /// - Parameter messageIds: Array of message IDs to fetch
    /// - Returns: Array of full GTLRGmail_Message objects
    /// - Throws: GmailServiceError on failure
    private func fetchMessageDetails(messageIds: [String]) async throws -> [GTLRGmail_Message] {
        var fullMessages: [GTLRGmail_Message] = []

        for messageId in messageIds {
            let message = try await getMessage(messageId: messageId)
            fullMessages.append(message)
        }

        return fullMessages
    }

    /// Fetches a single message by ID
    /// - Parameter messageId: The ID of the message to fetch
    /// - Returns: Full GTLRGmail_Message object
    /// - Throws: GmailServiceError on failure
    func getMessage(messageId: String) async throws -> GTLRGmail_Message {
        let service = try getGmailService()

        let query = GTLRGmailQuery_UsersMessagesGet.query(withUserId: "me", identifier: messageId)
        query.format = kGTLRGmailFormatFull // Get full message including body

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GmailServiceError.fetchFailed(error))
                        return
                    }

                    guard let message = result as? GTLRGmail_Message else {
                        continuation.resume(throwing: GmailServiceError.messageNotFound)
                        return
                    }

                    continuation.resume(returning: message)
                }
            }
        }
    }

    /// Searches for messages using Gmail search syntax
    /// - Parameter searchQuery: Gmail search query (e.g., "is:unread from:example@gmail.com")
    /// - Returns: Array of matching GTLRGmail_Message objects
    /// - Throws: GmailServiceError on failure
    func searchMessages(searchQuery: String) async throws -> [GTLRGmail_Message] {
        return try await listMessages(maxResults: 20, query: searchQuery)
    }

    // MARK: - Send Messages

    /// Sends an email message
    /// - Parameters:
    ///   - to: Recipient email address
    ///   - subject: Email subject
    ///   - body: Email body (plain text or HTML)
    ///   - isHTML: Whether the body is HTML (default: false)
    /// - Throws: GmailServiceError on failure
    func sendMessage(to: String, subject: String, body: String, isHTML: Bool = false) async throws {
        let service = try getGmailService()

        // Create MIME message
        let mimeMessage = createMIMEMessage(to: to, subject: subject, body: body, isHTML: isHTML)

        // Convert to base64url encoding (Gmail API requirement)
        guard let messageData = mimeMessage.data(using: .utf8) else {
            throw GmailServiceError.invalidMessageFormat
        }
        let base64Message = messageData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Create Gmail message object
        let gmailMessage = GTLRGmail_Message()
        gmailMessage.raw = base64Message

        // Create send query
        let query = GTLRGmailQuery_UsersMessagesSend.query(withObject: gmailMessage, userId: "me")

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GmailServiceError.sendFailed(error))
                        return
                    }

                    print("✓ Email sent successfully")
                    continuation.resume()
                }
            }
        }
    }

    /// Creates a MIME-formatted email message
    /// - Parameters:
    ///   - to: Recipient email address
    ///   - subject: Email subject
    ///   - body: Email body
    ///   - isHTML: Whether the body is HTML
    /// - Returns: MIME-formatted message string
    private func createMIMEMessage(to: String, subject: String, body: String, isHTML: Bool) -> String {
        let contentType = isHTML ? "text/html; charset=utf-8" : "text/plain; charset=utf-8"

        var message = ""
        message += "To: \(to)\r\n"
        message += "Subject: \(subject)\r\n"
        message += "Content-Type: \(contentType)\r\n"
        message += "\r\n"
        message += body

        return message
    }

    // MARK: - Message Actions

    /// Marks a message as read
    /// - Parameter messageId: The ID of the message to mark as read
    /// - Throws: GmailServiceError on failure
    func markAsRead(messageId: String) async throws {
        try await modifyLabels(messageId: messageId, addLabels: [], removeLabels: ["UNREAD"])
    }

    /// Marks a message as unread
    /// - Parameter messageId: The ID of the message to mark as unread
    /// - Throws: GmailServiceError on failure
    func markAsUnread(messageId: String) async throws {
        try await modifyLabels(messageId: messageId, addLabels: ["UNREAD"], removeLabels: [])
    }

    /// Deletes a message (moves to trash)
    /// - Parameter messageId: The ID of the message to delete
    /// - Throws: GmailServiceError on failure
    func deleteMessage(messageId: String) async throws {
        let service = try getGmailService()

        let query = GTLRGmailQuery_UsersMessagesTrash.query(withUserId: "me", identifier: messageId)

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GmailServiceError.unknownError(error))
                        return
                    }

                    print("✓ Message moved to trash")
                    continuation.resume()
                }
            }
        }
    }

    /// Modifies labels on a message
    /// - Parameters:
    ///   - messageId: The ID of the message
    ///   - addLabels: Labels to add
    ///   - removeLabels: Labels to remove
    /// - Throws: GmailServiceError on failure
    private func modifyLabels(messageId: String, addLabels: [String], removeLabels: [String]) async throws {
        let service = try getGmailService()

        let modifyRequest = GTLRGmail_ModifyMessageRequest()
        if !addLabels.isEmpty {
            modifyRequest.addLabelIds = addLabels
        }
        if !removeLabels.isEmpty {
            modifyRequest.removeLabelIds = removeLabels
        }

        let query = GTLRGmailQuery_UsersMessagesModify.query(
            withObject: modifyRequest,
            userId: "me",
            identifier: messageId
        )

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GmailServiceError.unknownError(error))
                        return
                    }

                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Extracts the message body from a GTLRGmail_Message
    /// - Parameter message: The Gmail message
    /// - Returns: Decoded message body string
    func extractMessageBody(from message: GTLRGmail_Message) -> String? {
        // Try to get the body from the payload
        if let body = message.payload?.body?.data {
            return decodeBase64URLString(body)
        }

        // If multipart, search in parts
        if let parts = message.payload?.parts {
            for part in parts {
                if let mimeType = part.mimeType,
                   (mimeType == "text/plain" || mimeType == "text/html"),
                   let bodyData = part.body?.data {
                    return decodeBase64URLString(bodyData)
                }

                // Recursively search in nested parts
                if let nestedParts = part.parts {
                    for nestedPart in nestedParts {
                        if let bodyData = nestedPart.body?.data {
                            return decodeBase64URLString(bodyData)
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Extracts email addresses from message headers
    /// - Parameters:
    ///   - message: The Gmail message
    ///   - headerName: Name of header to extract (e.g., "From", "To")
    /// - Returns: Header value string
    func extractHeader(from message: GTLRGmail_Message, headerName: String) -> String? {
        guard let headers = message.payload?.headers else { return nil }

        for header in headers {
            if header.name?.lowercased() == headerName.lowercased() {
                return header.value
            }
        }

        return nil
    }

    /// Decodes base64url-encoded string (Gmail API format)
    /// - Parameter base64URLString: Base64url-encoded string
    /// - Returns: Decoded UTF-8 string
    private func decodeBase64URLString(_ base64URLString: String) -> String? {
        // Convert base64url to standard base64
        var base64String = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String += String(repeating: "=", count: 4 - remainder)
        }

        // Decode
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
