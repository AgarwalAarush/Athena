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
    /// - Parameter prompt: The user's input prompt.
    func route(prompt: String) async throws {
        let lowercasedPrompt = prompt.lowercased()

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
        Return a classification for whether it is a windowManagement task, a computerUse task, an appCommand task, or neither. 
        - 'windowManagement' tasks may include predefined user configs for how windows look.
        - 'appCommand' tasks are for making changes and navigating within the app itself (e.g. "go back to the chatview").
        - 'computerUse' tasks involve general computer operations not covered by the other categories.
        Respond with exactly one label: 'windowManagement', 'computerUse', 'appCommand', or 'NA'.
        """

        let classification = try await aiService.getCompletion(
            prompt: prompt,
            systemPrompt: systemPrompt,
            provider: .openai,
            model: "gpt-5-nano-2025-08-07"
        )

        return TaskType(rawValue: classification.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .notApplicable
    }

    // MARK: - Task Handlers

    private func handleCalendarTask(prompt: String) async {
        DispatchQueue.main.async {
            self.appViewModel?.showCalendar()
        }
    }

    private func handleNotesTask(prompt: String) async {
        DispatchQueue.main.async {
            self.appViewModel?.showNotes()
        }
    }

    private func handleWindowManagementTask(prompt: String) async {
        // Implementation to be added
    }

    private func handleComputerUseTask(prompt: String) async {
        // Implementation to be added
    }

    private func handleAppCommandTask(prompt: String) async {
        // Implementation to be added
    }
}
