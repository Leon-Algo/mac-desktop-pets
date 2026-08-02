# Persistent Control Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a labeled menu-bar control center plus a launch-visible floating fallback that can always pause, restore, configure, and quit Desktop Pets, including after all four characters are hidden.

**Architecture:** `AppController` coordinates one shared dynamic menu, `WorldRunner` publishes per-character control snapshots, and typed UI commands travel from pet context menus back to the controller. A replaceable status item uses a pure bounded health policy, while a focused `ControlCenterPanelController` owns the independent non-activating fallback panel.

**Tech Stack:** Swift 6.3, AppKit, Core Animation, OSLog, SwiftPM, XCTest, ServiceManagement, shell packaging with ad-hoc code signing.

## Global Constraints

- Support macOS 13 and later.
- Keep the application activation policy `.accessory`; no Dock icon or modal first-run activation-policy switch.
- Keep character assets, simulation, obstacle behavior, privacy footprint, and empty entitlements unchanged.
- Use one shared `NSMenu` for the status item and fallback panel.
- Always show `🐾 总台` on launch; hiding all characters must show it again.
- Never claim pixel-level status-item visibility from AppKit lifecycle properties.
- Use `Logger` without personal data.
- Follow red-green-refactor for every production behavior.

---

### Task 1: Pure control state and bounded status-item health policy

**Files:**
- Create: `Sources/DesktopPets/App/PetControlSnapshot.swift`
- Create: `Sources/DesktopPets/App/StatusItemHealthPolicy.swift`
- Modify: `Sources/DesktopPets/World/PetWorld.swift`
- Modify: `Sources/DesktopPets/App/WorldRunner.swift`
- Create: `Tests/DesktopPetsTests/ControlCenterStateTests.swift`

**Interfaces:**
- Produces: `PetControlState(id:displayName:isHidden:isPaused:)` and `WorldRunner.controlSnapshot`.
- Produces: `StatusItemHealthSnapshot(isMarkedVisible:hasButton:hasWindow:)` with `isHealthy`.
- Produces: `StatusItemHealthPolicy.observe(_:) -> StatusItemHealthAction`, where the action is `.none`, `.recreate`, or `.showFallback`.
- Produces: `PetWorld.isPaused(id:) -> Bool`.

- [x] **Step 1: Write failing snapshot tests**

```swift
func testControlSnapshotReportsPerPetHiddenAndPausedState() {
    // Toggle one pause and one hide, then assert exact IDs and booleans.
}

func testStatusHealthPolicyRepairsOnceThenFallsBackUntilRecovery() {
    var policy = StatusItemHealthPolicy()
    let unhealthy = StatusItemHealthSnapshot(isMarkedVisible: true, hasButton: true, hasWindow: false)
    XCTAssertEqual(policy.observe(unhealthy), .recreate)
    XCTAssertEqual(policy.observe(unhealthy), .showFallback)
    XCTAssertEqual(policy.observe(unhealthy), .showFallback)
    XCTAssertEqual(policy.observe(.healthy), .none)
    XCTAssertEqual(policy.observe(unhealthy), .recreate)
}
```

- [x] **Step 2: Run the focused tests and verify RED**

Run: `swift test --filter ControlCenterStateTests`

Expected: compile failure because the new state and health types do not exist.

- [x] **Step 3: Add minimal state and policy implementations**

Implement immutable `Sendable, Equatable` snapshots, expose per-agent paused state from `PetWorld`, and combine world state with `hiddenPetIDs` in `WorldRunner`.

- [x] **Step 4: Run focused and full tests and verify GREEN**

Run: `swift test --filter ControlCenterStateTests && swift test`

Expected: all tests pass.

- [x] **Step 5: Commit**

Run: `git add Sources/DesktopPets/App/PetControlSnapshot.swift Sources/DesktopPets/App/StatusItemHealthPolicy.swift Sources/DesktopPets/World/PetWorld.swift Sources/DesktopPets/App/WorldRunner.swift Tests/DesktopPetsTests/ControlCenterStateTests.swift && git commit -m "feat: model desktop pet control state"`

### Task 2: Shared dynamic menu and typed UI command routing

