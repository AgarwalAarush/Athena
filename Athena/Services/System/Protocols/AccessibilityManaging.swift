//
//  AccessibilityManaging.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import ApplicationServices

/// Errors that can occur when interacting with the accessibility API.
enum AccessibilityError: Error {
    case permissionDenied
    case attributeMissing(String)
    case conversionFailed
    case unexpectedType
    case operationFailed(String)
}

/// Abstraction over macOS Accessibility APIs (AXUIElement).
protocol AccessibilityManaging {
    /// Indicates whether the app currently has accessibility privileges.
    var isAccessibilityEnabled: Bool { get }

    /// Requests accessibility permissions. Setting `prompt` to true triggers the system dialog.
    @discardableResult
    func requestAccessibilityPermissions(prompt: Bool) -> Bool

    /// Returns an AXUIElement for the application with the provided process identifier.
    func applicationElement(for pid: pid_t) -> AXUIElement

    /// Returns the focused window of the given application element.
    func focusedWindow(of application: AXUIElement) -> Result<AXUIElement, AccessibilityError>

    /// Returns all windows owned by the given application element.
    func allWindows(of application: AXUIElement) -> Result<[AXUIElement], AccessibilityError>

    /// Reads a CGPoint-valued attribute from the provided accessibility element.
    func point(for attribute: CFString, of element: AXUIElement) -> Result<CGPoint, AccessibilityError>

    /// Reads a CGSize-valued attribute from the provided accessibility element.
    func size(for attribute: CFString, of element: AXUIElement) -> Result<CGSize, AccessibilityError>

    /// Sets a CGPoint-valued attribute on the provided accessibility element.
    func setPoint(_ point: CGPoint, for attribute: CFString, of element: AXUIElement) -> Result<Void, AccessibilityError>

    /// Sets a CGSize-valued attribute on the provided accessibility element.
    func setSize(_ size: CGSize, for attribute: CFString, of element: AXUIElement) -> Result<Void, AccessibilityError>
}
