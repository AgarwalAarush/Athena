//
//  EventCreateSplitView.swift
//  Athena
//
//  Split-screen event creation interface with form and live calendar preview
//

import SwiftUI
import EventKit

/// Split-screen view for creating calendar events
struct EventCreateSplitView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: DayViewModel
    @ObservedObject var calendarService = CalendarService.shared
    let initialData: PendingEventData
    let onCreate: (String, Date, Date, Date, String?, String?, EKCalendar) -> Void
    let onCancel: () -> Void
    
    // MARK: - State
    
    @State private var eventType: EventType = .event
    @State private var title: String
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String
    @State private var location: String
    @State private var selectedCalendar: EKCalendar
    @State private var showDatePicker = false
    
    // MARK: - Event Type
    
    enum EventType {
        case event
        case reminder
    }
    
    // MARK: - Initialization
    
    init(
        viewModel: DayViewModel,
        initialData: PendingEventData,
        onCreate: @escaping (String, Date, Date, Date, String?, String?, EKCalendar) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.initialData = initialData
        self.onCreate = onCreate
        self.onCancel = onCancel
        
        // Initialize state from initial data
        _title = State(initialValue: initialData.title)
        _date = State(initialValue: initialData.date)
        _startTime = State(initialValue: initialData.startTime)
        _endTime = State(initialValue: initialData.endTime)
        _notes = State(initialValue: initialData.notes ?? "")
        _location = State(initialValue: "")
        
        // Initialize selectedCalendar
        let defaultCalendar = CalendarService.shared.selectedCalendars.first
            ?? EKEventStore().defaultCalendarForNewEvents
            ?? EKCalendar(for: .event, eventStore: EKEventStore())
        _selectedCalendar = State(initialValue: defaultCalendar)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Top half: Event form
            formSection
                .frame(maxHeight: .infinity)
            
            Divider()
            
            // Bottom half: Live calendar preview
            calendarPreviewSection
                .frame(maxHeight: .infinity)
        }
        .glassBackground(
            material: AppMaterial.primaryGlass,
            cornerRadius: AppMetrics.cornerRadiusLarge
        )
        .padding()
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 0) {
            // Event/Reminder toggle and action buttons
            headerSection
            
            Divider()
                .padding(.vertical, AppMetrics.spacingSmall)
            
            // Form fields
            ScrollView {
                VStack(spacing: AppMetrics.spacing) {
                    titleField
                    locationField
                    dateField
                    timeFields
                    calendarField
                    notesField
                }
                .padding(AppMetrics.padding)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: AppMetrics.spacing) {
            // Event/Reminder toggle
            HStack(spacing: 0) {
                toggleButton(type: .event, title: "Event")
                toggleButton(type: .reminder, title: "Reminder")
            }
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusMedium, style: .continuous))
            
            Spacer()
            
            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            // Create button
            Button(action: handleCreate) {
                Text("Add")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isValid ? Color.blue : Color.gray)
                    .cornerRadius(AppMetrics.cornerRadiusMedium)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
        }
        .padding(AppMetrics.padding)
    }
    
    private func toggleButton(type: EventType, title: String) -> some View {
        Button(action: {
            withAnimation(AppAnimations.standardEasing) {
                eventType = type
            }
        }) {
            Text(title)
                .font(.headline)
                .foregroundColor(eventType == type ? .white : .primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(eventType == type ? Color(red: 1.0, green: 0.38, blue: 0.35) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Form Fields
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingSmall) {
            HStack(spacing: AppMetrics.spacingSmall) {
                Circle()
                    .fill(Color(selectedCalendar.cgColor))
                    .frame(width: 16, height: 16)
                
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            CustomStyledTextField(text: $title, placeholder: "New Event")
        }
    }
    
    private var locationField: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            CustomStyledTextField(text: $location, placeholder: "Add Location or Video Call")
        }
    }
    
    private var dateField: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            Image(systemName: "calendar")
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Button(action: { showDatePicker.toggle() }) {
                HStack {
                    Text(formatDate(date))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppMetrics.paddingMedium)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(AppMetrics.cornerRadiusSmall)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
                    .onChange(of: date) { _ in
                        updateTimesForNewDate()
                    }
            }
        }
    }
    
    private var timeFields: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // Start time
            DatePicker(
                "",
                selection: $startTime,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.field)
            .labelsHidden()
            .padding(.horizontal, AppMetrics.paddingMedium)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(AppMetrics.cornerRadiusSmall)
            .onChange(of: startTime) { _ in
                validateTimes()
            }
            
            Text("–")
                .foregroundColor(.secondary)
            
            // End time
            DatePicker(
                "",
                selection: $endTime,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.field)
            .labelsHidden()
            .padding(.horizontal, AppMetrics.paddingMedium)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(AppMetrics.cornerRadiusSmall)
            .onChange(of: endTime) { _ in
                validateTimes()
            }
        }
    }
    
    private var calendarField: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            if !calendarService.selectedCalendars.isEmpty {
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
                    HStack {
                        Circle()
                            .fill(Color(selectedCalendar.cgColor))
                            .frame(width: 12, height: 12)
                        
                        Text(selectedCalendar.title)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, AppMetrics.paddingMedium)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(AppMetrics.cornerRadiusSmall)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var notesField: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingSmall) {
            HStack(spacing: AppMetrics.spacingMedium) {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Text("Add Notes or URL")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            CustomMultiLineStyledTextField(text: $notes, placeholder: "")
                .frame(height: 60)
        }
    }
    
    // MARK: - Calendar Preview Section
    
    private var calendarPreviewSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Calendar Preview")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(AppMetrics.padding)
            
            Divider()
            
            // Mini timeline
            MiniTimelineView(
                date: date,
                startTime: combineDateWithTime(date: date, time: startTime),
                endTime: combineDateWithTime(date: date, time: endTime),
                existingEvents: viewModel.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) },
                focusWindowHours: 2
            )
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
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func validateTimes() {
        // Ensure end time is after start time
        if endTime <= startTime {
            endTime = Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
        }
    }
    
    private func updateTimesForNewDate() {
        // Update the date component of start and end times when date changes
        let calendar = Calendar.current
        let newStart = combineDateWithTime(date: date, time: startTime)
        let newEnd = combineDateWithTime(date: date, time: endTime)
        startTime = newStart
        endTime = newEnd
    }
    
    private func combineDateWithTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combined = dateComponents
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined) ?? date
    }
    
    // MARK: - Actions
    
    private func handleCreate() {
        let finalStart = combineDateWithTime(date: date, time: startTime)
        let finalEnd = combineDateWithTime(date: date, time: endTime)
        
        let finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        let finalLocation = location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location
        
        onCreate(title, date, finalStart, finalEnd, finalNotes, finalLocation, selectedCalendar)
    }
}

