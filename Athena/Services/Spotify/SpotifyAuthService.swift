//
//  SpotifyAuthService.swift
//  Athena
//
//  Created by Cursor on 11/9/25.
//

import Foundation
import AppKit

/// Errors that can occur during Spotify OAuth operations
enum SpotifyAuthError: Error, LocalizedError {
    case configurationMissing
    case configurationInvalid
    case userCancelled
    case sessionExpired
    case noActiveSession
    case invalidAuthorizationCode
    case authorizationDenied(String)
    case stateMismatch
    case tokenExchangeFailed(Error)
    case networkError(Error)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "Spotify OAuth configuration file (SpotifySecurity.plist) is missing."
        case .configurationInvalid:
            return "Spotify OAuth configuration is invalid. Check CLIENT_ID and CLIENT_SECRET."
        case .userCancelled:
            return "User cancelled the authorization."
        case .sessionExpired:
            return "Spotify OAuth session has expired. Please sign in again."
        case .noActiveSession:
            return "No active Spotify OAuth session. Please sign in first."
        case .invalidAuthorizationCode:
            return "Invalid authorization code received from Spotify."
        case .authorizationDenied(let reason):
            return "Authorization denied: \(reason)"
        case .stateMismatch:
            return "State parameter mismatch - possible CSRF attack detected."
        case .tokenExchangeFailed(let error):
            return "Failed to exchange authorization code for access token: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error during Spotify OAuth: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Unknown Spotify OAuth error: \(error.localizedDescription)"
        }
    }
}

/// Standard Spotify OAuth scopes
struct SpotifyOAuthScopes {
    // User data
    static let userReadPrivate = "user-read-private"
    static let userReadEmail = "user-read-email"
    
    // Playback
    static let userReadPlaybackState = "user-read-playback-state"
    static let userModifyPlaybackState = "user-modify-playback-state"
    static let userReadCurrentlyPlaying = "user-read-currently-playing"
    
    // Library
    static let userLibraryRead = "user-library-read"
    static let userLibraryModify = "user-library-modify"
    
    // Playlists
    static let playlistReadPrivate = "playlist-read-private"
    static let playlistModifyPublic = "playlist-modify-public"
    static let playlistModifyPrivate = "playlist-modify-private"
    
    // Recently played
    static let userReadRecentlyPlayed = "user-read-recently-played"
    
    // Top items
    static let userTopRead = "user-top-read"
    
    /// Default scopes for basic authentication and playback control
    static var defaultScopes: [String] {
        [
            userReadPrivate,
            userReadEmail,
            userReadPlaybackState,
            userModifyPlaybackState,
            userReadCurrentlyPlaying
        ]
    }
    
    /// All available scopes (for full access)
    static var allScopes: [String] {
        [
            userReadPrivate,
            userReadEmail,
            userReadPlaybackState,
            userModifyPlaybackState,
            userReadCurrentlyPlaying,
            userLibraryRead,
            userLibraryModify,
            playlistReadPrivate,
            playlistModifyPublic,
            playlistModifyPrivate,
            userReadRecentlyPlayed,
            userTopRead
        ]
    }
}

/// Represents a Spotify OAuth session with tokens
struct SpotifyAuthSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scopes: [String]
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
    
    var isValid: Bool {
        !isExpired
    }
}

/// Service for managing Spotify OAuth authentication and session
@MainActor
class SpotifyAuthService {
    static let shared = SpotifyAuthService()
    
    // MARK: - Properties
    
    private let keychainManager = KeychainManager.shared
    private let keychainKey = "spotify_auth_session"
    private var currentSession: SpotifyAuthSession?
    
    // OAuth endpoints
    private let authorizationEndpoint = "https://accounts.spotify.com/authorize"
    private let tokenEndpoint = "https://accounts.spotify.com/api/token"
    
    // State parameter for CSRF protection
    private var currentState: String?
    
    // Lazy-loaded configuration from plist
    private lazy var clientID: String = {
        loadConfiguration().clientID
    }()
    
    private lazy var clientSecret: String = {
        loadConfiguration().clientSecret
    }()
    
