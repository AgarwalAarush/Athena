//
//  FuzzyStringMatcher.swift
//  Athena
//
//  Fuzzy string matching utility using Levenshtein distance
//

import Foundation

struct FuzzyStringMatcher {
    
    /// Calculate the Levenshtein distance between two strings
    /// - Parameters:
    ///   - source: First string
    ///   - target: Second string
    /// - Returns: The minimum number of edits (insertions, deletions, substitutions) needed to transform source into target
    static func levenshteinDistance(_ source: String, _ target: String) -> Int {
        let sourceArray = Array(source.lowercased())
        let targetArray = Array(target.lowercased())
        
        let sourceLen = sourceArray.count
        let targetLen = targetArray.count
        
        // Handle empty strings
        if sourceLen == 0 { return targetLen }
        if targetLen == 0 { return sourceLen }
        
        // Create a matrix to store distances
        var matrix = Array(repeating: Array(repeating: 0, count: targetLen + 1), count: sourceLen + 1)
        
        // Initialize first row and column
        for i in 0...sourceLen {
            matrix[i][0] = i
        }
        for j in 0...targetLen {
            matrix[0][j] = j
        }
        
        // Fill in the rest of the matrix
        for i in 1...sourceLen {
            for j in 1...targetLen {
                let cost = sourceArray[i - 1] == targetArray[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[sourceLen][targetLen]
    }
    
    /// Calculate similarity score between two strings (0.0 to 1.0)
    /// - Parameters:
    ///   - source: First string
    ///   - target: Second string
    /// - Returns: Similarity score where 1.0 is identical and 0.0 is completely different
    static func similarityScore(_ source: String, _ target: String) -> Double {
        let distance = levenshteinDistance(source, target)
        let maxLength = max(source.count, target.count)
        
        guard maxLength > 0 else { return 1.0 } // Both empty strings are identical
        
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        return max(0.0, similarity) // Ensure non-negative
    }
    
    /// Check if source string fuzzy matches target with a minimum threshold
    /// - Parameters:
    ///   - source: String to match
    ///   - target: Target string to match against
    ///   - threshold: Minimum similarity score (0.0 to 1.0) required for a match
    /// - Returns: True if similarity score meets or exceeds threshold
    static func fuzzyMatch(_ source: String, target: String, threshold: Double) -> Bool {
        let score = similarityScore(source, target)
        return score >= threshold
    }
}

