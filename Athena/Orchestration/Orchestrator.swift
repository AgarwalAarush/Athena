//
//  Orchestrator.swift
//  Athena
//
//  Created by Aarush Agarwal on 10/31/25.
//

import Foundation

/// Defines the types of tasks the AI can route to.
enum TaskType: String, CaseIterable {
    case notes
    case calendar
    case windowManagement
    case computerUse
    case appCommand
    case wakewordControl
    case notApplicable = "NA"
}

/// The Orchestrator is responsible for routing user prompts to the appropriate handler.
/// It uses an AI model to classify the user's intent into one of the predefined task types.
class Orchestrator {

    private let aiService: AIServiceProtocol
    private weak var appViewModel: AppViewModel?

    /// Initializes the Orchestrator with a given AI service and optional AppViewModel.
    /// - Parameters:
    ///   - aiService: The AI service to use for intent classification.
    ///   - appViewModel: The view model to control the app's view state.
    init(aiService: AIServiceProtocol = AIService.shared, appViewModel: AppViewModel? = nil) {
        self.aiService = aiService
        self.appViewModel = appViewModel
    }

    /// Routes a user prompt to the appropriate handler.
    ///
    /// - Parameters:
    ///   - prompt: The user's input prompt.
    ///   - context: Optional current view context. When provided, indicates the user is already in that view
    ///              and the prompt should be processed IN CONTEXT of that view (e.g., "show tomorrow's events"
    ///              while in calendar view should navigate calendar, not just switch to it).
    ///
    /// - Note: **TODO - Context-Aware Routing Implementation Required**
    ///
    ///   When `context` is provided, the routing behavior should change:
    ///
    ///   **Calendar Context (context == .calendar):**
    ///   - User is already viewing the calendar
    ///   - Parse prompt for calendar-specific actions:
    ///     * Navigation: "show tomorrow", "next week", "go to Friday", "today"
    ///       → Call appViewModel.dayViewModel.nextDay() / previousDay() / today()
    ///       → Or set appViewModel.dayViewModel.selectedDate directly
    ///     * Event queries: "what's on my calendar", "show me morning events"
    ///       → Use CalendarService to fetch and potentially display results
    ///     * Event creation: "create meeting at 3pm", "schedule dentist appointment tomorrow"
    ///       → Parse with AI, call CalendarService.createEvent()
    ///     * Event modification: "move my 2pm meeting to 3pm", "delete lunch meeting"
    ///       → Parse with AI, call CalendarService.updateEvent() / deleteEvent()
    ///
    ///   **Notes Context (context == .notes):**
    ///   - User is already viewing notes
    ///   - Parse prompt for notes-specific actions:
    ///     * Create: "create note about X", "new note: ..."
    ///       → Set appViewModel.noteContent = [AI-generated content]
    ///     * Append: "add to note: ...", "also include ..."
    ///       → Append to appViewModel.noteContent
    ///     * Replace: "change note to ...", "rewrite as ..."
    ///       → Replace appViewModel.noteContent
    ///     * Format: "make this a bullet list", "add heading ..."
    ///       → Use AI to transform appViewModel.noteContent
    ///
    ///   **Chat Context (context == .chat or nil):**
    ///   - Use existing keyword/classification logic to determine if we should:
    ///     * Switch to calendar view (prompt contains "calendar")
    ///     * Switch to notes view (prompt contains "note"/"notes")
    ///     * Handle window management, computer use, or app commands
    ///
    ///   **Implementation Approach:**
    ///   ```swift
    ///   if let context = context {
    ///       switch context {
    ///       case .calendar:
    ///           // Already in calendar - execute calendar actions
    ///           let action = try await parseCalendarAction(prompt: prompt)
    ///           await executeCalendarAction(action)
    ///       case .notes:
    ///           // Already in notes - execute notes actions
    ///           let action = try await parseNotesAction(prompt: prompt)
    ///           await executeNotesAction(action)
    ///       case .chat:
    ///           // Use existing routing logic below
    ///           break
    ///       }
    ///       return
    ///   }
    ///   ```
    func route(prompt: String, context: AppView? = nil) async throws {
        // TODO: Implement context-aware routing (see documentation above)
        // For now, use existing keyword-based routing

        let lowercasedPrompt = prompt.lowercased()

        if let wakewordAction = detectWakewordControlAction(from: prompt) {
            await handleWakewordControlTask(prompt: prompt, inferredAction: wakewordAction)
            return
        }

        if lowercasedPrompt.contains("calendar") {
            await handleCalendarTask(prompt: prompt)
        } else if lowercasedPrompt.contains("note") || lowercasedPrompt.contains("notes") {
            await handleNotesTask(prompt: prompt)
        } else {
            let taskType = try await classifyTask(prompt: prompt)
            switch taskType {
            case .windowManagement:
                await handleWindowManagementTask(prompt: prompt)
            case .computerUse:
                await handleComputerUseTask(prompt: prompt)
            case .appCommand:
                await handleAppCommandTask(prompt: prompt)
            case .wakewordControl:
                await handleWakewordControlTask(prompt: prompt)
            case .notApplicable, .notes, .calendar:
                // Handle 'notApplicable' or cases that should have been caught by keyword search
                print("Task not applicable or mis-routed: \(taskType)")
            }
        }
    }

