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
                .font(.headline)
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
                .font(.headline)
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
                    .font(.headline)
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
                    .font(.headline)
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
                    .font(.headline)
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

// MARK: - Event Detail Popup View

/// Compact popup view for displaying event details with grouped form styling
struct EventDetailPopupView: View {
    let event: CalendarEvent
    let onClose: () -> Void
    let onDelete: (() -> Void)?
    let onUpdate: (() -> Void)?
    
    @ObservedObject var calendarService = CalendarService.shared
    
    // MARK: - State
    
    @State private var editedTitle: String
    @State private var editedStartDate: Date
    @State private var editedEndDate: Date
    @State private var editedLocation: String
    @State private var editedNotes: String
    @State private var editedCalendar: EKCalendar
    @State private var editedIsAllDay: Bool
    @State private var showDeleteConfirmation = false
    @State private var showDatePicker = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    // MARK: - Initialization
    
    init(event: CalendarEvent, onClose: @escaping () -> Void, onDelete: (() -> Void)? = nil, onUpdate: (() -> Void)? = nil) {
        self.event = event
        self.onClose = onClose
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        
        // Initialize state from event
        _editedTitle = State(initialValue: event.title)
        _editedStartDate = State(initialValue: event.startDate)
        _editedEndDate = State(initialValue: event.endDate)
        _editedLocation = State(initialValue: event.location ?? "")
        _editedNotes = State(initialValue: event.notes ?? "")
        _editedCalendar = State(initialValue: event.calendar)
        _editedIsAllDay = State(initialValue: event.isAllDay)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            headerSection
            
            // Content with grouped styling
            ScrollView {
                VStack(spacing: 12) {
                    // Group 1: Event title with calendar indicator
                    titleSection
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    // Group 2: Date/Time information
                    dateTimeSection
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    // Group 3: Location and Notes (conditionally)
                    if hasSupplementaryInfo {
                        supplementarySection
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, AppMetrics.padding)
                .padding(.top, 8)
                .padding(.bottom, AppMetrics.padding)
            }
        }
        .frame(width: 420, maxHeight: 600)
        .glassBackground(
            material: AppMaterial.primaryGlass,
            cornerRadius: AppMetrics.cornerRadiusLarge
        )
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Delete button
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .help("Delete Event")
            .alert("Delete Event", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    handleDelete()
                }
            } message: {
                Text("Are you sure you want to delete \"\(event.title)\"? This action cannot be undone.")
            }
            
