//
//  SystemTool.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation
import AppKit
import ApplicationServices

/// System operations service for macOS.
/// Handles file operations, system controls (brightness, volume), and app management.
final class SystemTool {
    static let shared = SystemTool()
    
    private init() {}
    
    // MARK: - Public Interface
    
    enum Action: String {
        case createFile = "create_file"
        case readFile = "read_file"
        case editFile = "edit_file"
        case deleteFile = "delete_file"
        case listFiles = "list_files"
        case setBrightness = "set_brightness"
        case getBrightness = "get_brightness"
        case setVolume = "set_volume"
        case getVolume = "get_volume"
        case openApp = "open_app"
        case closeApp = "close_app"
        case listRunningApps = "list_running_apps"
        case activateApp = "activate_app"
    }
    
    struct ToolParameters: Codable {
        let action: String
        let filePath: String?
        let content: String?
        let directory: String?
        let pattern: String?
        let brightness: Double?
        let volume: Int?
        let appName: String?
    }
    
    struct ToolResult {
        let success: Bool
        let result: [String: Any]?
        let error: String?
        
        init(success: Bool, result: [String: Any]? = nil, error: String? = nil) {
            self.success = success
            self.result = result
            self.error = error
        }
        
        func toJSON() -> [String: Any] {
            var json: [String: Any] = [
                "success": success
            ]
            
            if let result = result {
                json["result"] = result
            }
            
            if let error = error {
                json["error"] = error
            }
            
            return json
        }
    }
    
    func execute(parameters: ToolParameters) async throws -> ToolResult {
        guard let action = Action(rawValue: parameters.action) else {
            return ToolResult(success: false, error: "Unknown action: \(parameters.action)")
        }
        
        do {
            switch action {
            case .createFile:
                return try await createFile(parameters: parameters)
            case .readFile:
                return try await readFile(parameters: parameters)
            case .editFile:
                return try await editFile(parameters: parameters)
            case .deleteFile:
                return try await deleteFile(parameters: parameters)
            case .listFiles:
                return try await listFiles(parameters: parameters)
            case .setBrightness:
                return try await setBrightness(parameters: parameters)
            case .getBrightness:
                return try await getBrightness(parameters: parameters)
            case .setVolume:
                return try await setVolume(parameters: parameters)
            case .getVolume:
                return try await getVolume(parameters: parameters)
            case .openApp:
                return try await openApp(parameters: parameters)
            case .closeApp:
                return try await closeApp(parameters: parameters)
            case .listRunningApps:
                return try await listRunningApps(parameters: parameters)
            case .activateApp:
                return try await activateApp(parameters: parameters)
            }
        } catch {
            return ToolResult(success: false, error: "Error executing \(parameters.action): \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Operations
    
    private func createFile(parameters: ToolParameters) async throws -> ToolResult {
        guard let filePath = parameters.filePath else {
            return ToolResult(success: false, error: "file_path required")
        }
        
        let url = URL(fileURLWithPath: filePath)
        let content = parameters.content ?? ""
        
        // Create parent directories if needed
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Write file
        try content.write(to: url, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        let size = attributes[.size] as? Int64 ?? 0
        
        return ToolResult(
            success: true,
            result: [
                "file_path": filePath,
                "size_bytes": size,
                "message": "File created successfully"
            ]
        )
    }
    
    private func readFile(parameters: ToolParameters) async throws -> ToolResult {
        guard let filePath = parameters.filePath else {
            return ToolResult(success: false, error: "file_path required")
        }
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            return ToolResult(success: false, error: "File not found: \(filePath)")
        }
        
        let url = URL(fileURLWithPath: filePath)
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return ToolResult(success: false, error: "Not a file: \(filePath)")
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        let size = attributes[.size] as? Int64 ?? 0
        
        return ToolResult(
            success: true,
            result: [
                "file_path": filePath,
                "content": content,
                "size_bytes": size
            ]
        )
    }
    
    private func editFile(parameters: ToolParameters) async throws -> ToolResult {
        guard let filePath = parameters.filePath,
              let content = parameters.content else {
            return ToolResult(success: false, error: "file_path and content required")
        }
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            return ToolResult(success: false, error: "File not found: \(filePath)")
        }
        
        let url = URL(fileURLWithPath: filePath)
        try content.write(to: url, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        let size = attributes[.size] as? Int64 ?? 0
        
        return ToolResult(
            success: true,
            result: [
                "file_path": filePath,
                "size_bytes": size,
                "message": "File edited successfully"
            ]
        )
    }
    
    private func deleteFile(parameters: ToolParameters) async throws -> ToolResult {
        guard let filePath = parameters.filePath else {
            return ToolResult(success: false, error: "file_path required")
        }
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            return ToolResult(success: false, error: "File not found: \(filePath)")
        }
        
        let url = URL(fileURLWithPath: filePath)
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) else {
            return ToolResult(success: false, error: "File not found: \(filePath)")
        }
        
        if isDirectory.boolValue {
            try FileManager.default.removeItem(at: url)
            return ToolResult(
                success: true,
                result: [
                    "file_path": filePath,
                    "message": "Directory deleted successfully"
                ]
            )
        } else {
            try FileManager.default.removeItem(at: url)
            return ToolResult(
                success: true,
                result: [
                    "file_path": filePath,
                    "message": "File deleted successfully"
                ]
            )
        }
    }
    
    private func listFiles(parameters: ToolParameters) async throws -> ToolResult {
        let directory = parameters.directory ?? "."
        let pattern = parameters.pattern ?? "*"
        
        let url = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return ToolResult(success: false, error: "Not a directory: \(directory)")
        }
        
        let files = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: []
        )
        
