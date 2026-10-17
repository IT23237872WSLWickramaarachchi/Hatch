# Hatch 🥚

**Hatch** is a native iOS productivity app with a collectible-monster game, built as a university assignment for the Mobile Application Development and Design (MADD) module, Year 4 Semester 1.

Hatch motivates users to complete meaningful tasks and focus sessions by rewarding them with gold, player XP, and monster progression.

> Complete tasks and focus sessions → earn gold and XP → gain player levels →
> unlock and buy eggs and food → raise monsters → progress through offline battles.

---

## Current Status

| Milestone | Description                                          | Status         |
|-----------|------------------------------------------------------|----------------|
| 0         | Project specification, documentation, HatchCore setup | ✅ Completed (Mac verified) |
| 1         | Xcode project, task creation, Core Data persistence  | ✅ Completed (Automated tests & developer simulator checks passed) |
| 2         | Task completion, gold/XP, undo window                | ✅ Completed (Automated integration & developer simulator checks passed) |
| 3         | Focus sessions, player levels                        | ✅ Completed (Automated tests & developer simulator checks passed) |
| 4         | Shop and inventory                                   | ⏳ Pending     |
| 5         | Hatching and evolution                               | ⏳ Pending     |
| 6         | Interactive sanctuary and pet selection              | ⏳ Pending     |
| 7         | Offline battles and boss progression                 | ⏳ Pending     |
| 8         | App blocking (FamilyControls investigation)          | ⏳ Pending     |
| 9         | Testing, polish, documentation, demonstration        | ⏳ Pending     |

---

## Repository Structure

```
Hatch/                          <- repository root
├── .gitignore                  <- shared; personal Xcode state excluded
├── README.md                   <- this file
├── PROJECT_SPEC.md             <- full functional and technical specification
├── docs/
│   ├── ROADMAP.md              <- milestone plan with learning goals
│   ├── DECISIONS.md            <- confirmed choices vs provisional values
│   └── AI_ASSISTANCE.md        <- factual AI-assistance log
├── Packages/
│   └── HatchCore/              <- platform-independent Swift package (Milestone 0)
└── App/
    └── Hatch/                  <- Xcode project at App/Hatch/Hatch.xcodeproj (Milestone 1)
```

---

## Technical Stack

| Concern             | Choice                                                    |
|---------------------|-----------------------------------------------------------|
| Language            | Swift                                                     |
| UI Framework        | SwiftUI                                                   |
| Persistence         | Core Data (iOS layer)                                     |
| Monster/battle UI   | SpriteKit (iOS layer)                                     |
| Business logic      | HatchCore — local Swift package, no Apple-only frameworks |
| Minimum deployment  | iOS 26.0                                                  |
| Xcode version       | 26.6 (university Macs)                                    |
| Development OS      | Windows (Antigravity IDE) + university Macs for build/run |

---

## Key Design Principles

- **Platform separation**: HatchCore holds all game rules, reward maths, and progression logic. It has zero dependencies on UIKit, SwiftUI, Core Data, or SpriteKit, making it fully testable on any platform including Windows.
- **Testability first**: Business logic is exercised by Swift package tests before the Xcode project exists.
- **Honest productivity**: Task completion is self-reported; the reward structure incentivises flagging important tasks accurately.
- **No real-money or multiplayer**: All purchases use in-app gold only. All battles are offline and solo.

---

## Assignment Deliverables Tracked

- [ ] Three or more navigable screens
- [ ] Advanced UI and adaptive layouts
- [ ] Custom SwiftUI component or modifier
- [ ] Navigation
- [ ] Core Data persistence
- [ ] Meaningful framework integration (SpriteKit)
- [ ] Accessibility (Dark Mode, Dynamic Type, Reduce Motion, accessible controls)
- [ ] Unit, UI, and user acceptance tests
- [ ] Performance evaluation
- [ ] User guide, technical documentation, and written report
- [ ] GitHub source submission
- [ ] Factual AI-assistance records
- [ ] Third-party attribution
- [ ] Part B: visionOS/tvOS prototype and pitch *(tracked separately)*

---

## HatchCore Package

`Packages/HatchCore/` is a local Swift package containing platform-independent game rules.
It has **no** UIKit, SwiftUI, Core Data, or SpriteKit imports.

**Run tests** (requires Swift 5.9+ toolchain — use a Mac or install Swift for Windows):
```bash
swift test --package-path Packages/HatchCore
```

**Expected**: 13 tests pass, 0 failures.

**Mac first-session setup**: see [`docs/MAC_FIRST_SETUP.md`](docs/MAC_FIRST_SETUP.md)

---

## Development Notes

- All active development takes place directly on a single branch named `main` (no feature branches).
- Git mutations (commits, pushes, pulls) are made only upon explicit developer request. Commits remain small and descriptive.
- The Xcode project and Core Data model are created and managed **manually in Xcode** by the developer.
- `project.pbxproj` and shared scheme files are committed. Personal `xcuserdata/` is ignored.
- `Package.resolved` is committed to pin exact dependency versions.
- All AI assistance is logged factually in `docs/AI_ASSISTANCE.md`. No test outcomes or approvals are fabricated.

### Verification status (Milestones 0, 1, 2 & 3)

| Check | Result |
|---|---|
| HatchCore source reviewed | ✅ Source reviewed |
| `swift test` on Windows | ⚠️ Not executed — Swift toolchain absent on this machine |
| `swift test` on Mac | ✅ Passed (35 tests, 0 failures: Title validation, Rewards, Undo timing, Player progression, Focus timing) |
| Xcode build (simulator-target) | ✅ Passed (`xcodebuild` clean build on `Hatch` scheme with `HatchCore` linked) |
| Core Data disk persistence test | ✅ Passed (`PersistenceIntegrationTests` verified save and reload across stacks) |
| Core Data lightweight migration (V1->V2->V3) | ✅ Passed (`PersistenceIntegrationTests` verified tasks and player balances survive across V1, V2, and V3) |
| Undo & reconciliation integration test | ✅ Passed (`PersistenceIntegrationTests` verified 5s window, expiry boundary, and launch reconciliation) |
| Core Data save-failure rollback tests | ✅ Passed (`PersistenceIntegrationTests` verified task and focus session rollback without discarding unrelated edits) |
| Focus session lifecycle integration tests | ✅ Passed (`PersistenceIntegrationTests` verified single-session guard, pause/resume freeze, cancellation, and auto-completion) |
| Milestone 1 Manual Acceptance | ✅ Passed (Developer-reported: cancel, validation, single-save, restart persistence, second task) |
| Milestone 2 Manual Acceptance | ✅ Passed (Developer-confirmed: normal/important creation, instant completion feedback, undo within 5s, 5s expiry finalization, and background/relaunch reconciliation) |
| Milestone 3 Manual Acceptance | ✅ Passed (Developer-confirmed: all checks passed) |

> **Note on Git Status**: Milestone 3 checkpoint committed on `main`.

