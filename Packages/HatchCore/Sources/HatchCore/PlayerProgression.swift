//
//  PlayerProgression.swift
//  HatchCore
//
//  Created for Hatch Milestone 3.
//

import Foundation

/// Mathematical logic for player levelling and XP progression.
///
/// Implements the formula from PROJECT_SPEC.md § 6.2:
/// - Level 1 starts at 0 XP.
/// - Level 1 -> 2 requires 100 XP.
/// - Each subsequent level requires 50 XP more than the preceding level's requirement:
///   xpForNextLevel(currentLevel) = 100 + (currentLevel - 1) * 50
///
/// Current level is derived purely as a function of cumulative finalized lifetime XP.
public enum PlayerProgression {
    /// Starting player level on account creation.
    public static let initialLevel: Int = 1

    /// Base XP requirement to advance from Level 1 to Level 2.
    public static let baseThresholdXP: Int64 = 100

    /// Additional XP requirement increment per subsequent level.
    public static let thresholdIncrementXP: Int64 = 50

    /// The XP required to advance from `currentLevel` to `currentLevel + 1`.
    ///
    /// Formula: `100 + (currentLevel - 1) * 50`
    /// - Parameter currentLevel: The player's current level (clamped to >= 1).
    /// - Returns: The XP delta required for the next level.
    public static func xpRequiredForNextLevel(from currentLevel: Int) -> Int64 {
        let level = max(1, currentLevel)
        return baseThresholdXP + Int64(level - 1) * thresholdIncrementXP
    }

    /// The cumulative lifetime XP required to reach the exact start of a given level.
    ///
    /// Level 1 = 0 XP
    /// Level 2 = 100 XP
    /// Level 3 = 100 + 150 = 250 XP
    /// Level 4 = 250 + 200 = 450 XP
    /// Level 5 = 450 + 250 = 700 XP
    /// - Parameter targetLevel: The level reached.
    /// - Returns: Cumulative XP threshold.
    public static func cumulativeXPRequired(forLevel targetLevel: Int) -> Int64 {
        guard targetLevel > 1 else { return 0 }
        var total: Int64 = 0
        for lvl in 1..<targetLevel {
            total += xpRequiredForNextLevel(from: lvl)
        }
        return total
    }

    /// Derives the player's current level from cumulative finalized lifetime XP.
    ///
    /// Handles boundary cases:
    /// - `level(for: threshold - 1) == previousLevel`
    /// - `level(for: threshold) == nextLevel`
    /// - `level(for: threshold + 1) == nextLevel`
    /// Also supports multiple level-ups from a single large reward in a single pass.
    /// - Parameter cumulativeXP: Total lifetime XP earned (finalized only).
    /// - Returns: Current level (minimum 1).
    public static func level(forCumulativeXP cumulativeXP: Int64) -> Int {
        guard cumulativeXP > 0 else { return initialLevel }

        var currentLevel = initialLevel
        var accumulated: Int64 = 0

        while true {
            let required = xpRequiredForNextLevel(from: currentLevel)
            if cumulativeXP < accumulated + required {
                return currentLevel
            }
            accumulated += required
            currentLevel += 1
        }
    }

    /// Detailed breakdown of progression within the player's current level.
    public struct LevelProgress: Equatable {
        public let level: Int
        public let cumulativeXP: Int64
        public let currentLevelBaseXP: Int64
        public let nextLevelBaseXP: Int64
        public let currentXPInLevel: Int64
        public let xpRequiredForNextLevel: Int64
        public let progressFraction: Double

        public init(
            level: Int,
            cumulativeXP: Int64,
            currentLevelBaseXP: Int64,
            nextLevelBaseXP: Int64,
            currentXPInLevel: Int64,
            xpRequiredForNextLevel: Int64,
            progressFraction: Double
        ) {
            self.level = level
            self.cumulativeXP = cumulativeXP
            self.currentLevelBaseXP = currentLevelBaseXP
            self.nextLevelBaseXP = nextLevelBaseXP
            self.currentXPInLevel = currentXPInLevel
            self.xpRequiredForNextLevel = xpRequiredForNextLevel
            self.progressFraction = progressFraction
        }
    }

    /// Computes full level progress metadata for display in the UI.
    /// - Parameter cumulativeXP: Total lifetime XP earned.
    /// - Returns: `LevelProgress` struct.
    public static func progress(forCumulativeXP cumulativeXP: Int64) -> LevelProgress {
        let currentLvl = level(forCumulativeXP: cumulativeXP)
        let baseXP = cumulativeXPRequired(forLevel: currentLvl)
        let nextXP = cumulativeXPRequired(forLevel: currentLvl + 1)
        let requiredDelta = nextXP - baseXP
        let inLevel = max(0, cumulativeXP - baseXP)
        let fraction = requiredDelta > 0 ? min(1.0, max(0.0, Double(inLevel) / Double(requiredDelta))) : 0.0

        return LevelProgress(
            level: currentLvl,
            cumulativeXP: cumulativeXP,
            currentLevelBaseXP: baseXP,
            nextLevelBaseXP: nextXP,
            currentXPInLevel: inLevel,
            xpRequiredForNextLevel: requiredDelta,
            progressFraction: fraction
        )
    }
}
