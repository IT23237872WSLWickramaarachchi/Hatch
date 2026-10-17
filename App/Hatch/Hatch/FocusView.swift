//
//  FocusView.swift
//  Hatch
//
//  Created for Hatch Milestone 3.
//

import SwiftUI
import CoreData
import Combine
import HatchCore

/// Focus screen allowing players to run timed focus sessions.
///
/// Features:
/// - Predefined duration choices: 15 min, 25 min, 50 min.
/// - Snapshotted rewards: 1 gold/min, 2 XP/min.
/// - Optional linking to an active task.
/// - Timestamp-based persistence: survives process suspension and relaunch.
/// - Controls: Start, Pause, Resume, Cancel, and Complete.
public struct FocusView: View {
    @EnvironmentObject private var persistence: PersistenceController
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FocusSessionEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isCompleted == NO AND isCancelled == NO")
    )
    private var activeSessions: FetchedResults<FocusSessionEntity>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == NO")
    )
    private var activeTasks: FetchedResults<TaskEntity>

    @State private var selectedDuration: Int = GameBalance.Focus.defaultDurationMinutes
    @State private var selectedLinkedTaskID: UUID? = nil
    @State private var currentTime: Date = Date()
    @State private var errorMessage: String? = nil
    @State private var showCancelConfirmation: Bool = false

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    public init() {}

    private var activeSession: FocusSessionEntity? {
        activeSessions.first
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let session = activeSession {
                    activeSessionCard(session)
                } else {
                    newSessionConfigCard
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding(16)
        }
        .navigationTitle("Focus Session")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { newTime in
            currentTime = newTime
            // Reconcile if session naturally finished while view is active
            if let session = activeSession, !session.isPaused, let startDate = session.startDate {
                let target = TimeInterval(session.targetDurationMinutes) * 60.0
                let elapsed = FocusSessionTiming.elapsedSeconds(
                    startDate: startDate,
                    pausedDuration: session.pausedDuration,
                    isPaused: false,
                    pauseStartDate: nil,
                    now: newTime
                )
                if FocusSessionTiming.isEligibleForCompletion(targetDurationSeconds: target, elapsedSeconds: elapsed) {
                    try? persistence.completeFocusSession(session, now: newTime, context: viewContext)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                currentTime = Date()
                try? persistence.reconcileActiveFocusSession(asOf: Date(), context: viewContext)
            }
        }
        .onAppear {
            currentTime = Date()
            try? persistence.reconcileActiveFocusSession(asOf: Date(), context: viewContext)
        }
        .confirmationDialog(
            "Cancel Focus Session?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Session", role: .destructive) {
                if let session = activeSession {
                    do {
                        try persistence.cancelFocusSession(session, now: Date(), context: viewContext)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("Keep Focusing", role: .cancel) {}
        } message: {
            Text("Cancelling will end this session and award no gold or XP.")
        }
    }

    // MARK: - Subviews

    private var newSessionConfigCard: some View {
        VStack(spacing: 20) {
            Text("Start a Focus Session")
                .font(.headline)
                .foregroundStyle(.primary)

            // Duration Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Duration", selection: $selectedDuration) {
                    Text("15 min").tag(GameBalance.Focus.shortDurationMinutes)
                    Text("25 min").tag(GameBalance.Focus.defaultDurationMinutes)
                    Text("50 min").tag(GameBalance.Focus.longDurationMinutes)
                }
                .pickerStyle(.segmented)
            }

            // Reward Preview
            let reward = RewardCalculator.reward(forFocusDurationMinutes: selectedDuration)
            HStack(spacing: 16) {
                Label("\(reward.gold) Gold", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.semibold))

                Label("\(reward.xp) XP", systemImage: "star.fill")
                    .foregroundStyle(.blue)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Optional Linked Task Picker
            if !activeTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Link to Active Task (Optional)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Linked Task", selection: $selectedLinkedTaskID) {
                        Text("None").tag(UUID?.none)
                        ForEach(activeTasks) { task in
                            Text(task.title ?? "Task").tag(Optional(task.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            // Start Button
            Button {
                startSession()
            } label: {
                Text("Begin Focus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func activeSessionCard(_ session: FocusSessionEntity) -> some View {
        let targetSeconds = TimeInterval(session.targetDurationMinutes) * 60.0
        let elapsed = FocusSessionTiming.elapsedSeconds(
            startDate: session.startDate ?? currentTime,
            pausedDuration: session.pausedDuration,
            isPaused: session.isPaused,
            pauseStartDate: session.pauseStartDate,
            now: currentTime
        )
        let remaining = FocusSessionTiming.remainingSeconds(
            targetDurationSeconds: targetSeconds,
            elapsedSeconds: elapsed
        )
        let isEligible = FocusSessionTiming.isEligibleForCompletion(
            targetDurationSeconds: targetSeconds,
            elapsedSeconds: elapsed
        )
        let progressFraction = min(1.0, max(0.0, elapsed / targetSeconds))

        return VStack(spacing: 24) {
            // Status Header
            HStack {
                Circle()
                    .fill(session.isPaused ? Color.orange : Color.green)
                    .frame(width: 10, height: 10)
                Text(session.isPaused ? "Paused" : "Focusing")
                    .font(.headline)
                    .foregroundStyle(session.isPaused ? .orange : .green)
                Spacer()
                Text("\(session.snapshotGold) Gold · \(session.snapshotXP) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Big Circular Countdown Display
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 14)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: CGFloat(progressFraction))
                    .stroke(
                        session.isPaused ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)

                VStack(spacing: 4) {
                    Text(formatSeconds(remaining))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text(isEligible ? "Complete!" : "Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            // Controls
            HStack(spacing: 16) {
                if isEligible {
                    Button {
                        completeSession(session)
                    } label: {
                        Text("Claim Rewards")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    if session.isPaused {
                        Button {
                            resumeSession(session)
                        } label: {
                            Text("Resume")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    } else {
                        Button {
                            pauseSession(session)
                        } label: {
                            Text("Pause")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private func startSession() {
        errorMessage = nil
        do {
            try persistence.startFocusSession(
                durationMinutes: selectedDuration,
                linkedTaskID: selectedLinkedTaskID,
                now: Date(),
                context: viewContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pauseSession(_ session: FocusSessionEntity) {
        errorMessage = nil
        do {
            try persistence.pauseFocusSession(session, now: Date(), context: viewContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resumeSession(_ session: FocusSessionEntity) {
        errorMessage = nil
        do {
            try persistence.resumeFocusSession(session, now: Date(), context: viewContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeSession(_ session: FocusSessionEntity) {
        errorMessage = nil
        do {
            try persistence.completeFocusSession(session, now: Date(), context: viewContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
