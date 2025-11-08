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
    @ObservedObject var viewModel: DayViewModel
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
            if viewModel.showCreateEventSplitView, let pendingData = viewModel.pendingEventData {
                // Split-screen event creation view
                EventCreateSplitView(
                    viewModel: viewModel,
                    initialData: pendingData,
                    onCreate: { title, date, startDate, endDate, notes, location, calendar in
                        handleCreateEvent(
                            title: title,
                            date: date,
                            startDate: startDate,
                            endDate: endDate,
                            notes: notes,
                            location: location,
                            calendar: calendar
                        )
                    },
                    onCancel: {
                        viewModel.dismissCreateEventModal()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                // Normal calendar view
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
                .glassBackground(
                    material: AppMaterial.primaryGlass,
                    cornerRadius: AppMetrics.cornerRadiusLarge
                )
                .padding()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

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
        .animation(AppAnimations.standardEasing, value: viewModel.showCreateEventSplitView)
        .onAppear {
            startCurrentTimeTimer()
        }
        .onChange(of: showEventDetail) { isPresented in
            if !isPresented {
                selectedEvent = nil
            }
        }
        .eventDetailOverlay(event: selectedEvent, isPresented: $showEventDetail) {
            selectedEvent = nil
        }
        .eventCreateOverlay(
            pendingData: viewModel.pendingEventData,
            isPresented: $viewModel.showCreateEventModal,
            onCreate: { title, date, startDate, endDate, notes, calendar in
                handleCreateEvent(
                    title: title,
                    date: date,
                    startDate: startDate,
                    endDate: endDate,
                    notes: notes,
                    location: nil,
                    calendar: calendar
                )
            },
            onCancel: {
                viewModel.dismissCreateEventModal()
            }
        )
    }

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        HStack {
            // Previous Day button
            Button(action: viewModel.previousDay) {
                Label("Previous", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.white)
            .help("Previous day (⌘←)")

            Spacer()

            // Date display
            VStack(spacing: 2) {
                Text(viewModel.formattedDate)
                    .font(.headline)
                    .foregroundColor(.white)
                if viewModel.isToday {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Today button
            Button(action: viewModel.today) {
                Text("Today")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.white)
            .disabled(viewModel.isToday)

            // Next Day button
            Button(action: viewModel.nextDay) {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.white)
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
                // Scroll to earliest meeting
                scrollToEarliestMeeting(scrollProxy)
            }
        }
    }

    // MARK: - All-Day Events Section

    private var allDayEventsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All-Day Events")
                .font(.caption)
                .foregroundColor(.white)
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
                        .foregroundColor(.white)
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
            .id(event.id)
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
                .foregroundColor(.white)
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

    /// Scroll to earliest meeting in the timeline
    private func scrollToEarliestMeeting(_ scrollProxy: ScrollViewProxy) {
        // Delay slightly to ensure view is rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                // Find the earliest timed event
                if let earliestEvent = viewModel.timedEvents.min(by: { $0.startDate < $1.startDate }) {
                    // Scroll to the earliest event's ID
                    scrollProxy.scrollTo(earliestEvent.id, anchor: .top)
                } else {
                    // No events, scroll to top of timeline
                    scrollProxy.scrollTo("timeline", anchor: .top)
                }
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

    /// Handle event creation from the modal/split view
    private func handleCreateEvent(
        title: String,
        date: Date,
        startDate: Date,
        endDate: Date,
        notes: String?,
        location: String?,
        calendar: EKCalendar
    ) {
        // Format title: capitalize first letter of each word (title case)
        let formattedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        
        print("[DayView] Creating event '\(formattedTitle)' from \(startDate) to \(endDate)")
        
        CalendarService.shared.createEvent(
            title: formattedTitle,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            location: location,
            in: calendar
        ) { event, error in
            Task { @MainActor in
                if let error = error {
                    print("[DayView] Error creating event: \(error.localizedDescription)")
                    viewModel.errorMessage = "Failed to create event: \(error.localizedDescription)"
                } else if let event = event {
                    print("[DayView] Successfully created event '\(event.title)'")
                    // Navigate to the event's date
                    viewModel.selectedDate = date
                    // Refresh events
                    await viewModel.fetchEvents()
                }
                // Dismiss modal/split view
                viewModel.dismissCreateEventModal()
            }
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
                .foregroundColor(.white)

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
    DayView(viewModel: DayViewModel())
        .environmentObject(AppViewModel())
        .frame(width: 800, height: 600)
}

// MARK: - Event Detail Overlay

extension View {
    func eventDetailOverlay(event: CalendarEvent?, isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil) -> some View {
        overlay(alignment: .center) {
            if isPresented.wrappedValue, let event {
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isPresented.wrappedValue = false
                            onDismiss?()
                        }
                    
                    EventDetailPopupView(event: event) {
                        isPresented.wrappedValue = false
                        onDismiss?()
                    }
                    .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPresented.wrappedValue)
            }
        }
    }
    
    func eventCreateOverlay(
        pendingData: PendingEventData?,
        isPresented: Binding<Bool>,
        onCreate: @escaping (String, Date, Date, Date, String?, EKCalendar) -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        overlay(alignment: .center) {
            if isPresented.wrappedValue, let pendingData {
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Don't dismiss on background tap for create modal
                        }
                    
                    EventCreateView(
                        initialData: pendingData,
                        onCreate: onCreate,
                        onCancel: onCancel
                    )
                    .frame(width: 420, height: 500)
                    .background(Color.white.opacity(1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPresented.wrappedValue)
            }
        }
    }
}