**Files:**
- Create: `Sources/DesktopPets/App/ControlCenterCommand.swift`
- Modify: `Sources/DesktopPets/Interaction/PetInteraction.swift`
- Modify: `Sources/DesktopPets/Rendering/PetSpriteView.swift`
- Modify: `Sources/DesktopPets/Rendering/PetWindowCoordinator.swift`
- Modify: `Sources/DesktopPets/App/WorldRunner.swift`
- Modify: `Sources/DesktopPets/App/AppController.swift`
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`
- Modify: `Tests/DesktopPetsTests/CommandRoutingTests.swift`
- Modify: `Tests/DesktopPetsTests/PetViewInteractionTests.swift`

**Interfaces:**
- Consumes: `WorldRunner.controlSnapshot` from Task 1.
- Produces: `ControlCenterCommand` cases for global and per-character operations.
- Produces: `StatusMenuController.refresh(preferences:characters:)`.
- Produces: `WorldRunner.onControlStateChange` and `WorldRunner.onUICommand` callbacks.

- [x] **Step 1: Write failing menu-model and context-command tests**

```swift
func testCharacterMenuStateUsesDisplayNameAndVisibilityPauseLabels() {
    let state = PetControlState(id: "person-left", displayName: "左侧人物", isHidden: true, isPaused: true)
    XCTAssertEqual(state.visibilityTitle, "显示")
    XCTAssertEqual(state.pauseTitle, "继续")
}

@MainActor
func testPetContextMenuContainsGlobalRecoveryAndQuitCommands() {
    let view = PetSpriteView(frame: .init(x: 0, y: 0, width: 180, height: 160), character: CharacterCatalog.fallback.characters[0])
    let titles = view.menu(for: syntheticRightClick)!.items.map(\.title)
    XCTAssertTrue(titles.contains("召回四人"))
    XCTAssertTrue(titles.contains("打开总台"))
    XCTAssertTrue(titles.contains("退出桌面伙伴"))
}
```

- [x] **Step 2: Run focused tests and verify RED**

Run: `swift test --filter CommandRoutingTests && swift test --filter PetViewInteractionTests`

Expected: compile/assertion failures for absent character state labels and context entries.

- [x] **Step 3: Implement typed routing and the shared dynamic menu**

Add UI command cases to the interaction channel, route simulation commands through `WorldRunner`, route `openControlCenter` and `quit` to `AppController`, and rebuild the one shared menu from current preferences plus character snapshots. The main status button title must be `🐾 桌宠` with a variable length.

- [x] **Step 4: Run focused and full tests and verify GREEN**

Run: `swift test --filter CommandRoutingTests && swift test --filter PetViewInteractionTests && swift test`

Expected: all tests pass.

- [x] **Step 5: Commit**

Run: `git add Sources/DesktopPets/App/ControlCenterCommand.swift Sources/DesktopPets/Interaction/PetInteraction.swift Sources/DesktopPets/Rendering/PetSpriteView.swift Sources/DesktopPets/Rendering/PetWindowCoordinator.swift Sources/DesktopPets/App/WorldRunner.swift Sources/DesktopPets/App/AppController.swift Sources/DesktopPets/App/StatusMenuController.swift Tests/DesktopPetsTests/CommandRoutingTests.swift Tests/DesktopPetsTests/PetViewInteractionTests.swift && git commit -m "feat: add shared desktop pet control menu"`

### Task 3: Floating fallback panel and lifecycle recovery

**Files:**
- Create: `Sources/DesktopPets/App/ControlCenterPanelController.swift`
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`
- Modify: `Sources/DesktopPets/App/AppController.swift`
- Modify: `Sources/DesktopPets/App/PreferencesStore.swift`
- Modify: `Tests/DesktopPetsTests/PanelConfigurationTests.swift`
- Modify: `Tests/DesktopPetsTests/PreferencesTests.swift`

**Interfaces:**
- Consumes: the shared `NSMenu` and health policy from Tasks 1–2.
- Produces: `ControlCenterPanelController.show()`, `hide()`, `toggle()`, `isVisible`, and `reposition(on:)`.
- Produces: `StatusMenuController.checkHealth()` and `StatusMenuController.diagnostics`.

- [x] **Step 1: Write failing fallback panel and non-modal guidance tests**

