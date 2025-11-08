//
//  ContactsPermissionManager.swift
//  Athena
//
//  Created by Cursor on 11/8/25.
//

import Foundation
internal import Contacts
import AppKit

/// Manages Contacts permission requests and status
@MainActor
final class ContactsPermissionManager: PermissionManaging {
    
    static let shared = ContactsPermissionManager()
    
    private let contactsService = ContactsService.shared
    
    private init() {}
    
    // MARK: - PermissionManaging
    
    var authorizationStatus: PermissionStatus {
        let status = contactsService.authorizationStatus
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
    
    var permissionDescription: String {
        "Athena needs access to your contacts to send messages to people by name."
    }
    
    func requestAuthorization() async -> PermissionRequestResult {
        print("[ContactsPermissionManager] 📇 Requesting Contacts authorization...")
        
        guard authorizationStatus == .notDetermined else {
            if authorizationStatus == .authorized {
                return .granted
            } else {
                return .requiresSystemSettings
            }
        }
        
        do {
            let granted = try await contactsService.requestAccess()
            if granted {
                print("[ContactsPermissionManager] ✅ Contacts access granted")
                return .granted
            } else {
                print("[ContactsPermissionManager] ❌ Contacts access denied")
                return .denied
            }
        } catch {
            print("[ContactsPermissionManager] ❌ Error requesting access: \(error.localizedDescription)")
            return .error(error)
        }
    }
    
    func openSystemSettings() {
        print("[ContactsPermissionManager] 🔧 Opening System Settings for Contacts...")
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts")!
        NSWorkspace.shared.open(url)
    }
}

