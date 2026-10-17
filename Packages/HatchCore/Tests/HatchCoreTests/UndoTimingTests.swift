//
//  UndoTimingTests.swift
//  HatchCoreTests
//
//  Created for Hatch Milestone 2.
//

import XCTest
@testable import HatchCore

final class UndoTimingTests: XCTestCase {
    private let window: TimeInterval = 5.0
    private let baseDate = Date(timeIntervalSince1970: 1776345600)

    func testCanUndoAtExactCompletionMoment() {
        let now = baseDate
        XCTAssertTrue(
            UndoTiming.canUndo(completedAt: baseDate, now: now, window: window),
            "Can undo immediately upon completion"
        )
    }

    func testCanUndoWithinWindow() {
        let midway = baseDate.addingTimeInterval(2.5)
        XCTAssertTrue(
            UndoTiming.canUndo(completedAt: baseDate, now: midway, window: window),
            "Can undo halfway through the window"
        )

        let justBeforeExpiry = baseDate.addingTimeInterval(4.999)
        XCTAssertTrue(
            UndoTiming.canUndo(completedAt: baseDate, now: justBeforeExpiry, window: window),
            "Can undo just before the 5.0s boundary"
        )
    }

    func testCannotUndoAtOrPastExactExpiryBoundary() {
        let exactlyAtExpiry = baseDate.addingTimeInterval(5.0)
        XCTAssertFalse(
            UndoTiming.canUndo(completedAt: baseDate, now: exactlyAtExpiry, window: window),
            "Cannot undo at exactly 5.0s (boundary is exclusive < window)"
        )

        let pastExpiry = baseDate.addingTimeInterval(5.001)
        XCTAssertFalse(
            UndoTiming.canUndo(completedAt: baseDate, now: pastExpiry, window: window),
            "Cannot undo after 5.0s window"
        )
    }

    func testCannotUndoIfNowIsBeforeCompletedAt() {
        let clockSkew = baseDate.addingTimeInterval(-1.0)
        XCTAssertFalse(
            UndoTiming.canUndo(completedAt: baseDate, now: clockSkew, window: window),
            "Negative elapsed time cannot be undone"
        )
    }

    func testDeadlineCalculation() {
        let deadline = UndoTiming.deadline(from: baseDate, window: window)
        XCTAssertEqual(
            deadline.timeIntervalSince(baseDate),
            5.0,
            "Deadline is exactly completedAt + 5.0 seconds"
        )
    }

    func testFinalizationEligibility() {
        let beforeExpiry = baseDate.addingTimeInterval(4.9)
        XCTAssertFalse(
            UndoTiming.isEligibleForFinalization(completedAt: baseDate, now: beforeExpiry, window: window),
            "Not eligible for finalization before 5 seconds have elapsed"
        )

        let exactlyAtExpiry = baseDate.addingTimeInterval(5.0)
        XCTAssertTrue(
            UndoTiming.isEligibleForFinalization(completedAt: baseDate, now: exactlyAtExpiry, window: window),
            "Eligible for finalization at exactly 5 seconds"
        )

        let afterExpiry = baseDate.addingTimeInterval(6.0)
        XCTAssertTrue(
            UndoTiming.isEligibleForFinalization(completedAt: baseDate, now: afterExpiry, window: window),
            "Eligible for finalization after 5 seconds"
        )
    }
}
