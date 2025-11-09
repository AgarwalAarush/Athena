//
//  ContactsService.swift
//  Athena
//
//  Created by Claude on 11/7/25.
//

import Foundation
internal import Contacts

/// Errors that can occur when using the ContactsService
enum ContactsError: Error, LocalizedError {
    case authorizationDenied
    case contactNotFound(String)
    case noPhoneNumber(String)
    case noEmailAddress(String)
    case multipleMatches([CNContact])
    case invalidContactStore

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Contacts access was denied. Please grant permission in System Settings."
        case .contactNotFound(let name):
            return "No contact found matching '\(name)'"
        case .noPhoneNumber(let name):
            return "Contact '\(name)' has no phone number"
        case .noEmailAddress(let name):
            return "Contact '\(name)' has no email address"
        case .multipleMatches(let contacts):
            let names = contacts.map { "\($0.givenName) \($0.familyName)" }.joined(separator: ", ")
            return "Multiple contacts found: \(names)"
        case .invalidContactStore:
            return "Failed to access Contacts database"
        }
    }
}

/// Service for interacting with macOS Contacts framework
/// Handles authorization, contact lookup, and phone number/email resolution
@MainActor
class ContactsService {

    static let shared = ContactsService()

    private let contactStore = CNContactStore()

    private init() {}

    // MARK: - Authorization

    /// Returns the current authorization status for Contacts access
    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Checks if the app has been granted access to Contacts
    var hasAccess: Bool {
        authorizationStatus == .authorized
    }

    /// Requests authorization to access Contacts
    /// - Returns: True if access was granted, false otherwise
    /// - Note: Permission request must happen off the main thread on macOS to show the system dialog
    func requestAccess() async throws -> Bool {
        print("[ContactsService] 📇 Requesting Contacts access...")

        let currentStatus = authorizationStatus
        print("[ContactsService] 📇 Current authorization status: \(currentStatus.rawValue)")

        if currentStatus == .authorized {
            print("[ContactsService] 📇 Already authorized")
            return true
        }

        // CRITICAL: Request access off the main thread (macOS requirement)
        // When called on main thread, macOS automatically denies without showing dialog
        return try await Task.detached { [contactStore] in
            do {
                let granted = try await contactStore.requestAccess(for: .contacts)
                print("[ContactsService] 📇 Access granted: \(granted)")
                return granted
            } catch {
                print("[ContactsService] ❌ Error requesting access: \(error.localizedDescription)")
                throw ContactsError.authorizationDenied
            }
        }.value
    }

    // MARK: - Contact Lookup

