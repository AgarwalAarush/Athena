//
//  EventCreateView.swift
//  Athena
//
//  Created by Claude Code
//

import SwiftUI
import EventKit

/// A modal view for creating calendar events with editable fields
struct EventCreateView: View {
    
    // MARK: - Properties
    
    @ObservedObject var calendarService = CalendarService.shared
    let initialData: PendingEventData
    let onCreate: (String, Date, Date, Date, String?, EKCalendar) -> Void
    let onCancel: () -> Void
    
    // MARK: - State
    
    @State private var title: String
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String
    @State private var selectedCalendar: EKCalendar?
    
    // MARK: - Initialization
    
    init(
        initialData: PendingEventData,
        onCreate: @escaping (String, Date, Date, Date, String?, EKCalendar) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialData = initialData
        self.onCreate = onCreate
        self.onCancel = onCancel
        
        // Initialize state from initial data
        _title = State(initialValue: initialData.title)
        _date = State(initialValue: initialData.date)
        _startTime = State(initialValue: initialData.startTime)
        _endTime = State(initialValue: initialData.endTime)
        _notes = State(initialValue: initialData.notes ?? "")
    }
    
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
                    
                    // Date section
                    dateSection
                    
                    // Time section
                    timeSection
                    
                    // Calendar selection section
                    calendarSection
                    
                    // Notes section
                    notesSection
                    
                    Spacer()
                }
                .padding()
            }
            
            // Action buttons
            actionButtons
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Create Event")
                .font(.headline)
                .foregroundColor(.black)
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.black)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .help("Cancel")
        }
        .padding()
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Title", systemImage: "text.cursor")
                .font(.headline)
                .foregroundColor(.black)
            
            TextField("Event title", text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Date", systemImage: "calendar")
                .font(.headline)
                .foregroundColor(.black)
            
            DatePicker(
                "Event date",
                selection: $date,
                displayedComponents: [.date]
            )
            .datePickerStyle(.stepperField)
            .labelsHidden()
        }
    }
    
    // MARK: - Time Section
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Time", systemImage: "clock")
                .font(.headline)
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start:")
                        .foregroundColor(.black)
                        .frame(width: 60, alignment: .leading)
                    
                    DatePicker(
                        "Start time",
                        selection: $startTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.stepperField)
                    .labelsHidden()
                }
                
                HStack {
                    Text("End:")
                        .foregroundColor(.black)
                        .frame(width: 60, alignment: .leading)
                    
                    DatePicker(
                        "End time",
                        selection: $endTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.stepperField)
                    .labelsHidden()
                }
                
                if endTime <= startTime {
                    Text("End time must be after start time")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Calendar Section
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Calendar", systemImage: "calendar.badge.plus")
                .font(.headline)
                .foregroundColor(.black)
            
            if calendarService.selectedCalendars.isEmpty {
                Text("No calendars available")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Picker("Select calendar", selection: $selectedCalendar) {
                    ForEach(calendarService.selectedCalendars, id: \.calendarIdentifier) { calendar in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(calendar.cgColor))
                                .frame(width: 12, height: 12)
                            
                            Text(calendar.title)
                                .foregroundColor(.black)
                        }
                        .tag(calendar as EKCalendar?)
                    }
                }
                .pickerStyle(.menu)
                .onAppear {
                    // Set default calendar if none selected
                    if selectedCalendar == nil {
                        selectedCalendar = calendarService.selectedCalendars.first
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundColor(.black)
            
            TextEditor(text: $notes)
                .frame(height: 80)
                .font(.body)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Button(action: handleCreate) {
                Text("Create Event")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isValid)
        }
        .padding()
    }
    
    // MARK: - Helper Properties
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        endTime > startTime &&
        selectedCalendar != nil
    }
    
    // MARK: - Actions
    
    private func handleCreate() {
        guard let calendar = selectedCalendar else { return }
        
        // Combine date with start/end times
        let cal = Calendar.current
        let dateComponents = cal.dateComponents([.year, .month, .day], from: date)
        let startComponents = cal.dateComponents([.hour, .minute], from: startTime)
        let endComponents = cal.dateComponents([.hour, .minute], from: endTime)
        
        var finalStartComponents = dateComponents
        finalStartComponents.hour = startComponents.hour
        finalStartComponents.minute = startComponents.minute
        
        var finalEndComponents = dateComponents
        finalEndComponents.hour = endComponents.hour
        finalEndComponents.minute = endComponents.minute
        
        guard let finalStart = cal.date(from: finalStartComponents),
              let finalEnd = cal.date(from: finalEndComponents) else {
            return
        }
        
        let finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        
        onCreate(title, date, finalStart, finalEnd, finalNotes, calendar)
    }
}

// MARK: - Preview

#Preview {
    let mockData = PendingEventData(
        title: "Lunch with Dave",
        date: Date(),
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        notes: "Discuss project updates"
    )
    
    return EventCreateView(
        initialData: mockData,
        onCreate: { _, _, _, _, _, _ in },
        onCancel: { }
    )
    .frame(width: 400, height: 600)
    .background(Color.white.opacity(1))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
}

