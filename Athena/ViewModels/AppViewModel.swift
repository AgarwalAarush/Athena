
import Foundation
import SwiftUI

enum AppView {
    case chat
    case calendar
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
}
