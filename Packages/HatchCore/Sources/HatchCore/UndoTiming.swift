//
//  UndoTiming.swift
//  HatchCore
//
//  Created for Hatch Milestone 2.
//

import Foundation

/// Pure business rules for evaluating undo window validity and deadline calculations.
public enum UndoTiming {
    /// Determines whether a completion event is still eligible to be undone.
    ///
    /// - Parameters:
    ///   - completedAt: The timestamp when the task was initially marked completed.
    ///   - now: The current reference timestamp.
    ///   - window: The duration of the undo window (defaults to `GameBalance.Undo.windowDurationSeconds`).
    /// - Returns: `true` if `0 <= (now - completedAt) < window`; otherwise `false`.
    public static func canUndo(
        completedAt: Date,
        now: Date,
        window: TimeInterval = GameBalance.Undo.windowDurationSeconds
    ) -> Bool {
        let elapsed = now.timeIntervalSince(completedAt)
        return elapsed >= 0 && elapsed < window
    }

    /// Computes the exact wall-clock deadline when the undo window expires.
    ///
    /// - Parameters:
    ///   - completedAt: The timestamp when completion began.
    ///   - window: The duration of the window (defaults to `GameBalance.Undo.windowDurationSeconds`).
    /// - Returns: `completedAt + window`.
    public static func deadline(
        from completedAt: Date,
        window: TimeInterval = GameBalance.Undo.windowDurationSeconds
    ) -> Date {
        completedAt.addingTimeInterval(window)
    }

    /// Determines whether a pending completion has expired and is eligible for permanent finalization.
    ///
    /// - Parameters:
    ///   - completedAt: The timestamp when completion began.
    ///   - now: The current reference timestamp.
    ///   - window: The duration of the window (defaults to `GameBalance.Undo.windowDurationSeconds`).
    /// - Returns: `true` if `now >= completedAt + window`.
    public static func isEligibleForFinalization(
        completedAt: Date,
        now: Date,
        window: TimeInterval = GameBalance.Undo.windowDurationSeconds
    ) -> Bool {
        let elapsed = now.timeIntervalSince(completedAt)
        return elapsed >= window
    }
}
