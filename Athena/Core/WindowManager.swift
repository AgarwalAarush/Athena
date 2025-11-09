//
//  WindowManager.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import AppKit
import SwiftUI
import Combine

class WindowManager: NSObject, ObservableObject, NSWindowDelegate {
    var window: NSWindow?
    var settingsWindow: NSWindow?
    weak var appDelegate: AppDelegate?

    @Published var windowSize: CGSize = CGSize(width: 450, height: 300)
    @Published var isExpanded: Bool = false

    // Window size constraints
    private let minWidth: CGFloat = 400
    private let maxWidth: CGFloat = 800
    private let minHeight: CGFloat = 250
    private let maxHeight: CGFloat = 700
    
    // Waveform-only and expanded heights
    private let waveformOnlyHeight: CGFloat = 60
    private let expandedHeight: CGFloat = 600
    
    private var originalWindowSize: CGSize?

    func setupFloatingWindow() {
        print("[WindowManager] 🏗️ Setting up floating window")
        
        // Create borderless floating window
        let window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        print("[WindowManager] ✅ Window created")

        // Set size constraints
        window.minSize = CGSize(width: minWidth, height: minHeight)
        window.maxSize = CGSize(width: maxWidth, height: maxHeight)
        print("[WindowManager] ✅ Size constraints set")

        // Center window on screen
        window.center()
        print("[WindowManager] ✅ Window centered")

        // Set content view with SwiftUI
        let contentView = ContentView()
            .environmentObject(self)

        // Configure hosting view for transparency (prevents black corners)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        window.contentView = hostingView
        print("[WindowManager] ✅ Content view configured")

        // Set delegate for debugging
        window.delegate = self
        print("[WindowManager] ✅ Window delegate set")

        // Store window reference
        self.window = window

        // Restore saved position if available
        restoreWindowPosition()
        
        // Store original size
        self.originalWindowSize = window.frame.size
        
        // Check if wakeword mode is enabled and collapse to waveform-only height
        if ConfigurationManager.shared.wakewordModeEnabled {
            print("[WindowManager] 🎵 Wakeword mode enabled - setting waveform-only height")
            collapseToWaveformOnly()
        }
        
        // Start with window hidden (will be shown by menu bar icon or wake word)
        window.orderOut(nil)
        print("[WindowManager] ✅ Window setup complete - starting hidden")
    }

    func openSettingsWindow() {
        // If settings window already exists and is visible, just bring it to front
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create a standard window with title bar
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        // Configure window
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 500, height: 600)

