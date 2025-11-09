//
//  SpotifyService.swift
//  Athena
//
//  Created by Cursor on 11/9/25.
//
//  Example service showing how to interact with Spotify Web API

import Foundation

/// Errors that can occur during Spotify API operations
enum SpotifyAPIError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Spotify. Please sign in first."
        case .invalidResponse:
            return "Invalid response from Spotify API."
        case .httpError(let code, let message):
            return "Spotify API error (\(code)): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode Spotify response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Models for Spotify API responses
struct SpotifyCurrentPlayback: Codable {
    let isPlaying: Bool
    let item: SpotifyTrack?
    let progressMs: Int?
    let device: SpotifyDevice?
    
    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
        case progressMs = "progress_ms"
        case device
    }
}

struct SpotifyTrack: Codable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let durationMs: Int
    let uri: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, uri
        case durationMs = "duration_ms"
    }
}

struct SpotifyArtist: Codable {
    let id: String
    let name: String
    let uri: String
}

struct SpotifyAlbum: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let uri: String
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

struct SpotifyDevice: Codable {
    let id: String
    let name: String
    let type: String
    let isActive: Bool
    let volumePercent: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, type
        case isActive = "is_active"
        case volumePercent = "volume_percent"
    }
}

struct SpotifyUserProfile: Codable {
    let id: String
    let displayName: String?
    let email: String?
    let images: [SpotifyImage]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case images
    }
}

/// Service for interacting with Spotify Web API
@MainActor
class SpotifyService {
    static let shared = SpotifyService()
    
    private let authService = SpotifyAuthService.shared
    private let baseURL = "https://api.spotify.com/v1"
    
    private init() {}
    
    // MARK: - Private Helpers
    
    /// Creates an authenticated URLRequest
    private func createRequest(endpoint: String, method: String = "GET") async throws -> URLRequest {
        let token = try await authService.getValidAccessToken()
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw SpotifyAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    /// Performs API request and decodes response
    private func performRequest<T: Decodable>(_ request: URLRequest, expecting type: T.Type) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpotifyAPIError.invalidResponse
            }
            
            // Check for HTTP errors
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw SpotifyAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // Decode response
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
            
        } catch let error as SpotifyAPIError {
            throw error
        } catch let error as DecodingError {
            throw SpotifyAPIError.decodingError(error)
        } catch {
            throw SpotifyAPIError.networkError(error)
        }
    }
    
    /// Performs API request without expecting a response body
    private func performRequest(_ request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw SpotifyAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    // MARK: - User Profile
    
    /// Gets the current user's profile
    func getCurrentUserProfile() async throws -> SpotifyUserProfile {
        let request = try await createRequest(endpoint: "/me")
        return try await performRequest(request, expecting: SpotifyUserProfile.self)
    }
    
    // MARK: - Playback
    
    /// Gets the current playback state
    func getCurrentPlayback() async throws -> SpotifyCurrentPlayback? {
        let request = try await createRequest(endpoint: "/me/player")
        
        // Note: This endpoint returns 204 if nothing is playing
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpotifyAPIError.invalidResponse
            }
            
            // 204 means no content (nothing playing)
            if httpResponse.statusCode == 204 {
                return nil
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw SpotifyAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(SpotifyCurrentPlayback.self, from: data)
            
        } catch let error as SpotifyAPIError {
            throw error
        } catch {
            throw SpotifyAPIError.networkError(error)
        }
    }
    
    /// Starts or resumes playback
    func play(deviceId: String? = nil) async throws {
        var endpoint = "/me/player/play"
        if let deviceId = deviceId {
            endpoint += "?device_id=\(deviceId)"
        }
        
        var request = try await createRequest(endpoint: endpoint, method: "PUT")
        request.httpBody = Data() // Empty body required
        
        try await performRequest(request)
    }
    
    /// Pauses playback
    func pause(deviceId: String? = nil) async throws {
        var endpoint = "/me/player/pause"
        if let deviceId = deviceId {
            endpoint += "?device_id=\(deviceId)"
        }
        
        var request = try await createRequest(endpoint: endpoint, method: "PUT")
        request.httpBody = Data() // Empty body required
        
        try await performRequest(request)
    }
    
    /// Skips to next track
    func skipToNext(deviceId: String? = nil) async throws {
        var endpoint = "/me/player/next"
        if let deviceId = deviceId {
            endpoint += "?device_id=\(deviceId)"
        }
        
        var request = try await createRequest(endpoint: endpoint, method: "POST")
        request.httpBody = Data() // Empty body required
        
        try await performRequest(request)
    }
    
    /// Skips to previous track
    func skipToPrevious(deviceId: String? = nil) async throws {
        var endpoint = "/me/player/previous"
        if let deviceId = deviceId {
            endpoint += "?device_id=\(deviceId)"
        }
        
        var request = try await createRequest(endpoint: endpoint, method: "POST")
        request.httpBody = Data() // Empty body required
        
        try await performRequest(request)
    }
    
    /// Sets playback volume (0-100)
    func setVolume(_ volumePercent: Int, deviceId: String? = nil) async throws {
        guard (0...100).contains(volumePercent) else {
            throw SpotifyAPIError.invalidResponse
        }
        
        var endpoint = "/me/player/volume?volume_percent=\(volumePercent)"
        if let deviceId = deviceId {
            endpoint += "&device_id=\(deviceId)"
        }
        
        var request = try await createRequest(endpoint: endpoint, method: "PUT")
        request.httpBody = Data() // Empty body required
        
        try await performRequest(request)
    }
    
    /// Seeks to position in current track (milliseconds)
    func seek(to positionMs: Int, deviceId: String? = nil) async throws {
        var endpoint = "/me/player/seek?position_ms=\(positionMs)"
        if let deviceId = deviceId {
            endpoint += "&device_id=\(deviceId)"
        }
        
        var request = try await createRequest(endpoint: endpoint, method: "PUT")
        request.httpBody = Data() // Empty body required
        
        try await performRequest(request)
    }
    
    // MARK: - Search
    
    /// Search for tracks
    func searchTracks(query: String, limit: Int = 20) async throws -> [SpotifyTrack] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let endpoint = "/search?q=\(encodedQuery)&type=track&limit=\(limit)"
        
        let request = try await createRequest(endpoint: endpoint)
        
        struct SearchResponse: Codable {
            struct Tracks: Codable {
                let items: [SpotifyTrack]
            }
            let tracks: Tracks
        }
        
        let response = try await performRequest(request, expecting: SearchResponse.self)
        return response.tracks.items
    }
    
    // MARK: - Playback Control with URI
    
    /// Play a specific track by URI
    func playTrack(uri: String, deviceId: String? = nil) async throws {
        var endpoint = "/me/player/play"
        if let deviceId = deviceId {
            endpoint += "?device_id=\(deviceId)"
        }
        
        var request = try await createRequest(endpoint: endpoint, method: "PUT")
        
        let body: [String: Any] = ["uris": [uri]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        try await performRequest(request)
    }
}

