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
    
    @State private var title: String
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String
    @State private var location: String
    @State private var selectedCalendar: EKCalendar
    @State private var showDatePicker = false
    @State private var showCalendarPicker = false
    
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
            // Action buttons
            headerSection
            
            // Form fields with grouped styling
            ScrollView {
                VStack(spacing: 12) {
                    // Group 1: Title and Location
                    VStack(spacing: 0) {
                        titleField
                            .fieldRowBackground()
                        
                        Divider()
                            .padding(.leading, AppMetrics.paddingLarge)
                        
                        locationField
                            .fieldRowBackground()
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Group 2: Date/Time
                    dateTimeDisplayField
                        .fieldRowBackground()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    // Group 3: Additional options
                    VStack(spacing: 0) {
                        alertRepeatField
                            .fieldRowBackground()
                        
                        Divider()
                            .padding(.leading, AppMetrics.paddingLarge)
                        
                        inviteesField
                            .fieldRowBackground()
                        
                        Divider()
                            .padding(.leading, AppMetrics.paddingLarge)
                        
                        notesField
                            .fieldRowBackground()
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal, AppMetrics.padding)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: AppMetrics.spacing) {
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
    
    // MARK: - Form Fields
    
    private var titleField: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Borderless text field
            TextField("New Event", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Calendar selector button with pill background
            Menu {
                ForEach(calendarService.allEventCalendars, id: \.calendarIdentifier) { calendar in
                    Button(action: {
                        selectedCalendar = calendar
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(calendar.cgColor))
                                .frame(width: 10, height: 10)
                            Text(calendar.title)
                            if calendar.calendarIdentifier == selectedCalendar.calendarIdentifier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(selectedCalendar.cgColor))
                        .frame(width: 10, height: 10)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
    }
    
    private var locationField: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Borderless text field
            TextField("Add Location or Video Call", text: $location)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundColor(location.isEmpty ? .secondary : .primary)
            
            Spacer()
            
            // Video button
            Button(action: { /* Future: Show video call options */ }) {
                HStack(spacing: 4) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
    }
    
    private var dateTimeDisplayField: some View {
        Button(action: { showDatePicker.toggle() }) {
            HStack {
                Text(formatDateTimeRange())
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, AppMetrics.paddingLarge)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker, arrowEdge: .trailing) {
            VStack(spacing: 0) {
                // Date picker
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
                    .onChange(of: date) { _ in
                        updateTimesForNewDate()
                    }
                
                Divider()
                
                // Time pickers
                HStack {
                    VStack {
                        Text("Start")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker(
                            "",
                            selection: $startTime,
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .onChange(of: startTime) { _ in
                            validateTimes()
                        }
                    }
                    
                    Text("–")
                        .foregroundColor(.secondary)
                    
                    VStack {
                        Text("End")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker(
                            "",
                            selection: $endTime,
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .onChange(of: endTime) { _ in
                            validateTimes()
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var alertRepeatField: some View {
        TappableOptionRow(title: "Add Alert, Repeat, or Travel Time") {
            // Future: Show alert/repeat configuration
        }
    }
    
    private var inviteesField: some View {
        TappableOptionRow(title: "Add Invitees") {
            // Future: Show invitees picker
        }
    }
    
    private var notesField: some View {
        Button(action: { /* Future: Open notes editor */ }) {
            HStack {
                Text(notes.isEmpty ? "Add Notes or URL" : notes)
                    .font(.system(size: 15))
                    .foregroundColor(notes.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, AppMetrics.paddingLarge)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Calendar Preview Section
    
    private var calendarPreviewSection: some View {
        MiniTimelineView(
            date: date,
            startTime: combineDateWithTime(date: date, time: startTime),
            endTime: combineDateWithTime(date: date, time: endTime),
            existingEvents: viewModel.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) },
            focusWindowHours: 2,
            newEventCalendar: selectedCalendar
        )
        .padding(AppMetrics.padding)
    }
    
    // MARK: - Helper Properties
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        endTime > startTime
    }
    
    // MARK: - Helper Methods
    
    private func formatDateTimeRange() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        
        let finalStart = combineDateWithTime(date: date, time: startTime)
        let finalEnd = combineDateWithTime(date: date, time: endTime)
        
        let dateString = dateFormatter.string(from: date)
        let startString = timeFormatter.string(from: finalStart).uppercased()
        let endString = timeFormatter.string(from: finalEnd).uppercased()
        
        return "\(dateString)  \(startString) – \(endString)"
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

// MARK: - View Modifiers

extension View {
    /// Consistent field row background styling
    func fieldRowBackground() -> some View {
        self
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

// MARK: - Supporting Components

/// Tappable option row with press state
struct TappableOptionRow: View {
    let title: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, AppMetrics.paddingLarge)
            .contentShape(Rectangle())
            .background(isPressed ? Color.gray.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Custom Text Field Components

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
        textView.textContainerInset = NSSize(width: 12, height: 10)
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
        
        // Set minimum height constraint
        let heightConstraint = containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        heightConstraint.priority = .required
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            heightConstraint
        ])
        
        // Style container
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(Color.gray.opacity(0.08)).cgColor
        containerView.layer?.cornerRadius = 6
        
        context.coordinator.textView = textView
        context.coordinator.placeholder = placeholder
        context.coordinator.updatePlaceholder()
        
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
        var placeholder: String = ""
        
        init(_ parent: CustomMultiLineStyledTextField) {
            self.parent = parent
        }
        
        func updatePlaceholder() {
            guard let textView = textView else { return }
            if parent.text.isEmpty {
                textView.string = placeholder
                textView.textColor = NSColor.placeholderTextColor
            } else {
                textView.textColor = NSColor.labelColor
            }
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = textView else { return }
            if parent.text.isEmpty && textView.string == placeholder {
                textView.string = ""
                textView.textColor = NSColor.labelColor
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            guard let textView = textView else { return }
            if textView.string.isEmpty {
                parent.text = ""
                updatePlaceholder()
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            // Don't update if showing placeholder
            if textView.textColor != NSColor.placeholderTextColor {
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

