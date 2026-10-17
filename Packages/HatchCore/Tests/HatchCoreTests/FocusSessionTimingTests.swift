//
//  FocusSessionTimingTests.swift
//  HatchCoreTests
//
//  Created for Hatch Milestone 3.
//

import XCTest
@testable import HatchCore

final class FocusSessionTimingTests: XCTestCase {
    func testFocusSessionRewardsSnapshot() {
        // Rates: 1 gold/min, 2 XP/min
        let r15 = RewardCalculator.reward(forFocusDurationMinutes: 15)
        XCTAssertEqual(r15.gold, 15)
        XCTAssertEqual(r15.xp, 30)

        let r25 = RewardCalculator.reward(forFocusDurationMinutes: 25)
        XCTAssertEqual(r25.gold, 25)
        XCTAssertEqual(r25.xp, 50)

        let r50 = RewardCalculator.reward(forFocusDurationMinutes: 50)
        XCTAssertEqual(r50.gold, 50)
        XCTAssertEqual(r50.xp, 100)
    }

    func testElapsedActiveSecondsWithoutPauses() {
        let t0 = Date(timeIntervalSince1970: 1776345600)
        let tNow = t0.addingTimeInterval(600) // 10 minutes later

        let elapsed = FocusSessionTiming.elapsedSeconds(
            startDate: t0,
            pausedDuration: 0,
            isPaused: false,
            pauseStartDate: nil,
            now: tNow
        )
        XCTAssertEqual(elapsed, 600)
    }

    func testElapsedActiveSecondsExcludesPastPauses() {
        let t0 = Date(timeIntervalSince1970: 1776345600)
        let tNow = t0.addingTimeInterval(600) // 10 minutes total wall time

        // 2 minutes (120s) accumulated in past pauses
        let elapsed = FocusSessionTiming.elapsedSeconds(
            startDate: t0,
            pausedDuration: 120,
            isPaused: false,
            pauseStartDate: nil,
            now: tNow
        )
        XCTAssertEqual(elapsed, 480)
    }

    func testElapsedActiveSecondsWhileCurrentlyPaused() {
        let t0 = Date(timeIntervalSince1970: 1776345600)
        let pauseStart = t0.addingTimeInterval(300) // paused at 5 minutes
        let tNow = t0.addingTimeInterval(600) // current time is at 10 minutes

        // Total wall time: 600s. Paused at 300s. Current pause duration: 300s.
        let elapsed = FocusSessionTiming.elapsedSeconds(
            startDate: t0,
            pausedDuration: 0,
            isPaused: true,
            pauseStartDate: pauseStart,
            now: tNow
        )
        XCTAssertEqual(elapsed, 300)
    }

    func testEligibilityAtExactBoundary() {
        let target: TimeInterval = 1500 // 25 minutes

        XCTAssertFalse(FocusSessionTiming.isEligibleForCompletion(
            targetDurationSeconds: target,
            elapsedSeconds: target - 1
        ))

        XCTAssertTrue(FocusSessionTiming.isEligibleForCompletion(
            targetDurationSeconds: target,
            elapsedSeconds: target
        ))

        XCTAssertTrue(FocusSessionTiming.isEligibleForCompletion(
            targetDurationSeconds: target,
            elapsedSeconds: target + 10
        ))
    }

    func testRemainingSecondsClampedAtZero() {
        let target: TimeInterval = 1500

        XCTAssertEqual(
            FocusSessionTiming.remainingSeconds(targetDurationSeconds: target, elapsedSeconds: 1000),
            500
        )
        XCTAssertEqual(
            FocusSessionTiming.remainingSeconds(targetDurationSeconds: target, elapsedSeconds: 1500),
            0
        )
        XCTAssertEqual(
            FocusSessionTiming.remainingSeconds(targetDurationSeconds: target, elapsedSeconds: 1600),
            0
        )
    }
}
