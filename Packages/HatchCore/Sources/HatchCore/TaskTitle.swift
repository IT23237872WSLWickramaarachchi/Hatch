import Foundation
/// TaskTitle.swift — HatchCore
///
/// Public API for validating and normalising a user-supplied task title.
///
/// This file lives in HatchCore (not the iOS app) because the same rules
/// must apply whether the title arrives from a SwiftUI text field, a unit
/// test, or a future import mechanism.  Keeping the rule here means it is
/// tested once and trusted everywhere.

// MARK: - Error type

/// The reasons a proposed task title can be rejected.
///
/// Conforms to `Error` so callers can use Swift's `Result` and `throws`
/// machinery, and to `Equatable` so tests can compare errors directly.
public enum TaskTitleError: Error, Equatable {
    /// The raw input was an empty string with no characters at all.
    case empty

    /// The input contained only whitespace characters (spaces, tabs,
    /// newlines, carriage returns, etc.) and nothing meaningful.
    case whitespaceOnly
}

// MARK: - Validation

/// Validates and normalises a proposed task title.
///
/// Validation steps (in order):
/// 1. Reject an empty string immediately.
/// 2. Strip leading and trailing whitespace/newlines.
/// 3. Reject the result if it is now empty (was whitespace-only).
/// 4. Return the stripped title, preserving any internal spacing.
///
/// No arbitrary character limit is imposed.  The task spec does not require
/// one, and the persistence layer (Core Data) can store arbitrarily long
/// strings.  A limit can be added here later without touching the iOS app.
///
/// - Parameter raw: The string exactly as the user typed it.
/// - Returns: `.success(normalizedTitle)` or `.failure(TaskTitleError)`.
public func validateTaskTitle(_ raw: String) -> Result<String, TaskTitleError> {
    // Step 1: an empty string has no characters to work with at all.
    guard !raw.isEmpty else {
        return .failure(.empty)
    }

    // Step 2: strip leading and trailing Unicode whitespace, including
    // spaces, tabs (\t), newlines (\n), carriage returns (\r), and any
    // other characters that Swift's `CharacterSet.whitespacesAndNewlines`
    // covers.  We do NOT strip whitespace from the interior of the string —
    // "Buy milk" must stay "Buy milk", not "Buymilk".
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    // Step 3: if trimming removed everything, the whole input was whitespace.
    guard !trimmed.isEmpty else {
        return .failure(.whitespaceOnly)
    }

    // Step 4: the trimmed string is valid.
    return .success(trimmed)
}