    /// Classifies a prompt into windowManagement, computerUse, appCommand, or notApplicable.
    private func classifyTask(prompt: String) async throws -> TaskType {
        let systemPrompt = """
        Given this user query:
        "\(prompt)"
        Return a classification for whether it is a wakewordControl task, a windowManagement task, a computerUse task, an appCommand task, or neither.
        - 'wakewordControl' tasks cover enabling, disabling, or toggling the wake word listening mode (e.g. "Athena shut down", "stop wakeword mode", "Athena wake up").
        - 'windowManagement' tasks may include predefined user configs for how windows look.
        - 'appCommand' tasks are for making changes and navigating within the app itself (e.g. "go back to the chatview").
        - 'computerUse' tasks involve general computer operations not covered by the other categories.
        Respond with exactly one label: 'wakewordControl', 'windowManagement', 'computerUse', 'appCommand', or 'NA'.
        """

        let classification = try await aiService.getCompletion(
            prompt: prompt,
            systemPrompt: systemPrompt,
            provider: .openai,
            model: "gpt-5-nano-2025-08-07"
        )

        return TaskType(rawValue: classification.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .notApplicable
    }

    // MARK: - Calendar Action Types

    /// Result of parsing a calendar query
    private struct CalendarActionResult {
        let action: CalendarActionType
        let params: [String: String]
    }

    /// Types of calendar actions that can be performed
    private enum CalendarActionType: String {
        case view       // Just open calendar
        case navigate   // Change visible date
        case create     // Create new event
        case update     // Modify existing event
        case delete     // Delete event
        case query      // Ask about events
    }

    // MARK: - Wakeword Control

    private enum WakewordControlAction {
        case disable
        case enable
        case toggle
    }

    /// Handles wakeword control requests, such as disabling the wake word listening loop.
    private func handleWakewordControlTask(prompt: String, inferredAction: WakewordControlAction? = nil) async {
        print("[Orchestrator] handleWakewordControlTask: Processing prompt '\(prompt)'")

        let action = inferredAction ?? detectWakewordControlAction(from: prompt)

        guard let action else {
            print("[Orchestrator] handleWakewordControlTask: No actionable wakeword command detected")
            return
        }

        let config = ConfigurationManager.shared
        await MainActor.run {
            let currentState = config.wakewordModeEnabled

            switch action {
            case .disable:
                guard currentState else {
                    print("[Orchestrator] handleWakewordControlTask: Wakeword mode already disabled")
                    return
                }
                print("[Orchestrator] handleWakewordControlTask: Disabling wakeword mode via configuration toggle")
                config.set(false, for: .wakewordModeEnabled)
            case .enable:
                guard !currentState else {
                    print("[Orchestrator] handleWakewordControlTask: Wakeword mode already enabled")
                    return
                }
                print("[Orchestrator] handleWakewordControlTask: Enabling wakeword mode via configuration toggle")
                config.set(true, for: .wakewordModeEnabled)
            case .toggle:
                let newValue = !currentState
                print("[Orchestrator] handleWakewordControlTask: Toggling wakeword mode to \(newValue ? "enabled" : "disabled")")
                config.set(newValue, for: .wakewordModeEnabled)
            }
        }
    }

    /// Attempts to infer the wakeword control action (enable/disable/toggle) from a user prompt.
    private func detectWakewordControlAction(from prompt: String) -> WakewordControlAction? {
        let lowered = prompt.lowercased()
        let components = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let tokens = components.filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return nil }

        let sanitized = tokens.joined(separator: " ")
        let tokenSet = Set(tokens)

        let mentionsAthena = tokenSet.contains("athena")
        let mentionsWakeword = tokenSet.contains("wakeword") || sanitized.contains("wakeword mode")

        let friendlyShutdownPatterns = ["good night", "goodnight", "go to sleep", "sleep now", "time to sleep"]
        if mentionsAthena && friendlyShutdownPatterns.contains(where: { sanitized.contains($0) }) {
            return .disable
        }

        if mentionsAthena && sanitized.contains("athena stop listening") {
            return .disable
        }

        if (mentionsAthena || mentionsWakeword) &&
            (sanitized.contains("stop listening") || sanitized.contains("stop the listening")) {
            return .disable
        }

        if mentionsAthena && sanitized.contains("athena shut down") {
            var suffix = sanitized.replacingOccurrences(of: "athena shut down", with: "")
            suffix = suffix.trimmingCharacters(in: .whitespaces)

            if suffix.isEmpty {
                return .disable
            }

            let suffixTokens = suffix.split(separator: " ")
            let fillerTokens: Set<String> = ["please", "pls", "plz", "now", "right", "ok", "thanks", "thank", "you", "for", "me"]
            let containsWakewordOrListening = suffix.contains("wakeword") || suffix.contains("wakeword mode") || suffix.contains("listening")
            let containsSleepLanguage = suffix.contains("sleep")

            if containsWakewordOrListening || containsSleepLanguage || suffixTokens.allSatisfy({ fillerTokens.contains(String($0)) }) {
                return .disable
            }
        }

        if mentionsWakeword {
            let shutdownPhrases = [
                "shut down", "shutdown", "shut off", "turn off", "power down",
                "power off", "stop", "stop listening", "disable", "deactivate"
            ]

            for phrase in shutdownPhrases {
                if sanitized.contains("\(phrase) wakeword") ||
                    sanitized.contains("\(phrase) wakeword mode") ||
                    sanitized.contains("\(phrase) the wakeword") {
                    return .disable
                }
            }
        }

        return nil
    }