    private lazy var redirectURI: String = {
        "athena://spotify-callback"
    }()
    
    // Configuration structure
    private struct SpotifyConfig {
        let clientID: String
        let clientSecret: String
    }
    
    // MARK: - Initialization
    
    private init() {
        // Attempt to restore saved session on initialization
        restoreSession()
    }
    
    // MARK: - Configuration Loading
    
    /// Loads Spotify OAuth configuration from SpotifySecurity.plist
    private func loadConfiguration() -> SpotifyConfig {
        guard let path = Bundle.main.path(forResource: "SpotifySecurity", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) as? [String: String],
              let clientID = config["CLIENT_ID"],
              let clientSecret = config["CLIENT_SECRET"] else {
            fatalError("SpotifySecurity.plist not found or invalid. Please create it with CLIENT_ID and CLIENT_SECRET keys.")
        }
        
        // Validate configuration
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            fatalError("CLIENT_ID or CLIENT_SECRET in SpotifySecurity.plist cannot be empty.")
        }
        
        return SpotifyConfig(clientID: clientID, clientSecret: clientSecret)
    }
    
    // MARK: - Authorization Flow
    
    /// Initiates Spotify OAuth authorization flow
    /// - Parameters:
    ///   - scopes: Array of OAuth scopes to request (defaults to basic scopes)
    /// - Returns: Authorized SpotifyAuthSession
    /// - Throws: SpotifyAuthError on failure
    func authorize(scopes: [String] = SpotifyOAuthScopes.defaultScopes) async throws -> SpotifyAuthSession {
        // Generate random state for CSRF protection
        let state = generateRandomState()
        currentState = state
        
        // Build authorization URL
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        
        guard let authURL = components.url else {
            throw SpotifyAuthError.configurationInvalid
        }
        
        print("[SpotifyAuth] 🎵 Opening authorization URL: \(authURL)")
        
        // Open browser for user authorization
        NSWorkspace.shared.open(authURL)
        
        // Wait for callback URL with proper timeout handling
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            var timeoutTask: Task<Void, Never>?
            
            AppDelegate.spotifyAuthCallback = { url in
                timeoutTask?.cancel()
                continuation.resume(returning: url)
            }
            
            // Set timeout for user to complete authorization
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 minutes
                if !Task.isCancelled {
                    AppDelegate.spotifyAuthCallback = nil
                    continuation.resume(throwing: SpotifyAuthError.userCancelled)
                }
            }
        }
        
        print("[SpotifyAuth] 🔗 Received callback URL: \(callbackURL)")
        
        // Extract and validate authorization code from URL
        let code = try extractAuthorizationCode(from: callbackURL, expectedState: state)
        
        // Clear state after use
        currentState = nil
        
        print("[SpotifyAuth] ✓ Authorization code extracted and validated")
        
        // Exchange code for access token
        let session = try await exchangeCodeForToken(code: code, scopes: scopes)
        
        // Save session
        try saveSession(session)
        currentSession = session
        
        print("[SpotifyAuth] ✓ Authorization complete, session saved")
        
        return session
    }
    
    /// Generates a random state string for CSRF protection
    private func generateRandomState() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<16).map { _ in letters.randomElement()! })
    }
    
    /// Extracts and validates authorization code from callback URL
    private func extractAuthorizationCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw SpotifyAuthError.invalidAuthorizationCode
        }
        
        // Check for error from Spotify
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            print("[SpotifyAuth] ❌ Authorization error: \(error)")
            throw SpotifyAuthError.authorizationDenied(error)
        }
        
        // Verify state parameter matches (CSRF protection)
        let receivedState = queryItems.first(where: { $0.name == "state" })?.value
        guard receivedState == expectedState else {
            print("[SpotifyAuth] ❌ State mismatch: expected \(expectedState), got \(receivedState ?? "nil")")
            throw SpotifyAuthError.stateMismatch
        }
        
        // Extract code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw SpotifyAuthError.invalidAuthorizationCode
        }
        
        return code
    }
    
    /// Exchanges authorization code for access token
    private func exchangeCodeForToken(code: String, scopes: [String]) async throws -> SpotifyAuthSession {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create Basic Authentication header with base64 encoded credentials
        let credentials = "\(clientID):\(clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw SpotifyAuthError.configurationInvalid
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Build request body (WITHOUT client_id and client_secret - they go in the header)
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        
        request.httpBody = components.query?.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpotifyAuthError.networkError(URLError(.badServerResponse))
            }
            
            print("[SpotifyAuth] Token exchange response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("[SpotifyAuth] Token exchange error: \(errorString)")
                }
                throw SpotifyAuthError.tokenExchangeFailed(
                    NSError(domain: "SpotifyAuth", code: httpResponse.statusCode,
                           userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                )
            }
            
            // Parse response
            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            
            // Create session
            let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            return SpotifyAuthSession(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: expiresAt,
                scopes: scopes
            )
            
        } catch let error as SpotifyAuthError {
            throw error
        } catch {
            throw SpotifyAuthError.tokenExchangeFailed(error)
        }
    }
    
    /// Refreshes the access token using refresh token
    func refreshToken() async throws -> SpotifyAuthSession {
        guard let session = currentSession,
              let refreshToken = session.refreshToken else {
            throw SpotifyAuthError.noActiveSession
        }
        
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create Basic Authentication header with base64 encoded credentials
        let credentials = "\(clientID):\(clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw SpotifyAuthError.configurationInvalid
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Build request body (WITHOUT client_id and client_secret - they go in the header)
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        
        request.httpBody = components.query?.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            
            // Create new session with refreshed token
            let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            let newSession = SpotifyAuthSession(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? refreshToken, // Use new refresh token if provided, otherwise keep old one
                expiresAt: expiresAt,
                scopes: session.scopes
            )
            
            // Save and update
            try saveSession(newSession)
            currentSession = newSession
            
            print("[SpotifyAuth] ✓ Token refreshed successfully")
            
            return newSession
            
        } catch {
            throw SpotifyAuthError.tokenExchangeFailed(error)
        }
    }
    
    // MARK: - Session Management
    
    /// Gets a valid access token, refreshing if necessary
    func getValidAccessToken() async throws -> String {
        guard let session = currentSession else {
            throw SpotifyAuthError.noActiveSession
        }
        
        // If token is expired, refresh it
        if session.isExpired {
            print("[SpotifyAuth] 🔄 Token expired, refreshing...")
            let newSession = try await refreshToken()
            return newSession.accessToken
        }
        
        return session.accessToken
    }
    
    /// Checks if user is authenticated
    func isAuthenticated() -> Bool {
        return currentSession != nil
    }
    
    /// Gets current session if valid
    func currentValidSession() -> SpotifyAuthSession? {
        guard let session = currentSession, session.isValid else {
            return nil
        }
        return session
    }
    
    /// Signs out the user
    func signOut() throws {
        try keychainManager.delete(for: keychainKey)
        currentSession = nil
        print("[SpotifyAuth] 👋 User signed out")
    }
    
    // MARK: - Persistence
    
    /// Saves session to keychain
    private func saveSession(_ session: SpotifyAuthSession) throws {
        try keychainManager.save(session, for: keychainKey)
    }
    
    /// Restores session from keychain
    private func restoreSession() {
        do {
            let session = try keychainManager.retrieve(for: keychainKey, as: SpotifyAuthSession.self)
            
            // Only restore if not expired
            if !session.isExpired {
                currentSession = session
                print("[SpotifyAuth] ✓ Session restored from keychain")
            } else {
                print("[SpotifyAuth] ⚠️ Stored session is expired")
                // Try to refresh automatically
                Task {
                    do {
                        currentSession = session // Set it temporarily so we can use the refresh token
                        _ = try await refreshToken()
                    } catch {
                        print("[SpotifyAuth] ❌ Failed to refresh expired session: \(error)")
                    }
                }
            }
        } catch KeychainError.itemNotFound {
            print("[SpotifyAuth] ℹ️ No stored session found")
        } catch {
            print("[SpotifyAuth] ⚠️ Failed to restore session: \(error)")
        }
    }
}

// MARK: - Token Response Model

private struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

