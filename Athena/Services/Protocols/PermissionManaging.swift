//
//  PermissionManaging.swift
//  Athena
//
//  Created by Cursor on 11/8/25.
//

import Foundation

/// Represents the authorization status for a permission
enum PermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var isGranted: Bool {
        self == .authorized
    }
    
    var displayString: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        }
    }
}

/// Result of a permission request
enum PermissionRequestResult {
    case granted
    case denied
    case requiresSystemSettings
    case error(Error)
}

/// Protocol for managing app permissions
@MainActor
protocol PermissionManaging {
    /// The current authorization status
    var authorizationStatus: PermissionStatus { get }
    
    /// Human-readable description of the permission
    var permissionDescription: String { get }
    
    /// Requests authorization for this permission
    /// - Returns: Result indicating whether permission was granted
    func requestAuthorization() async -> PermissionRequestResult
    
    /// Opens system settings to the relevant permission page
    func openSystemSettings()
}

/// Extension providing default implementation for common permission behaviors
extension PermissionManaging {
    /// Determines if the permission can be requested (vs requiring system settings)
    var canRequestDirectly: Bool {
        authorizationStatus == .notDetermined
    }
    
    /// Determines if user needs to go to system settings
    var requiresSystemSettings: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
}

