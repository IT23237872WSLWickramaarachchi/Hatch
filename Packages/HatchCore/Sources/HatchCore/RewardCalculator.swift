//
//  RewardCalculator.swift
//  HatchCore
//
//  Created for Hatch Milestone 2.
//

import Foundation

/// Represents the exact rewards awarded for a completed task or event.
public struct TaskReward: Equatable {
    public let gold: Int
    public let xp: Int

    public init(gold: Int, xp: Int) {
        self.gold = gold
        self.xp = xp
    }
}

/// Pure business logic for calculating task rewards.
public enum RewardCalculator {
    /// Calculates the reward for completing a task.
    ///
    /// Invariant: Important tasks must always award at least as much gold and XP as normal tasks.
    /// - Parameter isImportant: Whether the completed task was flagged as Important.
    /// - Returns: The exact `TaskReward` awarded.
    public static func reward(forTaskIsImportant isImportant: Bool) -> TaskReward {
        let normal = TaskReward(
            gold: GameBalance.Tasks.normalGold,
            xp: GameBalance.Tasks.normalXP
        )
        let important = TaskReward(
            gold: GameBalance.Tasks.importantGold,
            xp: GameBalance.Tasks.importantXP
        )

        // Enforce the invariant required by PROJECT_SPEC.md § 4.2
        assert(
            important.gold >= normal.gold && important.xp >= normal.xp,
            "Invariant violation: Important tasks must award at least as much gold and XP as normal tasks."
        )

        return isImportant ? important : normal
    }

    /// Calculates the snapshot reward for completing a focus session of the given duration in minutes.
    ///
    /// Per PROJECT_SPEC.md § 5.4:
    /// Reward per session = floor(durationMinutes × goldPerMinute) gold
    ///                    + floor(durationMinutes × xpPerMinute) XP
    /// - Parameter durationMinutes: Total planned session duration in minutes.
    /// - Returns: The exact snapshot `TaskReward`.
    public static func reward(forFocusDurationMinutes durationMinutes: Int) -> TaskReward {
        let gold = max(0, durationMinutes * GameBalance.Focus.goldPerMinute)
        let xp = max(0, durationMinutes * GameBalance.Focus.xpPerMinute)
        return TaskReward(gold: gold, xp: xp)
    }
}
