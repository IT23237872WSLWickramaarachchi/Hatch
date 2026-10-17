# Hatch — Project Specification

**Version**: 0.1 (Initialization)
**Date**: 2026-10-16
**Module**: Mobile Application Development and Design (MADD), SLIIT Year 4 Semester 1
**Status**: Living document — updated at each milestone

---

## 1. Product Purpose

Hatch motivates users to complete meaningful tasks and focus sessions by rewarding them with in-app gold, player XP, and monster progression.

**Core reward loop**:

```
Complete tasks and focus sessions
  → earn gold and XP
  → gain player levels
  → unlock and purchase eggs and food
  → raise monsters
  → progress through offline battles
```

No real-money purchases. No multiplayer. No backend accounts.

---

## 2. Environment and Platform

| Property           | Value                                              |
|--------------------|----------------------------------------------------|
| Language           | Swift                                              |
| UI Framework       | SwiftUI                                            |
| Persistence        | Core Data (iOS app target only)                    |
| Monster/battle UI  | SpriteKit (iOS app target only)                    |
| Business logic     | HatchCore — local Swift package (platform-free)    |
| Minimum deployment | iOS 26.0                                           |
| Xcode version      | 26.6                                               |
| Test destination   | Compatible iPhone Simulator                        |
| Dev machine        | Windows (Antigravity IDE); build on university Mac |

HatchCore **must not** import UIKit, SwiftUI, Core Data, SpriteKit, or any Apple-only framework. This constraint is enforced on every PR.

---

## 3. Repository Structure

```
Hatch/                   <- repository root (this folder)
├── .gitignore
├── README.md
├── PROJECT_SPEC.md      <- this file
├── docs/
│   ├── ROADMAP.md
│   ├── DECISIONS.md
│   └── AI_ASSISTANCE.md
├── Packages/
│   └── HatchCore/       <- Swift package; Milestone 0
└── App/
    └── Hatch/           <- Xcode project at App/Hatch/Hatch.xcodeproj (Milestone 1)
```

**Rules**:
- Every Hatch file lives inside the `Hatch/` root.
- `project.pbxproj` and shared Xcode schemes are committed.
- `xcuserdata/`, `DerivedData/`, and build products are git-ignored.
- `Package.resolved` is committed to pin resolved versions.

**Git Workflow Rules**:
- Single branch named `main` for all development; no feature branches.
- Git mutations (commits, pushes, pulls) are executed only upon explicit developer instruction.
- Commits are kept small, atomic, and descriptive.
- Pulls are fast-forward only (`--ff-only`). Force-pushing, discarding changes, or rewriting history is prohibited unless explicitly authorized.

---

## 4. Task Completion

### 4.1 Task Model

Each task has:
- A **title** (user-supplied string).
- An **Important** boolean flag.
- A **stable identity** (UUID) so each occurrence is unambiguous.

Completion is **honesty-based** (no verification mechanism).

### 4.2 Rewards

| Task type   | Gold | XP |
|-------------|------|----|
| Normal      | 10   | 20 |
| Important   | 15   | 30 |

> **PROVISIONAL** — values are placeholders subject to balancing. See `docs/DECISIONS.md`.

Important tasks must always award at least as much as normal tasks (invariant enforced in HatchCore).

### 4.3 Undo Window

The undo mechanism prevents accidental completion from permanently altering state:

1. **Immediate feedback**: The UI shows a completion indicator the moment the user taps.
2. **Pending state**: Rewards are *pending* — gold cannot be spent; XP cannot unlock levels — for exactly **5 seconds**.
3. **Undo cancels everything**: Tapping Undo during the window reverts completion, discards pending rewards, and resets the task.
4. **Finalization**: The deadline is persisted. When it expires (or after relaunch if already past), the task is finalized exactly once, and rewards become permanent.
5. **Post-finalization**: Finalized tasks cannot be re-opened initially. Reward history is preserved if the record is later archived or deleted.
6. **Relaunch reconciliation**: On app launch, any unfinalized deadlines that have already passed are finalized immediately.

Finalizing the same task twice must be impossible (enforced by a processed flag and idempotency in HatchCore).

---

## 5. Focus Sessions

### 5.1 Session Model

| Property       | Value                                      |
|----------------|--------------------------------------------|
| Default length | 25 minutes                                 |
| Choices        | 15 min, 25 min, 50 min                     |
| Max active     | One at a time                              |
| Task link      | Optional; a session may reference one task |

### 5.2 Controls

Start → Pause → Resume → Cancel (or natural completion).

### 5.3 Timer Persistence

The app persists **start timestamp** and **paused duration** rather than counting ticks. On background or relaunch, elapsed time is computed from wall-clock difference minus any paused interval. This prevents the timer from losing time when the OS suspends the process.

### 5.4 Rewards

```
Reward per session = floor(snapshotDurationMinutes × goldPerMinute) gold
                   + floor(snapshotDurationMinutes × xpPerMinute) XP
```