    // MARK: - Task Handlers

    /// Handles calendar-related tasks by switching to calendar view and executing calendar actions.
    ///
    /// This method:
    /// 1. ALWAYS switches to calendar view first
    /// 2. Parses the prompt using AI to determine action type (navigate, create, update, delete, query, or view)
    /// 3. Executes the appropriate calendar action via CalendarService and DayViewModel
    ///
    /// Supported actions:
    /// - **view**: Just open calendar
    /// - **navigate**: Change visible date (e.g., "show tomorrow", "go to Friday")
    /// - **create**: Create new event (e.g., "create meeting at 3pm called Team Sync")
    /// - **update**: Modify existing event (e.g., "move my dentist appointment to Thursday")
    /// - **delete**: Remove event (e.g., "delete my 2pm meeting")
    /// - **query**: Ask about events (e.g., "what's on my calendar today")
    private func handleCalendarTask(prompt: String) async {
        print("[Orchestrator] handleCalendarTask: Processing query '\(prompt)'")

        // ALWAYS switch to calendar view first
        await MainActor.run {
            self.appViewModel?.showCalendar()
        }

        // Parse the calendar query (with automatic fallback to keyword matching)
        let result = await parseCalendarQuery(prompt: prompt)
        print("[Orchestrator] handleCalendarTask: Executing action '\(result.action)'")

        // Execute the appropriate action
        switch result.action {
        case .view:
            // Already switched to calendar, nothing more to do
            print("[Orchestrator] handleCalendarTask: View action - calendar opened")

        case .navigate:
            await executeNavigate(params: result.params)

        case .create:
            await executeCreateEvent(params: result.params)

        case .update:
            await executeUpdateEvent(params: result.params)

        case .delete:
            await executeDeleteEvent(params: result.params)

        case .query:
            await executeQuery(params: result.params)
        }

        print("[Orchestrator] handleCalendarTask: Action completed")
    }

