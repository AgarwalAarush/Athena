//
//  EventBlockView.swift
//  Athena
//
//  Created by Claude Code
//

import SwiftUI
import EventKit

/// A view representing a single timed event block in the day timeline
struct EventBlockView: View {

    // MARK: - Properties

    let event: CalendarEvent

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Event title
            Text(event.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(textColor)

            // Event time
            Text(timeRange)
                .font(.caption2)
                .foregroundColor(textColor.opacity(0.8))
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .accessibilityLabel("\(event.title), \(timeRange)")
    }

    // MARK: - Computed Properties

    /// The time range string for the event (e.g., "2:00 - 3:00 PM")
    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)

        return "\(start) - \(end)"
    }

    /// Background color based on calendar color
    private var backgroundColor: Color {
        Color(event.calendar.cgColor).opacity(0.2)
    }

    /// Border color based on calendar color
    private var borderColor: Color {
        Color(event.calendar.cgColor)
    }

    /// Text color that contrasts with background
    private var textColor: Color {
        // Use a darker text color for better readability
        .primary
    }
}

// MARK: - Preview

#Preview {
    let mockCalendar: EKCalendar = {
        let calendar = EKCalendar(for: .event, eventStore: EKEventStore())
        calendar.cgColor = NSColor.systemBlue.cgColor
        return calendar
    }()

    let mockEvent = CalendarEvent(
        id: "1",
        title: "Team Meeting",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        isAllDay: false,
        notes: "Discuss project updates",
        calendar: mockCalendar
    )

    return EventBlockView(event: mockEvent)
        .frame(width: 200, height: 80)
        .padding()
}
