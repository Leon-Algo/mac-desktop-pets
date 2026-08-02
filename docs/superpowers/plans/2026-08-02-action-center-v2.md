# Action Center V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a discoverable typed action center with four distinct per-person actions, one group action, and immediate non-modal feedback.

**Architecture:** Pure Swift catalog and request/outcome types define the action contract. `PetWorld` remains the behavior source of truth, AppKit menus emit typed requests, and `WorldRunner` bridges outcomes into per-window Core Animation feedback bubbles. Existing panels and the shared native menu remain the only UI surfaces.

**Tech Stack:** Swift 6, SwiftPM, XCTest, AppKit `NSMenu`, Core Animation `CALayer`/`CATextLayer`, existing deterministic world engine.

## Global Constraints

- Support macOS 13 and later with no new runtime dependency, permission, network request, or entitlement.
- Keep the compact square `🐾` menu-bar item and independent `🐾 总台` recovery route.
- Use exact visible copy from the approved design; never expose internal state names.
- Preserve 25%, 50%, and 100% pet sizes and keep feedback text readable at every preset.
- Global pause rejects manual actions without changing the preference; per-person pause is cleared by a direct action.
- Every production behavior change follows a witnessed XCTest RED → GREEN cycle.

---

### Task 1: Typed action catalog and feedback state

**Files:**
- Create: `Sources/DesktopPets/Interaction/PetActionCatalog.swift`
- Create: `Sources/DesktopPets/Rendering/FeedbackBubbleState.swift`
- Create: `Tests/DesktopPetsTests/PetActionCatalogTests.swift`
- Create: `Tests/DesktopPetsTests/FeedbackBubbleStateTests.swift`

**Interfaces:**
- Produces: `PetActionID`, `PetActionScope`, `PetActionDefinition`, `PetActionRequest`, `PetActionOutcome`, and `PetActionCatalog`.
- Produces: `FeedbackBubbleState.show(message:) -> UInt64` and `dismiss(generation:)`.

- [x] **Step 1: Write catalog RED tests**

Assert the exact stable action order and metadata:

```swift
XCTAssertEqual(PetActionCatalog.individual.map(\.id), [.wave, .hop, .roll, .sleep])
XCTAssertEqual(PetActionCatalog.group.map(\.id), [.gatherPlay])
XCTAssertEqual(PetActionCatalog.individual.map(\.title), [
    "👋 打个招呼", "⬆️ 原地跳一下", "🙈 翻个跟头", "💤 趴下睡觉",
])
XCTAssertTrue(PetActionCatalog.all.allSatisfy { !$0.explanation.isEmpty && $0.duration > 0 })
XCTAssertEqual(Set(PetActionCatalog.all.map(\.id)).count, PetActionCatalog.all.count)
```

- [x] **Step 2: Run catalog RED**

Run `swift test --filter PetActionCatalogTests`. Expected: compilation fails because the catalog types do not exist.

- [x] **Step 3: Implement the catalog**

Define exact cases `wave`, `hop`, `roll`, `sleep`, and `gatherPlay`. Provide immutable definitions with scope, title, explanation, feedback, and duration. Use durations 1.8, 1.4, 1.4, 4.0, and 2.0 seconds respectively. `PetActionRequest` contains `actionID: PetActionID` and `targetID: String?`. `PetActionOutcome` has:

```swift
enum PetActionOutcome: Equatable, Sendable {
    case performed(affectedIDs: [String], feedback: String, duration: Double)
    case unavailable(targetID: String?, feedback: String, duration: Double)
}
```

- [x] **Step 4: Write and verify feedback-state RED**

Create a test where showing message A, then B, then dismissing A's generation leaves B visible; dismissing B clears it. Run `swift test --filter FeedbackBubbleStateTests` and confirm the missing-type failure.

- [x] **Step 5: Implement feedback generation state and verify GREEN**

Implement a value type holding `message: String?` and monotonically increasing `generation`. `show(message:)` increments and returns the generation. `dismiss(generation:)` clears only when it matches. Run both new test classes and then `swift test`.

- [x] **Step 6: Commit catalog slice**

Commit with `feat: define desktop pet action catalog`.

---

### Task 2: Deterministic manual actions in the world

**Files:**
- Modify: `Sources/DesktopPets/Interaction/PetInteraction.swift`
- Modify: `Sources/DesktopPets/World/PetState.swift`
- Modify: `Sources/DesktopPets/World/PetAgent.swift`
- Modify: `Sources/DesktopPets/World/PetWorld.swift`
- Modify: `Tests/DesktopPetsTests/PetInteractionTests.swift`
- Modify: `Tests/DesktopPetsTests/PetWorldTests.swift`

**Interfaces:**
- Consumes: `PetActionRequest`, `PetActionCatalog.definition(for:)`, `PetActionOutcome`.
- Produces: `PetInteraction.performAction(PetActionRequest)` and `PetInteractionResult.action(PetActionOutcome)`.
- Produces: `PetState.roll` and `PetAgent.manualActionID: PetActionID?`.

