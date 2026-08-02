# Pet Size Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent global 25%, 50%, and 100% desktop-pet sizes with a 50% default and geometry-correct live switching.

**Architecture:** A Codable `PetScalePreset` flows from preferences through the shared AppKit menu and `AppController` into `WorldRunner`. Rendering panels and world safe bounds consume the same preset, while packaged diagnostics recognize the resulting supported window sizes.

**Tech Stack:** Swift 6, AppKit, Core Animation, XCTest, Swift Package Manager.

## Global Constraints

- Support macOS 13 and later.
- Default new and migrated users to 50%.
- Offer exactly 25%, 50%, and 100%; no continuous slider and no per-person sizes.
- Scale visible windows, alpha hit regions, ground offsets, and screen-edge clearances together.
- Do not scale movement speed, jump physics, external window geometry, or the fallback control.
- Preserve all existing control and recovery routes.

---

### Task 1: Preset model, migration, and shared menu

**Files:**
- Modify: `Sources/DesktopPets/App/PreferencesStore.swift`
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`
- Modify: `Sources/DesktopPets/App/AppController.swift`
- Modify: `Tests/DesktopPetsTests/PreferencesTests.swift`
- Modify: `Tests/DesktopPetsTests/CommandRoutingTests.swift`

**Interfaces:**
- Produces: `enum PetScalePreset: String, Codable, CaseIterable, Sendable` with `quarter`, `half`, `original`, `factor`, `menuTitle`, and `panelSize`.
- Produces: `AppPreferences.petScale: PetScalePreset`, defaulting and migrating to `.half`.
- Produces: `@objc AppController.setPetScale(_:)` using an `NSMenuItem.representedObject` raw value.

- [ ] **Step 1: Write preference RED tests**

Assert defaults use `.half`, every case round-trips, and legacy JSON without `petScale` decodes with `.half` while preserving all legacy booleans.

- [ ] **Step 2: Verify preference RED**

Run `swift test --filter PreferencesTests` and confirm failures are caused by the absent preset model and preference field.

- [ ] **Step 3: Implement model and migration**

Add the enum and an explicit `AppPreferences` initializer plus `init(from:)` using `decodeIfPresent(PetScalePreset.self, forKey: .petScale) ?? .half`. Keep synthesized encoding.

- [ ] **Step 4: Verify preference GREEN**

Run `swift test --filter PreferencesTests` and require all preference tests to pass.

- [ ] **Step 5: Write menu RED test**

Refresh with `.half`, locate the `人物大小` submenu, assert titles `25%（最小）`, `50%（推荐）`, `100%（原样）`, and assert only 50% is checked.

- [ ] **Step 6: Verify menu RED**

Run the focused command-routing test and confirm the submenu is absent.

- [ ] **Step 7: Implement menu and command routing**

Build the three-item submenu from `PetScalePreset.allCases`, store `rawValue` in each represented object, check the active item, and have `AppController.setPetScale(_:)` persist and forward the valid preset to `WorldRunner`.

- [ ] **Step 8: Verify menu GREEN and commit**

Run `swift test --filter PreferencesTests` and `swift test --filter CommandRoutingTests`, then commit the model/menu slice.

### Task 2: Scale-aware AppKit panels and hit geometry

**Files:**
- Modify: `Sources/DesktopPets/Rendering/PetWindowCoordinator.swift`
- Modify: `Sources/DesktopPets/Rendering/PetSpriteView.swift`
- Modify: `Sources/DesktopPets/App/WorldRunner.swift`
- Modify: `Tests/DesktopPetsTests/PanelConfigurationTests.swift`
- Modify: `Tests/DesktopPetsTests/ControlCenterStateTests.swift`

**Interfaces:**
- Produces: `PetWindowCoordinator.setScale(_ preset: PetScalePreset)`.
- Produces: `PetSpriteView.setRenderScale(_ factor: CGFloat)`.
- Produces: `WorldRunner.setScale(_ preset: PetScalePreset)`.

- [ ] **Step 1: Write panel RED tests**

For all presets, apply a pose at `(300, 250)` and assert panel dimensions equal 45×40, 90×80, or 180×160, `midX == 300`, and `minY == 250 - 20 * factor`. Assert the sprite view bounds equal its panel bounds after resizing.

- [ ] **Step 2: Verify panel RED**

Run `swift test --filter PanelConfigurationTests` and confirm failures are caused by missing scale APIs and fixed panel geometry.

- [ ] **Step 3: Implement coordinated resizing**

Keep `basePanelSize = 180×160`, store the active preset, derive panel size and ground offset from its factor, resize `PetPanel` and `PetSpriteView`, update CALayer bounds/anchor position, and reapply poses after `WorldRunner` changes scale.

- [ ] **Step 4: Verify panel GREEN**

Run `swift test --filter PanelConfigurationTests` and `swift test --filter ControlCenterStateTests`.

- [ ] **Step 5: Commit rendering slice**

Commit scale-aware panels, views, runner routing, and tests.

### Task 3: Scale-aware world safety bounds

**Files:**
- Modify: `Sources/DesktopPets/World/PetWorld.swift`
- Modify: `Sources/DesktopPets/App/WorldRunner.swift`
- Modify: `Tests/DesktopPetsTests/PetWorldTests.swift`

**Interfaces:**
- Produces: `PetWorld.setScale(_ preset: PetScalePreset)` and derived half-width/top-clearance values.
- Consumes: `WorldRunner.start(preferences:)` and `WorldRunner.setScale(_:)`.

- [ ] **Step 1: Write world RED tests**

Set the world to `.quarter`, drag a pet beyond a 1200×800 display, and assert its anchor clamps to `x = 22.5` and `y = 765`; compare `.original` at `x = 90` and `y = 660`.

- [ ] **Step 2: Verify world RED**

Run the focused world test and confirm scale-aware bounds are missing.

- [ ] **Step 3: Implement shared safety metrics**

Store the active factor in `PetWorld`, replace every fixed 90/140 clamp argument with `90 * factor` and `140 * factor`, and set the world preset both at runner startup and on live changes.

- [ ] **Step 4: Verify world GREEN and full suite**

Run `swift test --filter PetWorldTests` followed by `swift test`.

- [ ] **Step 5: Commit world slice**

Commit the scale-aware world bounds and tests.

### Task 4: Packaged diagnostics and release verification

**Files:**
- Modify: `Sources/DesktopPets/App/DesktopPetsApplication.swift`
- Modify: `Tests/DesktopPetsTests/AppLaunchTests.swift`
- Modify: `docs/verification/final-acceptance.md`
- Modify: `progress.md`
- Modify: `task_plan.md`

**Interfaces:**
- Produces: `RunningAppInspection.evaluate(pid:windows:)` accepting exactly four uniformly sized pet windows at a supported preset.

- [ ] **Step 1: Write inspection RED tests**

Assert four 90×80 windows plus the named fallback are healthy; assert mixed supported sizes and four unrelated windows are degraded.

- [ ] **Step 2: Verify inspection RED**

Run `swift test --filter AppLaunchTests/testRunningInspectionRequiresIndependentFallbackControlWindow` and confirm 90×80 is rejected by the existing 180×160-only logic.

- [ ] **Step 3: Implement supported-size inspection**

Count windows matching each `PetScalePreset.panelSize`; require one preset count to equal four, report all supported pet windows in `petWindowCount`, and keep exact fallback matching.

- [ ] **Step 4: Verify full safety suite**

Run `swift test`, `swift test --sanitize=address`, and `swift build -c release -Xswiftc -strict-concurrency=complete`.

- [ ] **Step 5: Package and run**

Run `./Scripts/smoke-test.sh`, strict codesign verification, and `./script/build_and_run.sh`. Require four 90×80 pet windows, one fallback, and a healthy running report; leave the final app running.

- [ ] **Step 6: Record evidence and finish**

Update acceptance/planning records, run `git diff --check`, commit, and require `git status --short` to be empty.
