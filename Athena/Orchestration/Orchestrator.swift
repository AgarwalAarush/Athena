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
        // 1. Check for wakeword control (highest priority)
        if let wakewordAction = detectWakewordControlAction(from: prompt) {
            await handleWakewordControlTask(prompt: prompt, inferredAction: wakewordAction)
            return
        }

        // 2. Check for "go home" navigation (no LLM needed)
        if detectGoHomeCommand(from: prompt) {
            print("[Orchestrator] 🏠 Go home detected - navigating to home view")
            await MainActor.run {
                appViewModel?.showHome()
            }
            return
        }

        // 3. Quick keyword-based routing for obvious cases (avoid LLM call)
        if let quickRoute = detectQuickRoute(from: prompt) {
            print("[Orchestrator] ⚡ Quick route detected: \(quickRoute) (no LLM call needed)")
            switch quickRoute {
            case .notes:
                await handleNotesTask(prompt: prompt)
                return
            case .calendar:
                await handleCalendarTask(prompt: prompt)
                return
            case .windowManagement:
                await handleWindowManagementTask(prompt: prompt)
                return
            case .computerUse:
                await handleComputerUseTask(prompt: prompt)
                return
            case .appCommand:
                await handleAppCommandTask(prompt: prompt)
                return
            default:
                break
            }
        }

        // 4. Use LLM for ambiguous cases
        print("[Orchestrator] 🤖 Using LLM classification for ambiguous query")
        let taskType = try await classifyTask(prompt: prompt, context: context)
        switch taskType {
        case .calendar:
            await handleCalendarTask(prompt: prompt)
        case .notes:
            await handleNotesTask(prompt: prompt)
        case .windowManagement:
            await handleWindowManagementTask(prompt: prompt)
        case .computerUse:
            await handleComputerUseTask(prompt: prompt)
        case .appCommand:
            await handleAppCommandTask(prompt: prompt)
        case .wakewordControl:
            await handleWakewordControlTask(prompt: prompt)
        case .notApplicable:
            print("Task not applicable: \(prompt)")
        }
    }

    /// Classifies a prompt into windowManagement, computerUse, appCommand, or notApplicable.
    private func classifyTask(prompt: String, context: AppView?) async throws -> TaskType {
        let currentView = context ?? .chat
        let systemPrompt = """
        You are a task classifier for a desktop assistant named Athena. Your job is to determine the user's intent based on their query and the current application view.

        Taxonomy (return EXACTLY one of these labels):
        - 'notes': Any action related to notes (creating, editing, viewing notes).
        - 'calendar': Any action related to the calendar (opening calendar view, scheduling, viewing events, navigating dates).
        - 'wakewordControl': Enabling/disabling/toggling wake word listening (e.g., "Athena stop listening").
        - 'windowManagement': Arranging/managing windows (e.g., split, focus, resize).
        - 'appCommand': App-level navigation/settings not tied to a specific content domain (e.g., "open settings", "go back to chat/home").
        - 'computerUse': Operating the computer outside Athena (e.g., "open Safari", "take a screenshot").
        - 'NA': None of the above or unclear.

        Inputs:
        - Current view: '\(currentView)'
        - User query: "\(prompt)"

        Decision rules (in order of priority):
        1) If the query explicitly mentions a domain by name (e.g., "calendar", "notes", "events", "schedule"), RETURN that domain label, even if it says "open … view". (Do NOT return 'appCommand' for domain-named views.)
        2) If no domain term is present, but the query is clearly about app-level navigation or settings (e.g., "open settings", "go back", "switch theme", "open preferences"), RETURN 'appCommand'.
        3) If the query is about arranging or moving windows, RETURN 'windowManagement'.
        4) If the query is about the computer outside Athena (apps, OS features), RETURN 'computerUse'.
        5) If the query is to enable/disable wake word, RETURN 'wakewordControl'.
        6) If multiple could apply, prefer specific domain labels ('notes', 'calendar') over 'appCommand'.
        7) If genuinely unclear, RETURN 'NA'.

        Keyword guidance (non-exhaustive):
        - calendar domain: calendar, agenda, events, schedule, day, week, month, today, tomorrow
        - notes domain: note, notebook, notepad, jot, write this down, new note
        - appCommand: settings, preferences, theme, about, help, sign in, log out, home, chat (when not a domain)
        - windowManagement: resize, split, focus window, move window, center, maximize, minimize
        - computerUse: open Safari/Chrome, take screenshot, system volume, Bluetooth, Wi-Fi

        Examples (Current view -> Query => Label):
        - notes -> "Athena open calendar view" => calendar
        - calendar -> "show tomorrow" => calendar
        - notes -> "create a new note titled project ideas" => notes
        - chat -> "open settings" => appCommand
        - calendar -> "maximize the window" => windowManagement
        - any -> "open Safari" => computerUse
        - any -> "Athena stop listening" => wakewordControl
        - any -> "asdf qwer zzzz" => NA

        Output:
        Respond with exactly one label: 'notes', 'calendar', 'wakewordControl', 'windowManagement', 'appCommand', 'computerUse', or 'NA'.
        """

        let classification = try await aiService.getCompletion(
            prompt: prompt,
            systemPrompt: systemPrompt,
            provider: .openai,
            model: "gpt-5-nano"
        )

        print("[Orchestrator] 🔍 AI raw response: '\(classification)'")
        let trimmed = classification.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Orchestrator] 🔍 AI trimmed response: '\(trimmed)'")
        let taskType = TaskType(rawValue: trimmed) ?? .notApplicable
        print("[Orchestrator] 🔍 Final TaskType: \(taskType)")
        
        return taskType
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

    // MARK: - Quick Route Detection

    /// Attempts to quickly detect task type from obvious keywords without using LLM.
    /// Returns nil if the query is ambiguous and requires LLM classification.
    private func detectQuickRoute(from prompt: String) -> TaskType? {
        let lowercased = prompt.lowercased()
        let tokens = Set(lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        
        // Notes keywords (highest specificity first)
        let noteKeywords = ["note", "notes", "notebook", "notepad", "jot"]
        if noteKeywords.contains(where: { lowercased.contains($0) }) {
            return .notes
        }
        
        // Calendar keywords
        let calendarKeywords = ["calendar", "agenda", "event", "events", "schedule", "meeting", "appointment"]
        let timeKeywords = ["today", "tomorrow", "yesterday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        
        if calendarKeywords.contains(where: { lowercased.contains($0) }) {
            return .calendar
        }
        
        // Time references often indicate calendar
        if timeKeywords.contains(where: { tokens.contains($0) }) {
            return .calendar
        }
        
        // Window management keywords
        let windowKeywords = ["window", "resize", "split", "maximize", "minimize", "center", "arrange"]
        if windowKeywords.contains(where: { lowercased.contains($0) }) {
            return .windowManagement
        }
        
        // Computer use keywords (OS-level operations)
        let computerUseKeywords = ["safari", "chrome", "firefox", "browser", "screenshot", "volume", "bluetooth", "wifi", "wi-fi"]
        if computerUseKeywords.contains(where: { lowercased.contains($0) }) {
            return .computerUse
        }
        
        // App command keywords (but only if no domain is mentioned)
        let appCommandKeywords = ["settings", "preferences", "theme", "help", "about", "sign in", "log out", "home"]
        if appCommandKeywords.contains(where: { lowercased.contains($0) }) {
            return .appCommand
        }
        
        // No clear match - return nil to trigger LLM classification
        return nil
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

    /// Detects "go home" commands from the user prompt.
    /// Matches patterns like "go home", "take me home", "show home", "home page", etc.
    /// Returns true if a home navigation command is detected.
    private func detectGoHomeCommand(from prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        let components = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let tokens = components.filter { !$0.isEmpty }
        
        guard !tokens.isEmpty else { return false }
        
        let sanitized = tokens.joined(separator: " ")
        
        // Direct home patterns
        let homePatterns = [
            "go home",
            "take me home",
            "show home",
            "open home",
            "home page",
            "homepage",
            "go to home",
            "back home",
            "return home",
            "navigate home",
            "home view",
            "show me home"
        ]
        
        // Check if any home pattern matches
        for pattern in homePatterns {
            if sanitized.contains(pattern) {
                return true
            }
        }
        
        // Also check for just "home" as a standalone command
        if tokens.count == 1 && tokens[0] == "home" {
            return true
        }
        
        return false
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
        print("[Orchestrator] handleNotesTask: Processing query '\(prompt)'")

        // ALWAYS switch to notes view first
        await MainActor.run {
            self.appViewModel?.showNotes()
        }

        // Parse the notes query using AI
        do {
            let result = try await parseNotesQuery(prompt: prompt)
            print("[Orchestrator] handleNotesTask: Executing action '\(result.action)' with title '\(result.title ?? "N/A")'")

            switch result.action {
            case .open:
                if let title = result.title, !title.isEmpty {
                    await executeOpenNote(title: title)
                } else {
                    // No title specified, just stay in the notes view
                }
            case .create:
                await executeCreateNote(title: result.title)
            }

        } catch {
            print("[Orchestrator] handleNotesTask: Error parsing/executing notes query: \(error)")
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

    // MARK: - Notes Action Helpers

    private enum NotesActionType: String {
        case open
        case create
    }

    private struct NotesActionResult {
        let action: NotesActionType
        let title: String?
    }

    private func parseNotesQuery(prompt: String) async throws -> NotesActionResult {
        let systemPrompt = """
        You are a notes action parser. Analyze the user's query and determine if they want to open an existing note or create a new one.

        Actions:
        - "open": User wants to view or edit an existing note. Extract the title of the note.
        - "create": User wants to create a new note. Extract the title if they specify one.

        Respond ONLY with valid JSON in this exact format:
        {
          "action": "action_name",
          "title": "note_title"
        }

        Examples:
        Query: "open my note about the project proposal"
        Response: {"action": "open", "title": "project proposal"}

        Query: "create a new note called grocery list"
        Response: {"action": "create", "title": "grocery list"}
        
        Query: "new note"
        Response: {"action": "create", "title": null}

        Now parse this query: "\(prompt)"
        """

        let response = try await aiService.getCompletion(
            prompt: prompt,
            systemPrompt: systemPrompt,
            provider: .openai,
            model: "gpt-5-nano"
        )

        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let actionString = json["action"] as? String,
              let action = NotesActionType(rawValue: actionString) else {
            throw NSError(domain: "Orchestrator", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse notes query"])
        }

        let title = json["title"] as? String
        return NotesActionResult(action: action, title: title)
    }

    private func executeOpenNote(title: String) async {
        guard let notesViewModel = appViewModel?.notesViewModel else { return }
        
        let allNotes = await MainActor.run { notesViewModel.notes }
        
        print("[Orchestrator] executeOpenNote: Searching for '\(title)' among \(allNotes.count) notes")
        
        // Calculate fuzzy match scores for all notes
        let matchesWithScores = allNotes.map { note -> (note: NoteModel, score: Double) in
            let score = fuzzyMatchScore(query: title, target: note.title)
            print("[Orchestrator] executeOpenNote:   - '\(note.title)' => \(String(format: "%.2f%%", score * 100)) similarity")
            return (note: note, score: score)
        }
        
        // Filter by 35% threshold and sort by score descending
        let threshold = 0.35
        let qualifyingMatches = matchesWithScores
            .filter { $0.score >= threshold }
            .sorted { $0.score > $1.score }
        
        print("[Orchestrator] executeOpenNote: Found \(qualifyingMatches.count) matches above \(String(format: "%.0f%%", threshold * 100)) threshold")
        
        if let bestMatch = qualifyingMatches.first {
            print("[Orchestrator] executeOpenNote: Opening best match '\(bestMatch.note.title)' with score \(String(format: "%.2f%%", bestMatch.score * 100))")
            await MainActor.run {
                notesViewModel.selectNote(bestMatch.note)
            }
        } else {
            print("[Orchestrator] executeOpenNote: No note found matching '\(title)' above \(String(format: "%.0f%%", threshold * 100)) threshold")
            // No match found above threshold, stay in notes list view
        }
    }
    
    /// Calculates a fuzzy match score between a query and target string (0.0 to 1.0)
    /// Uses a combination of exact match, contains match, and Levenshtein distance
    private func fuzzyMatchScore(query: String, target: String) -> Double {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLower = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match
        if queryLower == targetLower {
            return 1.0
        }
        
        // Contains match gets high score
        if targetLower.contains(queryLower) {
            let lengthRatio = Double(queryLower.count) / Double(targetLower.count)
            return 0.85 + (0.15 * lengthRatio) // 0.85-1.0 range
        }
        
        if queryLower.contains(targetLower) {
            let lengthRatio = Double(targetLower.count) / Double(queryLower.count)
            return 0.75 + (0.10 * lengthRatio) // 0.75-0.85 range
        }
        
        // Use Levenshtein distance for similarity
        let distance = levenshteinDistance(queryLower, targetLower)
        let maxLength = max(queryLower.count, targetLower.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        
        // Boost score if query words are in target
        let queryWords = Set(queryLower.split(separator: " ").map(String.init))
        let targetWords = Set(targetLower.split(separator: " ").map(String.init))
        let commonWords = queryWords.intersection(targetWords)
        
        if !queryWords.isEmpty {
            let wordMatchRatio = Double(commonWords.count) / Double(queryWords.count)
            return max(similarity, wordMatchRatio * 0.8) // Word match can boost score
        }
        
        return similarity
    }
    
    /// Calculates the Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        
        var distance = Array(repeating: Array(repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        for i in 0...s1.count {
            distance[i][0] = i
        }
        
        for j in 0...s2.count {
            distance[0][j] = j
        }
        
        for i in 1...s1.count {
            for j in 1...s2.count {
                if s1[i - 1] == s2[j - 1] {
                    distance[i][j] = distance[i - 1][j - 1]
                } else {
                    distance[i][j] = min(
                        distance[i - 1][j] + 1,      // deletion
                        distance[i][j - 1] + 1,      // insertion
                        distance[i - 1][j - 1] + 1   // substitution
                    )
                }
            }
        }
        
        return distance[s1.count][s2.count]
    }

    private func executeCreateNote(title: String?) async {
        guard let notesViewModel = appViewModel?.notesViewModel else { return }
        notesViewModel.createNewNote()
        if let title = title {
            notesViewModel.currentNote?.title = title
        }
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

    /// Executes create event action by navigating to calendar view and presenting creation modal
    private func executeCreateEvent(params: [String: String]) async {
        print("[Orchestrator] executeCreateEvent: Starting with params: \(params)")
        
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

        // Combine date and time for start
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

        print("[Orchestrator] Create: Preparing event '\(title)' from \(startDate) to \(endDate)")

        // Navigate to calendar view first, showing the event's date
        await MainActor.run {
            self.appViewModel?.showCalendar()
            self.appViewModel?.dayViewModel.selectedDate = eventDate
        }

        // Create pending event data
        let pendingData = PendingEventData(
            title: title,
            date: eventDate,
            startTime: startDate,
            endTime: endDate,
            notes: notes
        )

        // Present the creation modal
        await MainActor.run {
            self.appViewModel?.dayViewModel.presentCreateEvent(with: pendingData)
        }

        print("[Orchestrator] Create: Modal presented with event data")
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
               Required params: title, date (default "today"), startTime (HH:mm format in 24-hour time)
               Optional params: endTime (HH:mm) OR duration (minutes as string), notes
               IMPORTANT: Convert AM/PM times to 24-hour format (e.g., "2pm" → "14:00", "11:30am" → "11:30")
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

            Query: "create an event tomorrow from 11:30 to 12:30 pm for lunch with Dave"
            Response: {"action": "create", "params": {"title": "Lunch with Dave", "date": "tomorrow", "startTime": "11:30", "endTime": "12:30"}}

            Query: "schedule a meeting at 2:30pm for one hour called Team Sync"
            Response: {"action": "create", "params": {"title": "Team Sync", "date": "today", "startTime": "14:30", "duration": "60"}}

            Query: "create event for coffee at 9am tomorrow"
            Response: {"action": "create", "params": {"title": "Coffee", "date": "tomorrow", "startTime": "09:00", "duration": "60"}}

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