- [x] **Step 1: Write individual-action RED tests**

For one target, issue each typed request and assert outcomes/states:

```swift
let cases: [(PetActionID, PetState)] = [
    (.wave, .greet), (.hop, .jump), (.roll, .roll), (.sleep, .sleep),
]
for (actionID, state) in cases {
    var world = makeWorld()
    let result = world.handle(
        .performAction(PetActionRequest(actionID: actionID, targetID: "person-left")),
        obstacles: map
    )
    guard case .action(.performed(let ids, _, _)) = result else { return XCTFail() }
    XCTAssertEqual(ids, ["person-left"])
    XCTAssertEqual(world.poses.first { $0.id == "person-left" }?.state, state)
}
```

- [x] **Step 2: Run individual-action RED**

Run `swift test --filter PetInteractionTests/testManualActionsEnterDistinctStates`. Expected: compilation fails because `performAction` and `roll` are absent.

- [x] **Step 3: Implement typed routing and states**

Add `.performAction(PetActionRequest)` and `.action(PetActionOutcome)`. Validate definition scope and target. For individual commands: clear target per-person pause, zero velocity, set `manualActionID`, then transition to greet/jump/roll/sleep. Hop sets `velocity.dy = 240` while retaining horizontal zero. A group request delegates to the existing gather logic and returns all affected IDs.

- [x] **Step 4: Write pause, invalid, and expiry RED tests**

Cover:

- global pause returns unavailable text `当前已暂停，请先继续活动` and leaves the pose unchanged;
- a per-person paused target resumes and moves through the requested action;
- a missing target or mismatched group target returns unavailable without mutation;
- wave returns to crawl after 1.8 seconds, roll after 1.4 seconds, and manual sleep after 4 seconds;
- roll pose phase reaches approximately 0.5 after 0.7 seconds and never snaps at 1 second.

- [x] **Step 5: Implement duration and phase rules**

Store `manualActionID` on `PetAgent`. In `PetAgent.pose`, use `min(stateTime / 1.4, 1)` for manual roll phase and the existing repeating phase otherwise. In `substep`, apply catalog duration only when `manualActionID` matches the state, then transition to crawl and clear the marker. Landing clears manual hop through the normal transition.

- [x] **Step 6: Verify world GREEN and regressions**

Run `swift test --filter PetInteractionTests`, `swift test --filter PetWorldTests`, then `swift test`.

- [x] **Step 7: Commit world slice**

Commit with `feat: add deterministic manual pet actions`.

---

### Task 3: Discoverable shared and context menus

