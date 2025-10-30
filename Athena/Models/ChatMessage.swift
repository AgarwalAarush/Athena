//
//  ChatMessage.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation

struct ChatMessage: Codable, Identifiable {
    var id: String = UUID().uuidString
    let role: MessageRole
    var content: String
    let timestamp: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
    
    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(MessageRole.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
}

// MARK: - Helper Extensions
extension ChatMessage {
    var isFromUser: Bool {
        role == .user
    }
    
    var isFromAssistant: Bool {
        role == .assistant
    }
}

