//
//  ContentView.swift
//  Hatch
//
//  Created for Hatch Milestone 1.
//

import SwiftUI
import CoreData

/// Main home screen for Hatch.
///
/// Purpose:
/// - Connects to the Core Data store and displays saved tasks.
/// - Presents the app title, a static starter egg companion placeholder,
///   a clear empty state, and a sheet trigger for adding tasks.
/// - Handles loading and store error states gracefully.
public struct ContentView: View {
    @EnvironmentObject private var persistence: PersistenceController
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.id, ascending: true)
        ],
        animation: .default
    )
    private var tasks: FetchedResults<TaskEntity>

    @State private var isPresentingAddTask: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if let error = persistence.loadError {
                errorStateView(message: error)
            } else if !persistence.isLoaded {
                loadingStateView
            } else {
                homeContent
            }
        }
    }

    // MARK: - Subviews

    private var homeContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Companion sanctuary header preview
                sanctuaryHeader

                // Task list or empty state
                if tasks.isEmpty {
                    emptyStateView
                } else {
                    taskList
                }
            }
            .navigationTitle("Hatch")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Add Task")
                    .accessibilityHint("Opens a sheet to enter a new task title")
                }
            }
            .sheet(isPresented: $isPresentingAddTask) {
                AddTaskView()
            }
        }
    }

    /// Sanctuary header displaying a cozy, lightweight egg placeholder.
    private var sanctuaryHeader: some View {
        VStack(spacing: 12) {
            EggPlaceholderView()
                .padding(.top, 8)

            Text("Your journey begins with a single task.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    /// The list of saved tasks sorted deterministically by creation date.
    private var taskList: some View {
        List {
            Section {
                ForEach(tasks) { task in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title ?? "Untitled Task")
                            .font(.body)
                            .foregroundStyle(.primary)

                        if let date = task.createdAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(task.title ?? "Untitled Task"), created \(task.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                }
            } header: {
                Text("Active Tasks (\(tasks.count))")
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Friendly empty state displayed when no tasks have been created yet.
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Tasks Yet")
                .font(.headline)

            Text("Tap the '+' button at the top to add your first task and begin earning progress.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No tasks yet. Tap the add button to create your first task.")
    }

    /// View displayed while Core Data is initializing the SQLite store.
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading tasks...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Error view displayed if Core Data fails to initialize the SQLite store.
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)

            Text("Storage Error")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A lightweight, static egg shape symbolizing the starter egg.
public struct EggPlaceholderView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.85, blue: 0.55),
                            Color(red: 0.94, green: 0.65, blue: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 52, height: 68)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: Color.orange.opacity(0.2), radius: 6, x: 0, y: 3)

            // Subtle highlight spot
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 10, height: 10)
                .offset(x: -10, y: -16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Starter egg companion")
    }
}

#Preview("Home with Tasks") {
    let controller = PersistenceController.preview
    let context = controller.viewContext
    let sampleTask = TaskEntity(context: context)
    sampleTask.id = UUID()
    sampleTask.title = "Read chapter 1"
    sampleTask.createdAt = Date()
    try? context.save()

    return ContentView()
        .environment(\.managedObjectContext, context)
        .environmentObject(controller)
}

#Preview("Empty State") {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environmentObject(PersistenceController.preview)
}
