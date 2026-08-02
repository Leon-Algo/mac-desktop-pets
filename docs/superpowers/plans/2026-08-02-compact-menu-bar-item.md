# Compact Menu-Bar Item Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the wide native `🐾 桌宠` status item with a tested square `🐾` control while preserving its menu, accessibility, health repair, and fallback route.

**Architecture:** Keep the change inside the existing AppKit-owned `StatusMenuController`. Use the system-defined square status-item length for both construction paths and expose only a read-only length value for tests.

**Tech Stack:** Swift 6, AppKit `NSStatusItem`, XCTest, Swift Package Manager.

## Global Constraints

- Support macOS 13 and later.
- Do not remove or alter shared menu commands, per-pet context menus, or the independent fallback control.
- Keep tooltip and accessibility meaning even though visible text is compact.
- Follow RED → GREEN → full verification before packaging.

---

### Task 1: Compact status-item contract

**Files:**
- Modify: `Tests/DesktopPetsTests/CommandRoutingTests.swift`
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`

**Interfaces:**
- Consumes: `StatusMenuController.init(target:)`, `statusButtonTitle`.
- Produces: `StatusMenuController.statusItemLength: CGFloat` and a square `🐾` status button.

- [ ] **Step 1: Write the failing test**

Change the shared-menu test to assert:

```swift
XCTAssertEqual(controller.statusButtonTitle, "🐾")
XCTAssertEqual(controller.statusItemLength, NSStatusItem.squareLength)
```

- [ ] **Step 2: Verify RED**

Run `swift test --filter CommandRoutingTests/testSharedMenuContainsGlobalAndFourCharacterControls` and confirm it fails because the title is still `🐾 桌宠` and `statusItemLength` does not exist.

- [ ] **Step 3: Implement the minimum AppKit change**

Create and recreate the status item with `NSStatusItem.squareLength`, set `button.title = "🐾"`, and expose `var statusItemLength: CGFloat { statusItem.length }`. Keep the existing tooltip, accessibility label, menu, and health policy.

- [ ] **Step 4: Verify GREEN and regressions**

Run the focused test, then `swift test`; both must pass.

- [ ] **Step 5: Update acceptance records and commit**

Record the compact control and final evidence in `docs/verification/final-acceptance.md`, `progress.md`, and `task_plan.md`, then commit the implementation.

### Task 2: Package and live verification

**Files:**
- Verify: `build/DesktopPets.app`
- Modify only if evidence changes: `docs/verification/final-acceptance.md`, `progress.md`

**Interfaces:**
- Consumes: packaged `DesktopPets.app` and `--inspect-running` diagnostic mode.
- Produces: a running ad-hoc-signed app with four pet windows and one fallback window.

- [ ] **Step 1: Run safety verification**

Run `swift test --sanitize=address` and `swift build -c release -Xswiftc -strict-concurrency=complete`.

- [ ] **Step 2: Package and validate**

Run `./Scripts/smoke-test.sh` and `codesign --verify --deep --strict --verbose=2 build/DesktopPets.app`. Require `petWindowCount: 4`, `fallbackControlPresent: true`, and nine successful interaction commands.

- [ ] **Step 3: Launch the final app**

Run `./script/build_and_run.sh`, wait for a healthy `--inspect-running` report, and leave that process running for user acceptance.

- [ ] **Step 4: Final repository check**

Run `git diff --check` and `git status --short`; commit any final documentation update and require a clean worktree.