    /// Handles notes-related tasks by switching to notes view or executing notes actions.
    ///
    /// **TODO - Current Implementation:** Only switches to notes view
    ///
    /// **Required Implementation:**
    /// This method is called when the user's prompt is notes-related. It should:
    ///
    /// 1. **Switch to notes view** (if not already there):
    ///    ```swift
    ///    await MainActor.run {
    ///        self.appViewModel?.showNotes()
    ///    }
    ///    ```
    ///
    /// 2. **Parse the prompt** to extract notes action intent:
    ///    - Use AI (via aiService) to determine action type and content
    ///    - Action types: create, append, replace, format, summarize
    ///
    /// 3. **Execute the action** via appViewModel.noteContent:
    ///    ```swift
    ///    // Example: Create new note
    ///    if action == "create" {
    ///        let content = await generateNoteContent(prompt: prompt)
    ///        await MainActor.run {
    ///            self.appViewModel?.noteContent = content
    ///        }
    ///    }
    ///
    ///    // Example: Append to existing note
    ///    if action == "append" {
    ///        let addition = await generateAddition(prompt: prompt)
    ///        await MainActor.run {
    ///            let current = self.appViewModel?.noteContent ?? ""
    ///            self.appViewModel?.noteContent = current + "\n\n" + addition
    ///        }
    ///    }
    ///
    ///    // Example: Format transformation
    ///    if action == "format" {
    ///        let current = self.appViewModel?.noteContent ?? ""
    ///        let transformed = await transformContent(current, instruction: prompt)
    ///        await MainActor.run {
    ///            self.appViewModel?.noteContent = transformed
    ///        }
    ///    }
    ///    ```
    ///
    /// **Access to Notes State:**
    /// - appViewModel.noteContent (String binding for rich text editor)
    private func handleNotesTask(prompt: String) async {
        // TODO: Implement AI-powered notes action parsing and execution
        // For now, just switch to notes view
        DispatchQueue.main.async {
            self.appViewModel?.showNotes()
        }
    }

    /// Handles window management tasks (e.g., "arrange windows side by side").
    ///
    /// **TODO - Not Yet Implemented**
    ///
    /// This should handle system-level window arrangement and management tasks.
    private func handleWindowManagementTask(prompt: String) async {
        // TODO: Implement window management
        print("[Orchestrator] Window management not yet implemented: \(prompt)")
    }

    /// Handles general computer use tasks (e.g., "open Safari", "take a screenshot").
    ///
    /// **TODO - Not Yet Implemented**
    ///
    /// This should handle general computer operations using system APIs.
    private func handleComputerUseTask(prompt: String) async {
        // TODO: Implement computer use actions
        print("[Orchestrator] Computer use not yet implemented: \(prompt)")
    }

