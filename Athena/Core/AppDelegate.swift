//
//  AppDelegate.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import AppKit
import SwiftUI
import AppAuth
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    var statusItem: NSStatusItem?
    private var eventMonitor: Any?
    private var settingsShortcutMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // Menu items that need to be updated dynamically
    private var wakewordToggleMenuItem: NSMenuItem?
    
    // OAuth flow sessions - stored globally to be accessible from URL handler
    static var currentAuthorizationFlow: OIDExternalUserAgentSession?
    
    // Spotify OAuth callback handler
    static var spotifyAuthCallback: ((URL) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] 🚀 Application launching")
        
        // Create the status bar item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Athena")
        }
        
        // Setup menu bar menu
        setupMenuBar()
        setupMenuBarStateObservers()
        print("[AppDelegate] ✅ Status bar item created with menu")

        // Initialize window manager with floating utility window configuration
        windowManager = WindowManager()
        windowManager?.appDelegate = self
        windowManager?.setupFloatingWindow()
        print("[AppDelegate] ✅ Window manager initialized with appDelegate reference")

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
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        let menu = NSMenu()
        
        // Show/Hide Window
        let showHideItem = NSMenuItem(title: "Show/Hide Window", action: #selector(toggleWindow), keyEquivalent: "")
        showHideItem.target = self
        menu.addItem(showHideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle Wakeword Mode
        let wakewordItem = NSMenuItem(title: "Wakeword Mode", action: #selector(toggleWakewordMode), keyEquivalent: "")
        wakewordItem.target = self
        // Set initial state based on current configuration
        wakewordItem.state = ConfigurationManager.shared.wakewordModeEnabled ? .on : .off
        wakewordToggleMenuItem = wakewordItem
        menu.addItem(wakewordItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Athena", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    private func setupMenuBarStateObservers() {
        // Subscribe to wakeword mode changes to update menu state
        ConfigurationManager.shared.$wakewordModeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self = self else { return }
                self.wakewordToggleMenuItem?.state = enabled ? .on : .off
                print("[AppDelegate] 🔄 Menu bar wakeword state updated: \(enabled)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Menu Actions
    
    @objc private func toggleWakewordMode() {
        let config = ConfigurationManager.shared
        let newValue = !config.wakewordModeEnabled
        print("[AppDelegate] 🎙️ Toggling wakeword mode: \(config.wakewordModeEnabled) -> \(newValue)")
        config.set(newValue, for: .wakewordModeEnabled)
    }
    
    @objc private func openSettings() {
        print("[AppDelegate] ⚙️ Opening settings from menu bar")
        windowManager?.openSettingsWindow()
    }
    
    @objc private func quitApplication() {
        print("[AppDelegate] 👋 Quitting application from menu bar")
        NSApplication.shared.terminate(nil)
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
        print("[AppDelegate] 🔐 Setting up global shortcut monitor (Option+A)")
        
        // Check if we have accessibility permissions for global hotkeys
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("[AppDelegate] ⚠️ Accessibility permissions not granted - global shortcuts won't work")
            print("[AppDelegate] 💡 Please grant accessibility permissions in System Settings > Privacy & Security > Accessibility")
        } else {
            print("[AppDelegate] ✅ Accessibility permissions granted")
        }
        
        let shortcutMask: NSEvent.ModifierFlags = [.option]
        let shortcutKeyCode: UInt16 = 0 // Key code for the "A" key on macOS keyboards

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == shortcutMask && event.keyCode == shortcutKeyCode {
                print("[AppDelegate] ⌨️ Global shortcut triggered (Option+A)")
                DispatchQueue.main.async {
                    self.toggleWindow()
                }
            }
        }
        
        print("[AppDelegate] ✅ Global shortcut monitor configured")
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
        cancellables.removeAll()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window is closed, keep running in background
        return false
    }
    
    // MARK: - URL Handling for OAuth
    
    /// Handles incoming URLs (OAuth redirect callback)
    func application(_ application: NSApplication, open urls: [URL]) {
        print("[AppDelegate] 🔗 application(_:open:) called with \(urls.count) URL(s)")
        
        for url in urls {
            print("[AppDelegate] 🔗 Processing URL: \(url.absoluteString)")
            print("[AppDelegate] 🔗 URL scheme: \(url.scheme ?? "nil")")
            print("[AppDelegate] 🔗 URL host: \(url.host ?? "nil")")
            print("[AppDelegate] 🔗 URL path: \(url.path)")
            print("[AppDelegate] 🔗 URL query: \(url.query ?? "nil")")
            
            // Handle Spotify OAuth redirect (athena://spotify-callback?code=...)
            if url.scheme == "athena", url.host == "spotify-callback" {
                print("[AppDelegate] 🎵 Spotify OAuth callback detected")
                AppDelegate.spotifyAuthCallback?(url)
                AppDelegate.spotifyAuthCallback = nil
                return
            }
            
            // Handle Google OAuth redirect
            print("[AppDelegate] 🔍 Checking for Google OAuth authorization flow...")
            if let authorizationFlow = AppDelegate.currentAuthorizationFlow {
                print("[AppDelegate] ✅ Authorization flow exists: \(authorizationFlow)")
                print("[AppDelegate] 🔄 Attempting to resume external user agent flow...")
                
                let resumed = authorizationFlow.resumeExternalUserAgentFlow(with: url)
                print("[AppDelegate] 🔄 Resume result: \(resumed)")
                
                if resumed {
                    AppDelegate.currentAuthorizationFlow = nil
                    print("[AppDelegate] ✅ Google OAuth redirect handled successfully")
                    return
                } else {
                    print("[AppDelegate] ⚠️ Authorization flow did not accept this URL")
                }
            } else {
                print("[AppDelegate] ⚠️ No authorization flow available (currentAuthorizationFlow is nil)")
            }
        }
        
        print("[AppDelegate] ⚠️ URL(s) not handled: \(urls.map { $0.absoluteString })")
    }
}
