//
//  GameBalance.swift
//  HatchCore
//
//  Created for Hatch Milestone 2.
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
}
