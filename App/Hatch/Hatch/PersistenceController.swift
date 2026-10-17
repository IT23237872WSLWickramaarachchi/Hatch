//
//  PersistenceController.swift
//  Hatch
//
//  Created for Hatch Milestone 1, updated for Milestone 2.
//

import CoreData
import Foundation
import Combine
import HatchCore

/// Manages the Core Data stack for Hatch.
///
/// Purpose:
/// - Initializes and loads the persistent store named "HatchModel" (V2 schema).
/// - Ensures automatic lightweight migration is configured so Milestone 1 data persists cleanly.
/// - Exposes the `viewContext` for SwiftUI views and `@FetchRequest`.
/// - Tracks loading status and non-fatal error messages.
/// - Manages atomic completion, undo, and relaunch reconciliation for tasks and player rewards.
public final class PersistenceController: ObservableObject {
    /// Shared singleton instance used by the live app.
    public static let shared = PersistenceController()

    /// Isolated in-memory instance for SwiftUI previews.
    public static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext
        _ = try? controller.getOrCreatePlayer(in: context)
        return controller
    }()

    /// The underlying Core Data container.
    public let container: NSPersistentContainer

    /// Whether the persistent store has finished loading and is ready for use.
    @Published public private(set) var isLoaded: Bool = false

    /// An understandable, human-readable description of any store loading failure.
    @Published public private(set) var loadError: String? = nil

    /// The main-queue managed object context for UI bindings and fetch requests.
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Initializes a persistence controller.
    /// - Parameter inMemory: When true, stores data in `/dev/null` (ephemeral).
    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HatchModel")

        if let description = container.persistentStoreDescriptions.first {
            // Configure automatic lightweight migration before loading the store
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true

            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        container.loadPersistentStores { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error as NSError? {
                    self.loadError = "Unable to load saved tasks. Please check your device storage. (\(error.localizedDescription))"
                    self.isLoaded = false
                } else {
                    self.container.viewContext.automaticallyMergesChangesFromParent = true
                    self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                    self.isLoaded = true

                    // Reconcile any unfinalized tasks that expired while the app was closed
                    try? self.reconcilePendingTasks()
                }
            }
        }
    }

    /// Saves pending changes in the specified context if any exist.
    /// - Parameter context: The context to save (defaults to `viewContext`).
    public func save(context: NSManagedObjectContext? = nil) throws {
        let targetContext = context ?? viewContext
        if targetContext.hasChanges {
            try targetContext.save()
        }
    }

    // MARK: - Player Progress Management

    /// Retrieves the single existing `PlayerEntity` or creates it if this is the first launch.
    @discardableResult
    public func getOrCreatePlayer(in context: NSManagedObjectContext) throws -> PlayerEntity {
        let request: NSFetchRequest<PlayerEntity> = PlayerEntity.fetchRequest()
        request.fetchLimit = 1

        let results = try context.fetch(request)
        if let existing = results.first {
            return existing
        }

        let newPlayer = PlayerEntity(context: context)
        newPlayer.id = UUID()
        newPlayer.finalizedGold = 0
        newPlayer.finalizedXP = 0
        newPlayer.pendingGold = 0
        newPlayer.pendingXP = 0
        try context.save()
        return newPlayer
    }

    // MARK: - Task Completion & Undo Operations

    /// Completes a task, awarding pending gold and XP atomically in the same transaction.
    /// - Parameters:
    ///   - task: The task to mark complete.
    ///   - now: Reference timestamp (defaults to current time).
    ///   - context: Optional context to use (defaults to task's context or `viewContext`).
    @MainActor
    public func completeTask(_ task: TaskEntity, now: Date = Date(), context: NSManagedObjectContext? = nil) throws {
        // Guard against duplicate completions or completing already finalized tasks
        guard !task.isCompleted else { return }

        let targetContext = context ?? task.managedObjectContext ?? viewContext
        let reward = RewardCalculator.reward(forTaskIsImportant: task.isImportant)
        let player = try getOrCreatePlayer(in: targetContext)

        let deadline = UndoTiming.deadline(from: now, window: GameBalance.Undo.windowDurationSeconds)

        task.isCompleted = true
        task.completedAt = now
        task.undoDeadline = deadline
        task.awardedGold = Int32(reward.gold)
        task.awardedXP = Int32(reward.xp)
        task.isFinalized = false

        // Pending rewards are held in escrow and cannot be spent yet
        player.pendingGold += Int64(reward.gold)
        player.pendingXP += Int64(reward.xp)

        do {
            try targetContext.save()
        } catch {
            targetContext.rollback()
            throw error
        }
    }

    /// Undoes a task completion if the persisted deadline has not expired.
    /// - Parameters:
    ///   - task: The task to revert.
    ///   - now: Reference timestamp (defaults to current time).
    ///   - context: Optional context to use.
    /// - Returns: `true` if successfully undone; `false` if the window had already expired.
    @MainActor
    @discardableResult
    public func undoTaskCompletion(_ task: TaskEntity, now: Date = Date(), context: NSManagedObjectContext? = nil) throws -> Bool {
        guard task.isCompleted, !task.isFinalized, let deadline = task.undoDeadline else {
            return false
        }

        let targetContext = context ?? task.managedObjectContext ?? viewContext

        // Use the persisted deadline directly rather than recalculating from GameBalance
        guard now < deadline else {
            // Window has expired; finalize instead
            try finalizeTask(task, now: now, context: targetContext)
            return false
        }

        let player = try getOrCreatePlayer(in: targetContext)
        let goldToDeduct = Int64(task.awardedGold)
        let xpToDeduct = Int64(task.awardedXP)

        task.isCompleted = false
        task.completedAt = nil
        task.undoDeadline = nil
        task.awardedGold = 0
        task.awardedXP = 0
        task.isFinalized = false

        player.pendingGold = max(0, player.pendingGold - goldToDeduct)
        player.pendingXP = max(0, player.pendingXP - xpToDeduct)

        do {
            try targetContext.save()
            return true
        } catch {
            targetContext.rollback()
            throw error
        }
    }

    /// Finalizes a completed task once its undo window has expired, converting pending rewards to permanent rewards.
    /// - Parameters:
    ///   - task: The task to finalize.
    ///   - now: Reference timestamp.
    ///   - context: Optional context to use.
    @MainActor
    public func finalizeTask(_ task: TaskEntity, now: Date = Date(), context: NSManagedObjectContext? = nil) throws {
        guard task.isCompleted, !task.isFinalized else { return }

        let targetContext = context ?? task.managedObjectContext ?? viewContext
        let player = try getOrCreatePlayer(in: targetContext)
        let gold = Int64(task.awardedGold)
        let xp = Int64(task.awardedXP)

        task.isFinalized = true

        player.pendingGold = max(0, player.pendingGold - gold)
        player.pendingXP = max(0, player.pendingXP - xp)
        player.finalizedGold += gold
        player.finalizedXP += xp

        do {
            try targetContext.save()
        } catch {
            targetContext.rollback()
            throw error
        }
    }

    /// Reconciles all pending tasks whose persisted undo deadlines have passed.
    /// Called on app launch and when returning to the foreground.
    /// - Parameters:
    ///   - now: Reference timestamp (defaults to current date).
    ///   - context: Optional context to use.
    @MainActor
    public func reconcilePendingTasks(asOf now: Date = Date(), context: NSManagedObjectContext? = nil) throws {
        let targetContext = context ?? viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "isCompleted == YES AND isFinalized == NO AND undoDeadline <= %@",
            now as NSDate
        )

        let expiredTasks = try targetContext.fetch(request)
        guard !expiredTasks.isEmpty else { return }

        let player = try getOrCreatePlayer(in: targetContext)
        for task in expiredTasks {
            let gold = Int64(task.awardedGold)
            let xp = Int64(task.awardedXP)

            task.isFinalized = true
            player.pendingGold = max(0, player.pendingGold - gold)
            player.pendingXP = max(0, player.pendingXP - xp)
            player.finalizedGold += gold
            player.finalizedXP += xp
        }

        try targetContext.save()
    }
}