        // Set title bar background color to #1E1E1E
        window.titlebarAppearsTransparent = false
        window.backgroundColor = NSColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1.0)
        if let titlebar = window.standardWindowButton(.closeButton)?.superview {
            titlebar.wantsLayer = true
            titlebar.layer?.backgroundColor = NSColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1.0).cgColor
        }

        // Set content view with SwiftUI
        let settingsView = SettingsView()
        window.contentView = NSHostingView(rootView: settingsView)

        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Store window reference
        settingsWindow = window
    }
    
    func resizeForCalendar() {
        let newSize = CGSize(width: windowSize.width, height: 600)
        setWindowSize(newSize)
    }

    func resizeForChat() {
        if let originalSize = originalWindowSize {
            setWindowSize(originalSize)
        }
    }
    
    /// Resize window based on the specific view being shown
    func resizeForView(_ view: AppView) {
        guard let window = window else { return }
        
        let height: CGFloat
        switch view {
        case .gmail, .messaging:
            height = 650  // Taller height to display full form content and expanded text fields
        case .calendar, .notes:
            height = 600  // Full height for content-heavy views
        default:
            height = expandedHeight  // Default expanded height
        }
        
        // If transitioning from waveform-only mode, restore proper size constraints
        if !isExpanded {
            window.minSize = CGSize(width: minWidth, height: minHeight)
            window.maxSize = CGSize(width: maxWidth, height: maxHeight)
            isExpanded = true
        }
        
        let newSize = CGSize(width: windowSize.width, height: height)
        setWindowSize(newSize)
    }
    
    // MARK: - Waveform Expansion/Collapse
    
    /// Expands window from waveform-only to full content view
    /// Keeps top edge fixed and expands downward
    func expandToContentView() {
        guard let window = window else { return }
        
        // Restore proper size constraints before expanding
        window.minSize = CGSize(width: minWidth, height: minHeight)
        window.maxSize = CGSize(width: maxWidth, height: maxHeight)
        
        let newSize = CGSize(width: windowSize.width, height: expandedHeight)
        
        // Calculate new frame keeping top edge fixed
        let currentFrame = window.frame
        let topLeft = NSPoint(x: currentFrame.minX, y: currentFrame.maxY)
        let newOrigin = NSPoint(x: topLeft.x, y: topLeft.y - newSize.height)
        let newFrame = NSRect(origin: newOrigin, size: newSize)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
        
        windowSize = newSize
        isExpanded = true
    }
    
    /// Collapses window back to waveform-only view
    /// Keeps top edge fixed and contracts upward
    func collapseToWaveformOnly() {
        guard let window = window else { return }
        
        // Temporarily adjust minSize to allow waveform-only height
        window.minSize = CGSize(width: minWidth, height: waveformOnlyHeight)
        
        let newSize = CGSize(width: windowSize.width, height: waveformOnlyHeight)
        
        // Calculate new frame keeping top edge fixed
        let currentFrame = window.frame
        let topLeft = NSPoint(x: currentFrame.minX, y: currentFrame.maxY)
        let newOrigin = NSPoint(x: topLeft.x, y: topLeft.y - newSize.height)
        let newFrame = NSRect(origin: newOrigin, size: newSize)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
        
        windowSize = newSize
        isExpanded = false
    }
    
    func setWindowSize(_ size: CGSize, animated: Bool = true) {
        guard let window = window else { return }
        
        // Constrain size to min/max
        let constrainedWidth = min(max(size.width, minWidth), maxWidth)
        let constrainedHeight = min(max(size.height, minHeight), maxHeight)
        let constrainedSize = CGSize(width: constrainedWidth, height: constrainedHeight)
        
        // Calculate new frame keeping the top edge fixed so only the bottom moves
        let currentFrame = window.frame
        let topLeft = NSPoint(x: currentFrame.minX, y: currentFrame.maxY)
        let newOrigin = NSPoint(x: topLeft.x, y: topLeft.y - constrainedHeight)
        let newFrame = NSRect(origin: newOrigin, size: constrainedSize)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
        }
        
        windowSize = constrainedSize
        
        // Update isExpanded based on whether we're at waveform-only size or larger
        isExpanded = (constrainedHeight > waveformOnlyHeight)
    }
    
    func toggleWindowVisibility() {
        guard let window = window else {
            print("[WindowManager] ❌ Window is nil in toggleWindowVisibility")
            return
        }
        
        print("[WindowManager] 🔄 toggleWindowVisibility called - current state: \(window.isVisible ? "visible" : "hidden")")
        
        if window.isVisible {
            window.orderOut(nil)
            print("[WindowManager] ✅ Window hidden")
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("[WindowManager] ✅ Window shown and activated")
        }
    }
    
    func saveWindowPosition() {
        guard let window = window else { return }
        
        let frame = window.frame
        UserDefaults.standard.set(frame.origin.x, forKey: "windowOriginX")
        UserDefaults.standard.set(frame.origin.y, forKey: "windowOriginY")
        UserDefaults.standard.set(frame.size.width, forKey: "windowWidth")
        UserDefaults.standard.set(frame.size.height, forKey: "windowHeight")
    }
    
    private func restoreWindowPosition() {
        guard let window = window else { return }
        
        let x = UserDefaults.standard.double(forKey: "windowOriginX")
        let y = UserDefaults.standard.double(forKey: "windowOriginY")
        let width = UserDefaults.standard.double(forKey: "windowWidth")
        let height = UserDefaults.standard.double(forKey: "windowHeight")
        
        if width > 0 && height > 0 {
            let frame = NSRect(x: x, y: y, width: width, height: height)
            window.setFrame(frame, display: true)
            windowSize = frame.size
        }
    }
    
    // MARK: - Google Authorization Support
    
    /// Gets the appropriate window for Google OAuth authorization
    /// - Parameter preferSettings: If true and settings window is open, returns settings window
    /// - Returns: NSWindow to present authorization UI from, or nil if no window available
    func getWindowForAuthorization(preferSettings: Bool = false) -> NSWindow? {
        if preferSettings, let settingsWindow = settingsWindow, settingsWindow.isVisible {
            return settingsWindow
        }
        return window
    }
    
    deinit {
        saveWindowPosition()
    }
    
    // MARK: - NSWindowDelegate Methods (for debugging)
    
    func windowDidBecomeKey(_ notification: Notification) {
        print("[WindowManager] 🔑 Window became key (focused)")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        print("[WindowManager] 🔓 Window resigned key (lost focus)")
    }
    
    func windowWillClose(_ notification: Notification) {
        print("[WindowManager] 🚪 Window will close")
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        print("[WindowManager] 🎯 Window became main")
    }
    
    func windowDidResignMain(_ notification: Notification) {
        print("[WindowManager] 📤 Window resigned main")
    }
}
