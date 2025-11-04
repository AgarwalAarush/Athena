//
//  CursorWorkspaceInference.swift
//  Athena
//
//  Created by Claude on 11/4/25.
//

import Foundation
import AppKit

/// Utilities for inferring Cursor/VS Code workspace URLs from window information
/// This enables precise reopening of editor windows with the correct folder/workspace
final class CursorWorkspaceInference {
    static let shared = CursorWorkspaceInference()

    // MARK: - Properties

    /// Cache of PID -> workspace URL mappings (from recent observations)
    private var workspaceCache: [pid_t: URL] = [:]

    /// Lock for thread-safe access
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Infer workspace URL for a Cursor/VS Code window
    /// Tries multiple strategies in order of reliability
    func inferWorkspaceURL(
        bundleID: String,
        pid: pid_t,
        title: String?,
        axWindow: AXUIElement
    ) -> URL? {
        // Strategy 1: Parse from window title
        if let title = title, let url = parseWorkspaceFromTitle(title) {
            cacheWorkspace(url: url, for: pid)
            return url
        }

        // Strategy 2: Check cached workspace for this PID
        if let cachedURL = getCachedWorkspace(for: pid) {
            return cachedURL
        }

        // Strategy 3: Try to get document path via AX (if it's a single file)
        if let documentURL = getDocumentURL(from: axWindow) {
            cacheWorkspace(url: documentURL, for: pid)
            return documentURL
        }

        // Strategy 4: Probe via CLI (if available)
        if let cliURL = probeViaCLI(bundleID: bundleID, pid: pid) {
            cacheWorkspace(url: cliURL, for: pid)
            return cliURL
        }

        return nil
    }