        var fileList: [[String: Any]] = []
        for fileURL in files {
            // Filter by pattern if specified (simple glob support)
            let fileName = fileURL.lastPathComponent
            if pattern != "*" && !fileName.matches(pattern: pattern) {
                continue
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let size = attributes[.size] as? Int64 ?? 0
            let modified = attributes[.modificationDate] as? Date ?? Date()
            
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            
            fileList.append([
                "name": fileName,
                "path": fileURL.path,
                "is_dir": isDir.boolValue,
                "size_bytes": size,
                "modified": modified.timeIntervalSince1970
            ])
        }
        
        return ToolResult(
            success: true,
            result: [
                "directory": directory,
                "pattern": pattern,
                "files": fileList,
                "count": fileList.count
            ]
        )
    }
    
    // MARK: - System Controls
    
    private func setBrightness(parameters: ToolParameters) async throws -> ToolResult {
        guard let brightness = parameters.brightness else {
            return ToolResult(success: false, error: "brightness required (0.0 to 1.0)")
        }
        
        // Use AppleScript to set brightness
        let script = """
        tell application "System Events"
            set brightness to \(brightness)
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        _ = appleScript?.executeAndReturnError(&error)
        
        if error != nil {
            return ToolResult(
                success: false,
                error: "Could not set brightness. Grant accessibility permissions."
            )
        }
        
        return ToolResult(
            success: true,
            result: [
                "brightness": brightness,
                "message": "Brightness set to \(Int(brightness * 100))%"
            ]
        )
    }
    
    private func getBrightness(parameters: ToolParameters) async throws -> ToolResult {
        // Note: macOS doesn't provide a direct API for getting brightness
        // This is a simplified implementation
        return ToolResult(
            success: false,
            error: "Getting brightness is not directly supported on macOS"
        )
    }
    
    private func setVolume(parameters: ToolParameters) async throws -> ToolResult {
        guard let volume = parameters.volume else {
            return ToolResult(success: false, error: "volume required (0 to 100)")
        }
        
        let script = "set volume output volume \(volume)"
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        _ = appleScript?.executeAndReturnError(&error)
        
        if error != nil {
            return ToolResult(
                success: false,
                error: "Could not set volume: \(error?.description ?? "Unknown error")"
            )
        }
        
        return ToolResult(
            success: true,
            result: [
                "volume": volume,
                "message": "Volume set to \(volume)%"
            ]
        )
    }
    
    private func getVolume(parameters: ToolParameters) async throws -> ToolResult {
        let script = "output volume of (get volume settings)"
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            return ToolResult(
                success: false,
                error: "Could not get volume: \(error.description)"
            )
        }
        
        if let volumeString = result?.stringValue,
           let volume = Int(volumeString) {
            return ToolResult(
                success: true,
                result: [
                    "volume": volume
                ]
            )
        }
        
        return ToolResult(success: false, error: "Could not parse volume")
    }
    
    // MARK: - App Management
    
    private func openApp(parameters: ToolParameters) async throws -> ToolResult {
        guard let appName = parameters.appName else {
            return ToolResult(success: false, error: "app_name required")
        }
        
        let script = """
        tell application "\(appName)"
            activate
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        _ = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            return ToolResult(
                success: false,
                error: "Could not open '\(appName)': \(error.description)"
            )
        }
        
        return ToolResult(
            success: true,
            result: [
                "app_name": appName,
                "message": "Application '\(appName)' opened"
            ]
        )
    }
    
    private func closeApp(parameters: ToolParameters) async throws -> ToolResult {
        guard let appName = parameters.appName else {
            return ToolResult(success: false, error: "app_name required")
        }
        
        let script = """
        tell application "\(appName)"
            quit
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        _ = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            return ToolResult(
                success: false,
                error: "Could not close '\(appName)': \(error.description)"
            )
        }
        
        return ToolResult(
            success: true,
            result: [
                "app_name": appName,
                "message": "Application '\(appName)' closed"
            ]
        )
    }
    
    private func activateApp(parameters: ToolParameters) async throws -> ToolResult {
        guard let appName = parameters.appName else {
            return ToolResult(success: false, error: "app_name required")
        }
        
        let script = """
        tell application "\(appName)"
            activate
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        _ = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            return ToolResult(
                success: false,
                error: "Could not activate '\(appName)': \(error.description)"
            )
        }
        
        return ToolResult(
            success: true,
            result: [
                "app_name": appName,
                "message": "Application '\(appName)' activated"
            ]
        )
    }
    
    private func listRunningApps(parameters: ToolParameters) async throws -> ToolResult {
        let script = """
        tell application "System Events"
            get name of every application process whose background only is false
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            return ToolResult(
                success: false,
                error: "Could not list running apps: \(error.description)"
            )
        }
        
        // Parse comma-separated list
        if let appsString = result?.stringValue {
            let apps = appsString.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            return ToolResult(
                success: true,
                result: [
                    "apps": apps,
                    "count": apps.count
                ]
            )
        }
        
        return ToolResult(success: false, error: "Could not parse app list")
    }
}

// MARK: - Helper Extensions

private extension String {
    func matches(pattern: String) -> Bool {
        // Simple glob pattern matching
        let regex = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: self)
    }
}