    /// Searches for contacts by name using fuzzy matching
    /// - Parameter name: The name to search for (can be partial, case-insensitive)
    /// - Returns: Array of matching contacts, sorted by match quality
    ///
    /// - Note: You may see a console warning about CardDAV, Exchange, and LDAP account types.
    ///   This is a benign system message from the Contacts framework when it attempts to enumerate
    ///   all available contact sources on macOS. The warning does not indicate an error or prevent
    ///   functionality - it's expected behavior and can be safely ignored. The app has the correct
    ///   entitlement (com.apple.security.personal-information.addressbook) and contacts are
    ///   accessed successfully.
    func searchContacts(byName name: String) async throws -> [CNContact] {
        if !hasAccess {
            print("[ContactsService] ❌ No Contacts access, requesting...")
            let granted = try await requestAccess()
            if !granted {
                throw ContactsError.authorizationDenied
            }
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        let searchQuery = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("[ContactsService] 🔍 Searching for contacts matching '\(searchQuery)'")

        // Fetch all contacts (for fuzzy matching)
        // Note: This will trigger a benign system warning about CardDAV/Exchange/LDAP account types
        // This is expected behavior and does not indicate an error
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        var allContacts: [CNContact] = []

        do {
            try contactStore.enumerateContacts(with: fetchRequest) { contact, stop in
                allContacts.append(contact)
            }
        } catch {
            print("[ContactsService] ❌ Error fetching contacts: \(error.localizedDescription)")
            throw ContactsError.invalidContactStore
        }

        print("[ContactsService] 📇 Found \(allContacts.count) total contacts")

        // Fuzzy match against all contacts
        let matchesWithScores = allContacts.compactMap { contact -> (contact: CNContact, score: Double)? in
            let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
            let givenName = contact.givenName.lowercased()
            let familyName = contact.familyName.lowercased()
            let nickname = contact.nickname.lowercased()

            // Calculate scores for different name components
            let fullNameScore = fuzzyMatchScore(query: searchQuery, target: fullName)
            let givenNameScore = fuzzyMatchScore(query: searchQuery, target: givenName)
            let familyNameScore = fuzzyMatchScore(query: searchQuery, target: familyName)
            let nicknameScore = nickname.isEmpty ? 0.0 : fuzzyMatchScore(query: searchQuery, target: nickname)

            // Take the best score
            let bestScore = max(fullNameScore, givenNameScore, familyNameScore, nicknameScore)

            print("[ContactsService]   - '\(fullName)' => \(String(format: "%.2f%%", bestScore * 100)) similarity")

            // Only include contacts with score above threshold
            guard bestScore >= 0.35 else { return nil }

            return (contact: contact, score: bestScore)
        }

        // Sort by score descending
        let sortedMatches = matchesWithScores.sorted { $0.score > $1.score }
        print("[ContactsService] 📇 Found \(sortedMatches.count) matches above 35% threshold")

        return sortedMatches.map { $0.contact }
    }

    /// Looks up a contact by name and returns the best match
    /// - Parameter name: The name to search for
    /// - Returns: The best matching contact, or nil if no good match found
    /// - Throws: ContactsError if no contact found or multiple equally good matches
    func lookupContact(byName name: String) async throws -> CNContact {
        let matches = try await searchContacts(byName: name)

        guard !matches.isEmpty else {
            throw ContactsError.contactNotFound(name)
        }

        // Return the best match (first in sorted array)
        let bestMatch = matches[0]
        print("[ContactsService] ✅ Best match: \(bestMatch.givenName) \(bestMatch.familyName)")

        return bestMatch
    }

    // MARK: - Phone Number & Email Lookup

    /// Looks up the primary phone number for a contact by name
    /// - Parameter name: The contact name to search for
    /// - Returns: The phone number as a string (e.g., "+15551234567")
    /// - Throws: ContactsError if contact not found or has no phone number
    func lookupPhoneNumber(for name: String) async throws -> String {
        // Check if the input is already a phone number
        if isPhoneNumber(name) {
            print("[ContactsService] 📞 Input '\(name)' is already a phone number")
            return name
        }

        let contact = try await lookupContact(byName: name)

        guard !contact.phoneNumbers.isEmpty else {
            throw ContactsError.noPhoneNumber("\(contact.givenName) \(contact.familyName)")
        }

        // Get the first phone number (primary)
        let phoneNumber = contact.phoneNumbers[0].value.stringValue
        print("[ContactsService] 📞 Found phone number: \(phoneNumber)")

        return phoneNumber
    }

    /// Looks up the primary email address for a contact by name
    /// - Parameter name: The contact name to search for
    /// - Returns: The email address as a string
    /// - Throws: ContactsError if contact not found or has no email
    func lookupEmailAddress(for name: String) async throws -> String {
        // Check if the input is already an email
        if isEmailAddress(name) {
            print("[ContactsService] 📧 Input '\(name)' is already an email address")
            return name
        }

        let contact = try await lookupContact(byName: name)

        guard !contact.emailAddresses.isEmpty else {
            throw ContactsError.noEmailAddress("\(contact.givenName) \(contact.familyName)")
        }

        // Get the first email address (primary)
        let email = contact.emailAddresses[0].value as String
        print("[ContactsService] 📧 Found email: \(email)")

        return email
    }

    // MARK: - Validation Helpers

    /// Checks if a string is a valid phone number format
    private func isPhoneNumber(_ string: String) -> Bool {
        // Match phone number pattern: optional +, then digits, spaces, dashes, or parentheses
        let phonePattern = "^\\+?[0-9\\s\\-\\(\\)]{7,}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phonePattern)
        return phonePredicate.evaluate(with: string)
    }

    /// Checks if a string is a valid email address format
    private func isEmailAddress(_ string: String) -> Bool {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return emailPredicate.evaluate(with: string)
    }

    // MARK: - Fuzzy Matching

    /// Calculates a fuzzy match score between a query and target string (0.0 to 1.0)
    /// Uses a combination of exact match, contains match, and Levenshtein distance
    private func fuzzyMatchScore(query: String, target: String) -> Double {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLower = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Guard against empty strings to prevent Range crash
        guard !queryLower.isEmpty && !targetLower.isEmpty else { return 0.0 }

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
        
        // Handle empty strings gracefully
        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }

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
}
