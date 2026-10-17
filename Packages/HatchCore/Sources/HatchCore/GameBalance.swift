//
//  GameBalance.swift
//  HatchCore
//
//  Created for Hatch Milestone 2, updated for Milestone 3.
//

import Foundation

/// Centralized game balance constants for Hatch.
///
/// Marked PROVISIONAL per docs/DECISIONS.md. Modifying values here
/// updates them everywhere across business logic, UI, and tests.
public enum GameBalance {
    /// Task reward balance configuration.
    public enum Tasks {
        /// Gold awarded for completing a normal task.
        public static let normalGold: Int = 10
        /// Player XP awarded for completing a normal task.
        public static let normalXP: Int = 20

        /// Gold awarded for completing an important task.
        public static let importantGold: Int = 15
        /// Player XP awarded for completing an important task.
        public static let importantXP: Int = 30
    }

    /// Undo window configuration.
    public enum Undo {
        /// The duration of the pending completion window in seconds (5 seconds).
        public static let windowDurationSeconds: TimeInterval = 5.0
    }

    /// Focus session balance configuration.
    public enum Focus {
        /// Gold awarded per minute of completed focus session.
        public static let goldPerMinute: Int = 1
        /// Player XP awarded per minute of completed focus session.
        public static let xpPerMinute: Int = 2

        /// Predefined focus session durations in minutes.
        public static let shortDurationMinutes: Int = 15
        public static let defaultDurationMinutes: Int = 25
        public static let longDurationMinutes: Int = 50
    }
}
