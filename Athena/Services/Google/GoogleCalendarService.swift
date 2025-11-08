//
//  GoogleCalendarService.swift
//  Athena
//
//  Created by Claude Code on 11/7/25.
//

import Foundation
import GoogleAPIClientForREST_Calendar
import GTMAppAuth

/// Errors that can occur during Google Calendar operations
enum GoogleCalendarServiceError: Error, LocalizedError {
    case notAuthenticated
    case authorizationFailed(Error)
    case eventNotFound
    case createFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case fetchFailed(Error)
    case invalidEventData
    case calendarNotFound
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Google. Please sign in first."
        case .authorizationFailed(let error):
            return "Google Calendar authorization failed: \(error.localizedDescription)"
        case .eventNotFound:
            return "The requested calendar event was not found."
        case .createFailed(let error):
            return "Failed to create calendar event: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update calendar event: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete calendar event: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch calendar events: \(error.localizedDescription)"
        case .invalidEventData:
            return "Invalid calendar event data provided."
        case .calendarNotFound:
            return "The specified calendar was not found."
        case .unknownError(let error):
            return "Unknown Google Calendar error: \(error.localizedDescription)"
        }
    }
}

/// Service for managing Google Calendar operations
@MainActor
class GoogleCalendarService {
    static let shared = GoogleCalendarService()

    // MARK: - Properties

    private let authService = GoogleAuthService.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Calendar Service Setup

    /// Creates and configures a GTLRCalendarService instance with current authorization
    /// - Returns: Configured GTLRCalendarService
    /// - Throws: GoogleCalendarServiceError if authorization fails
    private func getCalendarService() throws -> GTLRCalendarService {
        // Get authorization from GoogleAuthService
        guard let authorization = try? authService.getAuthorization() else {
            throw GoogleCalendarServiceError.notAuthenticated
        }

        // Create Calendar service
        let service = GTLRCalendarService()

        // Assign authorizer (GTMAppAuthFetcherAuthorization)
        service.authorizer = authorization

        return service
    }

    // MARK: - List Events

