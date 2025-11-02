
//
//  CalendarService.swift
//  Athena
//
//  Created by Aarush Agarwal on 10/31/25.
//

import Foundation
import EventKit

/// A simple struct to represent a calendar event, decoupled from EKEvent.
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let notes: String?
    let calendar: EKCalendar
}

/// A service to interact with the user's calendar using EventKit.
class CalendarService {
    
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    
    private init() {}
    
    // MARK: - Authorization

    /// Requests access to the user's calendar.
    /// - Parameter completion: A closure that is called with a boolean indicating whether access was granted and an optional error.
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    completion(granted, error)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    completion(granted, error)
                }
            }
        }
    }

    /// A boolean indicating whether the app has been granted access to the user's calendar.
    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            // For reading events, we need fullAccess
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    /// Returns the current authorization status for calendar access.
    func authorizationStatus() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }
    
    // MARK: - Fetching Events
    
    /// Fetches events from the user's calendars for a given date range.
    /// - Parameters:
    ///   - startDate: The start date of the range to fetch events from.
    ///   - endDate: The end date of the range to fetch events from.
    ///   - completion: A closure that is called with an array of `CalendarEvent` objects or an error.
    func fetchEvents(from startDate: Date, to endDate: Date, completion: @escaping ([CalendarEvent]?, Error?) -> Void) {
        guard isAuthorized else {
            completion(nil, NSError(domain: "CalendarService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authorized to access calendar."]))
            return
        }
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        
        let events = eventStore.events(matching: predicate).map { ekEvent -> CalendarEvent in
            return CalendarEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                isAllDay: ekEvent.isAllDay,
                notes: ekEvent.notes,
                calendar: ekEvent.calendar
            )
        }
        
        completion(events, nil)
    }
    
    // MARK: - Creating Events
    
    /// Creates a new event in the user's calendar.
    /// - Parameters:
    ///   - title: The title of the event.
    ///   - startDate: The start date and time of the event.
    ///   - endDate: The end date and time of the event.
    ///   - notes: Optional notes for the event.
    ///   - calendar: The calendar to add the event to. If nil, the default calendar is used.
    ///   - completion: A closure that is called with the created `CalendarEvent` or an error.
    func createEvent(title: String, startDate: Date, endDate: Date, notes: String?, in calendar: EKCalendar? = nil, completion: @escaping (CalendarEvent?, Error?) -> Void) {
        guard isAuthorized else {
            completion(nil, NSError(domain: "CalendarService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authorized to access calendar."]))
            return
        }
        
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = title
        newEvent.startDate = startDate
        newEvent.endDate = endDate
        newEvent.notes = notes
        newEvent.calendar = calendar ?? eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(newEvent, span: .thisEvent)
            let calendarEvent = CalendarEvent(
                id: newEvent.eventIdentifier,
                title: newEvent.title,
                startDate: newEvent.startDate,
                endDate: newEvent.endDate,
                isAllDay: newEvent.isAllDay,
                notes: newEvent.notes,
                calendar: newEvent.calendar
            )
            completion(calendarEvent, nil)
        } catch {
            completion(nil, error)
        }
    }
    
    // MARK: - Updating Events
    
    /// Updates an existing event in the user's calendar.
    /// - Parameters:
    ///   - event: The `CalendarEvent` to update.
    ///   - completion: A closure that is called with the updated `CalendarEvent` or an error.
    func updateEvent(_ event: CalendarEvent, completion: @escaping (CalendarEvent?, Error?) -> Void) {
        guard isAuthorized else {
            completion(nil, NSError(domain: "CalendarService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authorized to access calendar."]))
            return
        }
        
        guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
            completion(nil, NSError(domain: "CalendarService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found."]))
            return
        }
        
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.isAllDay = event.isAllDay
        ekEvent.notes = event.notes
        ekEvent.calendar = event.calendar
        
        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            let updatedEvent = CalendarEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                isAllDay: ekEvent.isAllDay,
                notes: ekEvent.notes,
                calendar: ekEvent.calendar
            )
            completion(updatedEvent, nil)
        } catch {
            completion(nil, error)
        }
    }
    
    // MARK: - Deleting Events
    
    /// Deletes an event from the user's calendar.
    /// - Parameters:
    ///   - event: The `CalendarEvent` to delete.
    ///   - completion: A closure that is called with an optional error.
    func deleteEvent(_ event: CalendarEvent, completion: @escaping (Error?) -> Void) {
        guard isAuthorized else {
            completion(NSError(domain: "CalendarService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authorized to access calendar."]))
            return
        }
        
        guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
            completion(NSError(domain: "CalendarService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found."]))
            return
        }
        
        do {
            try eventStore.remove(ekEvent, span: .thisEvent)
            completion(nil)
        } catch {
            completion(error)
        }
    }
}
