//
//  USAGE_EXAMPLE.swift
//  Athena
//
//  Created by Cursor on 11/9/25.
//
//  Complete examples of how to use Spotify integration

import SwiftUI

// MARK: - Example 1: Simple Playback Control View

struct SpotifyPlaybackControlView: View {
    @State private var currentTrack: SpotifyTrack?
    @State private var isPlaying = false
    @State private var errorMessage: String?
    
    private let spotifyService = SpotifyService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Current Track Display
            if let track = currentTrack {
                VStack(spacing: 8) {
                    Text(track.name)
                        .font(.headline)
                    Text(track.artists.map(\.name).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No track playing")
                    .foregroundColor(.secondary)
            }
            
            // Playback Controls
            HStack(spacing: 20) {
                Button(action: previous) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                
                Button(action: next) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            .buttonStyle(.plain)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button("Refresh", action: refreshPlayback)
                .buttonStyle(.bordered)
        }
        .padding()
        .onAppear {
            refreshPlayback()
        }
    }
    
    private func refreshPlayback() {
        Task {
            do {
                if let playback = try await spotifyService.getCurrentPlayback() {
                    await MainActor.run {
                        currentTrack = playback.item
                        isPlaying = playback.isPlaying
                        errorMessage = nil
                    }
                } else {
                    await MainActor.run {
                        currentTrack = nil
                        isPlaying = false
                        errorMessage = "No active playback"
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func togglePlayPause() {
        Task {
            do {
                if isPlaying {
                    try await spotifyService.pause()
                } else {
                    try await spotifyService.play()
                }
                
                // Wait a bit for Spotify to update, then refresh
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                refreshPlayback()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func next() {
        Task {
            do {
                try await spotifyService.skipToNext()
                try? await Task.sleep(nanoseconds: 500_000_000)
                refreshPlayback()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func previous() {
        Task {
            do {
                try await spotifyService.skipToPrevious()
                try? await Task.sleep(nanoseconds: 500_000_000)
                refreshPlayback()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Example 2: Search and Play View

struct SpotifySearchView: View {
    @State private var searchQuery = ""
    @State private var searchResults: [SpotifyTrack] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    private let spotifyService = SpotifyService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                TextField("Search for songs...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                
                Button(action: performSearch) {
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .disabled(searchQuery.isEmpty || isSearching)
            }
            
            // Results List
            if searchResults.isEmpty {
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                } else if !searchQuery.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                }
            } else {
                List(searchResults, id: \.id) { track in
                    Button(action: {
                        playTrack(track)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.name)
                                .font(.headline)
                            Text(track.artists.map(\.name).joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(track.album.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await spotifyService.searchTracks(query: searchQuery, limit: 20)
                
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
    
    private func playTrack(_ track: SpotifyTrack) {
        Task {
            do {
                try await spotifyService.playTrack(uri: track.uri)
                await MainActor.run {
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to play track: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Example 3: User Profile View

struct SpotifyUserProfileView: View {
    @State private var userProfile: SpotifyUserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let spotifyService = SpotifyService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView()
            } else if let profile = userProfile {
                VStack(spacing: 12) {
                    // Profile Image
                    if let imageUrl = profile.images?.first?.url,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                        }
                    }
                    
                    // Profile Info
                    if let displayName = profile.displayName {
                        Text(displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    if let email = profile.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("ID: \(profile.id)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .onAppear {
            loadProfile()
        }
    }
    
    private func loadProfile() {
        Task {
            do {
                let profile = try await spotifyService.getCurrentUserProfile()
                await MainActor.run {
                    userProfile = profile
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Example 4: Integration with Orchestrator

// Example of how to add Spotify controls to your AI orchestrator
extension Orchestrator {
    
    /// Handle Spotify-related commands from the AI
    func handleSpotifyCommand(_ command: String) async throws -> String {
        let spotifyService = SpotifyService.shared
        
        // Parse command (this is a simple example - you'd want more sophisticated parsing)
        if command.lowercased().contains("play") {
            try await spotifyService.play()
            return "Started playback"
            
        } else if command.lowercased().contains("pause") {
            try await spotifyService.pause()
            return "Paused playback"
            
        } else if command.lowercased().contains("next") || command.lowercased().contains("skip") {
            try await spotifyService.skipToNext()
            return "Skipped to next track"
            
        } else if command.lowercased().contains("previous") || command.lowercased().contains("back") {
            try await spotifyService.skipToPrevious()
            return "Went back to previous track"
            
        } else if command.lowercased().contains("what") && command.lowercased().contains("playing") {
            if let playback = try await spotifyService.getCurrentPlayback(),
               let track = playback.item {
                let artists = track.artists.map(\.name).joined(separator: ", ")
                return "Currently playing: \"\(track.name)\" by \(artists)"
            } else {
                return "Nothing is currently playing"
            }
            
        } else {
            return "Unknown Spotify command"
        }
    }
}

// MARK: - Example 5: Complete Spotify Widget

struct SpotifyWidget: View {
    @State private var isAuthenticated = false
    @State private var currentPlayback: SpotifyCurrentPlayback?
    @State private var errorMessage: String?
    
    private let authService = SpotifyAuthService.shared
    private let spotifyService = SpotifyService.shared
    
    var body: some View {
        VStack {
            if !isAuthenticated {
                // Show auth prompt
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Connect to Spotify")
                        .font(.headline)
                    
                    Button("Connect") {
                        authenticate()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Show playback controls
                if let playback = currentPlayback, let track = playback.item {
                    VStack(spacing: 12) {
                        // Album Art
                        if let imageUrl = track.album.images.first?.url,
                           let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .cornerRadius(8)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 200, height: 200)
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Track Info
                        VStack(spacing: 4) {
                            Text(track.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text(track.artists.map(\.name).joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Controls
                        HStack(spacing: 30) {
                            Button(action: { skipToPrevious() }) {
                                Image(systemName: "backward.fill")
                            }
                            
                            Button(action: { togglePlayPause() }) {
                                Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 36))
                            }
                            
                            Button(action: { skipToNext() }) {
                                Image(systemName: "forward.fill")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("No active playback")
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .onAppear {
            checkAuthAndRefresh()
        }
    }
    
    private func checkAuthAndRefresh() {
        isAuthenticated = authService.isAuthenticated()
        if isAuthenticated {
            refreshPlayback()
        }
    }
    
    private func authenticate() {
        Task {
            do {
                _ = try await authService.authorize()
                await MainActor.run {
                    isAuthenticated = true
                    refreshPlayback()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func refreshPlayback() {
        Task {
            do {
                let playback = try await spotifyService.getCurrentPlayback()
                await MainActor.run {
                    currentPlayback = playback
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func togglePlayPause() {
        Task {
            do {
                if currentPlayback?.isPlaying == true {
                    try await spotifyService.pause()
                } else {
                    try await spotifyService.play()
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
                refreshPlayback()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func skipToNext() {
        Task {
            do {
                try await spotifyService.skipToNext()
                try? await Task.sleep(nanoseconds: 500_000_000)
                refreshPlayback()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func skipToPrevious() {
        Task {
            do {
                try await spotifyService.skipToPrevious()
                try? await Task.sleep(nanoseconds: 500_000_000)
                refreshPlayback()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Playback Control") {
    SpotifyPlaybackControlView()
}

#Preview("Search") {
    SpotifySearchView()
        .frame(width: 400, height: 600)
}

#Preview("User Profile") {
    SpotifyUserProfileView()
}

#Preview("Widget") {
    SpotifyWidget()
        .frame(width: 300)
}

