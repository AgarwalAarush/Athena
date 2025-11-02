
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
        currentView = .calendar
        windowManager?.resizeForCalendar()
    }

    func showChat() {
        currentView = .chat
        windowManager?.resizeForChat()
    }

    func showNotes() {
        currentView = .notes
        windowManager?.resizeForCalendar()
    }
}
