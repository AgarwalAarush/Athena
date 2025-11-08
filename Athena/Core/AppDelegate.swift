//
//  AppDelegate.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import AppKit
import SwiftUI
import AppAuth

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    var statusItem: NSStatusItem?
    private var eventMonitor: Any?
    private var settingsShortcutMonitor: Any?
    
    // OAuth flow session - stored globally to be accessible from URL handler
    static var currentAuthorizationFlow: OIDExternalUserAgentSession?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] 🚀 Application launching")
        
        // Create the status bar item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Athena")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        print("[AppDelegate] ✅ Status bar item created")

        // Initialize window manager with floating utility window configuration
        windowManager = WindowManager()
        windowManager?.setupFloatingWindow()
        print("[AppDelegate] ✅ Window manager initialized")

        // Hide dock icon for floating utility window
        NSApp.setActivationPolicy(.accessory)
        print("[AppDelegate] ✅ Activation policy set to .accessory")

        // Explicitly hide the window - it will be shown when menu bar icon is clicked
        windowManager?.window?.orderOut(nil)
        print("[AppDelegate] ✅ Window explicitly hidden on startup")

        setupGlobalShortcutMonitor()
        setupSettingsShortcutMonitor()

        Task { @MainActor in
            await SpeechService.shared.requestAuthorization()
        }
        
        print("[AppDelegate] ✅ Application launch completed")
    }

    @objc func toggleWindow() {
        print("[AppDelegate] 🔔 toggleWindow() called")
        
        guard let windowManager = windowManager else {
            print("[AppDelegate] ❌ windowManager is nil")
            return
        }
        
        guard let window = windowManager.window else {
            print("[AppDelegate] ❌ window is nil")
            return
        }
        
        print("[AppDelegate] 📊 Window current state: \(window.isVisible ? "visible" : "hidden")")

        if !window.isVisible {
            // Window is hidden, show it
            print("[AppDelegate] 🪟 Window is hidden, positioning near menu bar and showing")
            
            // Position window near menu bar
            if let button = statusItem?.button {
                let buttonFrame = button.window?.frame ?? .zero
                let screen = NSScreen.main?.visibleFrame ?? .zero
                let windowSize = window.frame.size

                let x = buttonFrame.origin.x + (buttonFrame.width / 2) - (windowSize.width / 2)
                let y = screen.maxY - 5 - windowSize.height
                
                print("[AppDelegate] 📍 Setting window position: x=\(x), y=\(y)")
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            // Show the window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("[AppDelegate] ✅ Window shown and activated")
        } else {
            // Window is visible, hide it
            print("[AppDelegate] 🪟 Window is visible, hiding it")
            window.orderOut(nil)
            print("[AppDelegate] ✅ Window hidden")
        }
    }
    
    private func setupGlobalShortcutMonitor() {
        let shortcutMask: NSEvent.ModifierFlags = [.option]
        let shortcutKeyCode: UInt16 = 0 // Key code for the "A" key on macOS keyboards

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == shortcutMask && event.keyCode == shortcutKeyCode {
                DispatchQueue.main.async {
                    self.toggleWindow()
                }
            }
        }
    }

    private func setupSettingsShortcutMonitor() {
        // Listen for Command+, to open settings
        settingsShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Key code 43 is for comma (,)
            if flags == .command && event.keyCode == 43 {
                DispatchQueue.main.async {
                    self.windowManager?.openSettingsWindow()
                }
                return nil // Consume the event
            }

            return event
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = settingsShortcutMonitor {
            NSEvent.removeMonitor(monitor)
            settingsShortcutMonitor = nil
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window is closed, keep running in background
        return false
    }
    
    // MARK: - URL Handling for OAuth
    
    /// Handles incoming URLs (OAuth redirect callback)
    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle Google OAuth redirect
        for url in urls {
            if let authorizationFlow = AppDelegate.currentAuthorizationFlow,
               authorizationFlow.resumeExternalUserAgentFlow(with: url) {
                AppDelegate.currentAuthorizationFlow = nil
                print("✓ OAuth redirect handled successfully")
                return
            }
        }
    }
}