> **PROVISIONAL rates**: 1 gold/min, 2 XP/min. See `docs/DECISIONS.md`.

- Rewards are **snapshot** at session start — changing global rates mid-session has no effect.
- Award exactly once per completed session.
- Cancellation earns nothing.
- Paused time is excluded from the elapsed count.
- Completing the session and the optional linked task each earn their own, independent rewards.
- Sessions do not auto-complete their linked task.

### 5.5 Relaunch Reconciliation

On launch, any interrupted active session is checked:
- If sufficient time has passed for natural completion → finalize as completed.
- If the session was cancelled (or user chooses to cancel) → discard.
- If still in progress → resume from correct elapsed position.

---

## 6. Player Progression

### 6.1 Starting State

| Property     | Value       |
|--------------|-------------|
| Starting XP  | 0           |
| Starting gold| 0           |
| Starting level| 1          |
| Starter egg  | Granted once|

### 6.2 Levelling Formula

```
XP required for level N (cumulative from level 1):
  Level 1→2:  100 XP
  Each subsequent level requires 50 more XP than the one before it.

  General rule:
    threshold(n) = 100 + (n-2) × 50    for n >= 2
    cumulative(N) = sum of threshold(n) for n = 2..N

Equivalently:
  xpForNextLevel(currentLevel) = 100 + (currentLevel - 1) × 50
```

> **Example**: 1→2: 100 XP, 2→3: 150 XP, 3→4: 200 XP, ...

- The app stores **cumulative XP** and derives the current level from it.
- Multiple level-ups from one reward event are handled in a single pass.
- Player level gates shop items and bosses.
- Player level **does not** automatically increase monster combat stats.

### 6.3 Gold

- **Finalized gold** is spendable.
- **Pending gold** (inside an undo window) cannot be spent.
- Gold is never converted to XP or vice versa.

### 6.4 Starter Egg

Granted exactly once — on first launch — and recorded in persistent state to prevent duplication across reinstalls (within the same Core Data store).

---

## 7. Shop

Two sections, in order:

1. **Eggs** — Fire Egg, Ice Egg, plus the starter egg option.
2. **Food** — two food types (names and stats: provisional).

### 7.1 Purchase Rules

- Items are gated by **player level** (minimum level to see/buy).
- Unlocking an item does not grant it free; the player must have sufficient finalized gold.
- Validation before every purchase: level sufficient → gold sufficient → item available → quantity valid.
- Gold deduction and inventory addition occur **atomically** (in one Core Data save).
- Duplicate processing of one purchase action is prevented (idempotency guard).
- Quantities are persisted.

### 7.2 Initial Item Catalogue (Provisional)

| Item         | Section | Min level | Cost (gold) | Notes               |
|--------------|---------|-----------|-------------|---------------------|
| Starter Egg  | Eggs    | 1         | 50          | Placeholder          |
| Fire Egg     | Eggs    | TBD       | TBD         | Placeholder          |
| Ice Egg      | Eggs    | TBD       | TBD         | Placeholder          |
| Basic Food   | Food    | 1         | TBD         | Placeholder          |
| Premium Food | Food    | TBD       | TBD         | Placeholder          |

All values marked TBD are confirmed provisional. See `docs/DECISIONS.md`.

---

## 8. Monsters

### 8.1 Form Progression

```
Egg → Base Monster → Evolved Monster
```

Each monster has exactly these three states. There is no further evolution.

### 8.2 Evolution

Evolution requires:
- A minimum quantity of food items consumed.
- A minimum number of completed focus sessions (counts tracked per monster).

> **Specific thresholds**: TBD before Milestone 5. Marked provisional in `docs/DECISIONS.md`.

Evolution is **independent of player levelling**.

### 8.3 Ownership and Identity

- Each owned monster instance has a stable UUID.
- The **Sanctuary** displays up to two user-selected monsters.

### 8.4 Art

Use supplied art when available. Use clearly labelled placeholder images otherwise. Do not use copyrighted third-party art without attribution.

### 8.5 Types (initial scope)

- Fire
- Ice

---

## 9. SpriteKit Integration

SpriteKit is used **exclusively in the iOS app target** for:

- Animated sanctuary monsters.
- Tap reactions.
- Hatching and evolution effects.
- Battle attack animations and result presentation.

SpriteKit scenes may call into HatchCore for game-state queries. HatchCore must not import SpriteKit.

This integration is accurately described as Apple's game framework (part of the Apple SDK), included because the app includes interactive animated game content. The assignment includes the Games category in its framework list; grading interpretation is the lecturer's responsibility.

---

## 10. Battles

### 10.1 Overview

- Offline, turn-based combat (no real-time, no network).
- Teams of 1–4 monsters.
- Fire and Ice types initially; type advantages apply.
- Predefined opponents on a **milestone map** with escalating difficulty.

### 10.2 Boss Requirements

