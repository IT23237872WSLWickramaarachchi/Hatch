# Milestone 0 Checklist

**Branch**: `main` (single branch workflow)
**Last updated**: 2026-10-16

Use this checklist during your viva to explain what was done, how, and what remains pending.

---

## Windows (this machine)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Package source created (`Packages/HatchCore/Package.swift`) | ✅ Done | tools-version 5.9; compatible with Swift 5.9+ and Xcode 26.6 |
| 2 | `Sources/HatchCore/TaskTitle.swift` created | ✅ Done | `validateTaskTitle(_:)` returns `Result<String, TaskTitleError>` |
| 3 | `Tests/HatchCoreTests/TaskTitleTests.swift` created | ✅ Done | 13 XCTest cases covering empty, whitespace-only, trimming, and internal-spacing rules |
| 4 | `swift test` attempted on Windows | ⚠️ Blocked | `swift` is not installed on this Windows machine. Tests are source-reviewed only. |
| 5 | Repository structure verified | ✅ Done | All files inside `Hatch/` root; no nested `.git` |
| 6 | Mac setup guide prepared (`docs/MAC_FIRST_SETUP.md`) | ✅ Done | Covers clone, toolchain check, `swift test`, Xcode project, Core Data model |
| 7 | `docs/MILESTONE_0_CHECKLIST.md` created | ✅ Done | This file |
| 8 | `README.md` updated | ✅ Done | Package location, test command, setup guide link |
| 9 | `docs/AI_ASSISTANCE.md` updated | ✅ Done | Session entries logged |
| 10 | Workflow updated to single branch `main` | ✅ Done | No feature branches; all development on `main` |
| 11 | Files staged and committed on `main` | ⏳ Awaiting your instruction | Files are ready; you control Git mutations |
| 12 | `main` pushed to remote | ⏳ Awaiting your instruction | Push when you are ready |

---

## Mac (university machine — Milestone 0 / Setup completion)

| # | Task | Status | Notes |
|---|------|--------|-------|
| M1 | Repository cloned or pulled on Mac | ✅ Done | On branch `main`, synchronized with remote |
| M2 | Swift toolchain version verified (`swift --version`) | ✅ Done | Xcode 26.1.1, Swift 6.x |
| M3 | iOS simulator runtime confirmed | ✅ Done | iOS Simulator SDK verified |
| M4 | `swift test --package-path Packages/HatchCore` run | ✅ Done | 13 passed, 0 failures (after `import Foundation` added) |
| M5 | Xcode project created at `App/Hatch/Hatch.xcodeproj` | ✅ Done | Manually created; path at `App/Hatch/Hatch.xcodeproj` |
| M6 | No nested `.git` inside `App/` | ✅ Done | Verified no nested repository |
| M7 | Starter app builds for Simulator target | ✅ Build passed | `xcodebuild` clean build succeeded on `Hatch` scheme; runtime UI verification pending |
| M8 | HatchCore linked to app target | ✅ Done | Local package dependency resolved |
| M9 | `import HatchCore` build-check passes | ✅ Done | `ContentView.swift` compiles cleanly with `HatchCore` import |
| M10 | `HatchModel.xcdatamodeld` created | ✅ Done | Located in `App/Hatch/Hatch/` |
| M11 | `TaskEntity` with `id`, `title`, `createdAt` attributes added | ✅ Done | Confirmed non-optional: verified via compiled model `NSAttributeDescription.isOptional == false` |
| M12 | Codegen set to Class Definition; no manual `TaskEntity.swift` written | ✅ Done | `codeGenerationType="class"`, module `Current Product Module` (`.TaskEntity`) |
| M13 | Xcode project and model files committed | ✅ Done | Committed and pushed to origin/main as part of Milestone 1 checkpoint |

---

## Explicitly out of scope for Milestone 0

The following are **not implemented here** and must not be assumed done:

- SwiftUI task list or add-task screens.
- `NSPersistentContainer` setup or Core Data save/load code.
- Gold, XP, rewards, or player progression logic.
- Focus sessions.
- Shop or inventory.
- SpriteKit scenes.
- Monsters, evolution, or battles.
- App blocking (FamilyControls).

All of the above begin in Milestone 1 or later.

---

## Verification terminology (project standard)

| Term | Meaning |
|------|---------|
| Source reviewed | Code has been read and is logically consistent |
| `swift test` passed | The command ran and produced 0 failures |
| Xcode build passed | Developer ran a clean build in Xcode with 0 errors |
| Simulator verified | Developer ran the feature in the Simulator |
| Device tested | Feature confirmed on a physical iOS device |
