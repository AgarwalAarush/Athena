//
//  WindowManager.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import AppKit
import SwiftUI
import Combine

class WindowManager: NSObject, ObservableObject {
    var window: NSWindow?
    var settingsWindow: NSWindow?

    @Published var windowSize: CGSize = CGSize(width: 450, height: 300)

    // Window size constraints
    private let minWidth: CGFloat = 400
    private let maxWidth: CGFloat = 800
    private let minHeight: CGFloat = 250
    private let maxHeight: CGFloat = 600
    
    private var originalWindowSize: CGSize?

    func setupFloatingWindow() {
        // Create borderless floating window
        let window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        // Set size constraints
        window.minSize = CGSize(width: minWidth, height: minHeight)
        window.maxSize = CGSize(width: maxWidth, height: maxHeight)

        // Center window on screen
        window.center()

        // Set content view with SwiftUI
        let contentView = ContentView()
            .environmentObject(self)
        window.contentView = NSHostingView(rootView: contentView)

        // Make window key and order front
        window.makeKeyAndOrderFront(nil)

        // Store window reference
        self.window = window

        // Restore saved position if available
        restoreWindowPosition()
        
        // Store original size
        self.originalWindowSize = window.frame.size
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
    }
    
    func toggleWindowVisibility() {
        guard let window = window else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
    
    deinit {
        saveWindowPosition()
    }
}
