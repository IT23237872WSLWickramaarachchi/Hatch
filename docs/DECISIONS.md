# Hatch — Design Decisions

This document distinguishes **confirmed choices** from **provisional values**.

- **Confirmed**: Agreed upon, stable, and unlikely to change without a deliberate decision.
- **Provisional**: Placeholder numbers or rules that are intentionally adjustable. They are centralized in `GameBalance` in HatchCore. Change them there and the change propagates everywhere.
- **Deferred**: Decision not yet made; implementation is blocked or explicitly left for a later milestone.

---

## Architecture and Technology

| Decision                                      | Status    | Rationale                                                                                           |
|-----------------------------------------------|-----------|-----------------------------------------------------------------------------------------------------|
| Business logic in HatchCore (pure Swift pkg)  | Confirmed | Testable on Windows; no Mac or Xcode needed for unit tests; forces clean separation                 |
| SwiftUI for all app UI                        | Confirmed | Modern Apple UI framework; required by assignment context                                           |
| Core Data for persistence                     | Confirmed | Explicitly required; supports atomic transactions and relational data                               |
| SpriteKit for monster/battle animation        | Confirmed | Apple's game framework; appropriate for animated pixel-art; kept in iOS layer only                  |
| HatchCore has zero Apple-only dependencies    | Confirmed | Any violation breaks Windows testability and is treated as a bug                                    |
| No XcodeGen; project.pbxproj managed manually | Confirmed | University assessment requires demonstrable Xcode knowledge; tooling complexity avoided             |
| UserDefaults only for lightweight preferences | Confirmed | Durable progress always uses Core Data; UserDefaults is not a persistence replacement               |
| Minimum deployment target: iOS 26.0           | Confirmed | University Mac with Xcode 26.6                                                                      |
| No third-party dependency managers (CocoaPods, Carthage) | Confirmed | Swift Package Manager covers the local HatchCore package; no external dependencies planned currently |
| No multiplayer, backend accounts, or real-money IAP | Confirmed | Explicitly out of scope                                                                       |
| Single-branch `main` Git workflow             | Confirmed | Simplifies synchronization between Windows and Mac; clear linear history for assessment; no feature branches |

---

## Game Balance (All values are PROVISIONAL)

All the numbers below live in `Packages/HatchCore/Sources/HatchCore/GameBalance.swift`.
Changing them there changes them everywhere — in logic, tests, and the UI.
They are placeholders to unblock implementation; they will be tuned during playtesting.

### Task Rewards

| Task type | Gold reward | XP reward |
|-----------|-------------|-----------|
| Normal    | 10          | 20        |
| Important | 15          | 30        |

**Invariant (confirmed)**: Important tasks must always award at least as much as normal tasks. This is enforced by an assertion in `RewardCalculator`.

### Undo Window

| Property          | Value    |
|-------------------|----------|
| Window duration   | 5 seconds |

### Focus Session Rewards

| Property        | Rate         |
|-----------------|--------------|
| Gold per minute | 1            |
| XP per minute   | 2            |

Session reward = `floor(durationMinutes × rate)`. Snapshot at session start.

### Focus Session Durations

| Option  | Minutes |
|---------|---------|
| Short   | 15      |
| Default | 25      |
| Long    | 50      |

### Player Levelling

| Property                   | Value                                        |
|----------------------------|----------------------------------------------|
| Starting level             | 1                                            |
| Starting XP                | 0                                            |
| XP for level 1→2           | 100                                          |
| XP increment per level     | +50 over the preceding level's threshold     |

Formula (confirmed as the specification-defined rule):
```
xpRequired(currentLevel → next) = 100 + (currentLevel - 1) × 50
```

### Shop Items (Catalogue — Provisional)

| Item         | Section | Min Player Level | Cost (gold) |
|--------------|---------|------------------|-------------|
| Starter Egg  | Eggs    | 1                | 50          |
| Fire Egg     | Eggs    | TBD              | TBD         |
| Ice Egg      | Eggs    | TBD              | TBD         |
| Basic Food   | Food    | 1                | TBD         |
| Premium Food | Food    | TBD              | TBD         |

### Monster Evolution Thresholds

| Monster type | Food required | Focus sessions required |
|--------------|---------------|-------------------------|
| All          | TBD           | TBD                     |

Evolution thresholds are deferred until Milestone 5 when monster art and form data are finalized.

### Battle Rewards

Rewards per opponent are deferred until Milestone 7.

### Boss Gate Requirements

| Property                  | Rule                                              |
|---------------------------|---------------------------------------------------|
| Player level gate         | Specific minimum level per boss (TBD, Milestone 7)|
| Milestone prerequisite    | All non-boss fights in the preceding milestone    |

---

## Undo Mechanism

| Property                                    | Status    | Notes                                                                  |
|---------------------------------------------|-----------|------------------------------------------------------------------------|
| Pending rewards cannot be spent or levelled | Confirmed | Prevents the undo from un-spending already-spent gold                  |
| Finalization is idempotent                  | Confirmed | Processed flag in Core Data; checked before every finalize call        |
| Finalized tasks cannot be re-opened         | Confirmed | Initially; may revisit for edit support in a later milestone            |
| Deadline persisted as a timestamp           | Confirmed | Relaunch reconciliation depends on this                                 |
| Reward history preserved on archive/delete  | Confirmed | Gold and XP permanently awarded are never reversed                      |

---

## Focus Sessions

| Property                                          | Status    | Notes                                                       |
|---------------------------------------------------|-----------|-------------------------------------------------------------|
| Timer persists start timestamp, not tick count    | Confirmed | Survives process suspension and relaunch                    |
| Paused intervals tracked and excluded             | Confirmed | `pausedDuration` accumulated each time session is paused    |
| One active session at a time                      | Confirmed | New session attempt while one is active is blocked in UI    |
| Session does not auto-complete linked task        | Confirmed | Independent reward events                                   |
| Session duration snapshotted at start             | Confirmed | Rate changes mid-session have no effect                     |
| Cancelled sessions earn no reward                 | Confirmed |                                                             |

---

## App Blocking (FamilyControls)

| Property                            | Status   | Notes                                                                              |
|-------------------------------------|----------|------------------------------------------------------------------------------------|
| Implementation decision             | Deferred | Pending entitlement approval and real-device availability                          |
| Simulator testing                   | N/A      | FamilyControls cannot be Simulator-tested; must not be claimed as verified         |
| Focus timer independent of blocking | Confirmed | The 25-minute focus timer works regardless of whether blocking is implemented      |

---

## SpriteKit

| Property                                    | Status    | Notes                                                                    |
|---------------------------------------------|-----------|--------------------------------------------------------------------------|
| Kept in iOS app target only                 | Confirmed | HatchCore never imports SpriteKit                                        |
| Used for monster animation and battle UI    | Confirmed |                                                                          |
| Reduce Motion respected                     | Confirmed | Animations skipped or simplified when `reduceMotion` accessibility is on |
| No additional frameworks added for count    | Confirmed | Only frameworks that serve a real purpose are included                   |

---

## Part B — visionOS / tvOS

Decisions for Part B are tracked separately and will be added when Part B work begins.

---

## Revision History

| Version | Date       | Change                                |
|---------|------------|---------------------------------------|
| 0.1     | 2026-10-16 | Initial creation from project brief   |
| 0.2     | 2026-10-16 | Adopt single-branch `main` Git workflow |
