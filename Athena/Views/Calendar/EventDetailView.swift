//
//  EventDetailView.swift
//  Athena
//
//  Created by Claude Code
//

import SwiftUI
import EventKit

/// A detailed view of a calendar event shown in a sheet/modal
struct EventDetailView: View {

    // MARK: - Properties

    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title section
                    titleSection

                    Divider()

                    // Time section
                    timeSection

                    Divider()

                    // Calendar section
                    calendarSection

                    if hasSupplementaryDetails {
                        Divider()

                        // Location section
                        if let location = event.location, !location.isEmpty {
                            locationSection(location)
                        }

                        // URL section
                        if let url = event.url {
                            urlSection(url)
                        }
                    }

                    // Notes section (if available)
                    if let notes = event.notes, !notes.isEmpty {
                        Divider()
                        notesSection(notes)
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .frame(width: 375)
        .frame(minHeight: 300)
        .background(Color.white.opacity(0.6))
        .cornerRadius(12)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Event Details")
                .font(.headline)
                .foregroundColor(.black)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.black) // Changed from .secondary
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding()
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(event.calendar.cgColor))
                    .frame(width: 4, height: 40)
                    .cornerRadius(2)

                Text(event.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Time", systemImage: "clock")
                .font(.headline)
                .foregroundColor(.black) // Changed from .secondary

            if event.isAllDay {
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundColor(.orange)
                    Text("All Day")
                        .font(.body)
                        .foregroundColor(.black)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Start:")
                            .foregroundColor(.black) // Changed from .secondary
                            .frame(width: 60, alignment: .leading)
                        Text(formatDateTime(event.startDate))
                            .foregroundColor(.black) // Explicitly set to black
                    }

                    HStack {
                        Text("End:")
                            .foregroundColor(.black) // Changed from .secondary
                            .frame(width: 60, alignment: .leading)
                        Text(formatDateTime(event.endDate))
                            .foregroundColor(.black) // Explicitly set to black
                    }

                    HStack {
                        Text("Duration:")
                            .foregroundColor(.black) // Changed from .secondary
                            .frame(width: 60, alignment: .leading)
                        Text(formatDuration())
                            .foregroundColor(.black) // Explicitly set to black
                    }
                }
                .font(.body)
            }
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Calendar", systemImage: "calendar")
                .font(.headline)
                .foregroundColor(.black) // Changed from .secondary

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(event.calendar.cgColor))
                    .frame(width: 12, height: 12)

                Text(event.calendar.title)
                    .font(.body)
                    .foregroundColor(.black)
            }
        }
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundColor(.black) // Changed from .secondary

            Text(notes)
                .font(.body)
                .foregroundColor(.black) // Changed from .primary
                .textSelection(.enabled)
        }
    }

    private func locationSection(_ location: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Location", systemImage: "mappin.and.ellipse")
                .font(.headline)
                .foregroundColor(.black)

            Text(location)
                .font(.body)
                .foregroundColor(.black)
        }
    }

    private func urlSection(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Link", systemImage: "link")
                .font(.headline)
                .foregroundColor(.black)

            Link(destination: url) {
                Text(url.absoluteString)
                    .font(.body)
                    .foregroundColor(.blue)
                    .underline()
            }
        }
    }

    // MARK: - Helper Methods

    /// Format date and time for display
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Calculate and format event duration
    private func formatDuration() -> String {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private var hasSupplementaryDetails: Bool {
        let hasLocation = (event.location?.isEmpty == false)
        let hasURL = (event.url != nil)
        return hasLocation || hasURL
    }
}

// MARK: - Preview

#Preview {
    let mockCalendar: EKCalendar = {
        let calendar = EKCalendar(for: .event, eventStore: EKEventStore())
        calendar.title = "Work"
        calendar.cgColor = NSColor.systemBlue.cgColor
        return calendar
    }()

    let mockEvent = CalendarEvent(
        id: "1",
        title: "Team Standup Meeting",
        startDate: Date(),
        endDate: Date().addingTimeInterval(1800),
        isAllDay: false,
        notes: "Daily standup to discuss progress and blockers. Join via Zoom link in calendar invite.",
        location: "Conference Room A",
        url: URL(string: "https://zoom.us/j/123456789"),
        calendar: mockCalendar
    )

    return EventDetailView(event: mockEvent)
}
