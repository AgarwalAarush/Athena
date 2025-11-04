
import Foundation
import SwiftUI
import Combine

enum AppView {
    case home
    case chat
    case calendar
    case notes
}

class AppViewModel: ObservableObject {
    @Published var currentView: AppView = .home

    // MARK: - View Models for Orchestrator Access

    /// DayViewModel for calendar view - accessible to orchestrator for executing calendar actions
    /// NOTE: Must be @Published (not @StateObject) because AppViewModel is not a View
    @Published var dayViewModel = DayViewModel()

    /// NotesViewModel for notes view - accessible to orchestrator for executing notes actions
    @Published var notesViewModel = NotesViewModel(store: SwiftDataNotesStore())

    /// Note content for notes view - accessible to orchestrator for executing notes actions
    @Published var noteContent: String = ""

    // MARK: - Private Properties

    private var windowManager: WindowManager?
    
    // MARK: - Wake Word Management
    
    /// Reference to the wake word manager (set by ChatViewModel)
    private var wakeWordManager: WakeWordTranscriptionManager?
    
    /// Flag to track if wake word was paused (to resume it later)
    private var wakeWordWasPaused: Bool = false

    func setup(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func showCalendar() {
        stopListenModeIfActive()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .calendar
        }
        windowManager?.resizeForCalendar()
    }

    func showChat() {
        stopListenModeIfActive()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .chat
        }
        windowManager?.resizeForChat()
    }

    func showNotes() {
        stopListenModeIfActive()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .notes
        }
        windowManager?.resizeForCalendar()
    }

    func showHome() {
        stopListenModeIfActive()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .home
        }
        windowManager?.resizeForCalendar()
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
        print("[AppViewModel] Setting wake word manager: \(manager != nil ? "present" : "nil")")
        self.wakeWordManager = manager
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
}
