//
//  RewardCalculatorTests.swift
//  HatchCoreTests
//
//  Created for Hatch Milestone 2.
//

import XCTest
@testable import HatchCore

final class RewardCalculatorTests: XCTestCase {
    func testNormalTaskAwardsSpecifiedRewards() {
        let reward = RewardCalculator.reward(forTaskIsImportant: false)
        XCTAssertEqual(reward.gold, 10, "Normal task must award 10 gold per specification")
        XCTAssertEqual(reward.xp, 20, "Normal task must award 20 XP per specification")
    }

    func testImportantTaskAwardsSpecifiedRewards() {
        let reward = RewardCalculator.reward(forTaskIsImportant: true)
        XCTAssertEqual(reward.gold, 15, "Important task must award 15 gold per specification")
        XCTAssertEqual(reward.xp, 30, "Important task must award 30 XP per specification")
    }

    func testImportantTaskAlwaysAwardsAtLeastAsMuchAsNormal() {
        let normal = RewardCalculator.reward(forTaskIsImportant: false)
        let important = RewardCalculator.reward(forTaskIsImportant: true)

        XCTAssertGreaterThanOrEqual(important.gold, normal.gold, "Invariant: Important gold >= normal gold")
        XCTAssertGreaterThanOrEqual(important.xp, normal.xp, "Invariant: Important XP >= normal XP")
    }
}
