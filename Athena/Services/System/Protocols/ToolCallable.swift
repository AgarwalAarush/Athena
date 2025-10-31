//
//  ToolCallable.swift
//  Athena
//
//  Created by GPT-5 (Codex) on 10/30/25.
//

import Foundation

/// Protocol that describes an operation that can be exposed as a tool call.
protocol ToolCallable {
    associatedtype Parameters: Codable
    associatedtype ResultValue: Codable

    /// Identifier used by external systems (e.g., Python backend) to select the tool.
    var toolIdentifier: String { get }

    /// Developer-facing summary of what the tool does.
    var toolDescription: String { get }

    /// Execute the tool with the given parameters.
    func execute(parameters: Parameters) async throws -> ToolCallResult<ResultValue>
}
