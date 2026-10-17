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

                    // Reconcile any unfinalized tasks and expired focus sessions
                    try? self.reconcilePendingTasks()
                    try? self.reconcileActiveFocusSession()
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

    // MARK: - Focus Session Management

    public enum FocusSessionError: LocalizedError {
        case activeSessionAlreadyExists
        case sessionNotEligibleForCompletion
        case sessionAlreadyFinished

        public var errorDescription: String? {
            switch self {
            case .activeSessionAlreadyExists:
                return "A focus session is already in progress."
            case .sessionNotEligibleForCompletion:
                return "The focus session has not reached its target duration yet."
            case .sessionAlreadyFinished:
                return "This focus session is already completed or cancelled."
            }
        }
    }

    /// Fetches the currently active focus session (running or paused), if one exists.
    public func getActiveFocusSession(in context: NSManagedObjectContext? = nil) throws -> FocusSessionEntity? {
        let targetContext = context ?? viewContext
        let request: NSFetchRequest<FocusSessionEntity> = FocusSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO AND isCancelled == NO")
        request.fetchLimit = 1
        return try targetContext.fetch(request).first
    }

    /// Starts a new focus session. Throws `FocusSessionError.activeSessionAlreadyExists` if another session is active.
    @MainActor
    @discardableResult
    public func startFocusSession(
        durationMinutes: Int,
        linkedTaskID: UUID? = nil,
        now: Date = Date(),
        context: NSManagedObjectContext? = nil
    ) throws -> FocusSessionEntity {
        let targetContext = context ?? viewContext
        if let _ = try getActiveFocusSession(in: targetContext) {
            throw FocusSessionError.activeSessionAlreadyExists
        }

        let reward = RewardCalculator.reward(forFocusDurationMinutes: durationMinutes)

        let session = FocusSessionEntity(context: targetContext)
        session.id = UUID()
        session.startDate = now
        session.targetDurationMinutes = Int32(durationMinutes)
        session.pausedDuration = 0.0
        session.isPaused = false
        session.pauseStartDate = nil
        session.isCompleted = false
        session.isCancelled = false
        session.snapshotGold = Int32(reward.gold)
        session.snapshotXP = Int32(reward.xp)
        session.linkedTaskID = linkedTaskID

        do {
            try targetContext.save()
            return session
        } catch {
            targetContext.refresh(session, mergeChanges: false)
            throw error
        }
    }

    /// Pauses an active focus session.
    @MainActor
    public func pauseFocusSession(
        _ session: FocusSessionEntity,
        now: Date = Date(),
        context: NSManagedObjectContext? = nil
    ) throws {
        guard !session.isCompleted, !session.isCancelled, !session.isPaused else { return }
        let targetContext = context ?? session.managedObjectContext ?? viewContext

        session.isPaused = true
        session.pauseStartDate = now

        do {
            try targetContext.save()
        } catch {
            targetContext.refresh(session, mergeChanges: false)
            throw error
        }
    }

    /// Resumes a paused focus session.
    @MainActor
    public func resumeFocusSession(
        _ session: FocusSessionEntity,
        now: Date = Date(),
        context: NSManagedObjectContext? = nil
    ) throws {
        guard !session.isCompleted, !session.isCancelled, session.isPaused else { return }
        let targetContext = context ?? session.managedObjectContext ?? viewContext

        if let pauseStart = session.pauseStartDate, now >= pauseStart {
            session.pausedDuration += now.timeIntervalSince(pauseStart)
        }
        session.isPaused = false
        session.pauseStartDate = nil

        do {
            try targetContext.save()
        } catch {
            targetContext.refresh(session, mergeChanges: false)
            throw error
        }
    }

    /// Cancels an active focus session. Awards zero rewards.
    @MainActor
    public func cancelFocusSession(
        _ session: FocusSessionEntity,
        now: Date = Date(),
        context: NSManagedObjectContext? = nil
    ) throws {
        guard !session.isCompleted, !session.isCancelled else { return }
        let targetContext = context ?? session.managedObjectContext ?? viewContext

        session.isCancelled = true
        session.isPaused = false
        session.pauseStartDate = nil

        do {
            try targetContext.save()
        } catch {
            targetContext.refresh(session, mergeChanges: false)
            throw error
        }
    }

    /// Completes an eligible focus session, awarding snapshot gold and XP atomically.
    @MainActor
    public func completeFocusSession(
        _ session: FocusSessionEntity,
        now: Date = Date(),
        context: NSManagedObjectContext? = nil
    ) throws {
        guard !session.isCompleted, !session.isCancelled else {
            throw FocusSessionError.sessionAlreadyFinished
        }
        guard let startDate = session.startDate else {
            throw FocusSessionError.sessionAlreadyFinished
        }

        let targetDuration = TimeInterval(session.targetDurationMinutes) * 60.0
        let elapsed = FocusSessionTiming.elapsedSeconds(
            startDate: startDate,
            pausedDuration: session.pausedDuration,
            isPaused: session.isPaused,
            pauseStartDate: session.pauseStartDate,
            now: now
        )

        guard FocusSessionTiming.isEligibleForCompletion(
            targetDurationSeconds: targetDuration,
            elapsedSeconds: elapsed
        ) else {
            throw FocusSessionError.sessionNotEligibleForCompletion
        }

        let targetContext = context ?? session.managedObjectContext ?? viewContext
        let player = try getOrCreatePlayer(in: targetContext)

        if session.isPaused, let pauseStart = session.pauseStartDate, now >= pauseStart {
            session.pausedDuration += now.timeIntervalSince(pauseStart)
        }

        session.isCompleted = true
        session.completedAt = now
        session.isPaused = false
        session.pauseStartDate = nil

        player.finalizedGold += Int64(session.snapshotGold)
        player.finalizedXP += Int64(session.snapshotXP)

        do {
            try targetContext.save()
        } catch {
            targetContext.refresh(session, mergeChanges: false)
            targetContext.refresh(player, mergeChanges: false)
            throw error
        }
    }

    /// Reconciles the active focus session on launch or returning to the foreground.
    /// If an active unpaused session has reached its target duration, finalizes it automatically.
    @MainActor
    public func reconcileActiveFocusSession(
        asOf now: Date = Date(),
        context: NSManagedObjectContext? = nil
    ) throws {
        let targetContext = context ?? viewContext
        guard let session = try getActiveFocusSession(in: targetContext) else { return }

        // If paused, elapsed time is frozen, so it cannot naturally complete while paused
        guard !session.isPaused else { return }
        guard let startDate = session.startDate else { return }

        let targetDuration = TimeInterval(session.targetDurationMinutes) * 60.0
        let elapsed = FocusSessionTiming.elapsedSeconds(
            startDate: startDate,
            pausedDuration: session.pausedDuration,
            isPaused: false,
            pauseStartDate: nil,
            now: now
        )

        if FocusSessionTiming.isEligibleForCompletion(
            targetDurationSeconds: targetDuration,
            elapsedSeconds: elapsed
        ) {
            try completeFocusSession(session, now: now, context: targetContext)
        }
    }
}