To challenge a boss, the player must satisfy both:
1. Minimum player level.
2. Completion of the preceding milestone battle.

### 10.3 Session Interaction

- Battles take place **outside** active focus sessions (short matches).
- Monsters have Tired/Resting states; completing focus sessions accelerates recovery.

### 10.4 Rewards and Replay

- Win rewards: gold and XP (amounts: TBD per opponent).
- Interruption rule: if a battle is abandoned mid-way, no reward is granted for that attempt.
- Replay: already-defeated opponents may be replayed for reduced or no reward (exact rule: TBD).

### 10.5 Tutorial

An optional battle tutorial is planned. Exact trigger and content: TBD.

### 10.6 Exclusions

- No multiplayer.
- No wagering or real-money transactions.
- No backend accounts or server-side state.

---

## 11. App Blocking (Provisional Investigation)

The following Apple frameworks will be investigated separately before committing to an implementation:

- `FamilyControls` — requires a special entitlement; **cannot** be tested in the Simulator.
- `ManagedSettings` — applies content restrictions during focus sessions.
- `DeviceActivity` — monitors app usage and triggers callbacks.

**Constraints**:
- Do not fake blocking with a timer overlay.
- The standard focus timer must function independently of blocking.
- Simulator-only testing will not be presented as real-device verification.
- Implementation is gated on entitlement approval and real-device testing availability.

---

## 12. Architecture

### 12.1 Layers

```
┌─────────────────────────────────────┐
│  SwiftUI Views                      │  UI only; no business logic
├─────────────────────────────────────┤
│  Feature ViewModels / State Objects │  Thin; delegate rules to HatchCore
├─────────────────────────────────────┤
│  Core Data (iOS layer)              │  Persistence; entity ↔ model mapping
├─────────────────────────────────────┤
│  HatchCore (Swift package)          │  Pure Swift; all game rules and maths
└─────────────────────────────────────┘
SpriteKit scenes sit alongside SwiftUI at the iOS layer.
```

### 12.2 HatchCore

- **No** Apple-only framework imports.
- Contains: reward calculations, levelling formula, session timing logic, undo state machine, battle rules, monster form progression rules, shop validation.
- Fully covered by Swift package unit tests (runnable on Windows via `swift test`).

### 12.3 State Management

- **Core Data**: durable progress (tasks, sessions, monsters, inventory, player state).
- **UserDefaults**: lightweight preferences only (e.g., preferred session duration).

### 12.4 Balancing Values

All numerical game-balance constants live in a single `GameBalance` structure inside HatchCore, clearly marked provisional. No magic numbers scattered through feature code.

---

## 13. Visual and Accessibility Direction

- Modern, uncluttered functional UI.
- Cozy pixel-art monsters and scenery.
- Clear hierarchy and readable typography.
- Compact gold balance visible throughout.
- Player level grouped with an XP progress bar.
- One combined reward message per completion event.
- Crisp pixel-art scaling (no blurring of low-resolution sprites).
- Full **Dark Mode** support.
- **Dynamic Type** for all text.
- All interactive controls are accessible (minimum 44 × 44 pt tap targets, accessibility labels).
- **Reduce Motion**: optional particle and animation effects are skipped or simplified.

### 13.1 Navigation Destinations (initial)

1. Home (task list and player summary).
2. Focus.
3. Shop.

Sanctuary and Battle screens added in later milestones.

---

## 14. Testing Plan (high-level)

| Layer       | Tool                   | Coverage target                             |
|-------------|------------------------|---------------------------------------------|
| HatchCore   | Swift package tests    | All reward, level, session, and shop rules  |
| iOS app     | XCTest unit tests      | ViewModel / state-object logic              |
| iOS app     | XCUITest               | Key user flows (task add, complete, undo)   |
| Performance | XCTest metrics         | List rendering and Core Data fetch time     |

Testing infrastructure is set up in Milestone 0. App-level tests are added alongside each feature milestone.

---

## 15. Verification Standards

Claims in this project use the following explicit terms:

| Term                      | Meaning                                               |
|---------------------------|-------------------------------------------------------|
| Source reviewed           | Code has been read and is logically consistent        |
| swift test passed         | `swift test` ran on the Swift package with zero failures |
| Xcode build passed        | Developer ran a clean build in Xcode with zero errors |
| Simulator verified        | Developer ran the feature in the Simulator            |
| Device tested             | Feature confirmed on a physical iOS device            |

No claim implies a stronger verification than actually performed.

---

## 16. Part B — visionOS / tvOS Prototype

A separate visionOS or tvOS prototype and accompanying pitch is required for Part B of the assignment. It is tracked independently from this iOS implementation. Details will be added when Part B work begins.

---

## 17. Revision History

| Version | Date       | Author         | Notes                        |
|---------|------------|----------------|------------------------------|
| 0.1     | 2026-10-16 | Initialization | Created from user brief      |
