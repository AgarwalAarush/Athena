
import Foundation
import SwiftUI
import Combine

enum AppView {
    case chat
    case calendar
    case notes
}

class AppViewModel: ObservableObject {
    @Published var currentView: AppView = .chat
    
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
}
