//
//  AppDelegate.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    var statusItem: NSStatusItem?
    private var eventMonitor: Any?
    private var settingsShortcutMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Athena")
            button.action = #selector(toggleWindow)
            button.target = self
        }

        // Initialize window manager with floating utility window configuration
        windowManager = WindowManager()
        windowManager?.setupFloatingWindow()

        // Hide dock icon for floating utility window
        NSApp.setActivationPolicy(.accessory)

        // Initially hide the window - it will be shown when menu bar icon is clicked
        windowManager?.toggleWindowVisibility()

        setupGlobalShortcutMonitor()
        setupSettingsShortcutMonitor()

        Task { @MainActor in
            await SpeechService.shared.requestAuthorization()
        }
    }

    @objc func toggleWindow() {
        guard let windowManager = windowManager else { return }

        // Position window near the status bar item before showing
        if let button = statusItem?.button,
           let window = windowManager.window {

            if !window.isVisible {
                // Calculate position below the status bar item
                let buttonFrame = button.window?.frame ?? .zero
                let screen = NSScreen.main?.visibleFrame ?? .zero
                let windowSize = window.frame.size

                let x = buttonFrame.origin.x + (buttonFrame.width / 2) - (windowSize.width / 2)
                let y = screen.maxY - buttonFrame.height - windowSize.height - 5 // A little below the menu bar

                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }

        windowManager.toggleWindowVisibility()
    }
    
    private func setupGlobalShortcutMonitor() {
        let shortcutMask: NSEvent.ModifierFlags = [.command, .control]
        let shortcutKeyCode: UInt16 = 38 // Key code for the "J" key on macOS keyboards

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
}
