# “叫爸爸”动作替换 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the manual sleep and group-play commands with typed individual and group “叫爸爸” actions while retaining autonomous sleeping.

**Architecture:** Rename the catalog IDs so domain semantics match the UI, map the individual command to a short jump, and reuse group gathering for the collective command. Existing typed outcomes continue driving per-pet feedback bubbles and visibility restoration.

**Tech Stack:** Swift 6, SwiftPM, AppKit, Core Animation, XCTest

## Global Constraints

- Keep macOS 13+ support and add no dependency.
- Keep autonomous `.sleep` world behavior intact.
- Use `爸爸！` as the visible feedback for both new actions.
- Add no sound in this iteration.

---

### Task 1: Typed catalog and world behavior

**Files:**
- Modify: `Tests/DesktopPetsTests/PetActionCatalogTests.swift`
- Modify: `Tests/DesktopPetsTests/PetInteractionTests.swift`
- Modify: `Sources/DesktopPets/Interaction/PetActionCatalog.swift`
- Modify: `Sources/DesktopPets/World/PetWorld.swift`

**Interfaces:**
- Produces: `PetActionID.callDad`, `PetActionID.groupCallDad`
- Preserves: `PetActionOutcome.performed(affectedIDs:feedback:duration:)`

- [ ] **Step 1: Write failing catalog and routing tests**

Expect individual IDs `[.wave, .hop, .roll, .callDad]`, group ID `[.groupCallDad]`, labels `📣 叫爸爸` and `📣 四人一起喊爸爸`, individual state `.jump`, and group feedback `爸爸！` for all character IDs.

- [ ] **Step 2: Run tests to verify RED**

Run: `swift test --filter 'PetActionCatalogTests|PetInteractionTests'`
Expected: compilation failure because `callDad` and `groupCallDad` do not exist.

- [ ] **Step 3: Implement the minimal semantic replacement**

Rename the enum cases and catalog definitions. Route `.callDad` to `.jump` with the existing hop velocity and route `.groupCallDad` through existing group gather behavior. Use a short deterministic duration.

- [ ] **Step 4: Run focused tests to verify GREEN**

Run: `swift test --filter 'PetActionCatalogTests|PetInteractionTests'`
Expected: all selected tests pass.

### Task 2: Menu, self-test, documentation, and release verification

**Files:**
- Modify: `Tests/DesktopPetsTests/CommandRoutingTests.swift`
- Modify: `Tests/DesktopPetsTests/PetInteractionTests.swift`
- Modify: `Sources/DesktopPets/App/DesktopPetsApplication.swift`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: `PetActionID.callDad`, `PetActionID.groupCallDad`
- Verifies: persistent action center, per-pet feedback, packaged self-test

- [ ] **Step 1: Write failing menu and runner expectations**

Require `📣 叫爸爸`, `📣 四人一起喊爸爸`, typed represented objects using the new IDs, and four active `爸爸！` feedback bubbles after the group action.

- [ ] **Step 2: Run tests to verify RED**

Run: `swift test --filter 'CommandRoutingTests|WorldRunnerInteractionTests'`
Expected: failures until menus and routing consume the renamed catalog entries.

- [ ] **Step 3: Update packaged self-test and acceptance records**

Replace old `.sleep` and `.gatherPlay` requests with the new IDs. Record focused and final verification evidence in project planning files.

- [ ] **Step 4: Run final verification**

Run normal and AddressSanitizer test suites, strict-concurrency Release build, packaging script, deep code-sign verification, packaged smoke/self-test, and live running-window inspection.
Expected: every command succeeds, exactly four pet windows plus the fallback control are reported, and the ordinary app remains running.

- [ ] **Step 5: Commit the completed behavior change**

Commit the tests, implementation, and updated project records together with a focused feature message.
