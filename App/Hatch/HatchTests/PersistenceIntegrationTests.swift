//
//  PersistenceIntegrationTests.swift
//  HatchTests
//
//  Created for Hatch Milestones 1 and 2.
//

import XCTest
import CoreData
@testable import Hatch
@testable import HatchCore

/// Integration tests for verifying Core Data persistence, lightweight migration,
/// atomic task completion, 5-second undo window, and relaunch reconciliation.
final class PersistenceIntegrationTests: XCTestCase {
    private var temporaryDirectoryURL: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HatchPersistenceTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
        storeURL = temporaryDirectoryURL.appendingPathComponent("HatchTestStore.sqlite")
    }

    override func tearDownWithError() throws {
        if let storeURL = storeURL, FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.removeItem(at: storeURL)
        }
        if let temporaryDirectoryURL = temporaryDirectoryURL, FileManager.default.fileExists(atPath: temporaryDirectoryURL.path) {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeContainer(at url: URL, model: NSManagedObjectModel? = nil) throws -> NSPersistentContainer {
        let container: NSPersistentContainer
        if let model = model {
            container = NSPersistentContainer(name: "HatchModel", managedObjectModel: model)
        } else {
            container = NSPersistentContainer(name: "HatchModel")
        }

        let description = NSPersistentStoreDescription(url: url)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
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

    private func findMomdURL() -> URL? {
        // Find HatchModel.momd in main bundle or framework bundles
        if let url = Bundle.main.url(forResource: "HatchModel", withExtension: "momd") {
            return url
        }
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "HatchModel", withExtension: "momd") {
                return url
            }
        }
        return nil
    }

    // MARK: - Tests

    func testTaskPersistsAcrossContainerInstances() throws {
        let expectedId = UUID()
        let expectedTitle = "Read chapter 1"
        let expectedDate = Date(timeIntervalSince1970: 1776345600)

        // Session 1: Create container, insert task, and save
        do {
            let container1 = try makeContainer(at: storeURL)
            let context1 = container1.viewContext

            let task = TaskEntity(context: context1)
            task.id = expectedId
            task.title = expectedTitle
            task.createdAt = expectedDate

            try context1.save()
        }

        // Session 2: Open completely new container instance pointing to the same disk file
        do {
            let container2 = try makeContainer(at: storeURL)
            let context2 = container2.viewContext

            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            let fetchedTasks = try context2.fetch(request)

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

    func testExistingMilestone1StoreMigratesToV2AndPreservesRecords() throws {
        guard let momdURL = findMomdURL() else {
            XCTFail("Could not locate HatchModel.momd bundle")
            return
        }

        let v1URL = momdURL.appendingPathComponent("HatchModel.mom")
        guard let v1Model = NSManagedObjectModel(contentsOf: v1URL) else {
            XCTFail("Could not load original V1 model")
            return
        }

        let originalId = UUID()
        let originalTitle = "Milestone 1 Surviving Task"
        let originalDate = Date(timeIntervalSince1970: 1776345000)

        // Step 1: Populate an SQLite database using ONLY the V1 model schema
        do {
            let v1Container = try makeContainer(at: storeURL, model: v1Model)
            let v1Context = v1Container.viewContext

            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskEntity", into: v1Context)
            task.setValue(originalId, forKey: "id")
            task.setValue(originalTitle, forKey: "title")
            task.setValue(originalDate, forKey: "createdAt")

            try v1Context.save()
        }

        // Step 2: Open that exact SQLite file using the current V2 model with automatic lightweight migration
        do {
            let v2Container = try makeContainer(at: storeURL) // Loads current V2 model
            let v2Context = v2Container.viewContext

            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            let migratedTasks = try v2Context.fetch(request)

            XCTAssertEqual(migratedTasks.count, 1, "Expected original task to survive V1 -> V2 migration")
            let task = migratedTasks.first!
            XCTAssertEqual(task.id, originalId)
            XCTAssertEqual(task.title, originalTitle)
            XCTAssertEqual(task.createdAt, originalDate)

            // Verify default values applied cleanly to migrated entity
            XCTAssertFalse(task.isCompleted, "Migrated task should have isCompleted default to false")
            XCTAssertFalse(task.isImportant, "Migrated task should have isImportant default to false")
            XCTAssertFalse(task.isFinalized, "Migrated task should have isFinalized default to false")
            XCTAssertEqual(task.awardedGold, 0)
            XCTAssertEqual(task.awardedXP, 0)

            // Verify PlayerEntity can be created and persisted in the migrated database
            let controller = PersistenceController.shared
            let player = try controller.getOrCreatePlayer(in: v2Context)
            XCTAssertEqual(player.finalizedGold, 0)
            XCTAssertEqual(player.finalizedXP, 0)
        }
    }

    @MainActor
    func testCompletingTaskAwardsExactlyOnceAndRepeatedTapsAreIdempotent() throws {
        let container = try makeContainer(at: storeURL)
        let context = container.viewContext
        let controller = PersistenceController.shared

        // Set up player and normal task
        let player = try controller.getOrCreatePlayer(in: context)
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Normal Task"
        task.isImportant = false
        task.createdAt = Date()
        try context.save()

        let t0 = Date(timeIntervalSince1970: 1776345600)

        // First completion tap
        try controller.completeTask(task, now: t0)

        XCTAssertTrue(task.isCompleted)
        XCTAssertFalse(task.isFinalized)
        XCTAssertEqual(task.awardedGold, 10, "Normal task awards 10 gold")
        XCTAssertEqual(task.awardedXP, 20, "Normal task awards 20 XP")
        XCTAssertEqual(player.pendingGold, 10)
        XCTAssertEqual(player.pendingXP, 20)
        XCTAssertEqual(player.finalizedGold, 0, "Rewards must remain pending and unspendable")
        XCTAssertEqual(player.finalizedXP, 0)

        // Second completion tap (simulating rapid tapping)
        try controller.completeTask(task, now: t0.addingTimeInterval(1.0))

        // Balances must remain strictly unchanged
        XCTAssertEqual(player.pendingGold, 10, "Duplicate tap must not award duplicate rewards")
        XCTAssertEqual(player.pendingXP, 20)
    }

    @MainActor
    func testUndoWithinWindowRestoresTaskAndDeductsPendingBalances() throws {
        let container = try makeContainer(at: storeURL)
        let context = container.viewContext
        let controller = PersistenceController.shared

        let player = try controller.getOrCreatePlayer(in: context)
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Important Task"
        task.isImportant = true
        task.createdAt = Date()
        try context.save()

        let t0 = Date(timeIntervalSince1970: 1776345600)
        try controller.completeTask(task, now: t0)

        XCTAssertEqual(player.pendingGold, 15, "Important task awards 15 gold")
        XCTAssertEqual(player.pendingXP, 30, "Important task awards 30 XP")

        // Undo within 5-second window (at t0 + 2.5s)
        let undoSuccess = try controller.undoTaskCompletion(task, now: t0.addingTimeInterval(2.5))
        XCTAssertTrue(undoSuccess, "Undo must succeed within the 5-second window")

        XCTAssertFalse(task.isCompleted, "Task must reset to active")
        XCTAssertNil(task.completedAt)
        XCTAssertNil(task.undoDeadline)
        XCTAssertEqual(task.awardedGold, 0)
        XCTAssertEqual(task.awardedXP, 0)
        XCTAssertEqual(player.pendingGold, 0, "Pending gold must be completely rolled back")
        XCTAssertEqual(player.pendingXP, 0, "Pending XP must be completely rolled back")
    }

    @MainActor
    func testUndoAtOrAfterExpiryFollowsSpecifiedBoundaryAndFinalizesInstead() throws {
        let container = try makeContainer(at: storeURL)
        let context = container.viewContext
        let controller = PersistenceController.shared

        let player = try controller.getOrCreatePlayer(in: context)
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Normal Task"
        task.isImportant = false
        task.createdAt = Date()
        try context.save()

        let t0 = Date(timeIntervalSince1970: 1776345600)
        try controller.completeTask(task, now: t0)

        // Attempt undo at exactly 5.0s (boundary: elapsed >= window means expired)
        let undoAtExpiry = try controller.undoTaskCompletion(task, now: t0.addingTimeInterval(5.0))
        XCTAssertFalse(undoAtExpiry, "Undo must be rejected at or after 5.0 seconds")

        // Task must be finalized instead and rewards transferred to finalized balances
        XCTAssertTrue(task.isCompleted)
        XCTAssertTrue(task.isFinalized)
        XCTAssertEqual(player.pendingGold, 0)
        XCTAssertEqual(player.pendingXP, 0)
        XCTAssertEqual(player.finalizedGold, 10, "Finalized gold must be spendable")
        XCTAssertEqual(player.finalizedXP, 20)
    }

    @MainActor
    func testCompletionAndBalancesSurviveReopeningStore() throws {
        let expectedId = UUID()
        let t0 = Date(timeIntervalSince1970: 1776345600)

        // Session 1: Complete important task and save to disk
        do {
            let container1 = try makeContainer(at: storeURL)
            let context1 = container1.viewContext
            let controller = PersistenceController.shared

            let task = TaskEntity(context: context1)
            task.id = expectedId
            task.title = "Important Task Across Reopen"
            task.isImportant = true
            task.createdAt = t0
            try context1.save()

            let player = try controller.getOrCreatePlayer(in: context1)
            task.isCompleted = true
            task.completedAt = t0
            task.undoDeadline = t0.addingTimeInterval(5.0)
            task.awardedGold = 15
            task.awardedXP = 30
            task.isFinalized = false
            player.pendingGold = 15
            player.pendingXP = 30
            try context1.save()
        }

        // Session 2: Open second container on disk
        do {
            let container2 = try makeContainer(at: storeURL)
            let context2 = container2.viewContext
            let controller = PersistenceController.shared

            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            let tasks = try context2.fetch(request)
            XCTAssertEqual(tasks.count, 1)

            let task = tasks.first!
            XCTAssertTrue(task.isCompleted)
            XCTAssertTrue(task.isImportant)
            XCTAssertEqual(task.awardedGold, 15)
            XCTAssertEqual(task.awardedXP, 30)
            XCTAssertEqual(task.undoDeadline, t0.addingTimeInterval(5.0))

            let player = try controller.getOrCreatePlayer(in: context2)
            XCTAssertEqual(player.pendingGold, 15)
            XCTAssertEqual(player.pendingXP, 30)
        }
    }

    @MainActor
    func testReconciliationFinalizesExpiredTasksOnRelaunch() throws {
        let container = try makeContainer(at: storeURL)
        let context = container.viewContext
        let controller = PersistenceController.shared

        let player = try controller.getOrCreatePlayer(in: context)
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Task Expired During App Suspension"
        task.isImportant = false
        task.createdAt = Date()
        try context.save()

        let t0 = Date(timeIntervalSince1970: 1776345600)
        try controller.completeTask(task, now: t0)

        XCTAssertEqual(player.pendingGold, 10)
        XCTAssertEqual(player.finalizedGold, 0)

        // Simulate returning to foreground 10 seconds later
        let t10 = t0.addingTimeInterval(10.0)
        try controller.reconcilePendingTasks(asOf: t10, context: context)

        XCTAssertTrue(task.isFinalized, "Task must be marked finalized after reconciliation")
        XCTAssertEqual(player.pendingGold, 0, "Pending gold transferred")
        XCTAssertEqual(player.finalizedGold, 10, "Finalized gold credited")
        XCTAssertEqual(player.finalizedXP, 20, "Finalized XP credited")
    }

    @MainActor
    func testSaveFailureDuringRewardOperationRollsBackStateAndPreventsRewardDuplication() throws {
        let container = try makeContainer(at: storeURL)
        let controller = PersistenceController.shared

        let failingContext = FailingSaveContext(concurrencyType: .mainQueueConcurrencyType)
        failingContext.persistentStoreCoordinator = container.persistentStoreCoordinator

        // 1. Initial setup: create and persist player and task successfully
        failingContext.shouldFailSave = false
        let player = try controller.getOrCreatePlayer(in: failingContext)
        let task = TaskEntity(context: failingContext)
        task.id = UUID()
        task.title = "Save Failure Integration Test"
        task.isImportant = false
        task.createdAt = Date(timeIntervalSince1970: 1776345600)
        try failingContext.save()

        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(task.awardedGold, 0)
        XCTAssertEqual(task.awardedXP, 0)
        XCTAssertEqual(player.pendingGold, 0)
        XCTAssertEqual(player.pendingXP, 0)
        XCTAssertEqual(player.finalizedGold, 0)
        XCTAssertEqual(player.finalizedXP, 0)
        XCTAssertFalse(failingContext.hasChanges)

        // 2. Trigger save failure during completion
        failingContext.shouldFailSave = true
        let t0 = Date(timeIntervalSince1970: 1776345600)

        XCTAssertThrowsError(try controller.completeTask(task, now: t0, context: failingContext)) { error in
            XCTAssertEqual(error as? FailingSaveContext.SimulatedError, .simulatedDiskFailure)
        }

        // 3. Verify in-memory state is restored consistently
        XCTAssertFalse(task.isCompleted, "In-memory task must revert isCompleted to false after save failure")
        XCTAssertNil(task.completedAt, "In-memory task must clear completedAt after save failure")
        XCTAssertNil(task.undoDeadline, "In-memory task must clear undoDeadline after save failure")
        XCTAssertEqual(task.awardedGold, 0, "In-memory task awardedGold must revert to 0")
        XCTAssertEqual(task.awardedXP, 0, "In-memory task awardedXP must revert to 0")
        XCTAssertEqual(player.pendingGold, 0, "In-memory player pendingGold must revert to 0")
        XCTAssertEqual(player.pendingXP, 0, "In-memory player pendingXP must revert to 0")
        XCTAssertEqual(player.finalizedGold, 0, "In-memory player finalizedGold must remain 0")
        XCTAssertEqual(player.finalizedXP, 0, "In-memory player finalizedXP must remain 0")
        XCTAssertFalse(failingContext.hasChanges, "Context must have no uncommitted changes after rollback")

        // 4. Verify disk store: no partial completion or balance changes persist
        let verificationContext = container.newBackgroundContext()
        let diskTasks = try verificationContext.fetch(TaskEntity.fetchRequest())
        XCTAssertEqual(diskTasks.count, 1)
        let diskTask = diskTasks.first!
        let diskPlayer = try controller.getOrCreatePlayer(in: verificationContext)

        XCTAssertFalse(diskTask.isCompleted, "Persisted task on disk must remain uncompleted")
        XCTAssertNil(diskTask.completedAt)
        XCTAssertNil(diskTask.undoDeadline)
        XCTAssertEqual(diskTask.awardedGold, 0)
        XCTAssertEqual(diskTask.awardedXP, 0)
        XCTAssertEqual(diskPlayer.pendingGold, 0, "Persisted player pendingGold must remain 0")
        XCTAssertEqual(diskPlayer.pendingXP, 0, "Persisted player pendingXP must remain 0")
        XCTAssertEqual(diskPlayer.finalizedGold, 0)
        XCTAssertEqual(diskPlayer.finalizedXP, 0)

        // 5. Retrying the operation must succeed and NOT duplicate rewards
        failingContext.shouldFailSave = false
        try controller.completeTask(task, now: t0, context: failingContext)

        XCTAssertTrue(task.isCompleted, "Task must complete on retry")
        XCTAssertEqual(task.awardedGold, 10, "Normal task must award exactly 10 gold")
        XCTAssertEqual(task.awardedXP, 20, "Normal task must award exactly 20 XP")
        XCTAssertEqual(player.pendingGold, 10, "Pending gold must be exactly 10, not duplicated to 20")
        XCTAssertEqual(player.pendingXP, 20, "Pending XP must be exactly 20, not duplicated to 40")
        XCTAssertEqual(player.finalizedGold, 0, "Rewards must remain pending until undo window expires")
        XCTAssertEqual(player.finalizedXP, 0)

        // Verify disk after retry
        let postRetryContext = container.newBackgroundContext()
        let retriedDiskTask = try postRetryContext.fetch(TaskEntity.fetchRequest()).first!
        let retriedDiskPlayer = try controller.getOrCreatePlayer(in: postRetryContext)
        XCTAssertTrue(retriedDiskTask.isCompleted)
        XCTAssertEqual(retriedDiskTask.awardedGold, 10)
        XCTAssertEqual(retriedDiskPlayer.pendingGold, 10)
        XCTAssertEqual(retriedDiskPlayer.pendingXP, 20)
    }

    // MARK: - Milestone 3: Focus Sessions & Progression Tests

    func testExistingV2StoreMigratesToV3AndPreservesRecords() throws {
        guard let momdURL = findMomdURL() else {
            XCTFail("Could not locate HatchModel.momd bundle")
            return
        }

        let v2URL = momdURL.appendingPathComponent("HatchModelV2.mom")
        guard let v2Model = NSManagedObjectModel(contentsOf: v2URL) else {
            XCTFail("Could not load V2 model")
            return
        }

        let originalTaskId = UUID()
        let t0 = Date(timeIntervalSince1970: 1776345600)

        // Step 1: Populate SQLite store using V2 model
        do {
            let v2Container = try makeContainer(at: storeURL, model: v2Model)
            let v2Context = v2Container.viewContext

            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskEntity", into: v2Context)
            task.setValue(originalTaskId, forKey: "id")
            task.setValue("V2 Task to Migrate", forKey: "title")
            task.setValue(t0, forKey: "createdAt")
            task.setValue(true, forKey: "isImportant")
            task.setValue(true, forKey: "isCompleted")
            task.setValue(false, forKey: "isFinalized")
            task.setValue(t0, forKey: "completedAt")
            task.setValue(t0.addingTimeInterval(5.0), forKey: "undoDeadline")
            task.setValue(Int32(15), forKey: "awardedGold")
            task.setValue(Int32(30), forKey: "awardedXP")

            let player = NSEntityDescription.insertNewObject(forEntityName: "PlayerEntity", into: v2Context)
            player.setValue(UUID(), forKey: "id")
            player.setValue(Int64(50), forKey: "finalizedGold")
            player.setValue(Int64(100), forKey: "finalizedXP")
            player.setValue(Int64(15), forKey: "pendingGold")
            player.setValue(Int64(30), forKey: "pendingXP")

            try v2Context.save()
        }

        // Step 2: Open with current V3 model and verify lightweight migration
        do {
            let v3Container = try makeContainer(at: storeURL)
            let v3Context = v3Container.viewContext

            let tasks = try v3Context.fetch(TaskEntity.fetchRequest())
            XCTAssertEqual(tasks.count, 1)
            let task = tasks.first!
            XCTAssertEqual(task.id, originalTaskId)
            XCTAssertEqual(task.title, "V2 Task to Migrate")
            XCTAssertTrue(task.isImportant)
            XCTAssertTrue(task.isCompleted)
            XCTAssertFalse(task.isFinalized)
            XCTAssertEqual(task.awardedGold, 15)
            XCTAssertEqual(task.awardedXP, 30)

            let player = try PersistenceController.shared.getOrCreatePlayer(in: v3Context)
            XCTAssertEqual(player.finalizedGold, 50)
            XCTAssertEqual(player.finalizedXP, 100)
            XCTAssertEqual(player.pendingGold, 15)
            XCTAssertEqual(player.pendingXP, 30)

            // Verify FocusSessionEntity can be created and persisted in migrated database
            let session = FocusSessionEntity(context: v3Context)
            session.id = UUID()
            session.startDate = t0
            session.targetDurationMinutes = 25
            session.snapshotGold = 25
            session.snapshotXP = 50
            try v3Context.save()

            let sessions = try v3Context.fetch(FocusSessionEntity.fetchRequest())
            XCTAssertEqual(sessions.count, 1)
        }
    }

    @MainActor
    func testStartFocusSessionEnforcesSingleActiveSession() throws {
        let container = try makeContainer(at: storeURL)
        let context = container.viewContext
        let controller = PersistenceController.shared
        _ = try controller.getOrCreatePlayer(in: context)

        let t0 = Date(timeIntervalSince1970: 1776345600)
        let session = try controller.startFocusSession(durationMinutes: 25, now: t0, context: context)
        XCTAssertEqual(session.targetDurationMinutes, 25)
        XCTAssertEqual(session.snapshotGold, 25)
        XCTAssertEqual(session.snapshotXP, 50)

        // Attempting to start another session while one is running must throw
        XCTAssertThrowsError(try controller.startFocusSession(durationMinutes: 15, now: t0.addingTimeInterval(60), context: context)) { error in
            XCTAssertEqual(error as? PersistenceController.FocusSessionError, .activeSessionAlreadyExists)
        }

        // Even when paused, starting another session must still be prevented
        try controller.pauseFocusSession(session, now: t0.addingTimeInterval(120), context: context)
        XCTAssertThrowsError(try controller.startFocusSession(durationMinutes: 50, now: t0.addingTimeInterval(180), context: context)) { error in
            XCTAssertEqual(error as? PersistenceController.FocusSessionError, .activeSessionAlreadyExists)
        }
    }

    @MainActor
    func testFocusSessionPauseResumeAndRelaunchFreezesElapsedTime() throws {
        let t0 = Date(timeIntervalSince1970: 1776345600)

        // Session 1: Start at t0, pause at t0 + 300s (5m elapsed)
        do {
            let container1 = try makeContainer(at: storeURL)
            let context1 = container1.viewContext
            let controller = PersistenceController.shared
            _ = try controller.getOrCreatePlayer(in: context1)

            let session = try controller.startFocusSession(durationMinutes: 25, now: t0, context: context1)
            try controller.pauseFocusSession(session, now: t0.addingTimeInterval(300), context: context1)
            XCTAssertTrue(session.isPaused)
            XCTAssertEqual(session.pauseStartDate, t0.addingTimeInterval(300))
        }

        // Session 2: Reopen in new container 10 minutes later (t0 + 900s)
        do {
            let container2 = try makeContainer(at: storeURL)
            let context2 = container2.viewContext
            let controller = PersistenceController.shared

            guard let session = try controller.getActiveFocusSession(in: context2) else {
                XCTFail("Active session should survive reopen")
                return
            }
            guard let startDate = session.startDate else {
                XCTFail("Active session must have startDate")
                return
            }
            XCTAssertTrue(session.isPaused)

            // Elapsed time must remain frozen at 300s despite wall clock advancing to t0 + 900s
            let elapsedWhilePaused = FocusSessionTiming.elapsedSeconds(
                startDate: startDate,
                pausedDuration: session.pausedDuration,
                isPaused: session.isPaused,
                pauseStartDate: session.pauseStartDate,
                now: t0.addingTimeInterval(900)
            )
            XCTAssertEqual(elapsedWhilePaused, 300, "Elapsed active time must freeze while paused")

            // Resume at t0 + 900s
            try controller.resumeFocusSession(session, now: t0.addingTimeInterval(900), context: context2)
            XCTAssertFalse(session.isPaused)
            XCTAssertNil(session.pauseStartDate)
            XCTAssertEqual(session.pausedDuration, 600, "Accumulated pause must equal 600s")

            // Active elapsed at t0 + 1000s should now be 300 + 100 = 400s
            let elapsedAfterResume = FocusSessionTiming.elapsedSeconds(
                startDate: startDate,
                pausedDuration: session.pausedDuration,
                isPaused: session.isPaused,
                pauseStartDate: session.pauseStartDate,
                now: t0.addingTimeInterval(1000)
            )
            XCTAssertEqual(elapsedAfterResume, 400)
        }
    }

    @MainActor
    func testFocusSessionCancellationAwardsNothing() throws {
        let container = try makeContainer(at: storeURL)
        let context = container.viewContext
        let controller = PersistenceController.shared
        let player = try controller.getOrCreatePlayer(in: context)

        let t0 = Date(timeIntervalSince1970: 1776345600)
        let session = try controller.startFocusSession(durationMinutes: 15, now: t0, context: context)
        XCTAssertEqual(session.snapshotGold, 15)
        XCTAssertEqual(session.snapshotXP, 30)

        try controller.cancelFocusSession(session, now: t0.addingTimeInterval(300), context: context)
        XCTAssertTrue(session.isCancelled)
        XCTAssertFalse(session.isCompleted)

        // Player balances must remain strictly 0
        XCTAssertEqual(player.finalizedGold, 0)
        XCTAssertEqual(player.finalizedXP, 0)
        XCTAssertEqual(player.pendingGold, 0)
        XCTAssertEqual(player.pendingXP, 0)
    }

    @MainActor
    func testFocusSessionCompletionAwardsRewardsAtomicallyAndRejectsDuplicates() throws {
        let container = try makeContainer(at: storeURL)
        let context = container.viewContext
        let controller = PersistenceController.shared
        let player = try controller.getOrCreatePlayer(in: context)

        let t0 = Date(timeIntervalSince1970: 1776345600)
        let session = try controller.startFocusSession(durationMinutes: 25, now: t0, context: context)

        // Attempt early completion before target duration
        XCTAssertThrowsError(try controller.completeFocusSession(session, now: t0.addingTimeInterval(1400), context: context)) { error in
            XCTAssertEqual(error as? PersistenceController.FocusSessionError, .sessionNotEligibleForCompletion)
        }
        XCTAssertEqual(player.finalizedGold, 0)

        // Complete when target duration is met (t0 + 1500s)
        try controller.completeFocusSession(session, now: t0.addingTimeInterval(1500), context: context)
        XCTAssertTrue(session.isCompleted)
        XCTAssertEqual(session.completedAt, t0.addingTimeInterval(1500))

        XCTAssertEqual(player.finalizedGold, 25, "Finalized gold must be credited directly")
        XCTAssertEqual(player.finalizedXP, 50, "Finalized XP must be credited directly")
        XCTAssertEqual(player.pendingGold, 0)
        XCTAssertEqual(player.pendingXP, 0)

        // Attempt duplicate completion
        XCTAssertThrowsError(try controller.completeFocusSession(session, now: t0.addingTimeInterval(1600), context: context)) { error in
            XCTAssertEqual(error as? PersistenceController.FocusSessionError, .sessionAlreadyFinished)
        }
        XCTAssertEqual(player.finalizedGold, 25, "Rewards must not be duplicated")
        XCTAssertEqual(player.finalizedXP, 50)
    }

    @MainActor
    func testRelaunchReconciliationNaturallyCompletesFinishedUnpausedSession() throws {
        let container = try makeContainer(at: storeURL)
        let context = container.viewContext
        let controller = PersistenceController.shared
        let player = try controller.getOrCreatePlayer(in: context)

        let t0 = Date(timeIntervalSince1970: 1776345600)
        let session = try controller.startFocusSession(durationMinutes: 15, now: t0, context: context)

        // Simulate returning to foreground after 1000s (> 15m / 900s)
        try controller.reconcileActiveFocusSession(asOf: t0.addingTimeInterval(1000), context: context)

        XCTAssertTrue(session.isCompleted)
        XCTAssertEqual(player.finalizedGold, 15)
        XCTAssertEqual(player.finalizedXP, 30)
    }

    @MainActor
    func testFocusSessionSaveFailureRollsBackWithoutDiscardingUnrelatedEdits() throws {
        let container = try makeContainer(at: storeURL)
        let controller = PersistenceController.shared

        let failingContext = FailingSaveContext(concurrencyType: .mainQueueConcurrencyType)
        failingContext.persistentStoreCoordinator = container.persistentStoreCoordinator
        failingContext.shouldFailSave = false

        let player = try controller.getOrCreatePlayer(in: failingContext)
        let t0 = Date(timeIntervalSince1970: 1776345600)

        // Create baseline entities and save them to disk
        let unrelatedTask = TaskEntity(context: failingContext)
        unrelatedTask.id = UUID()
        unrelatedTask.title = "Unrelated Task Baseline"
        unrelatedTask.createdAt = t0

        let session = FocusSessionEntity(context: failingContext)
        session.id = UUID()
        session.startDate = t0
        session.targetDurationMinutes = 25
        session.pausedDuration = 0.0
        session.isPaused = false
        session.isCompleted = false
        session.isCancelled = false
        session.snapshotGold = 25
        session.snapshotXP = 50
        try failingContext.save()

        // Make an unsaved edit to the unrelated task AFTER baseline save
        unrelatedTask.title = "Unrelated Task Modified"
        XCTAssertTrue(unrelatedTask.hasChanges)

        failingContext.shouldFailSave = true
        XCTAssertThrowsError(try controller.completeFocusSession(session, now: t0.addingTimeInterval(1500), context: failingContext)) { error in
            XCTAssertEqual(error as? FailingSaveContext.SimulatedError, .simulatedDiskFailure)
        }

        // Verify session and player were rolled back
        XCTAssertFalse(session.isCompleted)
        XCTAssertNil(session.completedAt)
        XCTAssertEqual(player.finalizedGold, 0)
        XCTAssertEqual(player.finalizedXP, 0)

        // Unrelated edit must NOT be discarded
        XCTAssertTrue(unrelatedTask.hasChanges, "Unrelated unsaved edits must be preserved during rollback")
        XCTAssertEqual(unrelatedTask.title, "Unrelated Task Modified")

        // Retry with save enabled
        failingContext.shouldFailSave = false
        try controller.completeFocusSession(session, now: t0.addingTimeInterval(1500), context: failingContext)

        XCTAssertTrue(session.isCompleted)
        XCTAssertEqual(player.finalizedGold, 25)
        XCTAssertEqual(player.finalizedXP, 50)
    }
}

// MARK: - Test Helpers

private final class FailingSaveContext: NSManagedObjectContext {
    var shouldFailSave: Bool = false

    enum SimulatedError: Error, Equatable {
        case simulatedDiskFailure
    }

    override func save() throws {
        if shouldFailSave {
            throw SimulatedError.simulatedDiskFailure
        }
        try super.save()
    }
}
