//
//  SpotifySettingsView.swift
//  Athena
//
//  Created by Cursor on 11/9/25.
//
//  Example integration of Spotify authentication into Settings UI

import SwiftUI

struct SpotifySettingsSection: View {
    @State private var isAuthenticated = false
    @State private var isAuthenticating = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let authService = SpotifyAuthService.shared
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spotify Integration")
                            .font(.headline)
                        Text("Connect your Spotify account for music control")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Status
                HStack {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    
                    if isAuthenticated {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not Connected", systemImage: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    if isAuthenticated {
                        Button(action: signOut) {
                            Label("Disconnect", systemImage: "link.badge.minus")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Button(action: testConnection) {
                            Label("Test Connection", systemImage: "checkmark.shield")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: authenticate) {
                            if isAuthenticating {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                    Text("Authenticating...")
                                }
                            } else {
                                Label("Connect to Spotify", systemImage: "link.badge.plus")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAuthenticating)
                    }
                }
            }
            .padding(8)
        }
        .onAppear {
            updateAuthStatus()
        }
        .alert("Spotify", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Actions
    
    private func updateAuthStatus() {
        isAuthenticated = authService.isAuthenticated()
    }
    
    private func authenticate() {
        isAuthenticating = true
        
        Task {
            do {
                // Request authentication with default scopes
                _ = try await authService.authorize(
                    scopes: SpotifyOAuthScopes.defaultScopes
                )
                
                // For more scopes, use:
                // _ = try await authService.authorize(
                //     scopes: SpotifyOAuthScopes.allScopes
                // )
                
                await MainActor.run {
                    updateAuthStatus()
                    alertMessage = "Successfully connected to Spotify! You can now control music playback."
                    showAlert = true
                    isAuthenticating = false
                }
                
            } catch let error as SpotifyAuthError {
                await MainActor.run {
                    switch error {
                    case .userCancelled:
                        alertMessage = "Authorization was cancelled."
                    case .configurationMissing:
                        alertMessage = "Spotify configuration is missing. Please ensure SpotifySecurity.plist is set up correctly."
                    default:
                        alertMessage = error.localizedDescription
                    }
                    showAlert = true
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to connect: \(error.localizedDescription)"
                    showAlert = true
                    isAuthenticating = false
                }
            }
        }
    }
    
    private func signOut() {
        do {
            try authService.signOut()
            updateAuthStatus()
            alertMessage = "Successfully disconnected from Spotify."
            showAlert = true
        } catch {
            alertMessage = "Failed to sign out: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func testConnection() {
        Task {
            do {
                // Test by getting a valid access token
                let token = try await authService.getValidAccessToken()
                
                // Make a test API call to verify connection
                var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw SpotifyAuthError.networkError(URLError(.badServerResponse))
                }
                
                // Parse user info
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let displayName = json["display_name"] as? String {
                    await MainActor.run {
                        alertMessage = "Connection successful! Logged in as: \(displayName)"
                        showAlert = true
                    }
                } else {
                    await MainActor.run {
                        alertMessage = "Connection successful!"
                        showAlert = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    alertMessage = "Connection test failed: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SpotifySettingsSection()
        .frame(width: 500)
        .padding()
}