**Files:**
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`
- Modify: `Sources/DesktopPets/App/AppController.swift`
- Modify: `Sources/DesktopPets/Rendering/PetSpriteView.swift`
- Modify: `Tests/DesktopPetsTests/CommandRoutingTests.swift`
- Modify: `Tests/DesktopPetsTests/PetViewInteractionTests.swift`

**Interfaces:**
- Consumes: `PetActionCatalog.individual`, `PetActionCatalog.group`, and typed `PetActionRequest` represented objects.
- Produces: `AppController.performPetAction(_:)` and nested `NSMenu` action surfaces.

- [x] **Step 1: Write shared-menu RED tests**

Assert a top-level `动作中心` exists. Verify its person menus are ordered `格子衫`, `黑背心`, `薄荷衫`, `黑外套`; each contains the four exact individual titles and typed requests for that person. Verify `🎉 四人集合玩耍` stores a request with `targetID == nil`. Verify every item tooltip equals its catalog explanation.

- [x] **Step 2: Run shared-menu RED**

Run `swift test --filter CommandRoutingTests/testSharedMenuExposesDiscoverableActionCenter`. Expected: failure because no `动作中心` item exists.

- [x] **Step 3: Implement shared menus and selector routing**

Add `动作中心` after `召回四人`. Replace `做个动作` in each character management menu with a `让他做动作…` submenu. Build action items through one helper that assigns `target`, `representedObject`, and `toolTip`. Implement `performPetAction(_:)` to validate a typed request and call `runner?.handle(.performAction(request))`.

- [x] **Step 4: Write context-menu RED tests**

Build a `PetSpriteView` context menu and assert `让他做动作…` contains the same four definitions, no visible title equals `做个动作`, and invoking the first submenu item's target/action emits `.performAction(.init(actionID: .wave, targetID: petIdentifier))`.

- [x] **Step 5: Implement the context submenu and verify GREEN**

Replace `reactFromMenu` with typed action routing. Keep single-click mapped to `.react` for backward-compatible direct greeting and double-click mapped to group play. Run `swift test --filter CommandRoutingTests`, `swift test --filter PetViewInteractionTests`, then `swift test`.

- [x] **Step 6: Commit menu slice**

Commit with `feat: add discoverable desktop pet action menus`.

---

### Task 4: Motion rendering and transient feedback bubbles

**Files:**
- Modify: `Sources/DesktopPets/Rendering/PetSpriteView.swift`
- Modify: `Sources/DesktopPets/Rendering/PetWindowCoordinator.swift`
- Modify: `Sources/DesktopPets/App/WorldRunner.swift`
- Modify: `Tests/DesktopPetsTests/PetViewInteractionTests.swift`
- Modify: `Tests/DesktopPetsTests/PanelConfigurationTests.swift`
- Modify: `Tests/DesktopPetsTests/WorldRunnerInteractionTests.swift`

**Interfaces:**
- Consumes: `PetActionOutcome` from `PetInteractionResult.action`.
- Produces: `PetSpriteView.showFeedback(message:duration:)`, `activeFeedbackText`, and `PetWindowCoordinator.showFeedback(for:message:duration:)`.

- [x] **Step 1: Write rendering and feedback RED tests**

Verify:

- applying `.roll` at phase 0.5 produces a transform distinct from crawl and approximately π radians of rotation;
- `showFeedback` immediately sets `activeFeedbackText`;
- a second message replaces the first;
- feedback font remains at least 11 points after `setRenderScale(0.25)`;
- the coordinator exposes feedback only for the requested identifier.

- [x] **Step 2: Run rendering RED**

Run `swift test --filter PetViewInteractionTests` and `swift test --filter PanelConfigurationTests/testCoordinatorRoutesFeedbackToOnePet`. Expected: missing feedback APIs and no roll transform.

- [x] **Step 3: Implement Core Animation presentation**

Add a rounded bubble background layer and centered `CATextLayer` above `petLayer`. Use system font size 11 or larger, a high-contrast dynamic background, and fixed readable sizing independent of `renderScale`. Update its position when the panel size changes. `showFeedback` uses `FeedbackBubbleState`, cancels/replaces a pending `DispatchWorkItem`, and dismisses only the matching generation.

For `.roll`, rotate by `direction * phase * 2 * .pi` and add a small sinusoidal vertical bounce. Keep existing transforms for all other states.

- [x] **Step 4: Write runner RED tests**

Hide one person, issue its wave request, and assert hidden count returns to zero, its panel becomes visible, and the coordinator reports `嗨！`. Issue group play after hiding two people and assert all panels visible and all affected feedback is present. Issue a command during global pause and assert the pause explanation is shown without state change.

- [x] **Step 5: Implement outcome bridging**

In `WorldRunner.handle`, process `.action` results. For performed outcomes, remove affected IDs from `hiddenPetIDs`, show their panels, apply poses, and forward feedback/duration. For unavailable outcomes with a target, show that panel's feedback without altering visibility preferences. Extend diagnostics with `activeFeedbackCount`.

- [x] **Step 6: Verify rendering/runner GREEN**

Run the three modified suites and then `swift test`.

- [x] **Step 7: Commit presentation slice**

Commit with `feat: show pet action motion and feedback`.

---

### Task 5: Acceptance records and release verification

**Files:**
- Modify: `Sources/DesktopPets/App/DesktopPetsApplication.swift`
- Modify: `Tests/DesktopPetsTests/AppLaunchTests.swift`
- Modify: `docs/verification/final-acceptance.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Interfaces:**
- Produces: interaction self-test coverage for four manual actions plus group play.

- [x] **Step 1: Extend interaction self-test RED**

Add the four individual action requests and one group request to `InteractionSelfTest.run()`. Update the expected command count and assert every result is handled/action-performed. Run `swift test --filter AppLaunchTests/testInteractionSelfTestExercisesCommandsAndPreservesFourFinitePets` and confirm the old command count fails.

- [x] **Step 2: Implement self-test reporting and verify GREEN**

Count typed action outcomes as successful commands and keep the finite four-pet invariant. Run `swift test --filter AppLaunchTests` and `swift test`.

- [ ] **Step 3: Run complete safety suite**

Run:

```bash
swift test
swift test --sanitize=address
swift build -c release -Xswiftc -strict-concurrency=complete
./Scripts/smoke-test.sh
codesign --verify --deep --strict --verbose=2 build/DesktopPets.app
```

Require zero failures, strict build success, `status: ok`, four pet windows, the fallback controller, and strict signature validity.

- [ ] **Step 4: Run and inspect the ordinary app**

Run `./script/build_and_run.sh`, wait for `DesktopPets`, inspect it with `--inspect-running`, and verify four uniformly sized pet windows plus the fallback. Leave the final app running.

- [ ] **Step 5: Record acceptance and finish**

Update the acceptance matrix with action catalog/menu/feedback evidence and exact test counts. Mark Phase 10 complete. Run `git diff --check`, commit with `docs: record action center acceptance`, and require `git status --short` to be empty.
