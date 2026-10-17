//
//  AddTaskView.swift
//  Hatch
//
//  Created for Hatch Milestone 1.
//

import SwiftUI
import CoreData
import HatchCore

/// Sheet view for validating and creating a new task.
///
/// Purpose:
/// - Collects a task title from the user.
/// - Validates the input using HatchCore's `validateTaskTitle(_:)` function.
/// - Inserts a new `TaskEntity` into Core Data upon valid submission.
/// - Prevents duplicate submissions and rolls back on failure.
public struct AddTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSaving: Bool = false
    @FocusState private var isTitleFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What do you want to accomplish?", text: $title)
                        .focused($isTitleFocused)
                        .accessibilityLabel("Task title input")
                        .disabled(isSaving)
                        .onSubmit(saveTask)
                } header: {
                    Text("Task Details")
                } footer: {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                            .accessibilityLabel("Validation error: \(errorMessage)")
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                    .accessibilityLabel("Cancel task creation")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(isSaving)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Save task")
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
    }

    private func saveTask() {
        guard !isSaving else { return }
        errorMessage = nil

        // Validate the title using HatchCore's platform-independent validator
        let validation = validateTaskTitle(title)
        switch validation {
        case .failure(let error):
            switch error {
            case .empty:
                errorMessage = "Please enter a task title."
            case .whitespaceOnly:
                errorMessage = "Task title cannot be whitespace only."
            }
            return

        case .success(let normalizedTitle):
            isSaving = true

            let newTask = TaskEntity(context: viewContext)
            newTask.id = UUID()
            newTask.title = normalizedTitle
            newTask.createdAt = Date()

            do {
                try viewContext.save()
                isSaving = false
                dismiss()
            } catch {
                // Roll back insertion so the unsaved object is discarded from the context
                viewContext.rollback()
                isSaving = false
                errorMessage = "Failed to save task: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    AddTaskView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
