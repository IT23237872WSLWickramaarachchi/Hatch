# Hatch 🥚

**Hatch** is a native iOS productivity app with a collectible-monster game, built as a university assignment for the Mobile Application Development and Design (MADD) module, Year 4 Semester 1.

Hatch motivates users to complete meaningful tasks and focus sessions by rewarding them with gold, player XP, and monster progression.

> Complete tasks and focus sessions → earn gold and XP → gain player levels →
> unlock and buy eggs and food → raise monsters → progress through offline battles.

---

## Current Status

| Milestone | Description                                          | Status         |
|-----------|------------------------------------------------------|----------------|
| 0         | Project specification, documentation, HatchCore setup | 🔄 In Progress |
| 1         | Xcode project, task creation, Core Data persistence  | ⏳ Pending     |
| 2         | Task completion, gold/XP, undo window                | ⏳ Pending     |
| 3         | Focus sessions, player levels                        | ⏳ Pending     |
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
└── App/                        <- reserved for manually created Xcode project (Milestone 1)
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

## Development Notes

- The Xcode project and Core Data model are created and managed **manually in Xcode** by the developer.
- `project.pbxproj` and shared scheme files are committed. Personal `xcuserdata/` is ignored.
- `Package.resolved` is committed to pin exact dependency versions.
- All AI assistance is logged factually in `docs/AI_ASSISTANCE.md`. No test outcomes or approvals are fabricated.
