//
//  UserInteractionTracker.swift
//  Athena
//
//  Monitors user interactions and triggers auto-hide after inactivity
//

import AppKit
import Foundation

/// Tracks user interactions (clicks, typing, scrolling) and auto-hides the window after a period of inactivity
@MainActor
class UserInteractionTracker: ObservableObject {
    // MARK: - Properties
    
    /// Timer for auto-hide delay
    private var hideTimer: Timer?
    
    /// Delay before auto-hiding (3 seconds)
    private let hideDelay: TimeInterval = 3.0
    
    /// Reference to WindowManager for controlling window visibility
    weak var windowManager: WindowManager?
    
    /// Reference to AppViewModel for checking orchestrator state and collapsing content
    weak var appViewModel: AppViewModel?
    
    /// Event monitor for tracking user interactions
    private var eventMonitor: Any?
    
    /// Flag to track if tracking is active
    private var isTracking = false
    
    // MARK: - Lifecycle
    
    deinit {
        stopTracking()
    }
    
    // MARK: - Public Methods
    
    /// Starts monitoring user interactions
    func startTracking() {
        guard !isTracking else {
            print("[UserInteractionTracker] Already tracking, skipping")
            return
        }
        
        print("[UserInteractionTracker] 🎯 Starting interaction tracking")
        isTracking = true
        
        // Set up event monitor for local events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .leftMouseDown,
            .rightMouseDown,
            .keyDown,
            .scrollWheel
        ]) { [weak self] event in
            self?.recordInteraction()
            return event
        }
        
        // Start the initial timer
        resetTimer()
    }
    
    /// Stops monitoring user interactions
    func stopTracking() {
        guard isTracking else { return }
        
        print("[UserInteractionTracker] 🛑 Stopping interaction tracking")
        isTracking = false
        
        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // Invalidate timer
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    /// Records a user interaction and resets the auto-hide timer
    func recordInteraction() {
        // Only log occasionally to avoid spam
        if Int.random(in: 0..<10) == 0 {
            print("[UserInteractionTracker] 👆 Interaction detected, resetting timer")
        }
        resetTimer()
    }
    
    // MARK: - Private Methods
    
    /// Resets the auto-hide timer to the full delay
    private func resetTimer() {
        // Invalidate existing timer
        hideTimer?.invalidate()
        
        // Create new timer
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            self?.checkAndHide()
        }
    }
    
    /// Checks conditions and hides window if appropriate
    private func checkAndHide() {
        guard let appViewModel = appViewModel,
              let windowManager = windowManager else {
            print("[UserInteractionTracker] ⚠️ Missing references, cannot hide")
            return
        }
        
        // Don't hide if orchestrator is running
        if appViewModel.isOrchestratorRunning {
            print("[UserInteractionTracker] 🚫 Orchestrator is running, not hiding")
            // Reset timer to check again later
            resetTimer()
            return
        }
        
        // Don't hide if content is not expanded (already in waveform-only mode)
        guard appViewModel.isContentExpanded else {
            print("[UserInteractionTracker] ℹ️ Content not expanded, no need to hide")
            return
        }
        
        print("[UserInteractionTracker] 🙈 Inactivity detected, collapsing content and hiding window")
        
        // Collapse content first
        appViewModel.collapseContent()
        
        // Small delay before hiding to let collapse animation finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            windowManager.toggleWindowVisibility()
        }
    }
}

