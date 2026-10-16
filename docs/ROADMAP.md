# Hatch — Development Roadmap

Each milestone has a goal, a list of deliverables, and a "what you will learn" section so the implementation is also an educational progression.

---

## Milestone 0 — Windows Preparation (Current)

**Goal**: Everything that can be done on Windows before touching Xcode — spec, docs, HatchCore scaffold, and tests.

### Deliverables
- [x] `.gitignore` (Xcode + Swift package aware)
- [x] `README.md`
- [x] `PROJECT_SPEC.md`
- [x] `docs/ROADMAP.md` (this file)
- [x] `docs/DECISIONS.md`
- [x] `docs/AI_ASSISTANCE.md`
- [ ] `Packages/HatchCore/` — Swift package scaffold
- [ ] `GameBalance.swift` — centralized balancing constants
- [ ] `RewardCalculator.swift` — task and session reward logic
- [ ] `PlayerProgression.swift` — levelling formula
- [ ] `UndoState.swift` — undo state machine
- [ ] HatchCore unit tests (runnable via `swift test` on Windows)
- [ ] Git repository initialized and initial commit made
- [ ] Mac setup guide (`docs/MAC_SETUP.md`) with exact Xcode steps

### What you will learn
- Why we isolate business logic in a separate Swift package.
- How `swift test` works without Xcode or a Mac.
- The levelling formula as an equation before it becomes code.
- The undo state machine modelled explicitly before it becomes UI.

---

## Milestone 1 — Manual Xcode Setup and First App (Mac Required)

**Goal**: A working iOS app that lets you create tasks, displays them in a list, and persists them in Core Data after app restarts.

### Deliverables
- [ ] Xcode project created manually at `App/Hatch.xcodeproj`
- [ ] Core Data model file (`Hatch.xcdatamodeld`) with `TaskItem` entity
- [ ] `ContentView` showing a task list with an add button
- [ ] `AddTaskView` with title field and Important toggle
- [ ] Core Data `NSPersistentContainer` setup in the app
- [ ] Tasks persist across app restarts
- [ ] HatchCore linked as a local package dependency
- [ ] Xcode build passes; app runs in Simulator

### What you will learn
- How `NSPersistentContainer` and `@FetchRequest` connect Core Data to SwiftUI.
- What a Core Data entity and attribute are, and how they map to Swift objects.
- How to link a local Swift package into an Xcode project.
- The SwiftUI `List` and `NavigationStack` patterns.

---

## Milestone 2 — Task Completion, Gold, XP, and Undo (Mac Required)

**Goal**: Mark tasks complete, earn gold and XP, and support a 5-second undo window that safely rolls back if triggered.

### Deliverables
- [ ] `CompletionPending` state stored in Core Data
- [ ] Undo countdown UI element (5-second window)
- [ ] Pending gold/XP clearly distinguished from finalized in the UI
- [ ] Finalization persisted and reconciled on relaunch
- [ ] HatchCore unit tests for the undo state machine
- [ ] Player gold and XP displayed on Home screen

### What you will learn
- Why we persist the deadline rather than trust a timer.
- How to handle relaunch reconciliation (app killed during a pending window).
- Idempotency: ensuring a task cannot be finalized twice even under edge conditions.

---

## Milestone 3 — Focus Sessions and Player Levels (Mac Required)

**Goal**: Run focus sessions with a persistent wall-clock timer; award gold and XP on completion; compute and display player level.

### Deliverables
- [ ] `FocusSession` entity in Core Data
- [ ] Focus screen with duration picker and session controls
- [ ] Timestamp-based timer that survives backgrounding and relaunch
- [ ] Session completion reward (snapshot at start)
- [ ] Player level computed from cumulative XP
- [ ] Level-up animation (respects Reduce Motion)
- [ ] HatchCore tests for levelling formula and session reward calculation

### What you will learn
- Why timestamps are more reliable than tick counters for timers.
- How `scenePhase` lets you respond to app backgrounding in SwiftUI.
- How to derive a value (level) from stored data (cumulative XP) rather than caching it.

---

## Milestone 4 — Shop and Inventory (Mac Required)

**Goal**: Purchase eggs and food using finalized gold; persist inventory; validate level and gold atomically.

