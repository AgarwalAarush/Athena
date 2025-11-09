# Spotify Integration Guide for Athena

This guide explains how to complete the Spotify OAuth integration in Athena using the custom URL scheme method.

## Overview

Athena now supports Spotify authentication using a **custom URL scheme** (`athena://spotify-callback`). This provides a native macOS experience where the browser redirects back to the app after authentication.

## What's Already Configured

✅ **Info.plist Updated**
- Custom URL scheme `athena://` registered
- App will receive callbacks at `athena://spotify-callback`

✅ **AppDelegate Updated**
- URL handling code added to route Spotify OAuth callbacks
- Static callback handler property for async continuation

✅ **SpotifyAuthService Created**
- Complete OAuth 2.0 implementation
- Token refresh support
- Keychain storage for secure credential management
- Scope management for different permission levels

## Setup Instructions

### 1. Create Spotify App in Spotify Dashboard

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Log in with your Spotify account
3. Click "Create App"
4. Fill in the details:
   - **App Name**: Athena (or your preferred name)
   - **App Description**: Personal AI assistant with Spotify integration
   - **Redirect URI**: `athena://spotify-callback` ⚠️ **EXACTLY THIS**
   - **API/SDKs**: Check "Web API"
5. Click "Save"
6. On your app's page, note your:
   - **Client ID**
   - **Client Secret** (click "Show Client Secret")

### 2. Create SpotifySecurity.plist

