//
//  ContentView.swift
//  Hatch
//
//  Created for Hatch Milestone 1, updated for Milestone 2.
//

import SwiftUI
import CoreData
import Combine
import HatchCore

/// Main home screen for Hatch.
///
/// Purpose:
/// - Connects to the Core Data store and displays saved tasks.
/// - Shows player's spendable finalized gold/XP and pending rewards.
/// - Provides task completion actions, instant visual feedback, and a 5-second undo window.
/// - Automatically reconciles expired tasks on launch and foreground return.
public struct ContentView: View {
    @EnvironmentObject private var persistence: PersistenceController
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FetchRequest(sortDescriptors: [])
    private var players: FetchedResults<PlayerEntity>

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.id, ascending: true)
        ],
        animation: .default
    )
    private var allTasks: FetchedResults<TaskEntity>

    @State private var isPresentingAddTask: Bool = false
    @State private var actionErrorMessage: String? = nil

    public init() {}

    private var player: PlayerEntity? {
        players.first
    }

    /// Level progression derived exclusively from finalized lifetime XP (PROJECT_SPEC.md § 6.2).
    /// Pending task rewards are strictly excluded.
    private var levelProgress: PlayerProgression.LevelProgress {
        PlayerProgression.progress(forCumulativeXP: player?.finalizedXP ?? 0)
    }

    private var activeTasks: [TaskEntity] {
        allTasks.filter { !$0.isCompleted }
    }

    private var pendingTasks: [TaskEntity] {
        allTasks.filter { $0.isCompleted && !$0.isFinalized }
    }

    private var finalizedTasks: [TaskEntity] {
        allTasks.filter { $0.isCompleted && $0.isFinalized }
    }

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
        .onAppear {
            try? persistence.reconcilePendingTasks()
            try? persistence.reconcileActiveFocusSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Reconcile tasks and focus sessions when returning to foreground
                try? persistence.reconcilePendingTasks()
                try? persistence.reconcileActiveFocusSession()
            }
        }
    }

    // MARK: - Subviews

    private var homeContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sanctuary and Player Progress Header
                sanctuaryAndBalancesHeader

                // Active Pending Undo Banners
                if !pendingTasks.isEmpty {
                    pendingUndoSection
                }

                // Error message banner if action fails
                if let actionError = actionErrorMessage {
                    Text(actionError)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.9))
                }

                // Task list or empty state
                if allTasks.isEmpty {
                    emptyStateView
                } else {
                    taskList
                }
            }
            .navigationTitle("Hatch")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: FocusView()) {
                        Label("Focus", systemImage: "timer")
                            .font(.body.weight(.medium))
                    }
                    .accessibilityLabel("Focus Timer")
                    .accessibilityHint("Opens the focus session timer")
                }

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

    /// Sanctuary header displaying the starter egg and live player balances.
    private var sanctuaryAndBalancesHeader: some View {
        VStack(spacing: 12) {
            EggPlaceholderView()
                .padding(.top, 4)

            // Player Level and XP Progress Card
            VStack(spacing: 6) {
                HStack {
                    Label("Level \(levelProgress.level)", systemImage: "crown.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.purple)

                    Spacer()

                    Text("\(levelProgress.currentXPInLevel) / \(levelProgress.xpRequiredForNextLevel) XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: levelProgress.progressFraction)
                    .tint(.purple)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: levelProgress.progressFraction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Player Level \(levelProgress.level), \(levelProgress.currentXPInLevel) of \(levelProgress.xpRequiredForNextLevel) XP to next level")

            // Player Balances Bar
            HStack(spacing: 16) {
                // Gold Balance Card
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("🪙")
                        Text("\(player?.finalizedGold ?? 0)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    if let pending = player?.pendingGold, pending > 0 {
                        Text("+\(pending) pending")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Gold")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Gold: \(player?.finalizedGold ?? 0), pending: \(player?.pendingGold ?? 0)")

                // XP Balance Card
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("⭐")
                        Text("\(player?.finalizedXP ?? 0)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    if let pending = player?.pendingXP, pending > 0 {
                        Text("+\(pending) pending")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    } else {
                        Text("Lifetime XP")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Player XP: \(player?.finalizedXP ?? 0), pending: \(player?.pendingXP ?? 0)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    /// Banner showing tasks currently inside their 5-second undo window.
    private var pendingUndoSection: some View {
        VStack(spacing: 6) {
            ForEach(pendingTasks) { task in
                PendingUndoBanner(task: task) {
                    undoTask(task)
                } onExpire: {
                    finalizeTask(task)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// The list of active and finalized tasks.
    private var taskList: some View {
        List {
            if !activeTasks.isEmpty {
                Section {
                    ForEach(activeTasks) { task in
                        taskRow(task)
                    }
                } header: {
                    Text("Tasks (\(activeTasks.count))")
                }
            }

            if !finalizedTasks.isEmpty {
                Section {
                    ForEach(finalizedTasks) { task in
                        completedTaskRow(task)
                    }
                } header: {
                    Text("Completed (\(finalizedTasks.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Row for an active task with a completion button and metadata.
    private func taskRow(_ task: TaskEntity) -> some View {
        HStack(spacing: 12) {
            Button {
                completeTask(task)
            } label: {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete task: \(task.title ?? "")")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title ?? "Untitled Task")
                        .font(.body)
                        .foregroundStyle(.primary)

                    if task.isImportant {
                        Text("Important")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if let date = task.createdAt {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(task.isImportant ? "+15g / +30xp" : "+10g / +20xp")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// Row for a permanently finalized completed task.
    private func completedTaskRow(_ task: TaskEntity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled Task")
                    .font(.body)
                    .strikethrough()
                    .foregroundStyle(.secondary)

                if let completedAt = task.completedAt {
                    Text("Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("+\(task.awardedGold)g")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Completed task: \(task.title ?? ""), earned \(task.awardedGold) gold and \(task.awardedXP) XP")
    }

    // MARK: - Actions

    private func completeTask(_ task: TaskEntity) {
        actionErrorMessage = nil
        do {
            try persistence.completeTask(task)
        } catch {
            actionErrorMessage = "Could not complete task: \(error.localizedDescription)"
        }
    }

    private func undoTask(_ task: TaskEntity) {
        actionErrorMessage = nil
        do {
            let success = try persistence.undoTaskCompletion(task)
            if !success {
                actionErrorMessage = "Undo window has expired."
            }
        } catch {
            actionErrorMessage = "Could not undo completion: \(error.localizedDescription)"
        }
    }

    private func finalizeTask(_ task: TaskEntity) {
        actionErrorMessage = nil
        do {
            try persistence.finalizeTask(task)
        } catch {
            actionErrorMessage = "Could not finalize task: \(error.localizedDescription)"
        }
    }

    // MARK: - Status States

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

/// Banner with a countdown timer representing an active undo window.
struct PendingUndoBanner: View {
    @ObservedObject var task: TaskEntity
    let onUndo: () -> Void
    let onExpire: () -> Void

    @State private var timeRemaining: TimeInterval = 5.0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Completed!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)

                    Text("+\(task.awardedGold)g, +\(task.awardedXP)xp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(task.title ?? "Task") (Finalizing in \(String(format: "%.1f", max(0, timeRemaining)))s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Undo") {
                onUndo()
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.orange)
            .clipShape(Capsule())
            .accessibilityLabel("Undo completion of \(task.title ?? "")")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        .onReceive(timer) { now in
            if let deadline = task.undoDeadline {
                let remaining = deadline.timeIntervalSince(now)
                timeRemaining = remaining
                if remaining <= 0 {
                    onExpire()
                }
            }
        }
        .onAppear {
            if let deadline = task.undoDeadline {
                timeRemaining = deadline.timeIntervalSince(Date())
            }
        }
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

            // Highlight spot
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 10, height: 10)
                .offset(x: -10, y: -16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Starter egg companion")
    }
}
