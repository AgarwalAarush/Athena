

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
    case windowManagement = "window_management"
    case openApp = "open_app"
    case computerUse = "computer_use"
    case unknown
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
    
    /// Routes a user prompt to a specific task type by classifying the user's intent.
    /// - Parameter prompt: The user's input prompt.
    /// - Returns: The classified `TaskType`.
    func route(prompt: String) async throws -> TaskType {
        let systemPrompt = """
        You are a highly intelligent routing agent. Your task is to classify the user's prompt into one of the following categories: \(TaskType.allCases.map { $0.rawValue }.joined(separator: ", ")).
        Respond with only the category name, and nothing else. For example, if the user says 'take a note', you should respond with 'notes'.
        If the user's prompt does not fit into any of the categories, respond with 'unknown'.
        """
        
        let classification = try await aiService.getCompletion(
            prompt: prompt,
            systemPrompt: systemPrompt,
            provider: .openai,
            model: "gpt-5-nano-2025-08-07"
        )
        
        if let taskType = TaskType(rawValue: classification.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            return taskType
        } else {
            return .unknown
        }
    }
}

