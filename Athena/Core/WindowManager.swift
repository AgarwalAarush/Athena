//
//  WindowManager.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import AppKit
import SwiftUI

class WindowManager: NSObject, ObservableObject {
    private var window: NSWindow?
    
    @Published var windowSize: CGSize = CGSize(width: 470, height: 640)
    
    // Window size constraints
    private let minWidth: CGFloat = 400
    private let maxWidth: CGFloat = 800
    private let minHeight: CGFloat = 500
    private let maxHeight: CGFloat = 1200
    
    func setupFloatingWindow() {
        // Create floating utility window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        window.title = "Athena"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        
        // Set window level to float above other windows
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
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
    }
    
    func setWindowSize(_ size: CGSize, animated: Bool = true) {
        guard let window = window else { return }
        
        // Constrain size to min/max
        let constrainedWidth = min(max(size.width, minWidth), maxWidth)
        let constrainedHeight = min(max(size.height, minHeight), maxHeight)
        let constrainedSize = CGSize(width: constrainedWidth, height: constrainedHeight)
        
        // Calculate new frame maintaining top-left position
        var newFrame = window.frame
        newFrame.origin.y -= (constrainedHeight - window.frame.height)
        newFrame.size = constrainedSize
        
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

