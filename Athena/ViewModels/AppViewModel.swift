
import Foundation
import SwiftUI
import Combine

enum AppView {
    case home
    case chat
    case calendar
    case notes
    case messaging
    case gmail
}

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button?
    let secondaryButton: Alert.Button?
}

class AppViewModel: ObservableObject {
    @Published var currentView: AppView = .home
    @Published var alertInfo: AlertInfo?
    
    // MARK: - Content Expansion State
    
    /// Tracks whether the content area below the waveform is expanded
    @Published var isContentExpanded: Bool = false
    
    /// Tracks whether the orchestrator is currently running (prevents auto-hide)
    @Published var isOrchestratorRunning: Bool = false

    // MARK: - View Models for Orchestrator Access

    /// DayViewModel for calendar view - accessible to orchestrator for executing calendar actions
    /// NOTE: Must be @Published (not @StateObject) because AppViewModel is not a View
    @Published var dayViewModel = DayViewModel()

    /// NotesViewModel for notes view - accessible to orchestrator for executing notes actions
    @Published var notesViewModel = NotesViewModel(store: SwiftDataNotesStore())

    /// Note content for notes view - accessible to orchestrator for executing notes actions
    @Published var noteContent: String = ""
    
    /// MessagingViewModel for messaging view - accessible to orchestrator for executing messaging actions
    @Published var messagingViewModel = MessagingViewModel()

    /// Messaging status for user feedback - set by orchestrator after sending messages
    @Published var messagingStatus: String?
    
    /// GmailViewModel for Gmail view - accessible to orchestrator for executing email actions
    @Published var gmailViewModel = GmailViewModel()

    // MARK: - Private Properties

    private var windowManager: WindowManager?
    private weak var appDelegate: AppDelegate?
    
    // MARK: - Wake Word Management
    
    /// Reference to the wake word manager (set by ChatViewModel)
    private var wakeWordManager: WakeWordTranscriptionManager?
    
    /// Flag to track if wake word was paused (to resume it later)
    private var wakeWordWasPaused: Bool = false

    func setup(windowManager: WindowManager, appDelegate: AppDelegate) {
        print("[AppViewModel] 🔧 setup() called")
        print("[AppViewModel] 📊 windowManager: \(windowManager)")
        print("[AppViewModel] 📊 appDelegate: \(appDelegate)")
        
        self.windowManager = windowManager
        self.appDelegate = appDelegate
        
        // Setup messaging view model
        messagingViewModel.setup(appViewModel: self)
        
        // Setup Gmail view model
        gmailViewModel.setup(appViewModel: self)
        
        print("[AppViewModel] ✅ setup() completed - windowManager and appDelegate stored")
    }

    func showCalendar() {
        stopListenModeIfActive()
        isContentExpanded = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .calendar
        }
        windowManager?.expandToContentView()
    }

    func showChat() {
        stopListenModeIfActive()
        isContentExpanded = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .chat
        }
        windowManager?.expandToContentView()
    }

    func showNotes() {
        stopListenModeIfActive()
        isContentExpanded = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .notes
        }
        windowManager?.expandToContentView()
    }

    func showHome() {
        stopListenModeIfActive()
        isContentExpanded = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .home
        }
        windowManager?.expandToContentView()
    }
    
    func showGmail() {
        stopListenModeIfActive()
        isContentExpanded = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .gmail
        }
        windowManager?.expandToContentView()
    }
    
    /// Collapses the content area back to waveform-only view
    func collapseContent() {
        isContentExpanded = false
        windowManager?.collapseToWaveformOnly()
    }
    
    /// Stop listen mode if it's currently active
    private func stopListenModeIfActive() {
        if notesViewModel.listenModeState != .idle {
            print("[AppViewModel] 🔄 View switching - stopping active listen mode")
            notesViewModel.stopListenMode()
        }
    }
    
    // MARK: - Wake Word Control
    
    /// Set the wake word manager reference (called by ChatViewModel)
    func setWakeWordManager(_ manager: WakeWordTranscriptionManager?) {
        print("[AppViewModel] 🔧 Setting wake word manager: \(manager != nil ? "present" : "nil")")
        self.wakeWordManager = manager

        // Set up callback to show window when wake word is detected (if hidden)
        manager?.onWakeWordDetectedCallback = { [weak self] in
            print("[AppViewModel] 🎤 ⚡️ WAKE WORD CALLBACK TRIGGERED!")
            
            guard let self = self else {
                print("[AppViewModel] ❌ Wake word callback: self is nil")
                return
            }
            
            print("[AppViewModel] ✅ Wake word callback: self exists")
            print("[AppViewModel] 📊 appDelegate: \(self.appDelegate != nil ? "present" : "nil")")
            print("[AppViewModel] 📊 windowManager: \(self.windowManager != nil ? "present" : "nil")")
            print("[AppViewModel] 📊 window: \(self.windowManager?.window != nil ? "present" : "nil")")
            
            guard let appDelegate = self.appDelegate else {
                print("[AppViewModel] ❌ Wake word callback: appDelegate is nil - cannot show window")
                return
            }
            
            guard let window = self.windowManager?.window else {
                print("[AppViewModel] ❌ Wake word callback: window is nil - cannot check visibility")
                return
            }
            
            print("[AppViewModel] 📊 Window visibility: \(window.isVisible ? "visible" : "hidden")")

            if !window.isVisible {
                print("[AppViewModel] 🪟 Wake word detected - window is hidden, attempting to show it")
                // Use AppDelegate's toggleWindow method for proper window positioning and app activation
                DispatchQueue.main.async {
                    print("[AppViewModel] 🎯 Calling appDelegate.toggleWindow() on main thread")
                    appDelegate.toggleWindow()
                    print("[AppViewModel] ✅ toggleWindow() called")
                }
            } else {
                print("[AppViewModel] ℹ️ Wake word detected but window is already visible, not showing")
            }
        }
        
        print("[AppViewModel] ✅ Wake word callback configured successfully")
    }
    
    /// Pause wake word detection (used when entering listen mode)
    func pauseWakeWord() {
        print("[AppViewModel] 🔇 Pausing wake word mode")
        
        guard let manager = wakeWordManager else {
            print("[AppViewModel] ⚠️ No wake word manager to pause")
            return
        }
        
        // Only pause if it's currently running
        if manager.state != .idle {
            print("[AppViewModel] 🛑 Stopping wake word manager")
            manager.stop()
            wakeWordWasPaused = true
        } else {
            print("[AppViewModel] ⚠️ Wake word manager already idle, not pausing")
            wakeWordWasPaused = false
        }
    }
    
    /// Resume wake word detection (used when exiting listen mode)
    func resumeWakeWord() {
        print("[AppViewModel] 🔊 Resuming wake word mode (was paused: \(wakeWordWasPaused))")
        
        guard let manager = wakeWordManager, wakeWordWasPaused else {
            if wakeWordManager == nil {
                print("[AppViewModel] ⚠️ No wake word manager to resume")
            } else {
                print("[AppViewModel] ⚠️ Wake word was not paused, not resuming")
            }
            return
        }
        
        print("[AppViewModel] ▶️ Restarting wake word manager")
        Task {
            do {
                try await manager.start()
                print("[AppViewModel] ✅ Wake word manager resumed successfully")
            } catch {
                print("[AppViewModel] ❌ Error resuming wake word: \(error)")
            }
        }

        wakeWordWasPaused = false
    }

    // MARK: - Messaging Status Control

    /// Clears the current messaging status message
    func clearMessagingStatus() {
        messagingStatus = nil
    }
}
