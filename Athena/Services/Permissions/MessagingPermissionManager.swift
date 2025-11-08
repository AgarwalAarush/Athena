//
//  MessagingPermissionManager.swift
//  Athena
//
//  Created by Cursor on 11/8/25.
//

import Foundation
import AppKit

/// Manages Apple Events (Automation) permission for controlling Messages app
@MainActor
final class MessagingPermissionManager: PermissionManaging {
    
    static let shared = MessagingPermissionManager()
    
    private init() {}
    
    // MARK: - PermissionManaging
    
    var authorizationStatus: PermissionStatus {
        // Check if we have Apple Events permission by attempting to target Messages
        // This is a heuristic since there's no direct API to check Apple Events permission status
        let script = """
        tell application "System Events"
            return true
        end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if error != nil {
            // If we get an error, permission is likely denied
            return .denied
        } else if result != nil {
            // If successful, permission is granted
            return .authorized
        } else {
            // Unknown state
            return .notDetermined
        }
    }
    
    var permissionDescription: String {
        "Athena needs permission to control the Messages app to send messages automatically on your behalf."
    }
    
    func requestAuthorization() async -> PermissionRequestResult {
        print("[MessagingPermissionManager] 📱 Requesting Apple Events authorization...")
        
        // Apple Events permissions are requested automatically when first attempting to use AppleScript
        // We'll trigger a harmless AppleScript to prompt the user
        let script = """
        tell application "System Events"
            return true
        end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            print("[MessagingPermissionManager] ❌ AppleScript error: \(errorMessage)")
            
            // Check if it's a permission error
            if errorMessage.contains("not allowed") || errorMessage.contains("permission") {
                return .requiresSystemSettings
            } else {
                return .error(NSError(domain: "MessagingPermissionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
        }
        
        if result != nil {
            print("[MessagingPermissionManager] ✅ Apple Events access granted")
            return .granted
        } else {
            return .denied
        }
    }
    
    func openSystemSettings() {
        print("[MessagingPermissionManager] 🔧 Opening System Settings for Automation...")
        // Open System Settings to Privacy & Security > Automation
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Additional Helpers
    
    /// Checks if Messages app is available on the system
    var isMessagesAppAvailable: Bool {
        let messagesPath = "/System/Applications/Messages.app"
        return FileManager.default.fileExists(atPath: messagesPath)
    }
}