    /// Handles app-level commands (e.g., "go back to chat", "show settings").
    ///
    /// **TODO - Not Yet Implemented**
    ///
    /// This should handle navigation and commands within the app itself.
    /// Examples:
    /// - "go back" → appViewModel.showChat()
    /// - "show settings" → windowManager.openSettingsWindow()
    private func handleAppCommandTask(prompt: String) async {
        // TODO: Implement app command parsing
        print("[Orchestrator] App command not yet implemented: \(prompt)")
    }

    // MARK: - Calendar Action Helpers

    // MARK: Action Executors

    /// Executes a calendar navigation action (change visible date)
    private func executeNavigate(params: [String: String]) async {
        guard let targetDateString = params["targetDate"] else {
            print("[Orchestrator] Navigate: Missing targetDate parameter")
            return
        }

        guard let targetDate = parseDate(dateString: targetDateString) else {
            print("[Orchestrator] Navigate: Failed to parse date '\(targetDateString)'")
            return
        }

        print("[Orchestrator] Navigate: Moving to date \(targetDate)")
        await MainActor.run {
            self.appViewModel?.dayViewModel.selectedDate = targetDate
        }
    }

    /// Executes create event action
    private func executeCreateEvent(params: [String: String]) async {
        guard let title = params["title"] else {
            print("[Orchestrator] Create: Missing title parameter")
            return
        }

        // Parse date (default to today)
        let dateString = params["date"] ?? "today"
        guard let eventDate = parseDate(dateString: dateString) else {
            print("[Orchestrator] Create: Failed to parse date '\(dateString)'")
            return
        }

        // Parse start time
        guard let startTimeString = params["startTime"],
              let startTimeComponents = parseTime(startTimeString) else {
            print("[Orchestrator] Create: Missing or invalid startTime parameter")
            return
        }

        // Combine date and time
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        startComponents.hour = startTimeComponents.hour
        startComponents.minute = startTimeComponents.minute

        guard let startDate = calendar.date(from: startComponents) else {
            print("[Orchestrator] Create: Failed to create start date")
            return
        }

        // Calculate end date
        let endDate: Date
        if let endTimeString = params["endTime"],
           let endTimeComponents = parseTime(endTimeString) {
            var endComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
            endComponents.hour = endTimeComponents.hour
            endComponents.minute = endTimeComponents.minute
            endDate = calendar.date(from: endComponents) ?? calendar.date(byAdding: .hour, value: 1, to: startDate)!
        } else if let durationString = params["duration"],
                  let durationMinutes = Int(durationString) {
            endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate)!
        } else {
            // Default to 1 hour
            endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
        }

        let notes = params["notes"]

        print("[Orchestrator] Create: Creating event '\(title)' from \(startDate) to \(endDate)")

