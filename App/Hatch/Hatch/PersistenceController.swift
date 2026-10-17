//
//  PersistenceController.swift
//  Hatch
//
//  Created for Hatch Milestone 1.
//

import CoreData
import Foundation
import Combine

/// Manages the Core Data stack for Hatch.
///
/// Purpose:
/// - Initializes and loads the persistent store named "HatchModel".
/// - Exposes the `viewContext` for SwiftUI views and `@FetchRequest`.
/// - Tracks loading status and errors gracefully without crashing (`fatalError`)
///   or silently replacing/wiping user data.
/// - Supports an isolated in-memory configuration for SwiftUI previews and testing.
public final class PersistenceController: ObservableObject {
    /// Shared singleton instance used by the live app.
    public static let shared = PersistenceController()

    /// Isolated in-memory instance for SwiftUI previews.
    public static let preview: PersistenceController = {
        PersistenceController(inMemory: true)
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

        if inMemory {
            if let description = container.persistentStoreDescriptions.first {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        container.loadPersistentStores { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    // We avoid fatalError() to keep the user's data safe from destructive crashes.
                    self?.loadError = "Unable to load saved tasks. Please check your device storage. (\(error.localizedDescription))"
                    self?.isLoaded = false
                } else {
                    self?.container.viewContext.automaticallyMergesChangesFromParent = true
                    self?.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                    self?.isLoaded = true
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
}
