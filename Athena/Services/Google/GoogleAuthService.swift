//
//  GoogleAuthService.swift
//  Athena
//
//  Created by Cursor on 11/7/25.
//

import Foundation
import AppKit
import AppAuth
@_exported import GTMAppAuth

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

/// Standard Google OAuth scopes
struct GoogleOAuthScopes {
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

/// Service for managing Google OAuth authentication and session
@MainActor
class GoogleAuthService {
    static let shared = GoogleAuthService()
    
    // MARK: - Properties
    
    private let configManager = ConfigurationManager.shared
    private var currentAuthorization: AuthSession?
    
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
    
    /// Initiates Google OAuth authorization flow
    /// - Parameters:
    ///   - scopes: Array of OAuth scopes to request (defaults to basic openid and profile)
    ///   - presentingWindow: The NSWindow to present the authorization UI from
    /// - Returns: Authorized AuthSession
    /// - Throws: GoogleAuthError on failure
    func authorize(scopes: [String] = GoogleOAuthScopes.defaultScopes, presentingWindow: NSWindow) async throws -> AuthSession {
        // Get Google's OAuth configuration using discovery
        let issuer = URL(string: "https://accounts.google.com")!
        let configuration = try await discoverConfiguration(issuer: issuer)
        
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
                    
                    // Create AuthSession from OIDAuthState
                    let authorization = AuthSession(authState: authState)
                    
                    // Save authorization
                    do {
                        try self?.saveAuthorization(authorization)
                        let scopesString = scopes.joined(separator: ",")
                        try self?.configManager.saveGoogleAuthScopes(scopesString)
                        
                        // Update current authorization
                        self?.currentAuthorization = authorization
                        
                        print("✓ Google OAuth authorization successful")
                        continuation.resume(returning: authorization)
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
    
    /// Helper to discover OAuth configuration
    private func discoverConfiguration(issuer: URL) async throws -> OIDServiceConfiguration {
        return try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { configuration, error in
                if let error = error {
                    continuation.resume(throwing: GoogleAuthError.networkError(error))
                    return
                }
                
                guard let configuration = configuration else {
                    continuation.resume(throwing: GoogleAuthError.configurationInvalid)
                    return
                }
                
                continuation.resume(returning: configuration)
            }
        }
    }
    
    /// Restores a previously saved authorization from Keychain
    /// - Returns: The restored AuthSession if available
    @discardableResult
    func restoreSession() -> AuthSession? {
        guard let authData = configManager.getGoogleAuthSession() else {
            return nil
        }
        
        do {
            // Unarchive the entire AuthSession directly
            guard let authorization = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: AuthSession.self,
                from: authData
            ) else {
                print("⚠️ Failed to decode AuthSession from Keychain")
                return nil
            }
            
            currentAuthorization = authorization
            print("✓ Google OAuth authorization restored from Keychain")
            return authorization
            
        } catch {
            print("⚠️ Error restoring Google OAuth authorization: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Saves the authorization to Keychain
    /// - Parameter authorization: The AuthSession to save
    private func saveAuthorization(_ authorization: AuthSession) throws {
        do {
            // Archive the entire AuthSession using NSKeyedArchiver (it conforms to NSSecureCoding)
            let authData = try NSKeyedArchiver.archivedData(
                withRootObject: authorization,
                requiringSecureCoding: true
            )
            try configManager.saveGoogleAuthSession(authData)
            
        } catch {
            throw GoogleAuthError.unknownError(error)
        }
    }
    
    /// Refreshes the access token if it's expired or about to expire
    /// - Throws: GoogleAuthError if refresh fails
    func refreshToken() async throws {
        guard let authorization = currentAuthorization else {
            throw GoogleAuthError.noActiveSession
        }
        
        // Perform token refresh using continuation
        return try await withCheckedThrowingContinuation { continuation in
            authorization.authState.performAction { accessToken, idToken, error in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleAuthError.networkError(error))
                        return
                    }
                    
                    // Token refreshed successfully, save updated authorization
                    do {
                        try self.saveAuthorization(authorization)
                        print("✓ Google OAuth token refreshed")
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: GoogleAuthError.unknownError(error))
                    }
                }
            }
        }
    }
    
    /// Signs out the user and clears the stored authorization
    func signOut() {
        do {
            try configManager.deleteGoogleAuthSession()
            try configManager.saveGoogleAuthScopes("")
            currentAuthorization = nil
            print("✓ Google OAuth signed out")
        } catch {
            print("⚠️ Error signing out from Google OAuth: \(error.localizedDescription)")
        }
    }
    
    // MARK: - API Access
    
    /// Returns the current authorization for making Google API calls
    /// - Returns: AuthSession configured with current auth state
    /// - Throws: GoogleAuthError if no active authorization
    func getAuthorization() throws -> AuthSession {
        guard let authorization = currentAuthorization else {
            throw GoogleAuthError.noActiveSession
        }
        
        return authorization
    }
    
    /// Checks if user is currently authenticated
    /// - Returns: true if there's an active authorization
    func isAuthenticated() -> Bool {
        return currentAuthorization != nil && configManager.hasGoogleAuth()
    }
    
    /// Gets the user's email from the current authorization
    /// - Returns: User email if available
    func userEmail() -> String? {
        guard let authState = currentAuthorization?.authState,
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

