//
//  DayViewModel.swift
//  Athena
//
//  Created by Claude Code
//

import Foundation
import SwiftUI
import Combine
import EventKit
import AppKit

/// Data structure for holding AI-extracted event details before user confirmation
struct PendingEventData {
    var title: String
    var date: Date
    var startTime: Date
    var endTime: Date
    var notes: String?
}

/// ViewModel for managing day view calendar state and event fetching
@MainActor
class DayViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The currently selected date to display events for
    @Published var selectedDate: Date = Date()

    /// Array of calendar events for the selected date
    @Published var events: [CalendarEvent] = []

    /// Loading state indicator
    @Published var isLoading: Bool = false

    /// Error message to display if fetching fails
    @Published var errorMessage: String?

    /// Whether authorization has been granted
    @Published var isAuthorized: Bool = false

    /// Whether to show the event creation modal
    @Published var showCreateEventModal: Bool = false

    /// Pending event data for the creation modal
    @Published var pendingEventData: PendingEventData?

    // MARK: - Private Properties

    private let calendarService = CalendarService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        checkAuthorization()

        // Observe selectedDate changes to fetch events
        $selectedDate
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.fetchEvents()
                }
            }
            .store(in: &cancellables)
        
        // Observe calendar selection changes to refetch events
        calendarService.$selectedCalendarIDs
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                Task { @MainActor in
                    print("📅 Calendar selection changed - refetching events")
                    await self?.fetchEvents()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Authorization

    /// Check if calendar access is authorized
    func checkAuthorization() {
        let status = calendarService.authorizationStatus
        switch status {
        case .notDetermined:
            print("Calendar access status: Not Determined. Requesting access.")
        case .restricted:
            print("Calendar access status: Restricted.")
        case .denied:
            print("Calendar access status: Denied. Please grant access in System Settings.")
        case .authorized:
            print("Calendar access status: Authorized.")
        @unknown default:
            print("Calendar access status: Unknown.")
        }

        isAuthorized = calendarService.isAuthorized

        if !isAuthorized {
            requestAuthorization()
        } else {
            Task { await fetchEvents() }
        }
    }

    /// Request calendar access from the user
    func requestAuthorization() {
        calendarService.requestAccessWithActivation { [weak self] granted, error in
            Task { @MainActor in
                self?.isAuthorized = granted
                if granted {
                    await self?.fetchEvents()
                } else {
                    let status = self?.calendarService.authorizationStatus
                    if status == .denied || status == .restricted {
                        self?.errorMessage = "Calendar access is denied. Please enable it in System Settings."
                    } else if let error = error {
                        self?.errorMessage = "Calendar access denied: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    /// Opens System Settings to the Calendar privacy settings
    func openCalendarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Event Fetching

    /// Fetch events for the currently selected date
    func fetchEvents() async {
        isLoading = true
        errorMessage = nil

        // Get start and end of the selected day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            isLoading = false
            return
        }

        calendarService.fetchEvents(from: startOfDay, to: endOfDay) { [weak self] fetchedEvents, error in
            Task { @MainActor in
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = "Failed to fetch events: \(error.localizedDescription)"
                    self?.events = []
                } else {
                    self?.events = fetchedEvents ?? []
                }
            }
        }
    }

    // MARK: - Navigation

    /// Navigate to the previous day
    func previousDay() {
        guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = previousDay
    }

    /// Navigate to today
    func today() {
        selectedDate = Date()
    }

    /// Navigate to the next day
    func nextDay() {
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = nextDay
    }

    // MARK: - Computed Properties

    /// Whether the selected date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// All-day events for the selected date
    var allDayEvents: [CalendarEvent] {
        events.filter { $0.isAllDay }
    }

    /// Timed events for the selected date (non-all-day)
    var timedEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }
    }

    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: selectedDate)
    }

    // MARK: - Event Creation

    /// Present the event creation modal with pre-filled data
    func presentCreateEvent(with data: PendingEventData) {
        pendingEventData = data
        showCreateEventModal = true
    }

    /// Dismiss the event creation modal
    func dismissCreateEventModal() {
        showCreateEventModal = false
        pendingEventData = nil
    }
}