1. In Xcode, right-click on the `Athena` folder
2. Select "New File..." → "Property List"
3. Name it `SpotifySecurity.plist`
4. Add the following keys (copy from `SpotifySecurity.plist.example`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CLIENT_ID</key>
	<string>YOUR_SPOTIFY_CLIENT_ID_HERE</string>
	<key>CLIENT_SECRET</key>
	<string>YOUR_SPOTIFY_CLIENT_SECRET_HERE</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
</dict>
</plist>
```

5. Replace `YOUR_SPOTIFY_CLIENT_ID_HERE` and `YOUR_SPOTIFY_CLIENT_SECRET_HERE` with your actual credentials
6. **Important**: Add `SpotifySecurity.plist` to `.gitignore` to avoid committing secrets

### 3. Add to .gitignore

Add this line to your `.gitignore` file:

```
SpotifySecurity.plist
```

## Usage

### Basic Authentication

```swift
import SwiftUI

struct SpotifyAuthView: View {
    @State private var isAuthenticated = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if SpotifyAuthService.shared.isAuthenticated() {
                Text("✓ Connected to Spotify")
                    .foregroundColor(.green)
                
                Button("Sign Out") {
                    try? SpotifyAuthService.shared.signOut()
                    isAuthenticated = false
                }
            } else {
                Button("Connect Spotify") {
                    Task {
                        do {
                            _ = try await SpotifyAuthService.shared.authorize()
                            isAuthenticated = true
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
}
```

### Custom Scopes

Request specific permissions:

```swift
// Default scopes (playback control + user info)
try await SpotifyAuthService.shared.authorize()

// Custom scopes
try await SpotifyAuthService.shared.authorize(scopes: [
    SpotifyOAuthScopes.userReadPlaybackState,
    SpotifyOAuthScopes.userModifyPlaybackState,
    SpotifyOAuthScopes.userLibraryRead,
    SpotifyOAuthScopes.playlistModifyPrivate
])

// All available scopes
try await SpotifyAuthService.shared.authorize(
    scopes: SpotifyOAuthScopes.allScopes
)
```

### Making Authenticated API Calls

The service automatically handles token refresh:

```swift
// Get a valid access token (auto-refreshes if expired)
let accessToken = try await SpotifyAuthService.shared.getValidAccessToken()

// Make API call
var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

let (data, _) = try await URLSession.shared.data(for: request)
// Process response...
```

## Available OAuth Scopes

### User Data
- `user-read-private` - Read user profile
- `user-read-email` - Read user email

### Playback (Default Scopes)
- `user-read-playback-state` - Read current playback state
- `user-modify-playback-state` - Control playback (play, pause, skip, etc.)
- `user-read-currently-playing` - Read currently playing track

### Library
- `user-library-read` - Read saved tracks/albums
- `user-library-modify` - Add/remove tracks/albums

### Playlists
- `playlist-read-private` - Read private playlists
- `playlist-modify-public` - Edit public playlists
- `playlist-modify-private` - Edit private playlists

### History & Stats
- `user-read-recently-played` - Read recently played tracks
- `user-top-read` - Read top tracks/artists

## Architecture

### File Structure

```
Athena/
├── Services/
│   └── Spotify/
│       ├── SpotifyAuthService.swift      # OAuth authentication
│       └── SPOTIFY_INTEGRATION.md        # This file
├── Core/
│   └── AppDelegate.swift                 # URL callback handling
├── SpotifySecurity.plist                 # Your credentials (not in git)
├── SpotifySecurity.plist.example         # Template for credentials
└── Info.plist                            # URL scheme registration
```

### Authentication Flow

1. **User initiates auth**: `SpotifyAuthService.shared.authorize()`
2. **App opens browser**: Safari/default browser opens to Spotify login
3. **User logs in**: Grants permissions on Spotify's website
4. **Spotify redirects**: Browser redirects to `athena://spotify-callback?code=...`
5. **macOS intercepts**: OS routes URL to Athena app
6. **AppDelegate receives**: `application(_:open:)` method called
7. **Callback processed**: URL passed to `spotifyAuthCallback` continuation
8. **Token exchange**: Authorization code exchanged for access/refresh tokens
9. **Session saved**: Tokens stored securely in Keychain
10. **Ready to use**: All future API calls use stored tokens

### Token Management

- **Access tokens** expire after 1 hour
- **Refresh tokens** don't expire (unless revoked by user)
- The service automatically refreshes tokens before API calls
- Tokens are stored securely in macOS Keychain
- Session is restored on app launch if still valid

## Error Handling

```swift
do {
    _ = try await SpotifyAuthService.shared.authorize()
} catch SpotifyAuthError.userCancelled {
    print("User cancelled authorization")
} catch SpotifyAuthError.configurationMissing {
    print("SpotifySecurity.plist not found")
} catch SpotifyAuthError.sessionExpired {
    print("Session expired, need to re-authenticate")
} catch {
    print("Unexpected error: \(error)")
}
```

## Security Best Practices

✅ **Do:**
- Store `SpotifySecurity.plist` locally only
- Add `SpotifySecurity.plist` to `.gitignore`
- Use `.example` files for templates
- Store tokens in Keychain (already implemented)

❌ **Don't:**
- Commit `CLIENT_SECRET` to version control
- Hardcode credentials in source code
- Share your Spotify app credentials publicly

## Testing

### Manual Testing

1. Run the app
2. Trigger Spotify authentication
3. Browser should open to Spotify login
4. After login, app should automatically return to foreground
5. Check console for success messages:
   ```
   [SpotifyAuth] 🎵 Opening authorization URL: ...
   [AppDelegate] 🔗 Received URL: athena://spotify-callback?code=...
   [AppDelegate] 🎵 Spotify OAuth callback detected
   [SpotifyAuth] ✓ Authorization code extracted
   [SpotifyAuth] ✓ Authorization complete, session saved
   ```

### Integration Testing

```swift
// Check if authenticated
let isAuth = SpotifyAuthService.shared.isAuthenticated()

// Get current session
if let session = SpotifyAuthService.shared.currentValidSession() {
    print("Access token: \(session.accessToken)")
    print("Expires at: \(session.expiresAt)")
    print("Scopes: \(session.scopes)")
}

// Test API call
let token = try await SpotifyAuthService.shared.getValidAccessToken()
// Use token to call Spotify Web API...
```

## Spotify Web API Reference

Once authenticated, you can use the [Spotify Web API](https://developer.spotify.com/documentation/web-api):

- **Get Current Playback**: `GET /v1/me/player`
- **Play Track**: `PUT /v1/me/player/play`
- **Pause**: `PUT /v1/me/player/pause`
- **Skip**: `POST /v1/me/player/next`
- **Get User Profile**: `GET /v1/me`
- **Search**: `GET /v1/search`

All endpoints require `Authorization: Bearer {token}` header.

## Troubleshooting

### "SpotifySecurity.plist not found"
- Ensure you created the file in the correct location
- Check it's added to the app target in Xcode

### "Redirect URI mismatch"
- Verify Spotify Dashboard has `athena://spotify-callback` (exact match)
- Check Info.plist has `athena` URL scheme registered

### "App doesn't open after Spotify login"
- Verify Info.plist contains the Spotify URL scheme entry
- Check AppDelegate URL handling code is present
- Look for console messages in Xcode

### "Token exchange failed"
- Verify CLIENT_ID and CLIENT_SECRET are correct
- Check network connectivity
- Ensure redirect URI matches exactly in Spotify Dashboard

## Next Steps

1. **Create Spotify API Service**: Build a service layer for common Spotify operations
2. **Add UI Integration**: Add Spotify controls to your app's interface
3. **Implement Features**: 
   - Current playback display
   - Playback controls
   - Search functionality
   - Playlist management

## Support

- [Spotify Web API Documentation](https://developer.spotify.com/documentation/web-api)
- [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
- [OAuth 2.0 Authorization Guide](https://developer.spotify.com/documentation/general/guides/authorization/)

---

**Last Updated**: November 9, 2025  
**Athena Version**: 1.0

