//
//  CalendarSettingsView.swift
//  Athena
//
//  Created by Aarush Agarwal on 11/02/25.
//

import SwiftUI
import EventKit

/// A settings view that allows users to select which calendars to display
struct CalendarSettingsView: View {
    
    @ObservedObject var calendarService = CalendarService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Calendar Selection")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Authorization check
            if !calendarService.hasReadAccess {
                authorizationPromptView
            } else if calendarService.allEventCalendars.isEmpty {
                emptyStateView
            } else {
                calendarListView
            }
        }
        .padding()
        .frame(minWidth: 350, minHeight: 400)
    }
    
    // MARK: - Subviews
    
    private var authorizationPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Calendar Access Required")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Please grant calendar access to select calendars.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Grant Access") {
                calendarService.requestAccessWithActivation { granted, error in
                    if granted {
                        print("✅ Calendar access granted")
                    } else if let error = error {
                        print("❌ Calendar access error: \(error.localizedDescription)")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            
            Button("Open System Settings") {
                calendarService.openCalendarPrivacySettings()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Calendars Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("No calendars are available. Please add calendars in the System Calendar app.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var calendarListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selection info
            HStack {
                Text("\(calendarService.selectedCalendarIDs.count) of \(calendarService.allEventCalendars.count) calendars selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Select/Deselect All buttons
            HStack(spacing: 8) {
                Button("Select All") {
                    calendarService.selectAllCalendars()
                }
                .buttonStyle(.bordered)
                
                Button("Deselect All") {
                    calendarService.deselectAllCalendars()
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Calendar list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(calendarService.allEventCalendars, id: \.calendarIdentifier) { calendar in
                        CalendarRowView(calendar: calendar, calendarService: calendarService)
                    }
                }
            }
        }
    }
}

// MARK: - Calendar Row View

struct CalendarRowView: View {
    let calendar: EKCalendar
    @ObservedObject var calendarService: CalendarService
    
    private var isSelected: Bool {
        calendarService.selectedCalendarIDs.contains(calendar.calendarIdentifier)
    }
    
    var body: some View {
        Toggle(isOn: Binding(
            get: { isSelected },
            set: { calendarService.setCalendar(calendar, enabled: $0) }
        )) {
            HStack(spacing: 10) {
                // Calendar color indicator
                Circle()
                    .fill(Color(nsColor: calendar.color))
                    .frame(width: 12, height: 12)
                
                // Calendar title
                Text(calendar.title)
                    .font(.body)
                
                Spacer()
                
                // Calendar source (e.g., iCloud, Google)
                if let source = calendar.source {
                    Text(source.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    CalendarSettingsView()
}

