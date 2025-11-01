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
    case notApplicable = "NA"
}

/// The Orchestrator is responsible for routing user prompts to the appropriate handler.
/// It uses an AI model to classify the user's intent into one of the predefined task types.
class Orchestrator {

    private let aiService: AIServiceProtocol

    /// Initializes the Orchestrator with a given AI service.
    /// - Parameter aiService: The AI service to use for intent classification.
    init(aiService: AIServiceProtocol = AIService.shared) {
        self.aiService = aiService
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
            case .notApplicable, .notes, .calendar:
                // Handle 'notApplicable' or cases that should have been caught by keyword search
                print("Task not applicable or mis-routed: \(taskType)")
            }
        }
    }

    /// Classifies a prompt into windowManagement, computerUse, or notApplicable.
    private func classifyTask(prompt: String) async throws -> TaskType {
        let systemPrompt = """
        Given this user query:
        "\(prompt)"
        Return a classification for whether it is a windowManagement task, a computerUse task, or neither. Window management tasks may include predefined user configs for how windows look. Respond with exactly one label: 'windowManagement', 'computerUse', or 'NA'.
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
        // Implementation to be added
    }

    private func handleNotesTask(prompt: String) async {
        // Implementation to be added
    }

    private func handleWindowManagementTask(prompt: String) async {
        // Implementation to be added
    }

    private func handleComputerUseTask(prompt: String) async {
        // Implementation to be added
    }
}
