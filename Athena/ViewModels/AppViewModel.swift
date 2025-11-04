
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

    func setup(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func showCalendar() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .calendar
        }
        windowManager?.resizeForCalendar()
    }

    func showChat() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .chat
        }
        windowManager?.resizeForChat()
    }

    func showNotes() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .notes
        }
        windowManager?.resizeForCalendar()
    }

    func showHome() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentView = .home
        }
        windowManager?.resizeForCalendar()
    }
}