// MARK: - Custom Text Field Components

/// Single-line styled text field with subtle background
struct CustomStyledTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.delegate = context.coordinator
        
        // Padding configuration
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 12, height: 8)
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
        
        // Style container
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(Color.gray.opacity(0.08)).cgColor
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
        var parent: CustomStyledTextField
        var textView: NSTextView?
        
        init(_ parent: CustomStyledTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = textView {
                parent.text = textView.string
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return true // Prevent newlines
            }
            return false
        }
    }
}

/// Multi-line styled text field with subtle background
struct CustomMultiLineStyledTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.delegate = context.coordinator
        
        // Padding configuration
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 12, height: 8)
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
        
        // Style container
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(Color.gray.opacity(0.08)).cgColor
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
        var parent: CustomMultiLineStyledTextField
        var textView: NSTextView?
        
        init(_ parent: CustomMultiLineStyledTextField) {
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
    let viewModel = DayViewModel()
    let mockData = PendingEventData(
        title: "Team Meeting",
        date: Date(),
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        notes: "Discuss project updates"
    )
    
    return EventCreateSplitView(
        viewModel: viewModel,
        initialData: mockData,
        onCreate: { _, _, _, _, _, _, _ in },
        onCancel: { }
    )
    .frame(width: 800, height: 700)
}

