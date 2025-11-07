//
//  GoogleAuthService.swift
//  Athena
//
//  Created by Cursor on 11/7/25.
//

import Foundation
import AppKit
import GTMAppAuth
import AppAuth

/// Errors that can occur during Google OAuth operations
enum GoogleAuthError: Error, LocalizedError {
    case configurationMissing
    case configurationInvalid
    case userCancelled
    case sessionExpired
    case noActiveSession
    case networkError(Error)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "Google OAuth configuration file (GoogleSecurity.plist) is missing."
        case .configurationInvalid:
            return "Google OAuth configuration is invalid. Check CLIENT_ID and REVERSED_CLIENT_ID."
        case .userCancelled:
            return "User cancelled the authorization."
        case .sessionExpired:
            return "Google OAuth session has expired. Please sign in again."
        case .noActiveSession:
            return "No active Google OAuth session. Please sign in first."
        case .networkError(let error):
            return "Network error during Google OAuth: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Unknown Google OAuth error: \(error.localizedDescription)"
        }
    }
}

/// Service for managing Google OAuth authentication and session
@MainActor
class GoogleAuthService {
    static let shared = GoogleAuthService()
    
    // MARK: - Properties
    
    private let configManager = ConfigurationManager.shared
    private var currentAuthSession: GTMAuthSession?
    
    // Lazy-loaded configuration from plist
    private lazy var clientID: String = {
        loadConfiguration().clientID
    }()
    
    private lazy var reversedClientID: String = {
        loadConfiguration().reversedClientID
    }()
    
    private lazy var redirectURI: URL = {
        URL(string: "\(reversedClientID):/oauthredirect")!
    }()
    
    // Configuration structure
    private struct GoogleConfig {
        let clientID: String
        let reversedClientID: String
    }
    
    // MARK: - Initialization
    
    private init() {
        // Attempt to restore saved session on initialization
        restoreSession()
    }
    
    // MARK: - Configuration Loading
    
    /// Loads Google OAuth configuration from GoogleSecurity.plist
    private func loadConfiguration() -> GoogleConfig {
        guard let path = Bundle.main.path(forResource: "GoogleSecurity", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) as? [String: String],
              let clientID = config["CLIENT_ID"],
              let reversedClientID = config["REVERSED_CLIENT_ID"] else {
            fatalError("GoogleSecurity.plist not found or invalid. Please create it with CLIENT_ID and REVERSED_CLIENT_ID keys.")
        }
        
        // Validate configuration
        guard !clientID.isEmpty, !reversedClientID.isEmpty else {
            fatalError("CLIENT_ID or REVERSED_CLIENT_ID in GoogleSecurity.plist cannot be empty.")
        }
        
        return GoogleConfig(clientID: clientID, reversedClientID: reversedClientID)
    }
    
    // MARK: - Authorization Flow
    
    /// Standard Google OAuth scopes
    struct Scopes {
        static let openID = OIDScopeOpenID
        static let profile = OIDScopeProfile
        static let calendar = "https://www.googleapis.com/auth/calendar"
        static let calendarReadOnly = "https://www.googleapis.com/auth/calendar.readonly"
        static let drive = "https://www.googleapis.com/auth/drive"
        static let driveReadOnly = "https://www.googleapis.com/auth/drive.readonly"
        static let gmail = "https://mail.google.com/"
        static let gmailReadOnly = "https://www.googleapis.com/auth/gmail.readonly"
        
        /// Default scopes for basic authentication
        static var defaultScopes: [String] {
            [openID, profile]
        }
        
        /// All available scopes (for full access)
        static var allScopes: [String] {
            [openID, profile, calendar, drive, gmail]
        }
    }
    
    /// Initiates Google OAuth authorization flow
    /// - Parameters:
    ///   - scopes: Array of OAuth scopes to request (defaults to basic openid and profile)
    ///   - presentingWindow: The NSWindow to present the authorization UI from
    /// - Returns: Authorized GTMAuthSession
    /// - Throws: GoogleAuthError on failure
    func authorize(scopes: [String] = Scopes.defaultScopes, presentingWindow: NSWindow) async throws -> GTMAuthSession {
        // Get Google's OAuth configuration
        guard let configuration = GTMAuthSession.configurationForGoogle() else {
            throw GoogleAuthError.configurationInvalid
        }
        
        // Create authorization request
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: clientID,
            clientSecret: nil,
            scopes: scopes,
            redirectURL: redirectURI,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )
        
        // Perform authorization using continuation
        return try await withCheckedThrowingContinuation { continuation in
            // Present authorization UI and store the flow session
            let authFlow = OIDAuthState.authState(byPresenting: request, presenting: presentingWindow) { [weak self] authState, error in
                Task { @MainActor in
                    if let error = error {
                        // Check if user cancelled
                        if (error as NSError).domain == OIDGeneralErrorDomain &&
                           (error as NSError).code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue {
                            continuation.resume(throwing: GoogleAuthError.userCancelled)
                        } else if (error as NSError).domain == NSURLErrorDomain {
                            continuation.resume(throwing: GoogleAuthError.networkError(error))
                        } else {
                            continuation.resume(throwing: GoogleAuthError.unknownError(error))
                        }
                        return
                    }
                    
                    guard let authState = authState else {
                        continuation.resume(throwing: GoogleAuthError.unknownError(
                            NSError(domain: "GoogleAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No auth state returned"])
                        ))
                        return
                    }
                    
                    // Create GTMAuthSession from OIDAuthState
                    let authSession = GTMAuthSession(authState: authState)
                    
                    // Save session
                    do {
                        try self?.saveSession(authSession)
                        let scopesString = scopes.joined(separator: ",")
                        try self?.configManager.saveGoogleAuthScopes(scopesString)
                        
                        // Update current session
                        self?.currentAuthSession = authSession
                        
                        print("✓ Google OAuth authorization successful")
                        continuation.resume(returning: authSession)
                    } catch {
                        continuation.resume(throwing: GoogleAuthError.unknownError(error))
                    }
                }
            }
            
