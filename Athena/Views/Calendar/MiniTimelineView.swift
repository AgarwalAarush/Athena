//
//  MiniTimelineView.swift
//  Athena
//
//  Focused calendar timeline preview for event creation
//

import SwiftUI
import EventKit

/// A compact timeline view showing a focused window around an event time
struct MiniTimelineView: View {
    
    // MARK: - Properties
    
    let date: Date
    let startTime: Date
    let endTime: Date
    let existingEvents: [CalendarEvent]
    let focusWindowHours: Int
    let newEventCalendar: EKCalendar?
    
    // MARK: - Constants
    
    private let hourHeight: CGFloat = 60
    private let hourLabelWidth: CGFloat = 60
    
    // MARK: - Computed Properties
    
    /// Calculate the time range to display (±focusWindowHours around event)
    private var displayTimeRange: (start: Int, end: Int) {
        let calendar = Calendar.current
        let eventStartHour = calendar.component(.hour, from: startTime)
        
        let rangeStart = max(0, eventStartHour - focusWindowHours)
        let rangeEnd = min(24, eventStartHour + focusWindowHours + 1)
        
        return (rangeStart, rangeEnd)
    }
    
    private var hoursToDisplay: [Int] {
        let range = displayTimeRange
        return Array(range.start..<range.end)
    }
    
    /// Check if current time falls within the display range
    private var isCurrentTimeInRange: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if today
        guard calendar.isDate(now, inSameDayAs: date) else {
            return false
        }
        
        let currentHour = calendar.component(.hour, from: now)
        let range = displayTimeRange
        return currentHour >= range.start && currentHour < range.end
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Hour grid and labels
                        hourGrid
                        
                        // Existing events (with reduced opacity)
                        existingEventsLayer(in: geometry)
                        
                        // New event placeholder (highlighted)
                        newEventPlaceholder(in: geometry)
                        
                        // Current time indicator
                        if isCurrentTimeInRange {
                            currentTimeIndicator(in: geometry)
                        }
                    }
                    .frame(height: CGFloat(hoursToDisplay.count) * hourHeight)
                    .id("mini-timeline")
                }
                .onAppear {
                    // Scroll to the event start time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            scrollProxy.scrollTo("mini-timeline", anchor: .top)
                        }
                    }
                }
                .onChange(of: startTime) { _ in
                    // Re-scroll when start time changes
                    withAnimation {
                        scrollProxy.scrollTo("mini-timeline", anchor: .top)
                    }
                }
            }
        }
    }
    
    // MARK: - Hour Grid
    
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(hoursToDisplay, id: \.self) { hour in
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
    
    // MARK: - Existing Events Layer
    
    private func existingEventsLayer(in geometry: GeometryProxy) -> some View {
        ForEach(existingEvents.filter { !$0.isAllDay }) { event in
            if isEventInDisplayRange(event) {
                existingEventBlock(event: event, geometry: geometry)
            }
        }
    }
    
    private func existingEventBlock(event: CalendarEvent, geometry: GeometryProxy) -> some View {
        let position = calculateEventPosition(
            startDate: event.startDate,
            endDate: event.endDate,
            geometry: geometry
        )
        
        return VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.white)
        }
        .padding(6)
        .frame(width: position.width, height: position.height, alignment: .topLeading)
        .background(Color(event.calendar.cgColor).opacity(0.2))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(event.calendar.cgColor), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .offset(x: position.x, y: position.y)
    }
    
    // MARK: - New Event Placeholder
    
    private func newEventPlaceholder(in geometry: GeometryProxy) -> some View {
        let position = calculateEventPosition(
            startDate: startTime,
            endDate: endTime,
            geometry: geometry
        )
        
        let calendarColor = newEventCalendar.map { Color($0.cgColor) } ?? AppColors.accent
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("New Event")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text(formatTimeRange())
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(6)
        .frame(width: position.width, height: position.height)
        .background(
            LinearGradient(
                colors: [calendarColor.opacity(0.8), calendarColor.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(calendarColor, lineWidth: 2)
        )
        .shadow(color: calendarColor.opacity(0.3), radius: 8, y: 4)
        .offset(x: position.x, y: position.y)
    }
    
    // MARK: - Current Time Indicator
    
    private func currentTimeIndicator(in geometry: GeometryProxy) -> some View {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        let range = displayTimeRange
        let displayStartHour = range.start
        
        // Calculate minutes from display start
        let minutesFromStart = (hour - displayStartHour) * 60 + minute
        let totalMinutesInRange = hoursToDisplay.count * 60
        let yOffset = (Double(minutesFromStart) / Double(totalMinutesInRange)) * (hourHeight * CGFloat(hoursToDisplay.count))
        
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
    
    // MARK: - Helper Methods
    
    /// Calculate vertical position and size for an event
    private func calculateEventPosition(
        startDate: Date,
        endDate: Date,
        geometry: GeometryProxy
    ) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let calendar = Calendar.current
        let range = displayTimeRange
        
        // Calculate start offset in minutes from the display range start
        let displayStartHour = range.start
        let displayStartDate = calendar.date(bySettingHour: displayStartHour, minute: 0, second: 0, of: date) ?? date
        
        let startMinutes = calendar.dateComponents([.minute], from: displayStartDate, to: startDate).minute ?? 0
        let endMinutes = calendar.dateComponents([.minute], from: displayStartDate, to: endDate).minute ?? 0
        
        // Calculate vertical position (y offset)
        let totalMinutesInRange = hoursToDisplay.count * 60
        let yOffset = (Double(startMinutes) / Double(totalMinutesInRange)) * (hourHeight * CGFloat(hoursToDisplay.count))
        
        // Calculate height based on duration
        let duration = endMinutes - startMinutes
        let height = max((Double(duration) / Double(totalMinutesInRange)) * (hourHeight * CGFloat(hoursToDisplay.count)), 20)
        
        // Calculate horizontal position and width
        let availableWidth = geometry.size.width - hourLabelWidth - 16
        let xOffset = hourLabelWidth + 8
        let width = availableWidth
        
        return (xOffset, yOffset, width, height)
    }
    
    /// Check if event falls within the display range
    private func isEventInDisplayRange(_ event: CalendarEvent) -> Bool {
        let calendar = Calendar.current
        let eventHour = calendar.component(.hour, from: event.startDate)
        let range = displayTimeRange
        return eventHour >= range.start && eventHour < range.end
    }
    
    /// Format hour for display
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    /// Format time range for the new event
    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: startTime)
        let end = formatter.string(from: endTime)
        return "\(start) - \(end)"
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
    
    let now = Date()
    let mockEvents = [
        CalendarEvent(
            id: "1",
            title: "Team Meeting",
            startDate: Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now,
            endDate: Calendar.current.date(byAdding: .minute, value: -30, to: now) ?? now,
            isAllDay: false,
            notes: nil,
            location: nil,
            url: nil,
            calendar: mockCalendar
        )
    ]
    
    return MiniTimelineView(
        date: now,
        startTime: now,
        endTime: Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now,
        existingEvents: mockEvents,
        focusWindowHours: 2,
        newEventCalendar: mockCalendar
    )
    .frame(width: 400, height: 300)
    .padding()
}

