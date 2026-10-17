//
//  FocusSessionTiming.swift
//  HatchCore
//
//  Created for Hatch Milestone 3.
//

import Foundation

/// Pure logic for focus session timing, duration calculation, and completion eligibility.
///
/// Adheres to PROJECT_SPEC.md § 5:
/// - Timers compute elapsed time from wall-clock difference minus paused intervals.
/// - Does not rely on timer tick counts.
/// - Cancellation earns no rewards.
public enum FocusSessionTiming {
    /// Computes total elapsed active focus time in seconds.
    /// - Parameters:
    ///   - startDate: When the session began.
    ///   - pausedDuration: Total accumulated duration of past paused periods in seconds.
    ///   - isPaused: Whether the session is currently in a paused state.
    ///   - pauseStartDate: When the current paused period began (if `isPaused` is true).
    ///   - now: Reference timestamp.
    /// - Returns: Total elapsed active seconds (excluding pause intervals).
    public static func elapsedSeconds(
        startDate: Date,
        pausedDuration: TimeInterval,
        isPaused: Bool,
        pauseStartDate: Date?,
        now: Date
    ) -> TimeInterval {
        guard now >= startDate else { return 0 }
        let totalWallTime = now.timeIntervalSince(startDate)

        var totalPause = pausedDuration
        if isPaused, let pauseStart = pauseStartDate, now >= pauseStart {
            totalPause += now.timeIntervalSince(pauseStart)
        }

        return max(0, totalWallTime - totalPause)
    }

    /// Computes remaining seconds until target completion.
    /// - Parameters:
    ///   - targetDurationSeconds: The full planned session duration in seconds.
    ///   - elapsedSeconds: Total active elapsed seconds.
    /// - Returns: Remaining seconds (clamped to >= 0).
    public static func remainingSeconds(
        targetDurationSeconds: TimeInterval,
        elapsedSeconds: TimeInterval
    ) -> TimeInterval {
        max(0, targetDurationSeconds - elapsedSeconds)
    }

    /// Determines whether the session has reached or passed its target duration.
    /// - Parameters:
    ///   - targetDurationSeconds: The planned session duration in seconds.
    ///   - elapsedSeconds: Total active elapsed seconds.
    /// - Returns: `true` if eligible for completion.
    public static func isEligibleForCompletion(
        targetDurationSeconds: TimeInterval,
        elapsedSeconds: TimeInterval
    ) -> Bool {
        elapsedSeconds >= targetDurationSeconds
    }
}