        // Create the event
        CalendarService.shared.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes
        ) { event, error in
            if let error = error {
                print("[Orchestrator] Create: Error creating event: \(error.localizedDescription)")
            } else if let event = event {
                print("[Orchestrator] Create: Successfully created event '\(event.title)'")
                // Navigate to the event's date
                Task { @MainActor in
                    self.appViewModel?.dayViewModel.selectedDate = startDate
                }
            }
        }
    }

    /// Executes delete event action
    private func executeDeleteEvent(params: [String: String]) async {
        guard let eventIdentifier = params["eventIdentifier"] else {
            print("[Orchestrator] Delete: Missing eventIdentifier parameter")
            return
        }

        print("[Orchestrator] Delete: Searching for event matching '\(eventIdentifier)'")

        // Get current visible date and fetch events for that day
        let selectedDate = await MainActor.run {
            self.appViewModel?.dayViewModel.selectedDate ?? Date()
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            print("[Orchestrator] Delete: Failed to calculate end of day")
            return
        }

        // Fetch events for the selected day
        CalendarService.shared.fetchEvents(from: startOfDay, to: endOfDay) { events, error in
            if let error = error {
                print("[Orchestrator] Delete: Error fetching events: \(error.localizedDescription)")
                return
            }

            guard let events = events else {
                print("[Orchestrator] Delete: No events found")
                return
            }

            // Find event matching identifier (case-insensitive search in title)
            let lowercasedIdentifier = eventIdentifier.lowercased()
            guard let eventToDelete = events.first(where: { event in
                event.title.lowercased().contains(lowercasedIdentifier)
            }) else {
                print("[Orchestrator] Delete: No event found matching '\(eventIdentifier)'")
                return
            }

            print("[Orchestrator] Delete: Found event '\(eventToDelete.title)', deleting...")

            CalendarService.shared.deleteEvent(eventToDelete) { error in
                if let error = error {
                    print("[Orchestrator] Delete: Error deleting event: \(error.localizedDescription)")
                } else {
                    print("[Orchestrator] Delete: Successfully deleted event '\(eventToDelete.title)'")
                    // Refresh the view
                    Task { @MainActor in
                        await self.appViewModel?.dayViewModel.fetchEvents()
                    }
                }
            }
        }
    }

    /// Executes update event action
    private func executeUpdateEvent(params: [String: String]) async {
        guard let eventIdentifier = params["eventIdentifier"] else {
            print("[Orchestrator] Update: Missing eventIdentifier parameter")
            return
        }

        print("[Orchestrator] Update: Searching for event matching '\(eventIdentifier)'")

        // Get current visible date and fetch events for that day
        let selectedDate = await MainActor.run {
            self.appViewModel?.dayViewModel.selectedDate ?? Date()
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            print("[Orchestrator] Update: Failed to calculate end of day")
            return
        }

        // Fetch events for the selected day
        CalendarService.shared.fetchEvents(from: startOfDay, to: endOfDay) { events, error in
            if let error = error {
                print("[Orchestrator] Update: Error fetching events: \(error.localizedDescription)")
                return
            }

            guard let events = events else {
                print("[Orchestrator] Update: No events found")
                return
            }

            // Find event matching identifier
            let lowercasedIdentifier = eventIdentifier.lowercased()
            guard let eventToUpdate = events.first(where: { event in
                event.title.lowercased().contains(lowercasedIdentifier)
            }) else {
                print("[Orchestrator] Update: No event found matching '\(eventIdentifier)'")
                return
            }

            print("[Orchestrator] Update: Found event '\(eventToUpdate.title)', updating...")

            // For now, just log that we would update it
            // Full implementation would parse the 'changes' parameter and apply them
            print("[Orchestrator] Update: Would update event with params: \(params)")
            print("[Orchestrator] Update: TODO - Implement parameter parsing and event update")

            // TODO: Parse changes parameter and call CalendarService.updateEvent()
        }
    }

    /// Executes query action (ask about events)
    private func executeQuery(params: [String: String]) async {
        guard let dateRangeString = params["dateRange"] else {
            print("[Orchestrator] Query: Missing dateRange parameter")
            return
        }

        guard let targetDate = parseDate(dateString: dateRangeString) else {
            print("[Orchestrator] Query: Failed to parse date range '\(dateRangeString)'")
            return
        }

        print("[Orchestrator] Query: Fetching events for \(dateRangeString)")

        // Navigate to the date
        await MainActor.run {
            self.appViewModel?.dayViewModel.selectedDate = targetDate
        }

        // The calendar view will automatically show the events for that date
        // In the future, we could also display a summary or speak the events
    }

    // MARK: Parsing Helpers

    /// Fallback parser using keyword matching for common calendar queries
    /// Used when AI parsing fails or is unavailable
    private func parseCalendarQueryFallback(prompt: String) -> CalendarActionResult {
        let lowercased = prompt.lowercased()
        print("[Orchestrator] Using fallback keyword-based parser for: '\(prompt)'")

        // Navigation patterns
        if lowercased.contains("tomorrow") {
            print("[Orchestrator] Fallback: Detected 'tomorrow' - navigate action")
            return CalendarActionResult(action: .navigate, params: ["targetDate": "tomorrow"])
        }

        if lowercased.contains("today") {
            print("[Orchestrator] Fallback: Detected 'today' - navigate/query action")
            // If asking about events, treat as query; otherwise navigate
            if lowercased.contains("what") || lowercased.contains("show") {
                return CalendarActionResult(action: .query, params: ["dateRange": "today"])
            }
            return CalendarActionResult(action: .navigate, params: ["targetDate": "today"])
        }

        if lowercased.contains("yesterday") {
            print("[Orchestrator] Fallback: Detected 'yesterday' - navigate action")
            return CalendarActionResult(action: .navigate, params: ["targetDate": "yesterday"])
        }

        if lowercased.contains("next week") {
            print("[Orchestrator] Fallback: Detected 'next week' - navigate action")
            return CalendarActionResult(action: .navigate, params: ["targetDate": "next week"])
        }

        if lowercased.contains("next month") {
            print("[Orchestrator] Fallback: Detected 'next month' - navigate action")
            return CalendarActionResult(action: .navigate, params: ["targetDate": "next month"])
        }

        // Weekday navigation
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for weekday in weekdays {
            if lowercased.contains(weekday) {
                print("[Orchestrator] Fallback: Detected weekday '\(weekday)' - navigate action")
                return CalendarActionResult(action: .navigate, params: ["targetDate": weekday])
            }
        }

        // Create patterns
        if (lowercased.contains("create") || lowercased.contains("schedule") || lowercased.contains("add")) &&
           (lowercased.contains("at") || lowercased.contains("meeting") || lowercased.contains("event")) {
            print("[Orchestrator] Fallback: Detected create pattern - would need title/time extraction")
            // For now, just open calendar - full implementation would extract title and time
            return CalendarActionResult(action: .view, params: [:])
        }

        // Delete patterns
        if (lowercased.contains("delete") || lowercased.contains("remove") || lowercased.contains("cancel")) {
            print("[Orchestrator] Fallback: Detected delete pattern - would need event identifier")
            // For now, just open calendar - full implementation would extract event identifier
            return CalendarActionResult(action: .view, params: [:])
        }

        // Query patterns
        if lowercased.contains("what") && lowercased.contains("calendar") {
            print("[Orchestrator] Fallback: Detected query pattern")
            return CalendarActionResult(action: .query, params: ["dateRange": "today"])
        }

        // Default: just view calendar
        print("[Orchestrator] Fallback: No specific pattern matched - default to view")
        return CalendarActionResult(action: .view, params: [:])
    }

    /// Parses a calendar query using AI to determine action type and extract parameters
    /// Falls back to keyword matching if AI parsing fails
    private func parseCalendarQuery(prompt: String) async -> CalendarActionResult {
        print("[Orchestrator] Parsing calendar query: \(prompt)")

        // Try AI parsing first
        do {
            let currentDate = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            dateFormatter.timeStyle = .short

            let systemPrompt = """
            You are a calendar action parser. Analyze the user's query and determine what calendar action they want.

            Current date and time: \(dateFormatter.string(from: currentDate))

            Available actions:
            1. "view" - Just open/show calendar (no specific action)
            2. "navigate" - Change visible date
               Required params: targetDate (e.g., "tomorrow", "next week", "friday", "2024-03-15")
            3. "create" - Create new event
               Required params: title, date (default "today"), startTime (HH:mm format)
               Optional params: endTime (HH:mm) OR duration (minutes), notes
            4. "update" - Modify existing event
               Required params: eventIdentifier (description of event), changes (what to modify)
            5. "delete" - Delete event
               Required params: eventIdentifier (description of event to delete)
            6. "query" - Ask about events
               Required params: dateRange (e.g., "today", "this week", "tomorrow")
               Optional params: filters (e.g., "morning", "afternoon")

            Respond ONLY with valid JSON in this exact format (no markdown, no code blocks):
            {
              "action": "action_name",
              "params": {
                "param1": "value1",
                "param2": "value2"
              }
            }

            Examples:
            Query: "show me tomorrow"
            Response: {"action": "navigate", "params": {"targetDate": "tomorrow"}}

            Query: "create a meeting at 3pm called Team Sync"
            Response: {"action": "create", "params": {"title": "Team Sync", "date": "today", "startTime": "15:00", "duration": "60"}}

            Query: "delete my dentist appointment"
            Response: {"action": "delete", "params": {"eventIdentifier": "dentist appointment"}}

            Query: "what's on my calendar today"
            Response: {"action": "query", "params": {"dateRange": "today"}}

            Query: "open calendar"
            Response: {"action": "view", "params": {}}

            Now parse this query: "\(prompt)"
            Respond with ONLY the JSON, no other text.
            """

            print("[Orchestrator] Attempting AI parse...")
            let response = try await aiService.getCompletion(
                prompt: prompt,
                systemPrompt: systemPrompt,
                provider: .openai,
                model: "gpt-5-nano-2025-08-07"
            )

            print("[Orchestrator] AI response: \(response)")

            // Parse JSON response
            guard let jsonData = response.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let actionString = json["action"] as? String,
                  let action = CalendarActionType(rawValue: actionString) else {
                print("[Orchestrator] Failed to parse AI JSON response, using fallback")
                return parseCalendarQueryFallback(prompt: prompt)
            }

            let params = (json["params"] as? [String: String]) ?? [:]
            print("[Orchestrator] AI parsed action: \(action), params: \(params)")

            return CalendarActionResult(action: action, params: params)

        } catch {
            print("[Orchestrator] AI parsing error: \(error) - using fallback parser")
            return parseCalendarQueryFallback(prompt: prompt)
        }
    }

    /// Parses a relative or absolute date string into a Date
    private func parseDate(dateString: String, relativeTo baseDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let lowercased = dateString.lowercased().trimmingCharacters(in: .whitespaces)

        // Handle relative dates
        switch lowercased {
        case "today":
            return calendar.startOfDay(for: baseDate)
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: baseDate))
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: baseDate))
        case "next week":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfDay(for: baseDate))
        case "next month":
            return calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: baseDate))
        default:
            break
        }

        // Handle weekday names (e.g., "friday", "next friday")
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        for i in 0..<7 {
            if let futureDate = calendar.date(byAdding: .day, value: i, to: baseDate),
               weekdayFormatter.string(from: futureDate).lowercased() == lowercased {
                return calendar.startOfDay(for: futureDate)
            }
        }

        // Handle absolute dates (ISO format YYYY-MM-DD)
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Handle common date formats
        let commonFormatter = DateFormatter()
        commonFormatter.dateStyle = .medium
        if let date = commonFormatter.date(from: dateString) {
            return date
        }

        return nil
    }

    /// Parses a time string (e.g., "3pm", "15:00", "2:30pm") into Date components
    private func parseTime(_ timeString: String) -> DateComponents? {
        var cleaned = timeString.lowercased().trimmingCharacters(in: .whitespaces)

        // Handle "am/pm" format
        var isPM = false
        if cleaned.hasSuffix("pm") {
            isPM = true
            cleaned = cleaned.replacingOccurrences(of: "pm", with: "").trimmingCharacters(in: .whitespaces)
        } else if cleaned.hasSuffix("am") {
            cleaned = cleaned.replacingOccurrences(of: "am", with: "").trimmingCharacters(in: .whitespaces)
        }

        // Parse hour and minute
        let parts = cleaned.split(separator: ":").map(String.init)
        guard let hour = Int(parts[0]) else { return nil }

        let minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0

        // Adjust for PM
        var finalHour = hour
        if isPM && hour < 12 {
            finalHour += 12
        } else if !isPM && hour == 12 {
            finalHour = 0
        }

        var components = DateComponents()
        components.hour = finalHour
        components.minute = minute
        return components
    }
}
