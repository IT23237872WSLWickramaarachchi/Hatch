//
//  PersistenceIntegrationTests.swift
//  HatchTests
//
//  Created for Hatch Milestone 1.
//

import XCTest
import CoreData
@testable import Hatch

/// Integration tests for verifying disk-backed Core Data persistence.
///
/// Purpose:
/// - Verifies that data written to an SQLite store file persists across
///   distinct persistent container lifetimes (simulating an app restart).
/// - Ensures tests run in an isolated temporary disk folder and clean up completely.
final class PersistenceIntegrationTests: XCTestCase {
    private var temporaryDirectoryURL: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create an isolated temporary folder for each test execution
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HatchPersistenceTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
        storeURL = temporaryDirectoryURL.appendingPathComponent("HatchTestStore.sqlite")
    }

    override func tearDownWithError() throws {
        // Clean up test database files
        if let storeURL = storeURL, FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.removeItem(at: storeURL)
        }
        if let temporaryDirectoryURL = temporaryDirectoryURL, FileManager.default.fileExists(atPath: temporaryDirectoryURL.path) {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        try super.tearDownWithError()
    }

    private func makeContainer(at url: URL) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "HatchModel")
        let description = NSPersistentStoreDescription(url: url)
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let error = loadError {
            throw error
        }
        return container
    }

    func testTaskPersistsAcrossContainerInstances() throws {
        let expectedId = UUID()
        let expectedTitle = "Read chapter 1"
        let expectedDate = Date(timeIntervalSince1970: 1776345600) // Fixed deterministic timestamp

        // Session 1: Create container, insert task, and commit to disk
        do {
            let container1 = try makeContainer(at: storeURL)
            let context1 = container1.viewContext

            let task = TaskEntity(context: context1)
            task.id = expectedId
            task.title = expectedTitle
            task.createdAt = expectedDate

            try context1.save()
            // container1 goes out of scope and is deallocated, closing this stack
        }

        // Session 2: Create a completely new container instance pointing to the same disk file
        do {
            let container2 = try makeContainer(at: storeURL)
            let context2 = container2.viewContext

            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            let fetchedTasks = try context2.fetch(request)

            // Verify the entity was preserved on disk and restored
            XCTAssertEqual(fetchedTasks.count, 1, "Expected exactly 1 task persisted on disk")
            guard let savedTask = fetchedTasks.first else {
                XCTFail("Persisted task could not be retrieved from disk")
                return
            }

            XCTAssertEqual(savedTask.id, expectedId)
            XCTAssertEqual(savedTask.title, expectedTitle)
            XCTAssertEqual(savedTask.createdAt, expectedDate)
        }
    }
}