            Text("Event Details")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Save button
            Button(action: handleSave) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(hasChanges ? .white : .secondary)
                }
            }
            .disabled(!hasChanges || !isValid || isSaving)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(hasChanges && isValid ? Color.blue : Color.gray.opacity(0.3))
            .cornerRadius(AppMetrics.cornerRadiusMedium)
            .buttonStyle(.plain)
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
        .padding(AppMetrics.padding)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Calendar selector
            Menu {
                ForEach(calendarService.allEventCalendars, id: \.calendarIdentifier) { calendar in
                    Button(action: {
                        editedCalendar = calendar
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(calendar.cgColor))
                                .frame(width: 10, height: 10)
                            Text(calendar.title)
                            if calendar.calendarIdentifier == editedCalendar.calendarIdentifier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(editedCalendar.cgColor))
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
            
            // Title text field
            TextField("Event Title", text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
        .fieldRowBackground()
    }
    
    // MARK: - Date/Time Section
    
    private var dateTimeSection: some View {
        VStack(spacing: 0) {
            // Date row - tappable to show date picker
            Button(action: { showDatePicker.toggle() }) {
                HStack(spacing: AppMetrics.spacingMedium) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text(formatEditedDate())
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, AppMetrics.paddingLarge)
                .fieldRowBackground()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker, arrowEdge: .trailing) {
                VStack(spacing: 0) {
                    // Date picker
                    DatePicker("", selection: $editedStartDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding()
                        .onChange(of: editedStartDate) { newDate in
                            updateEndDateForNewStartDate(newDate)
                        }
                    
                    if !editedIsAllDay {
                        Divider()
                        
                        // Time pickers
                        HStack {
                            VStack {
                                Text("Start")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                DatePicker(
                                    "",
                                    selection: $editedStartDate,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.field)
                                .labelsHidden()
                                .onChange(of: editedStartDate) { _ in
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
                                    selection: $editedEndDate,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.field)
                                .labelsHidden()
                                .onChange(of: editedEndDate) { _ in
                                    validateTimes()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            
            if !editedIsAllDay {
                Divider()
                    .padding(.leading, AppMetrics.paddingLarge)
                
                // Time row
                HStack(spacing: AppMetrics.spacingMedium) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text(formatEditedTimeRange())
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, AppMetrics.paddingLarge)
                .fieldRowBackground()
                
                Divider()
                    .padding(.leading, AppMetrics.paddingLarge)
                
                // Duration row (read-only)
                HStack(spacing: AppMetrics.spacingMedium) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text(formatEditedDuration())
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, AppMetrics.paddingLarge)
                .fieldRowBackground()
            } else {
                Divider()
                    .padding(.leading, AppMetrics.paddingLarge)
                
                HStack(spacing: AppMetrics.spacingMedium) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text("All Day")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, AppMetrics.paddingLarge)
                .fieldRowBackground()
            }
        }
    }
    
    // MARK: - Supplementary Section
    
    private var supplementarySection: some View {
        VStack(spacing: 0) {
            // Location field
            HStack(spacing: AppMetrics.spacingMedium) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                TextField("Add Location", text: $editedLocation)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, AppMetrics.paddingLarge)
            .fieldRowBackground()
            
            Divider()
                .padding(.leading, AppMetrics.paddingLarge)
            
            // Notes field
            HStack(alignment: .top, spacing: AppMetrics.spacingMedium) {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                    .padding(.top, 2)
                
                TextEditor(text: $editedNotes)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppMetrics.paddingLarge)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helper Views
    
    private func infoRow(label: String, icon: String, allowMultiline: Bool = false) -> some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(label)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(allowMultiline ? nil : 1)
            
            Spacer()
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
        .fieldRowBackground()
    }
    
    // MARK: - Computed Properties
    
    private var hasSupplementaryInfo: Bool {
        return true // Always show location and notes fields for editing
    }
    
    private var hasChanges: Bool {
        return editedTitle != event.title ||
               editedStartDate != event.startDate ||
               editedEndDate != event.endDate ||
               editedLocation != (event.location ?? "") ||
               editedNotes != (event.notes ?? "") ||
               editedCalendar.calendarIdentifier != event.calendar.calendarIdentifier ||
               editedIsAllDay != event.isAllDay
    }
    
    private var isValid: Bool {
        return !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
               editedEndDate > editedStartDate
    }
    
    // MARK: - Formatting Methods
    
    private func formatEditedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: editedStartDate)
    }
    
    private func formatEditedTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: editedStartDate)
        let end = formatter.string(from: editedEndDate)
        return "\(start) – \(end)"
    }
    
    private func formatEditedDuration() -> String {
        let duration = editedEndDate.timeIntervalSince(editedStartDate)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateTimes() {
        // Ensure end time is after start time
        if editedEndDate <= editedStartDate {
            editedEndDate = Calendar.current.date(byAdding: .hour, value: 1, to: editedStartDate) ?? editedStartDate
        }
    }
    
    private func updateEndDateForNewStartDate(_ newStartDate: Date) {
        // Calculate duration from original dates
        let duration = editedEndDate.timeIntervalSince(editedStartDate)
        // Apply same duration to new start date
        editedEndDate = newStartDate.addingTimeInterval(duration)
    }
    
    // MARK: - Actions
    
    private func handleSave() {
        guard isValid && hasChanges else { return }
        
        isSaving = true
        
        // Create updated CalendarEvent
        let updatedEvent = CalendarEvent(
            id: event.id,
            title: editedTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: editedStartDate,
            endDate: editedEndDate,
            isAllDay: editedIsAllDay,
            notes: editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedNotes,
            location: editedLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedLocation,
            url: event.url,
            calendar: editedCalendar
        )
        
        CalendarService.shared.updateEvent(updatedEvent) { event, error in
            Task { @MainActor in
                isSaving = false
                
                if let error = error {
                    errorMessage = "Failed to update event: \(error.localizedDescription)"
                    print("[EventDetailPopupView] Error updating event: \(error.localizedDescription)")
                } else {
                    print("[EventDetailPopupView] Successfully updated event '\(editedTitle)'")
                    onUpdate?()
                    onClose()
                }
            }
        }
    }
    
    private func handleDelete() {
        CalendarService.shared.deleteEvent(event) { error in
            Task { @MainActor in
                if let error = error {
                    errorMessage = "Failed to delete event: \(error.localizedDescription)"
                    print("[EventDetailPopupView] Error deleting event: \(error.localizedDescription)")
                } else {
                    print("[EventDetailPopupView] Successfully deleted event '\(event.title)'")
                    onDelete?()
                    onClose()
                }
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

