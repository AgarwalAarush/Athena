//
//  Provider.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case openai = "openai"
    
    var displayName: String {
        return "OpenAI"
    }
    
    var defaultModel: String {
        return "gpt-5-nano"
    }
    
    var availableModels: [AIModel] {
        return [
            AIModel(id: "gpt-5-nano", name: "GPT-5 Nano", provider: .openai)
        ]
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