    /// Fetches upcoming events from the primary calendar
    /// - Parameters:
    ///   - maxResults: Maximum number of events to fetch (default: 10)
    ///   - calendarId: ID of the calendar (default: "primary")
    ///   - timeMin: Minimum start time for events (default: now)
    ///   - timeMax: Maximum start time for events (optional)
    /// - Returns: Array of GTLRCalendar_Event objects
    /// - Throws: GoogleCalendarServiceError on failure
    func fetchUpcomingEvents(
        maxResults: Int = 10,
        calendarId: String = "primary",
        timeMin: Date = Date(),
        timeMax: Date? = nil
    ) async throws -> [GTLRCalendar_Event] {
        let service = try getCalendarService()

        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: calendarId)
        query.maxResults = maxResults
        query.timeMin = GTLRDateTime(date: timeMin)
        if let timeMax = timeMax {
            query.timeMax = GTLRDateTime(date: timeMax)
        }
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.fetchFailed(error))
                        return
                    }

                    guard let events = (result as? GTLRCalendar_Events)?.items else {
                        continuation.resume(returning: [])
                        return
                    }

                    continuation.resume(returning: events)
                }
            }
        }
    }

    /// Fetches a single event by ID
    /// - Parameters:
    ///   - eventId: The ID of the event to fetch
    ///   - calendarId: ID of the calendar (default: "primary")
    /// - Returns: GTLRCalendar_Event object
    /// - Throws: GoogleCalendarServiceError on failure
    func getEvent(eventId: String, calendarId: String = "primary") async throws -> GTLRCalendar_Event {
        let service = try getCalendarService()

        let query = GTLRCalendarQuery_EventsGet.query(withCalendarId: calendarId, eventId: eventId)

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.fetchFailed(error))
                        return
                    }

                    guard let event = result as? GTLRCalendar_Event else {
                        continuation.resume(throwing: GoogleCalendarServiceError.eventNotFound)
                        return
                    }

                    continuation.resume(returning: event)
                }
            }
        }
    }

    /// Searches for events using a text query
    /// - Parameters:
    ///   - searchQuery: Text to search for in event summaries and descriptions
    ///   - calendarId: ID of the calendar (default: "primary")
    ///   - maxResults: Maximum number of events to return (default: 20)
    /// - Returns: Array of matching GTLRCalendar_Event objects
    /// - Throws: GoogleCalendarServiceError on failure
    func searchEvents(
        searchQuery: String,
        calendarId: String = "primary",
        maxResults: Int = 20
    ) async throws -> [GTLRCalendar_Event] {
        let service = try getCalendarService()

        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: calendarId)
        query.q = searchQuery
        query.maxResults = maxResults
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.fetchFailed(error))
                        return
                    }

                    guard let events = (result as? GTLRCalendar_Events)?.items else {
                        continuation.resume(returning: [])
                        return
                    }

                    continuation.resume(returning: events)
                }
            }
        }
    }

    // MARK: - Create Events

    /// Creates a new calendar event
    /// - Parameters:
    ///   - summary: Event title/summary
    ///   - description: Event description (optional)
    ///   - startTime: Event start time
    ///   - endTime: Event end time
    ///   - location: Event location (optional)
    ///   - attendees: Array of attendee email addresses (optional)
    ///   - calendarId: ID of the calendar (default: "primary")
    /// - Returns: Created GTLRCalendar_Event object
    /// - Throws: GoogleCalendarServiceError on failure
    func createEvent(
        summary: String,
        description: String? = nil,
        startTime: Date,
        endTime: Date,
        location: String? = nil,
        attendees: [String]? = nil,
        calendarId: String = "primary"
    ) async throws -> GTLRCalendar_Event {
        let service = try getCalendarService()

        // Create event object
        let event = GTLRCalendar_Event()
        event.summary = summary
        event.descriptionProperty = description
        event.location = location

        // Set start time
        let start = GTLRCalendar_EventDateTime()
        start.dateTime = GTLRDateTime(date: startTime)
        event.start = start

        // Set end time
        let end = GTLRCalendar_EventDateTime()
        end.dateTime = GTLRDateTime(date: endTime)
        event.end = end

        // Add attendees if provided
        if let attendees = attendees, !attendees.isEmpty {
            event.attendees = attendees.map { email in
                let attendee = GTLRCalendar_EventAttendee()
                attendee.email = email
                return attendee
            }
        }

        // Create insert query
        let query = GTLRCalendarQuery_EventsInsert.query(withObject: event, calendarId: calendarId)

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.createFailed(error))
                        return
                    }

                    guard let createdEvent = result as? GTLRCalendar_Event else {
                        continuation.resume(throwing: GoogleCalendarServiceError.invalidEventData)
                        return
                    }

                    print("✓ Calendar event created successfully")
                    continuation.resume(returning: createdEvent)
                }
            }
        }
    }

    /// Creates a quick event using natural language
    /// - Parameters:
    ///   - text: Natural language description (e.g., "Meeting tomorrow at 2pm")
    ///   - calendarId: ID of the calendar (default: "primary")
    /// - Returns: Created GTLRCalendar_Event object
    /// - Throws: GoogleCalendarServiceError on failure
    func createQuickEvent(text: String, calendarId: String = "primary") async throws -> GTLRCalendar_Event {
        let service = try getCalendarService()

        let query = GTLRCalendarQuery_EventsQuickAdd.query(withCalendarId: calendarId, text: text)

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.createFailed(error))
                        return
                    }

                    guard let createdEvent = result as? GTLRCalendar_Event else {
                        continuation.resume(throwing: GoogleCalendarServiceError.invalidEventData)
                        return
                    }

                    print("✓ Quick event created successfully")
                    continuation.resume(returning: createdEvent)
                }
            }
        }
    }

    // MARK: - Update Events

    /// Updates an existing calendar event
    /// - Parameters:
    ///   - eventId: ID of the event to update
    ///   - summary: New event title/summary (optional)
    ///   - description: New event description (optional)
    ///   - startTime: New event start time (optional)
    ///   - endTime: New event end time (optional)
    ///   - location: New event location (optional)
    ///   - calendarId: ID of the calendar (default: "primary")
    /// - Returns: Updated GTLRCalendar_Event object
    /// - Throws: GoogleCalendarServiceError on failure
    func updateEvent(
        eventId: String,
        summary: String? = nil,
        description: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        location: String? = nil,
        calendarId: String = "primary"
    ) async throws -> GTLRCalendar_Event {
        // First, fetch the existing event
        let existingEvent = try await getEvent(eventId: eventId, calendarId: calendarId)

        // Update fields
        if let summary = summary {
            existingEvent.summary = summary
        }
        if let description = description {
            existingEvent.descriptionProperty = description
        }
        if let location = location {
            existingEvent.location = location
        }
        if let startTime = startTime {
            let start = GTLRCalendar_EventDateTime()
            start.dateTime = GTLRDateTime(date: startTime)
            existingEvent.start = start
        }
        if let endTime = endTime {
            let end = GTLRCalendar_EventDateTime()
            end.dateTime = GTLRDateTime(date: endTime)
            existingEvent.end = end
        }

        let service = try getCalendarService()

        // Create update query
        let query = GTLRCalendarQuery_EventsUpdate.query(
            withObject: existingEvent,
            calendarId: calendarId,
            eventId: eventId
        )

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.updateFailed(error))
                        return
                    }

                    guard let updatedEvent = result as? GTLRCalendar_Event else {
                        continuation.resume(throwing: GoogleCalendarServiceError.invalidEventData)
                        return
                    }

                    print("✓ Calendar event updated successfully")
                    continuation.resume(returning: updatedEvent)
                }
            }
        }
    }

    // MARK: - Delete Events

    /// Deletes a calendar event
    /// - Parameters:
    ///   - eventId: ID of the event to delete
    ///   - calendarId: ID of the calendar (default: "primary")
    /// - Throws: GoogleCalendarServiceError on failure
    func deleteEvent(eventId: String, calendarId: String = "primary") async throws {
        let service = try getCalendarService()

        let query = GTLRCalendarQuery_EventsDelete.query(withCalendarId: calendarId, eventId: eventId)

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.deleteFailed(error))
                        return
                    }

                    print("✓ Calendar event deleted successfully")
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Calendar Management

    /// Lists all calendars accessible to the user
    /// - Returns: Array of GTLRCalendar_CalendarListEntry objects
    /// - Throws: GoogleCalendarServiceError on failure
    func listCalendars() async throws -> [GTLRCalendar_CalendarListEntry] {
        let service = try getCalendarService()

        let query = GTLRCalendarQuery_CalendarListList.query()

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.fetchFailed(error))
                        return
                    }

                    guard let calendarList = (result as? GTLRCalendar_CalendarList)?.items else {
                        continuation.resume(returning: [])
                        return
                    }

                    continuation.resume(returning: calendarList)
                }
            }
        }
    }

    // MARK: - Free/Busy Queries

    /// Checks free/busy information for a time range
    /// - Parameters:
    ///   - timeMin: Start time for the query
    ///   - timeMax: End time for the query
    ///   - calendarIds: Array of calendar IDs to check (default: ["primary"])
    /// - Returns: GTLRCalendar_FreeBusyResponse object
    /// - Throws: GoogleCalendarServiceError on failure
    func checkFreeBusy(
        timeMin: Date,
        timeMax: Date,
        calendarIds: [String] = ["primary"]
    ) async throws -> GTLRCalendar_FreeBusyResponse {
        let service = try getCalendarService()

        // Create request
        let request = GTLRCalendar_FreeBusyRequest()
        request.timeMin = GTLRDateTime(date: timeMin)
        request.timeMax = GTLRDateTime(date: timeMax)

        let items = calendarIds.map { calendarId in
            let item = GTLRCalendar_FreeBusyRequestItem()
            item.identifier = calendarId
            return item
        }
        request.items = items

        let query = GTLRCalendarQuery_FreebusyQuery(object: request)

        return try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket, result, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: GoogleCalendarServiceError.fetchFailed(error))
                        return
                    }

                    guard let freeBusyResponse = result as? GTLRCalendar_FreeBusyResponse else {
                        continuation.resume(
                            throwing: GoogleCalendarServiceError.unknownError(
                                NSError(domain: "GoogleCalendarService", code: -1, userInfo: nil)
                            )
                        )
                        return
                    }

                    continuation.resume(returning: freeBusyResponse)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Formats an event's time range as a readable string
    /// - Parameter event: The calendar event
    /// - Returns: Formatted time range string
    func formatEventTime(_ event: GTLRCalendar_Event) -> String? {
        guard let start = event.start?.dateTime?.date,
              let end = event.end?.dateTime?.date else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let startString = formatter.string(from: start)
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let endString = formatter.string(from: end)

        return "\(startString) - \(endString)"
    }

    /// Checks if an event is happening now
    /// - Parameter event: The calendar event
    /// - Returns: true if the event is currently happening
    func isEventHappeningNow(_ event: GTLRCalendar_Event) -> Bool {
        guard let start = event.start?.dateTime?.date,
              let end = event.end?.dateTime?.date else {
            return false
        }

        let now = Date()
        return now >= start && now <= end
    }

    /// Extracts all attendee email addresses from an event
    /// - Parameter event: The calendar event
    /// - Returns: Array of attendee email addresses
    func extractAttendeeEmails(_ event: GTLRCalendar_Event) -> [String] {
        guard let attendees = event.attendees else {
            return []
        }

        return attendees.compactMap { $0.email }
    }
}
