//
//  AccessibilityManager.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation
import ApplicationServices

/// Concrete implementation of `AccessibilityManaging` that wraps AXUIElement APIs.
final class AccessibilityManager: AccessibilityManaging {
    static let shared = AccessibilityManager()

    private init() {}

    var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestAccessibilityPermissions(prompt: Bool) -> Bool {
        if prompt {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [key: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        } else {
            return AXIsProcessTrusted()
        }
    }

    func applicationElement(for pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    func focusedWindow(of application: AXUIElement) -> Result<AXUIElement, AccessibilityError> {
        copyAttribute(kAXFocusedWindowAttribute as CFString, from: application)
            .flatMap { value in
                guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
                    return .failure(.unexpectedType)
                }
                let window = unsafeBitCast(value, to: AXUIElement.self)
                return .success(window)
            }
    }

    func allWindows(of application: AXUIElement) -> Result<[AXUIElement], AccessibilityError> {
        copyAttribute(kAXWindowsAttribute as CFString, from: application)
            .flatMap { value in
                guard CFGetTypeID(value) == CFArrayGetTypeID() else {
                    return .failure(.unexpectedType)
                }

                let array = unsafeBitCast(value, to: CFArray.self)
                let count = CFArrayGetCount(array)
                var windows: [AXUIElement] = []
                windows.reserveCapacity(count)

                for index in 0..<count {
                    let rawElement = CFArrayGetValueAtIndex(array, index)
                    let element = unsafeBitCast(rawElement, to: AXUIElement.self)
                    windows.append(element)
                }

                return .success(windows)
            }
    }

    func point(for attribute: CFString, of element: AXUIElement) -> Result<CGPoint, AccessibilityError> {
        copyAttribute(attribute, from: element)
            .flatMap { value in
                guard CFGetTypeID(value) == AXValueGetTypeID() else {
                    return .failure(.unexpectedType)
                }
                let axValue = unsafeBitCast(value, to: AXValue.self)
                var point = CGPoint.zero
                guard AXValueGetType(axValue) == .cgPoint else {
                    return .failure(.unexpectedType)
                }
                guard AXValueGetValue(axValue, .cgPoint, &point) else {
                    return .failure(.conversionFailed)
                }
                return .success(point)
            }
    }

    func size(for attribute: CFString, of element: AXUIElement) -> Result<CGSize, AccessibilityError> {
        copyAttribute(attribute, from: element)
            .flatMap { value in
                guard CFGetTypeID(value) == AXValueGetTypeID() else {
                    return .failure(.unexpectedType)
                }
                let axValue = unsafeBitCast(value, to: AXValue.self)
                var size = CGSize.zero
                guard AXValueGetType(axValue) == .cgSize else {
                    return .failure(.unexpectedType)
                }
                guard AXValueGetValue(axValue, .cgSize, &size) else {
                    return .failure(.conversionFailed)
                }
                return .success(size)
            }
    }

    func setPoint(_ point: CGPoint, for attribute: CFString, of element: AXUIElement) -> Result<Void, AccessibilityError> {
        print("[AccessibilityManager] setPoint called with point: \(point), attribute: \(attribute)")
        print("[AccessibilityManager] Accessibility enabled: \(isAccessibilityEnabled)")
        
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else {
            print("[AccessibilityManager] ERROR: Failed to create AXValue from point \(point)")
            return .failure(.conversionFailed)
        }
        
        print("[AccessibilityManager] Created AXValue, calling AXUIElementSetAttributeValue")
        let error = AXUIElementSetAttributeValue(element, attribute, value)
        print("[AccessibilityManager] AXUIElementSetAttributeValue returned error code: \(error.rawValue)")
        
        if error == .success {
            print("[AccessibilityManager] setPoint succeeded")
            return .success(())
        } else {
            print("[AccessibilityManager] ERROR: setPoint failed with AXError: \(error) (rawValue: \(error.rawValue))")
            return .failure(.fromAXError(error))
        }
    }

    func setSize(_ size: CGSize, for attribute: CFString, of element: AXUIElement) -> Result<Void, AccessibilityError> {
        print("[AccessibilityManager] setSize called with size: \(size), attribute: \(attribute)")
        print("[AccessibilityManager] Accessibility enabled: \(isAccessibilityEnabled)")
        
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else {
            print("[AccessibilityManager] ERROR: Failed to create AXValue from size \(size)")
            return .failure(.conversionFailed)
        }
        
        print("[AccessibilityManager] Created AXValue, calling AXUIElementSetAttributeValue")
        let error = AXUIElementSetAttributeValue(element, attribute, value)
        print("[AccessibilityManager] AXUIElementSetAttributeValue returned error code: \(error.rawValue)")
        
        if error == .success {
            print("[AccessibilityManager] setSize succeeded")
            return .success(())
        } else {
            print("[AccessibilityManager] ERROR: setSize failed with AXError: \(error) (rawValue: \(error.rawValue))")
            return .failure(.fromAXError(error))
        }
    }

    // MARK: - Private Helpers

    private func copyAttribute(_ attribute: CFString, from element: AXUIElement) -> Result<CFTypeRef, AccessibilityError> {
        guard isAccessibilityEnabled else {
            return .failure(.permissionDenied)
        }

        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        switch error {
        case .success:
            guard let value else {
                return .failure(.attributeMissing(attribute as String))
            }
            return .success(value)
        case .noValue:
            return .failure(.attributeMissing(attribute as String))
        default:
            return .failure(.fromAXError(error))
        }
    }
}

private extension AccessibilityError {
    static func fromAXError(_ error: AXError) -> AccessibilityError {
        let errorDescription: String
        switch error {
        case .success:
            errorDescription = "success"
        case .failure:
            errorDescription = "failure (-25200)"
        case .illegalArgument:
            errorDescription = "illegalArgument (-25201)"
        case .invalidUIElement:
            errorDescription = "invalidUIElement (-25202)"
        case .invalidUIElementObserver:
            errorDescription = "invalidUIElementObserver (-25203)"
        case .cannotComplete:
            errorDescription = "cannotComplete (-25204) - A fundamental error occurred, such as memory allocation failure"
        case .attributeUnsupported:
            errorDescription = "attributeUnsupported (-25205)"
        case .actionUnsupported:
            errorDescription = "actionUnsupported (-25206)"
        case .notificationUnsupported:
            errorDescription = "notificationUnsupported (-25207)"
        case .notImplemented:
            errorDescription = "notImplemented (-25208)"
        case .notificationAlreadyRegistered:
            errorDescription = "notificationAlreadyRegistered (-25209)"
        case .notificationNotRegistered:
            errorDescription = "notificationNotRegistered (-25210)"
        case .apiDisabled:
            errorDescription = "apiDisabled (-25211) - Assistive applications not enabled"
        case .noValue:
            errorDescription = "noValue (-25212)"
        case .parameterizedAttributeUnsupported:
            errorDescription = "parameterizedAttributeUnsupported (-25213)"
        case .notEnoughPrecision:
            errorDescription = "notEnoughPrecision (-25214)"
        @unknown default:
            errorDescription = "unknown error (rawValue: \(error.rawValue))"
        }
        
        print("[AccessibilityError] Converting AXError to AccessibilityError: \(errorDescription)")
        return .operationFailed("AXError: \(errorDescription)")
    }
}
