/// TaskTitleTests.swift — HatchCoreTests
///
/// Unit tests for `validateTaskTitle(_:)` in HatchCore.
///
/// We use XCTest because:
/// - It ships with every Swift toolchain (Swift 5.0+), including Windows
///   distributions, so `swift test` works without extra dependencies.
/// - Xcode's test runner understands XCTest natively — ⌘U runs these
///   tests on the Mac without any extra setup.
/// - swift-testing (the newer `Testing` module) requires Swift 5.10+ and
///   may not be available on older Windows toolchains.
///
/// What these tests prove:
///   The pure logic of `validateTaskTitle` — the trimming and rejection
///   rules — behaves correctly in isolation.
///
/// What these tests do NOT prove:
///   - That the iOS app correctly passes the user's text-field string to
///     this function (that is a UI/integration concern tested in Xcode).
///   - That Core Data saves or loads the validated title without data loss
///     (that is a persistence test, run on the iOS target in Xcode).

import XCTest
@testable import HatchCore

final class TaskTitleTests: XCTestCase {

    // MARK: - Rejection tests

    /// An empty string provides no title at all.
    func testEmptyStringIsRejected() {
        let result = validateTaskTitle("")
        XCTAssertEqual(result, .failure(.empty))
    }

    /// A string of only space characters has no meaningful content.
    func testSpacesOnlyIsRejected() {
        let result = validateTaskTitle("   ")
        XCTAssertEqual(result, .failure(.whitespaceOnly))
    }

    /// Tab characters are whitespace and should be treated the same way.
    func testTabsOnlyIsRejected() {
        let result = validateTaskTitle("\t\t")
        XCTAssertEqual(result, .failure(.whitespaceOnly))
    }

    /// Newline characters (Unix-style and Windows CRLF) are whitespace.
    func testNewlinesOnlyIsRejected() {
        let result = validateTaskTitle("\n\r\n")
        XCTAssertEqual(result, .failure(.whitespaceOnly))
    }

    /// A mix of whitespace characters that collectively form no real title.
    func testMixedWhitespaceOnlyIsRejected() {
        let result = validateTaskTitle("  \t \n  ")
        XCTAssertEqual(result, .failure(.whitespaceOnly))
    }

    // MARK: - Acceptance tests

    /// A plain word with no surrounding whitespace passes unchanged.
    func testValidTitleIsAccepted() {
        let result = validateTaskTitle("Read a book")
        XCTAssertEqual(result, .success("Read a book"))
    }

    /// Leading whitespace must be stripped; the rest is preserved.
    func testLeadingWhitespaceIsStripped() {
        let result = validateTaskTitle("   Buy groceries")
        XCTAssertEqual(result, .success("Buy groceries"))
    }

    /// Trailing whitespace must be stripped; the rest is preserved.
    func testTrailingWhitespaceIsStripped() {
        let result = validateTaskTitle("Submit report   ")
        XCTAssertEqual(result, .success("Submit report"))
    }

    /// Both ends have whitespace; both must be stripped.
    func testBothEndsStripped() {
        let result = validateTaskTitle("  Call dentist  ")
        XCTAssertEqual(result, .success("Call dentist"))
    }

    /// A single word with no surrounding whitespace is a valid minimal title.
    func testSingleWordIsAccepted() {
        let result = validateTaskTitle("Exercise")
        XCTAssertEqual(result, .success("Exercise"))
    }

    /// Internal spaces between words must be preserved exactly.
    /// "Buy  milk" (two spaces) should not become "Buy milk" (one space).
    func testInternalSpacingIsPreserved() {
        let result = validateTaskTitle("Buy  milk")   // two spaces intentional
        XCTAssertEqual(result, .success("Buy  milk")) // two spaces preserved
    }

    /// Leading/trailing whitespace stripped, internal spacing untouched.
    func testStripsEndsButPreservesInternalSpacing() {
        let result = validateTaskTitle("  Do  the  thing  ")
        XCTAssertEqual(result, .success("Do  the  thing"))
    }

    /// Newlines at the start and end should be stripped just like spaces.
    func testLeadingAndTrailingNewlinesStripped() {
        let result = validateTaskTitle("\nPlan the week\n")
        XCTAssertEqual(result, .success("Plan the week"))
    }
}
