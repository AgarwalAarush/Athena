//
//  DayView.swift
//  Athena
//
//  Created by Claude Code
//

import SwiftUI
import EventKit

/// Main day view calendar component displaying events for a single day
struct DayView: View {

    // MARK: - Properties

    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = DayViewModel()
    @State private var selectedEvent: CalendarEvent?
    @State private var showEventDetail = false
    @State private var currentTimeOffset: CGFloat = 0

    // MARK: - Constants

    private let hourHeight: CGFloat = 60
    private let hourLabelWidth: CGFloat = 60
    private let eventSpacing: CGFloat = 2
    private let eventCornerRadius: CGFloat = 4

    // MARK: - Body

    var body: some View {
        ZStack {
            // Rounded container for calendar content
            VStack(spacing: 0) {
                // Navigation header
                navigationHeader

                Divider()

                // Content area
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading events...")
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    Spacer()
                    errorView(message: errorMessage)
                    Spacer()
                } else {
                    calendarContent
                }
            }
            .background(Color.white.opacity(0.6))
            .cornerRadius(8)
            .padding()

            // Invisible buttons for keyboard shortcuts
            VStack {
                Button("", action: viewModel.previousDay)
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    .hidden()

                Button("", action: viewModel.nextDay)
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                    .hidden()
            }
            .frame(width: 0, height: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            startCurrentTimeTimer()
        }
        .sheet(isPresented: $showEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event)
            }
        }
    }

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        HStack {
            // Previous Day button
            Button(action: viewModel.previousDay) {
                Label("Previous", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.black)
            .help("Previous day (⌘←)")

            Spacer()

            // Date display
            VStack(spacing: 2) {
                Text(viewModel.formattedDate)
                    .font(.headline)
                    .foregroundColor(.black) // Explicitly set to black
                if viewModel.isToday {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.black) // Explicitly set to black
                }
            }

            Spacer()

            // Today button
            Button(action: viewModel.today) {
                Text("Today")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.black)
            .disabled(viewModel.isToday)

            // Next Day button
            Button(action: viewModel.nextDay) {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.black)
            .help("Next day (⌘→)")
        }
        .padding()
    }

    // MARK: - Calendar Content

    private var calendarContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    // All-day events section
                    if !viewModel.allDayEvents.isEmpty {
                        allDayEventsSection
                        Divider()
                            .padding(.vertical, 8)
                    }

                    // Timed events timeline
                    timelineView
                        .id("timeline")
                }
                .padding()
            }
            .onAppear {
                // Scroll to current time if viewing today
                if viewModel.isToday {
                    scrollToCurrentTime(scrollProxy)
                }
            }
        }
    }

    // MARK: - All-Day Events Section

    private var allDayEventsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All-Day Events")
                .font(.caption)
                .foregroundColor(.black) // Explicitly set to black
                .padding(.horizontal, 4)

            VStack(spacing: 4) {
                ForEach(viewModel.allDayEvents) { event in
                    AllDayEventRow(event: event)
                        .onTapGesture {
                            selectedEvent = event
                            showEventDetail = true
                        }
                }
            }
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Hour grid and labels
                hourGrid

                // Timed events
                timedEventsLayer(in: geometry)

                // Current time indicator
                if viewModel.isToday {
                    currentTimeIndicator(in: geometry)
                }
            }
        }
        .frame(height: hourHeight * 24) // 24 hours
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    // Hour label
                    Text(formatHour(hour))
                        .font(.caption)
                        .foregroundColor(.black) // Explicitly set to black
                        .frame(width: hourLabelWidth, alignment: .trailing)
                        .padding(.trailing, 8)

                    // Hour line
                    VStack(spacing: 0) {
                        Divider()
                        Spacer()
                    }
                }
                .frame(height: hourHeight)
            }
        }
    }

    // MARK: - Timed Events Layer

    private func timedEventsLayer(in geometry: GeometryProxy) -> some View {
        let eventGroups = calculateOverlappingGroups(viewModel.timedEvents)

        return ForEach(Array(eventGroups.enumerated()), id: \.offset) { _, group in
            ForEach(Array(group.enumerated()), id: \.element.id) { index, event in
                eventBlock(
                    event: event,
                    geometry: geometry,
                    columnIndex: index,
                    totalColumns: group.count
                )
            }
        }
    }

    // MARK: - Event Block

    private func eventBlock(
        event: CalendarEvent,
        geometry: GeometryProxy,
        columnIndex: Int,
        totalColumns: Int
    ) -> some View {
        let position = calculateEventPosition(
            event: event,
            geometry: geometry,
            columnIndex: columnIndex,
            totalColumns: totalColumns
        )

        return EventBlockView(event: event)
            .frame(width: position.width, height: position.height)
            .offset(x: position.x, y: position.y)
            .onTapGesture {
                selectedEvent = event
                showEventDetail = true
            }
    }

    // MARK: - Current Time Indicator

    private func currentTimeIndicator(in geometry: GeometryProxy) -> some View {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = Double(hour * 60 + minute)
        let yOffset = (totalMinutes / (24.0 * 60.0)) * hourHeight * 24

        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: hourLabelWidth + 4)

            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
                .padding(.leading, hourLabelWidth + 8)
        }
        .offset(y: yOffset)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.black) // Explicitly set to black
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                if message.contains("denied") || message.contains("not authorized") {
                    Button("Open Privacy Settings") {
                        viewModel.openCalendarSettings()
                    }
                }

                Button("Retry") {
                    viewModel.checkAuthorization()
                }.opacity(0.5)
            }
        }
        .padding()
    }

    // MARK: - Helper Methods

    /// Calculate vertical position and size for an event
    private func calculateEventPosition(
        event: CalendarEvent,
        geometry: GeometryProxy,
        columnIndex: Int,
        totalColumns: Int
    ) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: viewModel.selectedDate)

        // Calculate start offset in minutes from midnight
        let startMinutes = calendar.dateComponents([.minute], from: startOfDay, to: event.startDate).minute ?? 0
        let endMinutes = calendar.dateComponents([.minute], from: startOfDay, to: event.endDate).minute ?? 0

        // Calculate vertical position (y offset)
        let yOffset = (Double(startMinutes) / (24.0 * 60.0)) * hourHeight * 24

        // Calculate height based on duration
        let duration = endMinutes - startMinutes
        let height = max((Double(duration) / (24.0 * 60.0)) * hourHeight * 24, 20) // Minimum 20pt height

        // Calculate horizontal position and width for overlapping events
        let availableWidth = geometry.size.width - hourLabelWidth - 16
        let columnWidth = availableWidth / CGFloat(totalColumns)
        let xOffset = hourLabelWidth + 8 + (columnWidth * CGFloat(columnIndex))
        let width = columnWidth - eventSpacing

        return (xOffset, yOffset, width, height)
    }

    /// Group overlapping events together
    private func calculateOverlappingGroups(_ events: [CalendarEvent]) -> [[CalendarEvent]] {
        var sortedEvents = events.sorted { $0.startDate < $1.startDate }
        var groups: [[CalendarEvent]] = []

        while !sortedEvents.isEmpty {
            var currentGroup: [CalendarEvent] = [sortedEvents.removeFirst()]
            var i = 0

            while i < sortedEvents.count {
                let event = sortedEvents[i]
                // Check if this event overlaps with any event in the current group
                if currentGroup.contains(where: { eventsOverlap($0, event) }) {
                    currentGroup.append(sortedEvents.remove(at: i))
                } else {
                    i += 1
                }
            }

            groups.append(currentGroup)
        }

        return groups
    }

    /// Check if two events overlap in time
    private func eventsOverlap(_ event1: CalendarEvent, _ event2: CalendarEvent) -> Bool {
        return event1.startDate < event2.endDate && event2.startDate < event1.endDate
    }

    /// Format hour for display (e.g., "9 AM", "2 PM")
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    /// Scroll to current time in the timeline
    private func scrollToCurrentTime(_ scrollProxy: ScrollViewProxy) {
        // Delay slightly to ensure view is rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                scrollProxy.scrollTo("timeline", anchor: .top)
            }
        }
    }

    /// Start timer to update current time indicator
    private func startCurrentTimeTimer() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            // Force view update every minute
            currentTimeOffset += 0.001
        }
    }
}

// MARK: - Supporting Views

/// Row view for all-day events
struct AllDayEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color(event.calendar.cgColor))
                .frame(width: 4)
                .cornerRadius(2)

            Text(event.title)
                .font(.body)
                .lineLimit(1)
                .foregroundColor(.black)

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(event.calendar.cgColor).opacity(0.15))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(event.calendar.cgColor).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    DayView()
        .frame(width: 800, height: 600)
}
