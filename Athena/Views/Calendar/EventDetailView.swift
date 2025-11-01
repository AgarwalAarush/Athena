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
        .frame(minWidth: 400, minHeight: 300)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Event Details")
                .font(.headline)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
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
            }
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Time", systemImage: "clock")
                .font(.headline)
                .foregroundColor(.secondary)

            if event.isAllDay {
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundColor(.orange)
                    Text("All Day")
                        .font(.body)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Start:")
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(formatDateTime(event.startDate))
                    }

                    HStack {
                        Text("End:")
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(formatDateTime(event.endDate))
                    }

                    HStack {
                        Text("Duration:")
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(formatDuration())
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
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(event.calendar.cgColor))
                    .frame(width: 12, height: 12)

                Text(event.calendar.title)
                    .font(.body)
            }
        }
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(notes)
                .font(.body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
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
        calendar: mockCalendar
    )

    return EventDetailView(event: mockEvent)
}
