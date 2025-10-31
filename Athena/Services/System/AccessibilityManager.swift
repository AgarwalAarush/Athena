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
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else {
            return .failure(.conversionFailed)
        }

        let error = AXUIElementSetAttributeValue(element, attribute, value)
        if error == .success {
            return .success(())
        } else {
            return .failure(.fromAXError(error))
        }
    }

    func setSize(_ size: CGSize, for attribute: CFString, of element: AXUIElement) -> Result<Void, AccessibilityError> {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else {
            return .failure(.conversionFailed)
        }

        let error = AXUIElementSetAttributeValue(element, attribute, value)
        if error == .success {
            return .success(())
        } else {
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
        .operationFailed("AXError rawValue: \(error.rawValue)")
    }
}
