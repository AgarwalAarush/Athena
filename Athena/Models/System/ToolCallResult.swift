//
//  ToolCallResult.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation

/// Standard response payload for tool-callable services
struct ToolCallResult<Value: Codable>: Codable {
    let success: Bool
    let result: Value?
    let error: String?
    let metadata: [String: String]?

    init(
        success: Bool,
        result: Value? = nil,
        error: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.success = success
        self.result = result
        self.error = error
        self.metadata = metadata
    }
}
