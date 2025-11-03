//
//  Provider.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic (Claude)"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openai:
            return "gpt-5-nano"
        case .anthropic:
            return "claude-haiku-4-5-20251001"
        }
    }
    
    var availableModels: [AIModel] {
        switch self {
        case .openai:
            return [
                AIModel(id: "gpt-5-nano", name: "GPT-5 Nano", provider: .openai),
                AIModel(id: "gpt-4o", name: "GPT-4o", provider: .openai),
                AIModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: .openai),
                AIModel(id: "gpt-4-turbo", name: "GPT-4 Turbo", provider: .openai),
                AIModel(id: "gpt-4", name: "GPT-4", provider: .openai),
                AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openai)
            ]
        case .anthropic:
            return [
                AIModel(id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5", provider: .anthropic),
                AIModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: .anthropic),
                AIModel(id: "claude-3-sonnet-20240229", name: "Claude 3 Sonnet", provider: .anthropic),
                AIModel(id: "claude-3-haiku-20240307", name: "Claude 3 Haiku", provider: .anthropic)
            ]
        }
    }
}

struct AIModel: Identifiable, Codable {
    let id: String
    let name: String
    let provider: AIProvider
    
    var displayName: String {
        return name
    }
}

