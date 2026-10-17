# Mac First-Session Setup Guide — Hatch Milestone 0

**Audience**: You, the developer, working on a university Mac with Xcode 26.6.
**Goal**: Clone the repository, verify the toolchain, run HatchCore tests, create the Xcode project, and set up the Core Data model correctly.

> **Read this entirely before touching Xcode.**
> Steps are sequential. Skipping ahead causes errors that are harder to fix
> than the steps themselves.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| **Terminal** | Type this in the macOS Terminal (or Xcode's built-in terminal) |
| **Xcode** | Do this inside the Xcode application using its UI |
| **You decide** | You choose or type a value; the exact text matters |
| ✅ | Expected result — verify before continuing |

---

## Part 1 — Clone or Update the Repository

### First time on this Mac (repository not yet cloned)

**Terminal:**
```bash
# Navigate to wherever you keep university projects, e.g.:
cd ~/Developer

# Clone using HTTPS — you will be prompted for your GitHub credentials.
git clone https://github.com/IT23237872WSLWickramaarachchi/Hatch.git

cd Hatch
```

✅ You should see the repository files: `.gitignore`, `README.md`, `PROJECT_SPEC.md`, `docs/`, `Packages/`.

### Already cloned (returning to this Mac)

**Terminal:**
```bash
cd ~/Developer/Hatch   # adjust path to match your clone location

# Check the current branch and working-tree state first (must be on main).
git status
git branch

# Fast-forward-only pull from origin main.
git fetch origin
git merge --ff-only origin/main
```

If `merge --ff-only` fails with "Not possible to fast-forward", **stop** and report the error. Do not force or reset.

---

## Part 2 — Verify the Toolchain

**Terminal:**
```bash
xcode-select --print-path
swift --version
xcodebuild -version
```

✅ Expected output (approximate):
```
/Applications/Xcode.app/Contents/Developer
swift-driver version: ... Swift version 6.x.x
Xcode 26.6
Build version ...
```

If `swift --version` shows a version older than 5.9, stop and ask for help — the package manifest requires 5.9+.

### Check available simulators

**Terminal:**
```bash
xcrun simctl list runtimes
```

✅ You should see an iOS 26 runtime listed. If it is absent:

**Xcode → Settings (⌘,) → Platforms** — download the iOS 26 simulator runtime.

---

## Part 3 — Run HatchCore Tests

This is the Milestone 0 verification step. Run it **before** creating the Xcode project.

**Terminal:**
```bash
# From the repository root:
swift test --package-path Packages/HatchCore
```

✅ Expected output ends with something like:
```
Test Suite 'All tests' passed at ...
     Executed 13 tests, with 0 failures (0 unexpected) in ... seconds
```

If any tests **fail**, stop. Do not proceed to Xcode setup until the failure is understood and fixed.

If the command itself fails (`command not found: swift`), confirm that `xcode-select --print-path` points to Xcode 26.6's developer directory.

---

## Part 4 — Create the Xcode Project

> **Critical rule**: The Xcode project lives **inside** the existing Git repository.
> You are **not** creating a new folder with its own `.git`. You are adding
> project files to an already-initialized repository.

### 4.1 Open Xcode and start a new project

**Xcode:** File → New → Project...

### 4.2 Choose the template

- Filter: **iOS** (top tab).
- Template: **App**.
- Click **Next**.

### 4.3 Fill in the project options

Fill in each field **exactly** as shown:

| Field | Value |
|---|---|
| Product Name | `Hatch` |
| Team | Your university Apple ID / team (select from the dropdown) |
| Organization Identifier | `com.sliit.madd` (or your own reverse-domain; keep it consistent) |
| Bundle Identifier | auto-filled based on above — confirm it is reasonable |
| Interface | **SwiftUI** |
| Language | **Swift** |
| Storage | **None** ← Important: we add Core Data manually in step 6 |
| Include Tests | ☑ checked |

Click **Next**.

### 4.4 Choose the save location — critical step

A file panel opens asking where to save the project.

1. Navigate to the `Hatch` repository root (e.g. `~/Developer/Hatch`).
2. Open the `App` folder. If it does not exist yet, create it now: click **New Folder**, name it `App`.
3. **Uncheck** "Create Git repository on my Mac" — a repository already exists.
4. Click **Create**.

✅ The project file is now at `Hatch/App/Hatch/Hatch.xcodeproj`. No second `.git` folder should have been created inside `App/`. Confirm:

**Terminal:**
```bash
ls Hatch/App/Hatch/
# Expected: Hatch.xcodeproj   Hatch/   HatchTests/   HatchUITests/
ls Hatch/App/.git 2>/dev/null && echo "ERROR: nested repo found" || echo "OK: no nested repo"
```

---

## Part 5 — Run the Starter App

Before adding any feature code, confirm the unmodified Xcode template compiles and launches.

**Xcode:**
1. Select the `Hatch` scheme from the scheme picker (top-left toolbar).
2. Select a simulator: **iPhone 16** (or any compatible iOS 26 device).
3. Press **⌘R** (Run).

✅ A simulator window opens showing "Hello, world!" (the default SwiftUI template content). No errors in the Issue Navigator.

If the build fails here, fix the build environment (signing, simulator runtime) before continuing. Nothing else is usable until a clean build is confirmed.

---

## Part 6 — Add HatchCore as a Local Package Dependency

**What we are doing**: Telling Xcode that the iOS app should compile and link against the HatchCore Swift package that already exists in `Packages/HatchCore/`.

### 6.1 Add the local package to the workspace

**Xcode:** File → Add Package Dependencies...

- In the dialog, click **Add Local...** (bottom-left of the dialog).
- Navigate to `Hatch/Packages/HatchCore/` and click **Add Package**.

✅ Xcode resolves the package and shows `HatchCore` in the Package Dependencies section of the Project Navigator (left sidebar).

### 6.2 Link HatchCore to the app target

A sheet asks which targets should link against HatchCore.

- Check `Hatch` (the app target).
- Leave `HatchTests` and `HatchUITests` unchecked for now (they can be added when we write iOS-layer tests).
- Click **Add Package**.

✅ In **Project Settings → Hatch target → General → Frameworks, Libraries, and Embedded Content**, `HatchCore` appears.

### 6.3 Smoke test the link

Open `ContentView.swift`. At the top, add temporarily:

```swift
import HatchCore
```

**Xcode:** Press **⌘B** (Build only, no run).

✅ Build succeeds with no errors. Remove the temporary import line — this was only a link check.

---

## Part 7 — Create the Core Data Model

> **What a Core Data model is**: A `.xcdatamodeld` file is a schema — it
> describes tables (called *Entities*) and their columns (called *Attributes*).
> Xcode generates Swift class files from it automatically. You do **not**
> write those classes by hand.
>
> **Important**: Creating the model file does **not** by itself save or load
> anything. The actual persistence code (the `NSPersistentContainer` setup
> and fetch logic) is written in Milestone 1.

### 7.1 Create the Data Model file

**Xcode:** File → New → File from Template...

- Filter or scroll to find **Core Data → Data Model**.
- Click **Next**.
- Name the file exactly: `HatchModel`
  (Xcode appends `.xcdatamodeld` automatically — do not type the extension).
- Save location: inside the `App/Hatch/` source folder (alongside `ContentView.swift`).
- **Target membership**: check only the `Hatch` app target. Do not add it to `HatchTests` or `HatchUITests`.
- Click **Create**.

✅ `HatchModel.xcdatamodeld` appears in the Project Navigator under the `Hatch` group.

### 7.2 Create the TaskEntity entity

Click `HatchModel.xcdatamodeld` to open the Core Data model editor.

At the bottom of the editor, click **Add Entity**.

- Rename the entity from `Entity` to exactly: `TaskEntity`

> Why `TaskEntity` and not `Task`? Swift already has a `Task` type in its
> concurrency library. Naming our entity `TaskEntity` avoids a name collision
> that can cause confusing compile errors.

### 7.3 Add attributes to TaskEntity

With `TaskEntity` selected, click the **+** button in the Attributes section and add each attribute:

| Name | Type |
|---|---|
| `id` | UUID |
| `title` | String |
| `createdAt` | Date |

For each attribute, ensure **Optional** is **unchecked** in the Data Model Inspector (right panel) — these three fields are required for every task record.

> **Model Optionality vs. Swift Optional Types**: In Xcode's Class Definition codegen, generated properties (such as `var title: String?`, `var id: UUID?`, `var createdAt: Date?`) are declared as Swift optionals because Core Data managed objects can exist in unpopulated or faulted states in memory prior to persistence validation. This does not mean the underlying model attribute is optional; non-optional validation (`isOptional == false`) is enforced by Core Data when the managed object context performs a save.

> **UUID** is a built-in Core Data attribute type that stores a 128-bit universally unique identifier. We use it instead of an auto-increment integer because UUIDs remain stable and unique even if records are created on multiple devices or databases are merged.

### 7.4 Configure code generation

With `TaskEntity` still selected, open the **Data Model Inspector** (View menu → Inspectors → Data Model, or the right-panel icon).

Set:
- **Codegen**: `Class Definition`
- **Module**: `Current Product Module`

> **Class Definition** means Xcode generates the Swift `NSManagedObject`
> subclass for you automatically (in `DerivedData/`) every time you build.
> You will **not** see the generated file in the Project Navigator — that is
> correct and intentional. Do not create a `TaskEntity.swift` file manually;
> it would duplicate the generated class and produce a compiler error
> ("redeclaration of `TaskEntity`").

### 7.5 Verify the model

**Xcode:** Press **⌘B**.

✅ Build succeeds. The model editor should show `TaskEntity` with all three attributes, no warnings.

---

## Part 8 — Commit the Xcode Project and Model Files

> You are in control of all Git operations. This section tells you what to
> commit, not commands to paste blindly.

### 8.1 Check what is new

**Terminal (from the repository root):**
```bash
git status
```

You should see untracked or staged/unstaged files under `App/Hatch/`. The important ones to commit:

```
App/Hatch/Hatch.xcodeproj/project.pbxproj          ← the project graph
App/Hatch/Hatch/                                   ← source files, assets, and HatchModel
App/Hatch/HatchTests/                              ← test stubs
App/Hatch/HatchUITests/                            ← UI test stubs
```

The following should **not** appear (they are `.gitignore`-d):
- `App/Hatch/Hatch.xcodeproj/xcuserdata/` — personal user state, excluded by `.gitignore`.
- `DerivedData/` — build artifacts, excluded by `.gitignore`.

> **Note on `project.xcworkspace`**: The internal folder `Hatch.xcodeproj/project.xcworkspace/` is excluded by the `.gitignore` rule `*.xcworkspace`. In a standalone single-project setup without custom shared schemes, `contents.xcworkspacedata` simply points to `self:` and is recreated automatically by Xcode when the project is opened. It does not need to be force-tracked.

### 8.2 Stage the right files

```bash
git add App/Hatch/Hatch.xcodeproj/project.pbxproj
git add App/Hatch/Hatch/
git add App/Hatch/HatchTests/
git add App/Hatch/HatchUITests/
```

### 8.3 Review before committing

```bash
git diff --cached --stat
```

Verify no `xcuserdata/`, no `DerivedData/`, no `.env` or signing files appear.

### 8.4 Commit

```bash
git commit -m "feat(milestone-1-setup): add Xcode project and HatchModel Core Data schema

- App/Hatch/Hatch.xcodeproj: iOS SwiftUI app, iOS 26.0 minimum, HatchCore linked
- App/Hatch/Hatch/HatchModel.xcdatamodeld: TaskEntity with id (UUID), title (String),
  createdAt (Date); non-optional attributes; Class Definition codegen
- App/Hatch/HatchTests/, App/Hatch/HatchUITests/: test stubs

iOS simulator build: confirmed clean (xcodebuild succeeded).
swift test HatchCore: 13 passed, 0 failures."
```

---

## What Happens Next (Milestone 1)

The setup above gives you:
- A running SwiftUI app (still showing "Hello, world!").
- A Core Data schema with one entity.
- HatchCore linked but not yet called.

**Milestone 1 will add** (written collaboratively):
- A task list screen using `@FetchRequest` to read `TaskEntity` records.
- An add-task sheet with a title field and Important toggle.
- An `NSPersistentContainer` that opens the `HatchModel` store.
- Saving new tasks and verifying they survive an app restart.

**You do not write any of that now.** Confirm the simulator launches the starter app, then stop. The feature code is Milestone 1.