            // Store the authorization flow so AppDelegate can resume it with the redirect URL
            if let appDelegate = NSApp.delegate as? AppDelegate {
                type(of: appDelegate).currentAuthorizationFlow = authFlow
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Restores a previously saved authorization session from Keychain
    /// - Returns: The restored GTMAuthSession if available
    @discardableResult
    func restoreSession() -> GTMAuthSession? {
        guard let sessionData = configManager.getGoogleAuthSession() else {
            return nil
        }
        
        do {
            // Unarchive the GTMAuthSession
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: sessionData)
            unarchiver.requiresSecureCoding = true
            
            guard let authSession = try? unarchiver.decodeTopLevelObject(of: GTMAuthSession.self, forKey: NSKeyedArchiveRootObjectKey) else {
                print("⚠️ Failed to decode GTMAuthSession from Keychain")
                return nil
            }
            
            unarchiver.finishDecoding()
            
            currentAuthSession = authSession
            print("✓ Google OAuth session restored from Keychain")
            return authSession
            
        } catch {
            print("⚠️ Error restoring Google OAuth session: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Saves the authorization session to Keychain
    /// - Parameter session: The GTMAuthSession to save
    private func saveSession(_ session: GTMAuthSession) throws {
        do {
            // Archive the session using NSKeyedArchiver
            let archiver = NSKeyedArchiver(requiringSecureCoding: true)
            try archiver.encodeEncodable(session, forKey: NSKeyedArchiveRootObjectKey)
            archiver.finishEncoding()
            
            let sessionData = archiver.encodedData
            try configManager.saveGoogleAuthSession(sessionData)
            
        } catch {
            throw GoogleAuthError.unknownError(error)
        }
    }
    
    /// Refreshes the access token if it's expired or about to expire
    /// - Throws: GoogleAuthError if refresh fails
    func refreshToken() async throws {
        guard let session = currentAuthSession else {
            throw GoogleAuthError.noActiveSession
        }
        
        // Check if token needs refresh
        guard let authState = session.authState else {
            throw GoogleAuthError.sessionExpired
        }
        
        // Perform token refresh using continuation
        return try await withCheckedThrowingContinuation { continuation in
            authState.performAction { accessToken, idToken, error in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleAuthError.networkError(error))
                        return
                    }
                    
                    // Token refreshed successfully, save updated session
                    do {
                        try self.saveSession(session)
                        print("✓ Google OAuth token refreshed")
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: GoogleAuthError.unknownError(error))
                    }
                }
            }
        }
    }
    
    /// Signs out the user and clears the stored session
    func signOut() {
        do {
            try configManager.deleteGoogleAuthSession()
            try configManager.saveGoogleAuthScopes("")
            currentAuthSession = nil
            print("✓ Google OAuth signed out")
        } catch {
            print("⚠️ Error signing out from Google OAuth: \(error.localizedDescription)")
        }
    }
    
    // MARK: - API Access
    
    /// Returns an authorized fetcher service for making Google API calls
    /// - Returns: GTMSessionFetcherService configured with current authorization
    /// - Throws: GoogleAuthError if no active session
    func authorizedFetcher() throws -> GTMSessionFetcherService {
        guard let session = currentAuthSession else {
            throw GoogleAuthError.noActiveSession
        }
        
        let fetcherService = GTMSessionFetcherService()
        fetcherService.authorizer = session
        
        return fetcherService
    }
    
    /// Returns the current authorization session
    /// - Returns: Current GTMAuthSession if available
    func currentSession() -> GTMAuthSession? {
        return currentAuthSession
    }
    
    /// Checks if user is currently authenticated
    /// - Returns: true if there's an active session
    func isAuthenticated() -> Bool {
        return currentAuthSession != nil && configManager.hasGoogleAuth()
    }
    
    /// Gets the user's email from the current session
    /// - Returns: User email if available
    func userEmail() -> String? {
        guard let authState = currentAuthSession?.authState,
              let idToken = authState.lastTokenResponse?.idToken else {
            return nil
        }
        
        // Parse JWT to get email (simple base64 decode of payload)
        let segments = idToken.components(separatedBy: ".")
        guard segments.count > 1,
              let payloadData = Data(base64Encoded: base64Padded(segments[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let email = payload["email"] as? String else {
            return nil
        }
        
        return email
    }
    
    // Helper to pad base64 string
    private func base64Padded(_ string: String) -> String {
        let remainder = string.count % 4
        if remainder > 0 {
            return string.padding(toLength: string.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        return string
    }
}