### Deliverables
- [ ] `ShopItem` catalogue (static data, not Core Data)
- [ ] `Inventory` entity in Core Data (quantity per item type)
- [ ] Shop screen with Eggs and Food sections
- [ ] Level gate: items visible only at sufficient player level
- [ ] Atomic purchase transaction (deduct gold + add inventory in one Core Data save)
- [ ] Duplicate purchase prevention (idempotency guard)
- [ ] HatchCore tests for shop validation logic

### What you will learn
- Why some data is static (catalogue) vs dynamic (inventory).
- What an atomic transaction means and why it prevents inconsistent states.
- How to present sectioned lists in SwiftUI.

---

## Milestone 5 — Hatching and Evolution (Mac Required)

**Goal**: Incubate eggs from inventory; track monster state (Egg → Base → Evolved); meet food and focus thresholds to evolve.

### Deliverables
- [ ] `Monster` entity in Core Data with form, focusSessions count, foodConsumed count
- [ ] Incubation mechanic (egg becomes base monster after threshold)
- [ ] Evolution check in HatchCore (pure logic, no UI)
- [ ] Evolution trigger in app after meeting thresholds
- [ ] Placeholder sprites or supplied art for each form
- [ ] HatchCore tests for evolution eligibility

### What you will learn
- How to model a state machine (Egg → Base → Evolved) in Core Data.
- The difference between game logic (HatchCore) and persistence (Core Data).
- Why evolution thresholds live in `GameBalance` and are easy to tune.

---

## Milestone 6 — Interactive Sanctuary and Pet Selection (Mac Required)

**Goal**: Display up to two selected monsters in a SpriteKit scene with idle animations and tap reactions.

### Deliverables
- [ ] `SanctuaryScene.swift` — SpriteKit scene embedded via `SpriteView`
- [ ] Idle animation for base and evolved monster sprites
- [ ] Tap reaction (animation + sound optional)
- [ ] Monster selection UI (choose up to two from owned monsters)
- [ ] Reduce Motion respected (skip or simplify animations)

### What you will learn
- How `SpriteView` embeds a SpriteKit scene in SwiftUI.
- The SpriteKit action system (`SKAction.sequence`, `repeatForever`).
- How to pass data from SwiftUI state into a SpriteKit scene.

---

## Milestone 7 — Offline Battles and Boss Progression (Mac Required)

**Goal**: Implement turn-based combat on a milestone map with predefined opponents, type advantages, and boss gates.

### Deliverables
- [ ] `BattleEngine` in HatchCore (pure Swift, no UI)
- [ ] Type advantage table (Fire vs Ice)
- [ ] Milestone map data (opponents, rewards, boss requirements)
- [ ] `BattleScene.swift` — SpriteKit scene for attack animations and result
- [ ] Monster Tired/Resting state and focus-session recovery
- [ ] HatchCore unit tests for battle outcomes and boss gate logic

### What you will learn
- Turn-based game loop as a pure function (deterministic, testable).
- How to present SpriteKit animations that are driven by HatchCore results.
- Why keeping game rules in HatchCore lets you test battle outcomes without a running app.

---

## Milestone 8 — App Blocking Investigation (Conditional, Device Required)

**Goal**: Investigate FamilyControls and ManagedSettings; implement if entitlement is obtainable; document findings honestly.

### Deliverables
- [ ] Research doc: `docs/APP_BLOCKING.md` with entitlement requirements and simulator limitations
- [ ] Implementation (conditional on entitlement approval and device access)
- [ ] Documented limitation: Simulator cannot verify real blocking

### What you will learn
- How FamilyControls works at the OS level and why it cannot be Simulator-tested.
- The difference between verifiable and unverifiable claims.

---

## Milestone 9 — Testing, Polish, Documentation, and Demonstration (Mac Required)

**Goal**: Full test suite, performance evaluation, user guide, technical report, and screen-recorded demonstration video.

### Deliverables
- [ ] Complete HatchCore unit test suite
- [ ] XCTest unit tests for iOS ViewModels
- [ ] XCUITest suite for key user flows
- [ ] XCTest performance metrics (list scroll, Core Data fetch)
- [ ] `docs/USER_GUIDE.md`
- [ ] `docs/TECHNICAL_REPORT.md`
- [ ] Final `docs/AI_ASSISTANCE.md` audit
- [ ] Third-party attribution file
- [ ] Screen-recorded demonstration video
- [ ] GitHub repository prepared for submission

---

## Part B — visionOS / tvOS Prototype (Tracked Separately)

Requirements and timeline for the Part B prototype and pitch will be added when Part B work begins. This is tracked independently from the iOS implementation milestones above.
