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

## Mac (university machine — Milestone 0 completion)

These steps require a Mac with Xcode 26.6. They are **not** done yet.

| # | Task | Status | Notes |
|---|------|--------|-------|
| M1 | Repository cloned or pulled on Mac | ⏳ Pending | See `docs/MAC_FIRST_SETUP.md` Part 1 |
| M2 | Swift toolchain version verified (`swift --version`) | ⏳ Pending | Must be 5.9+ |
| M3 | iOS 26 simulator runtime confirmed | ⏳ Pending | `xcrun simctl list runtimes` |
| M4 | `swift test --package-path Packages/HatchCore` run | ⏳ Pending | Must show 0 failures before creating Xcode project |
| M5 | Xcode project created at `App/Hatch.xcodeproj` | ⏳ Pending | See `docs/MAC_FIRST_SETUP.md` Part 4 |
| M6 | No nested `.git` inside `App/` | ⏳ Pending | Must verify after project creation |
| M7 | Starter app launches in Simulator | ⏳ Pending | Clean build required before adding feature code |
| M8 | HatchCore linked to app target | ⏳ Pending | See `docs/MAC_FIRST_SETUP.md` Part 6 |
| M9 | `import HatchCore` build-check passes | ⏳ Pending | Quick smoke test of the link |
| M10 | `HatchModel.xcdatamodeld` created | ⏳ Pending | See `docs/MAC_FIRST_SETUP.md` Part 7 |
| M11 | `TaskEntity` with `id`, `title`, `createdAt` attributes added | ⏳ Pending | All three non-optional |
| M12 | Codegen set to Class Definition; no manual `TaskEntity.swift` written | ⏳ Pending | Prevents redeclaration error |
| M13 | Xcode project and model files committed | ⏳ Pending | See `docs/MAC_FIRST_SETUP.md` Part 8 |

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
