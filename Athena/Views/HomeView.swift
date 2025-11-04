//
//  HomeView.swift
//  Athena
//
//  Created by Cursor
//

import SwiftUI
import EventKit

struct HomeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content with white 0.6 opacity background
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Greeting Section
                    greetingSection
                    
//                    Divider()
                    
                    // Today's Calendar Events
                    calendarSection
                    
//                    Divider()
                    
                    // Recent Notes
                    recentNotesSection
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
        .padding()
        .onAppear {
            // Ensure events are fetched when the view appears
            Task {
                await appViewModel.dayViewModel.fetchEvents()
            }
        }
    }
    
    // MARK: - Greeting Section
    
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hello, I'm Athena.")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
    
    // MARK: - Calendar Section
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Events")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    appViewModel.showCalendar()
                }) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            if appViewModel.dayViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let errorMessage = appViewModel.dayViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            } else if todayEvents.isEmpty {
                Text("No events scheduled for today")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.5))
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(todayEvents.prefix(5)) { event in
                        EventSummaryRow(event: event)
                    }
                    
                    if todayEvents.count > 5 {
                        Button(action: {
                            appViewModel.showCalendar()
                        }) {
                            Text("+ \(todayEvents.count - 5) more events")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Notes Section
    
    private var recentNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Notes")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    appViewModel.showNotes()
                }) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            if recentNotes.isEmpty {
                Text("No notes yet")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.5))
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(recentNotes) { note in
                        NoteSummaryRow(note: note)
                            .onTapGesture {
                                appViewModel.notesViewModel.selectNote(note)
                                appViewModel.showNotes()
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var todayEvents: [CalendarEvent] {
        // Get events from DayViewModel (which is already configured for today by default)
        appViewModel.dayViewModel.events
    }
    
    private var recentNotes: [NoteModel] {
        // Get the last 2 most recently modified notes
        Array(appViewModel.notesViewModel.notes
            .sorted(by: { $0.modifiedAt > $1.modifiedAt })
            .prefix(2))
    }
}

// MARK: - Event Summary Row

struct EventSummaryRow: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Calendar color indicator
            Rectangle()
                .fill(Color(event.calendar.cgColor))
                .frame(width: 4)
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.body)
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if event.isAllDay {
                        Text("All Day")
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.6))
                    } else {
                        Text(formatEventTime(event))
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.6))
                    }
                    
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.black.opacity(0.6))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(event.calendar.cgColor).opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(event.calendar.cgColor).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatEventTime(_ event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let startTime = formatter.string(from: event.startDate)
        let endTime = formatter.string(from: event.endDate)
        
        return "\(startTime) - \(endTime)"
    }
}

// MARK: - Note Summary Row

struct NoteSummaryRow: View {
    let note: NoteModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.body)
                .foregroundColor(.black)
                .lineLimit(1)
            
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            
            Text(formatNoteDate(note.modifiedAt))
                .font(.caption2)
                .foregroundColor(.black.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatNoteDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
        .frame(width: 800, height: 600)
}

