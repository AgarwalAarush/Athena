//
//  EventCreateView.swift
//  Athena
//
//  Created by Claude Code
//

import SwiftUI
import EventKit
import AppKit

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
    @State private var selectedCalendar: EKCalendar
    @State private var showDatePicker = false
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    
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
        
        // FIX: Initialize selectedCalendar to prevent nil picker warning
        let defaultCalendar = CalendarService.shared.selectedCalendars.first 
            ?? EKEventStore().defaultCalendarForNewEvents
            ?? EKCalendar(for: .event, eventStore: EKEventStore())
        _selectedCalendar = State(initialValue: defaultCalendar)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with action button
            headerWithAction
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Header with Action
    
    private var headerWithAction: some View {
        HStack(spacing: 12) {
            Text("Create Event")
                .font(.headline)
                .foregroundColor(.black)
            
            Spacer()
            
            // Create button - matching header font size
            Button(action: handleCreate) {
                Text("Create")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(isValid ? Color.blue : Color.gray)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
            
            // Close button
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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "text.cursor")
                .foregroundColor(.black)
                .frame(width: 20)
            
            Text("Title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 70, alignment: .leading)
            
            CustomSingleLineTextField(text: $title, placeholder: "Event title")
                .frame(height: 32)
        }
    }
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .foregroundColor(.black)
                .frame(width: 20)
            
            Text("Date")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 70, alignment: .leading)
            
            // Custom date display with picker
            Button(action: { showDatePicker.toggle() }) {
                Text(formatDate(date))
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
            }
        }
    }
    
    // MARK: - Time Section
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Start time
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "clock")
                    .foregroundColor(.black)
                    .frame(width: 20)
                
                Text("Start")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 70, alignment: .leading)
                
                DatePicker(
                    "",
                    selection: $startTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.field)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(6)
            }
            
            // End time
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.black)
                    .frame(width: 20)
                
                Text("End")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 70, alignment: .leading)
                
                DatePicker(
                    "",
                    selection: $endTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.field)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(6)
            }
            
            // Error message
            if endTime <= startTime {
                Text("End time must be after start time")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 32)
            }
        }
    }
    
    // MARK: - Calendar Section
    
    private var calendarSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .foregroundColor(.black)
                .frame(width: 20)
            
            Text("Calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 70, alignment: .leading)
            
            if calendarService.selectedCalendars.isEmpty {
                Text("No calendars available")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Menu {
                    ForEach(calendarService.selectedCalendars, id: \.calendarIdentifier) { calendar in
                        Button(action: {
                            selectedCalendar = calendar
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color(calendar.cgColor))
                                    .frame(width: 12, height: 12)
                                Text(calendar.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(selectedCalendar.cgColor))
                            .frame(width: 12, height: 12)
                        
                        Text(selectedCalendar.title)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .foregroundColor(.black)
                    .frame(width: 20)
                
                Text("Notes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
            }
            
            CustomMultiLineTextField(text: $notes, placeholder: "Add notes...")
                .frame(height: 80)
        }
    }
    
    // MARK: - Helper Properties
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        endTime > startTime
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    
    private func handleCreate() {
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
        
        onCreate(title, date, finalStart, finalEnd, finalNotes, selectedCalendar)
    }
}

// MARK: - Custom Text Field Components

/// Single-line text field with custom styling matching MessageInputView
struct CustomSingleLineTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.black
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.delegate = context.coordinator
        
        // Remove extra padding - key to proper sizing
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 8, height: 6)
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // Configure scroll view
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        // Add scroll view to container
        containerView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Style container with light blue background and rounded corners
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(Color.blue.opacity(0.08)).cgColor
        containerView.layer?.cornerRadius = 6
        
        context.coordinator.textView = textView
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let scrollView = nsView.subviews.first as? NSScrollView,
           let textView = scrollView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomSingleLineTextField
        var textView: NSTextView?
        
        init(_ parent: CustomSingleLineTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = textView {
                parent.text = textView.string
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Prevent newlines in single-line field
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return true
            }
            return false
        }
    }
}

/// Multi-line text field with custom styling matching MessageInputView
struct CustomMultiLineTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.black
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.delegate = context.coordinator
        
        // Multiline configuration - remove extra padding
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 8, height: 6)
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        // Add scroll view to container
        containerView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Style container with light blue background and rounded corners
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(Color.blue.opacity(0.08)).cgColor
        containerView.layer?.cornerRadius = 6
        
        context.coordinator.textView = textView
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let scrollView = nsView.subviews.first as? NSScrollView,
           let textView = scrollView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomMultiLineTextField
        var textView: NSTextView?
        
        init(_ parent: CustomMultiLineTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = textView {
                parent.text = textView.string
            }
        }
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
    
    EventCreateView(
        initialData: mockData,
        onCreate: { _, _, _, _, _, _ in },
        onCancel: { }
    )
    .frame(width: 400, height: 600)
    .background(Color.white.opacity(1))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
}

