//
//  FloatingWindow.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import AppKit

class FloatingWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        // Set the window to be transparent
        self.isOpaque = false
        self.backgroundColor = .clear

        // Remove title bar and other window adornments
        self.styleMask = [.borderless, .resizable]

        // Make it float above other windows
        self.level = .floating

        // Ensure it doesn't get a shadow
        self.hasShadow = false  // Shadow is handled by the SwiftUI view for correct corner rounding

        // Prevent it from appearing in the Dock and Command-Tab switcher
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Make the window movable by clicking and dragging anywhere
        self.isMovableByWindowBackground = true
    }

    // Override to allow the window to become key (receive keyboard events)
    override var canBecomeKey: Bool {
        return true
    }

    // Override to allow the window to become main
    override var canBecomeMain: Bool {
        return true
    }
}
