//
//  PlayerProgressionTests.swift
//  HatchCoreTests
//
//  Created for Hatch Milestone 3.
//

import XCTest
@testable import HatchCore

final class PlayerProgressionTests: XCTestCase {
    func testLevel1AtZeroXP() {
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: 0), 1)
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: -10), 1, "Negative XP must return Level 1")
    }

    func testCumulativeThresholds() {
        // Level 1 starts at 0
        XCTAssertEqual(PlayerProgression.cumulativeXPRequired(forLevel: 1), 0)
        // Level 2 requires 100 XP
        XCTAssertEqual(PlayerProgression.cumulativeXPRequired(forLevel: 2), 100)
        // Level 3 requires 100 + 150 = 250 XP
        XCTAssertEqual(PlayerProgression.cumulativeXPRequired(forLevel: 3), 250)
        // Level 4 requires 250 + 200 = 450 XP
        XCTAssertEqual(PlayerProgression.cumulativeXPRequired(forLevel: 4), 450)
        // Level 5 requires 450 + 250 = 700 XP
        XCTAssertEqual(PlayerProgression.cumulativeXPRequired(forLevel: 5), 700)
    }

    func testLevel1To2Boundary() {
        let threshold = PlayerProgression.cumulativeXPRequired(forLevel: 2) // 100
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold - 1), 1)
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold), 2)
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold + 1), 2)
    }

    func testLevel2To3Boundary() {
        let threshold = PlayerProgression.cumulativeXPRequired(forLevel: 3) // 250
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold - 1), 2)
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold), 3)
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold + 1), 3)
    }

    func testLevel3To4Boundary() {
        let threshold = PlayerProgression.cumulativeXPRequired(forLevel: 4) // 450
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold - 1), 3)
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold), 4)
        XCTAssertEqual(PlayerProgression.level(forCumulativeXP: threshold + 1), 4)
    }

    func testMultiLevelJumpFromSingleReward() {
        // Gaining 500 XP at once jumps straight from Level 1 to Level 4 (since 450 <= 500 < 700)
        let newLevel = PlayerProgression.level(forCumulativeXP: 500)
        XCTAssertEqual(newLevel, 4)
    }

    func testProgressMetadataWithinLevel() {
        // At 130 XP:
        // - Level is 2 (base 100 XP)
        // - Next level is 3 (base 250 XP)
        // - Required delta is 150 XP
        // - In-level XP is 30
        // - Progress fraction is 30 / 150 = 0.20
        let progress = PlayerProgression.progress(forCumulativeXP: 130)
        XCTAssertEqual(progress.level, 2)
        XCTAssertEqual(progress.cumulativeXP, 130)
        XCTAssertEqual(progress.currentLevelBaseXP, 100)
        XCTAssertEqual(progress.nextLevelBaseXP, 250)
        XCTAssertEqual(progress.currentXPInLevel, 30)
        XCTAssertEqual(progress.xpRequiredForNextLevel, 150)
        XCTAssertEqual(progress.progressFraction, 0.20, accuracy: 0.0001)
    }
}