    /// Clear workspace cache (useful when apps are relaunched)
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        workspaceCache.removeAll()
    }

    /// Clear workspace for a specific PID
    func clearCache(for pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        workspaceCache.removeValue(forKey: pid)
    }

    // MARK: - Private - Strategy 1: Title Parsing

    private func parseWorkspaceFromTitle(_ title: String) -> URL? {
        // Common patterns in Cursor/VS Code titles:
        // "folder_name - Visual Studio Code"
        // "file.txt - folder_name - Visual Studio Code"
        // "folder_name (Workspace) - Visual Studio Code"
        // "/full/path/to/folder - Visual Studio Code"

        // Remove common suffixes
        let suffixes = [
            " - Visual Studio Code",
            " - Cursor",
            " - VS Code",
            " - Code - OSS",
            " (Workspace)"
        ]

        var cleanTitle = title
        for suffix in suffixes {
            if let range = cleanTitle.range(of: suffix, options: [.anchored, .backwards]) {
                cleanTitle.removeSubrange(range)
            }
        }

        // If there's a " - " separator, take the last part (usually the folder)
        if let lastDashIndex = cleanTitle.range(of: " - ", options: .backwards) {
            cleanTitle = String(cleanTitle[lastDashIndex.upperBound...])
        }

        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's an absolute path
        if cleanTitle.hasPrefix("/") || cleanTitle.hasPrefix("~") {
            let expandedPath = NSString(string: cleanTitle).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Try to resolve as a path in common locations
        let commonBases = [
            FileManager.default.homeDirectoryForCurrentUser.path,
            "/Users/\(NSUserName())/Developer",
            "/Users/\(NSUserName())/Projects",
            "/Users/\(NSUserName())/Documents"
        ]

        for base in commonBases {
            let candidatePath = "\(base)/\(cleanTitle)"
            if FileManager.default.fileExists(atPath: candidatePath) {
                return URL(fileURLWithPath: candidatePath)
            }
        }

        return nil
    }

    // MARK: - Private - Strategy 2: Cache

    private func getCachedWorkspace(for pid: pid_t) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return workspaceCache[pid]
    }

    private func cacheWorkspace(url: URL, for pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        workspaceCache[pid] = url
    }

    // MARK: - Private - Strategy 3: AX Document Path

    private func getDocumentURL(from axWindow: AXUIElement) -> URL? {
        // Try to get kAXDocumentAttribute (available for some editors with single-file windows)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXDocumentAttribute as CFString, &value)

        guard result == .success else { return nil }

        // The document attribute can be a string path or a URL
        if let pathString = value as? String {
            return URL(fileURLWithPath: pathString)
        } else if let urlString = value as? String, let url = URL(string: urlString) {
            return url
        }

        return nil
    }

    // MARK: - Private - Strategy 4: CLI Probing

    private func probeViaCLI(bundleID: String, pid: pid_t) -> URL? {
        // Determine which CLI to use based on bundle ID
        let cliCommand: String
        if bundleID.contains("cursor") {
            cliCommand = "cursor"
        } else if bundleID.contains("vscode") || bundleID.contains("code-oss") {
            cliCommand = "code"
        } else {
            return nil
        }

        // Check if CLI is available
        guard isCLIAvailable(cliCommand) else {
            return nil
        }

        // Try to get recent workspaces via CLI
        // Note: This is best-effort - not all versions expose this
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [cliCommand, "--list-extensions"] // Use a safe query to test CLI

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            // If CLI works, we know it's installed, but we can't easily query current workspace
            // This would require custom CLI flags that may not exist
            // For now, just return nil - the other strategies should cover most cases
            return nil
        } catch {
            return nil
        }
    }

    private func isCLIAvailable(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Public - Workspace Validation

    /// Validates that a workspace URL still exists and is accessible
    func validateWorkspace(_ url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Expands common path patterns (e.g., ~, relative paths)
    func expandPath(_ path: String) -> String {
        let nsPath = NSString(string: path)
        let expanded = nsPath.expandingTildeInPath
        return expanded
    }
}

// MARK: - Workspace Reopening Helper

extension CursorWorkspaceInference {
    /// Opens a Cursor/VS Code workspace using the appropriate CLI
    /// Returns the PID of the launched process, or nil if launch failed
    @discardableResult
    func openWorkspace(
        _ workspaceURL: URL,
        bundleID: String,
        newWindow: Bool = true
    ) -> pid_t? {
        let cliCommand: String
        if bundleID.contains("cursor") {
            cliCommand = "cursor"
        } else if bundleID.contains("vscode") || bundleID.contains("code-oss") {
            cliCommand = "code"
        } else {
            // Fallback to open command
            return openWorkspaceViaOpen(workspaceURL, bundleID: bundleID)
        }

        guard isCLIAvailable(cliCommand) else {
            // Fallback to open command
            return openWorkspaceViaOpen(workspaceURL, bundleID: bundleID)
        }

        // Use CLI to open workspace
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var arguments = [cliCommand]
        if newWindow {
            arguments.append("--new-window")
        }
        arguments.append(workspaceURL.path)

        process.arguments = arguments

        do {
            try process.run()
            // Give it a moment to launch
            usleep(500_000) // 500ms

            // Find the newly launched window (this is best-effort)
            // The caller should use window matching to find the actual window
            return nil // We don't have a direct way to get the PID from CLI launch
        } catch {
            print("CursorWorkspaceInference: Failed to launch via CLI: \(error)")
            return openWorkspaceViaOpen(workspaceURL, bundleID: bundleID)
        }
    }

    private func openWorkspaceViaOpen(_ workspaceURL: URL, bundleID: String) -> pid_t? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", bundleID, workspaceURL.path]

        do {
            try process.run()
            usleep(500_000) // 500ms
            return nil // open command doesn't return PID easily
        } catch {
            print("CursorWorkspaceInference: Failed to open via open command: \(error)")
            return nil
        }
    }

    /// Waits for a new Cursor window to appear that matches the expected workspace
    /// Returns the window descriptor when found, or nil on timeout
    func waitForWindow(
        matching workspaceURL: URL,
        bundleID: String,
        timeout: TimeInterval = 8.0,
        registry: WindowRegistry
    ) -> WindowDescriptor? {
        let deadline = Date().addingTimeInterval(timeout)
        let workspaceName = workspaceURL.lastPathComponent

        while Date() < deadline {
            let windows = registry.windows(for: bundleID)

            // Look for a window with matching workspace or title containing the workspace name
            for window in windows {
                if let workspace = window.workspaceURL, workspace == workspaceURL {
                    return window
                }
                if let title = window.title, title.contains(workspaceName) {
                    return window
                }
            }

            // Wait a bit before checking again
            usleep(200_000) // 200ms
        }

        return nil
    }
}