```swift
@MainActor
func testControlPanelIsNonactivatingAvailableOnAllSpacesAndAccessible() {
    let controller = ControlCenterPanelController(menu: NSMenu())
    XCTAssertTrue(controller.panel.styleMask.contains(.nonactivatingPanel))
    XCTAssertTrue(controller.panel.collectionBehavior.contains(.canJoinAllSpaces))
    XCTAssertEqual(controller.button.title, "🐾 总台")
    XCTAssertFalse(controller.panel.canBecomeKey)
}

func testControlHintCopyNamesBothControlRoutes() {
    XCTAssertTrue(ControlHintPolicy.guidance.contains("🐾 桌宠"))
    XCTAssertTrue(ControlHintPolicy.guidance.contains("🐾 总台"))
}
```

- [x] **Step 2: Run focused tests and verify RED**

Run: `swift test --filter PanelConfigurationTests && swift test --filter PreferencesTests`

Expected: compile failures because the fallback controller and non-modal guidance string do not exist.

- [x] **Step 3: Implement the panel, health checks, and startup behavior**

Create a borderless non-activating utility panel using `NSVisualEffectView` and an accessible button. Place it within `NSScreen.main?.visibleFrame`, show it on launch, connect it to the shared menu, observe Space/screen/app activation notifications, apply one bounded status-item recreation, and replace the modal first-run alert with the launch-visible control route plus concise guidance in the fallback tooltip. When global hide becomes true, always call `show()` on the fallback.

- [x] **Step 4: Run focused and full tests and verify GREEN**

Run: `swift test --filter PanelConfigurationTests && swift test --filter PreferencesTests && swift test`

Expected: all tests pass.

- [x] **Step 5: Commit**

Run: `git add Sources/DesktopPets/App/ControlCenterPanelController.swift Sources/DesktopPets/App/StatusMenuController.swift Sources/DesktopPets/App/AppController.swift Sources/DesktopPets/App/PreferencesStore.swift Tests/DesktopPetsTests/PanelConfigurationTests.swift Tests/DesktopPetsTests/PreferencesTests.swift && git commit -m "feat: add persistent floating pet control center"`

### Task 4: Telemetry, packaging, and live acceptance

**Files:**
- Modify: `Sources/DesktopPets/App/AppController.swift`
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`
- Modify: `Sources/DesktopPets/App/ControlCenterPanelController.swift`
- Modify: `Sources/DesktopPets/App/CommandLineMode.swift` only if the existing inspector cannot report control surfaces.
- Modify: `Tests/DesktopPetsTests/AppLaunchTests.swift` only if the inspector contract changes.
- Modify: `docs/verification/final-acceptance.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: all prior tasks.
- Produces: menu-bar/fallback diagnostics and filtered `OSLog` events under subsystem `com.codex.DesktopPets`, category `ControlCenter`.

- [x] **Step 1: Add a failing diagnostics assertion if a new inspector field is required**

Assert that packaged inspection reports status-item AppKit health, fallback visibility, and four character control states without claiming pixel visibility.

- [x] **Step 2: Run the focused test and verify RED, then add minimal diagnostics/telemetry**

Run: `swift test --filter AppLaunchTests`

Expected: the new diagnostic keys are absent before implementation and present afterward.

- [x] **Step 3: Run complete automated verification**

Run: `swift test`

Run: `swift test --sanitize=address`

Run: `swift build -c release -Xswiftc -strict-concurrency=complete`

Expected: zero failures and exit status 0 for every command.

- [x] **Step 4: Package, sign, and smoke-test**

Run: `./script/build_and_run.sh --verify`

Run: `codesign --verify --deep --strict --verbose=2 build/DesktopPets.app`

Expected: packaged inspection returns `status: ok`; signing verification exits 0.

- [x] **Step 5: Exercise live controls on the current Mac**

Launch with `./script/build_and_run.sh`, capture a full-screen image, and verify either `🐾 桌宠` or the independent `🐾 总台` is visibly available. Open the control menu, hide one character and restore it, hide all and confirm the fallback remains, recall all, pause/resume, enter/leave full-screen if feasible, then quit. Capture filtered logs for creation, health, fallback, and commands.

- [x] **Step 6: Update acceptance records and commit**

Record exact test counts, build/signing output, observed UI state, and any environment limitation. Mark Phase 7 complete only when all acceptance criteria have concrete evidence.

Run: `git add Sources Tests docs task_plan.md findings.md progress.md && git commit -m "test: verify persistent desktop pet control center"`
