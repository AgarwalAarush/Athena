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
            
            Divider()
                .padding(.vertical, AppMetrics.spacingSmall)
            
            // Form fields
            ScrollView {
                VStack(spacing: 0) {
                    titleField
                    Divider()
                    locationField
                    Divider()
                    dateTimeDisplayField
                    Divider()
                    alertRepeatField
                    Divider()
                    inviteesField
                    Divider()
                    notesField
                    Divider()
                }
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
                .font(.system(size: 15))
                .frame(height: 36)
            
            Spacer()
            
            // Calendar selector button
            Menu {
                ForEach(calendarService.allEventCalendars, id: \.calendarIdentifier) { calendar in
                    Button(action: {
                        selectedCalendar = calendar
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(calendar.cgColor))
                                .frame(width: 12, height: 12)
                            Text(calendar.title)
                            if calendar.calendarIdentifier == selectedCalendar.calendarIdentifier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(selectedCalendar.cgColor))
                        .frame(width: 12, height: 12)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
        .frame(height: 36)
    }
    
    private var locationField: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Borderless text field
            TextField("Add Location or Video Call", text: $location)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .frame(height: 36)
            
            Spacer()
            
            // Video icon and chevron
            HStack(spacing: 6) {
                Image(systemName: "video")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, AppMetrics.paddingLarge)
        .frame(height: 36)
    }
    
    private var dateTimeDisplayField: some View {
        Button(action: { showDatePicker.toggle() }) {
            HStack {
                Text(formatDateTimeRange())
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .frame(height: 36)
            .padding(.horizontal, AppMetrics.padding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
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
        VStack(alignment: .leading, spacing: 0) {
            CustomMultiLineStyledTextField(text: $notes, placeholder: "Add Notes or URL")
                .frame(height: 80)
        }
        .padding(AppMetrics.padding)
    }
    
    // MARK: - Calendar Preview Section
    
    private var calendarPreviewSection: some View {
        MiniTimelineView(
            date: date,
            startTime: combineDateWithTime(date: date, time: startTime),
            endTime: combineDateWithTime(date: date, time: endTime),
            existingEvents: viewModel.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) },
            focusWindowHours: 2
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

// MARK: - Supporting Components

/// Tappable option row with hover state
struct TappableOptionRow: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .frame(height: 36)
            .padding(.horizontal, AppMetrics.paddingLarge)
            .contentShape(Rectangle())
            .background(isHovering ? AppColors.hoverOverlay : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
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

