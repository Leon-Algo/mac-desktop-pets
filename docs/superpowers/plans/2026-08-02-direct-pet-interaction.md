# Direct Pet Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add discoverable shutdown guidance and direct shape-aware interaction with each desktop pet.

**Architecture:** AppKit views emit narrow `PetInteraction` commands through the existing window coordinator to `WorldRunner`. The deterministic world remains the source of truth for pet state and location, while panels own only event routing, hit masks, context menus, and visibility.

**Tech Stack:** Swift 6.3, AppKit, Core Animation, Core Graphics, XCTest, SwiftPM.

## Global Constraints

- Minimum macOS version remains 13.0.
- Add no third-party dependency or new privacy permission.
- Transparent regions must remain click-through in interactive mode.
- Every production behavior begins with a failing test.
- Preserve the existing menu-bar Quit path and geometry-only privacy model.

---

### Task 1: Interaction domain commands and world behavior

**Files:**
- Create: `Sources/DesktopPets/Interaction/PetInteraction.swift`
- Modify: `Sources/DesktopPets/World/PetWorld.swift`
- Test: `Tests/DesktopPetsTests/PetInteractionTests.swift`

**Interfaces:**
- Produces `PetInteraction` cases for react, group play, drag, release, toggle pause, recall, and hide.
- Produces `PetWorld.handle(_:obstacles:) -> PetInteractionResult`.

- [x] Write failing tests for reaction, group gathering, per-pet pause, recall, drag, release, and unknown identifiers.
- [x] Run `swift test --filter PetInteractionTests` and confirm failures are caused by missing interaction APIs.
- [x] Implement minimal deterministic world mutations and result values.
- [x] Run the targeted and full suites.
- [x] Commit the independently tested domain behavior.

### Task 2: Shape-aware panel hit testing and click routing

**Files:**
- Create: `Sources/DesktopPets/Interaction/ClickInterpreter.swift`
- Create: `Sources/DesktopPets/Rendering/PetAlphaMask.swift`
- Modify: `Sources/DesktopPets/Rendering/PetSpriteView.swift`
- Modify: `Sources/DesktopPets/Rendering/PetWindowCoordinator.swift`
- Test: `Tests/DesktopPetsTests/PetViewInteractionTests.swift`

**Interfaces:**
- Produces `ClickInterpreter.register(clickCount:) -> ClickDisposition`.
- Produces `PetAlphaMask.containsOpaquePixel(normalizedPoint:) -> Bool`.
- Produces coordinator callback `(PetInteraction) -> Void` and `updateMouseAcceptance(at:fullyClickThrough:)`.

- [x] Write failing tests for transparent/opaque mask locations, delayed-single cancellation, double-click routing, and full pass-through override.
- [x] Run the targeted tests and confirm the expected failures.
- [x] Implement alpha-mask lookup, click delay/cancellation, drag lifecycle, and context-menu actions.
- [x] Connect views and panels through one coordinator callback without global monitors.
- [x] Run the targeted and full suites, then commit.

### Task 3: Runner routing, per-pet visibility, and discoverability

**Files:**
- Modify: `Sources/DesktopPets/App/WorldRunner.swift`
- Modify: `Sources/DesktopPets/App/AppController.swift`
- Modify: `Sources/DesktopPets/App/PreferencesStore.swift`
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`
- Test: `Tests/DesktopPetsTests/PreferencesTests.swift`
- Test: `Tests/DesktopPetsTests/CommandRoutingTests.swift`

**Interfaces:**
- Consumes coordinator interaction callbacks.
- Produces one-time control hint and interactive-mode defaults.

- [x] Write failing tests for the new default, one-time hint persistence, global restore semantics, and menu wording.
- [x] Run targeted tests and confirm expected failures.
- [x] Route world/panel results, preserve dragging acceptance, and display the first-launch paw-menu hint once.
- [x] Run targeted and full suites, then commit.

### Task 4: Diagnostic self-test and packaged runtime verification

**Files:**
- Modify: `Sources/DesktopPets/App/CommandLineMode.swift`
- Modify: `Sources/DesktopPets/App/DesktopPetsApplication.swift`
- Modify: `Scripts/smoke-test.sh`
- Modify: `docs/verification/final-acceptance.md`
- Test: `Tests/DesktopPetsTests/AppLaunchTests.swift`

**Interfaces:**
- Produces `--interaction-self-test` JSON confirming every interaction command preserves four finite pet states.

- [x] Write the failing command-line parsing and report tests.
- [x] Implement the self-test using the real world and interaction router.
- [x] Run normal tests, AddressSanitizer, strict-concurrency Release build, packaging, signature checks, smoke test, and interaction self-test.
- [x] Update acceptance evidence and planning records.
- [x] Commit the verified interaction release.
