# macOS Desktop Pets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a native macOS menu-bar app with four recognizable crawling desktop pets that react to screen and visible-window edges.

**Architecture:** A SwiftPM AppKit executable separates deterministic world simulation from macOS window enumeration and transparent-panel rendering. Character atlases and manifests use platform-neutral PNG/JSON contracts, with procedural fallback assets guaranteeing launch even if a production atlas is unavailable.

**Tech Stack:** Swift 6.3, AppKit, SpriteKit, Core Graphics, XCTest/Swift Testing, SwiftPM, shell packaging scripts.

## Global Constraints

- Minimum macOS version is 13.0.
- No third-party runtime dependencies.
- Do not request Accessibility or Screen Recording permission.
- Do not capture, persist, or transmit window pixels, titles, or application content.
- Keep simulation and character manifests free of AppKit types.
- Every failure path must retain menu-bar Quit access and fall back safely.

## File map

- `Package.swift` — SwiftPM executable and test targets.
- `Sources/DesktopPets/App/` — application lifecycle, status item, command routing, preferences.
- `Sources/DesktopPets/World/` — geometry, obstacles, deterministic simulation, pet state machine.
- `Sources/DesktopPets/Platform/` — screen and Core Graphics window adapters.
- `Sources/DesktopPets/Rendering/` — transparent panels, SpriteKit character view, texture/fallback rendering.
- `Sources/DesktopPets/Characters/` — portable manifest models, validation, catalog loading.
- `Sources/DesktopPets/Resources/Characters/` — bundled JSON and PNG character packages.
- `Tests/DesktopPetsTests/` — deterministic unit and integration tests.
- `Scripts/package-app.sh` — local `.app` assembly and validation.
- `Scripts/smoke-test.sh` — launch/process/window-count smoke test.
- `docs/verification/` — generated evidence and final verification report.

---

### Task 1: SwiftPM application skeleton and diagnostics command

**Files:**
- Create: `Package.swift`
- Create: `Sources/DesktopPets/main.swift`
- Create: `Sources/DesktopPets/App/DesktopPetsApplication.swift`
- Create: `Sources/DesktopPets/App/CommandLineMode.swift`
- Create: `Tests/DesktopPetsTests/AppLaunchTests.swift`

**Interfaces:**
- Produces: `CommandLineMode.parse(_:) -> CommandLineMode`; `DesktopPetsApplication.run()`.

- [ ] Write a test proving `--self-test` and normal launch arguments parse deterministically.
- [ ] Run `swift test --filter AppLaunchTests` and verify the test fails because the types do not exist.
- [ ] Create the SwiftPM executable, resource declaration, application entry point, and `--self-test` JSON output containing version, architecture, and window-enumeration availability.
- [ ] Run `swift test --filter AppLaunchTests` and `swift run DesktopPets --self-test`; require passing tests and valid JSON output.
- [ ] Initialize the project Git repository and commit the independently working skeleton.

### Task 2: Geometry and obstacle normalization

**Files:**
- Create: `Sources/DesktopPets/World/WorldGeometry.swift`
- Create: `Sources/DesktopPets/World/Obstacle.swift`
- Create: `Sources/DesktopPets/World/ObstacleMap.swift`
- Create: `Tests/DesktopPetsTests/ObstacleMapTests.swift`

**Interfaces:**
- Produces: `WorldRect`, `WorldPoint`, `WorldVector`, `Obstacle`; `ObstacleMap.supportingSurface(below:within:)`; `ObstacleMap.nearestClimbableEdge(to:)`.

- [ ] Write tests for coordinate conversion, top-surface selection, side-edge selection, overlapping windows, zero-size rejection, and multiple displays.
- [ ] Run `swift test --filter ObstacleMapTests`; verify failures identify missing implementations.
- [ ] Implement value types with finite-value validation, deterministic ordering, and screen-edge fallback surfaces.
- [ ] Run geometry tests and the complete suite; require all passing.
- [ ] Commit the geometry subsystem.

### Task 3: Character manifest contract and safe fallback

**Files:**
- Create: `Sources/DesktopPets/Characters/CharacterManifest.swift`
- Create: `Sources/DesktopPets/Characters/CharacterCatalog.swift`
- Create: `Sources/DesktopPets/Resources/Characters/characters.json`
- Create: `Tests/DesktopPetsTests/CharacterCatalogTests.swift`

**Interfaces:**
- Produces: `CharacterManifest`, `AnimationClip`, `FrameRect`, `Personality`, `CharacterCatalog.load(bundle:)` and four stable identifiers `person-left`, `person-center-left`, `person-center-right`, `person-right`.

- [ ] Write decoding tests for four valid manifests, missing animation fallback, invalid normalized coordinates, duplicate identifiers, and corrupt JSON.
- [ ] Run `swift test --filter CharacterCatalogTests`; verify it fails before implementation.
- [ ] Implement strict validation plus four procedural fallback profiles matching clothing cues: plaid/eyeglasses, black sleeveless shirt, mint shirt/round glasses, and black jacket/white shirt.
- [ ] Run catalog tests and the complete suite; require all passing.
- [ ] Commit the portable character contract.

### Task 4: Deterministic pet behavior engine

**Files:**
- Create: `Sources/DesktopPets/World/PetState.swift`
- Create: `Sources/DesktopPets/World/PetAgent.swift`
- Create: `Sources/DesktopPets/World/SeededRandom.swift`
- Create: `Sources/DesktopPets/World/PetWorld.swift`
- Create: `Tests/DesktopPetsTests/PetWorldTests.swift`

**Interfaces:**
- Consumes: `ObstacleMap`, `CharacterManifest.Personality`.
- Produces: `PetWorld.step(deltaTime:obstacles:) -> [PetPose]`; `PetWorld.recall(to:)`; `PetWorld.setPaused(_:)`.

- [ ] Write tests for crawl motion, clamping, platform landing, climb transition, missing-platform fall, pause, recall, pair interaction cooldowns, deterministic seeds, and 30-minute accelerated invariants.
- [ ] Run `swift test --filter PetWorldTests`; verify failures precede implementation.
- [ ] Implement fixed-step movement and explicit transition cooldowns for all specified states.
- [ ] Run behavior tests and the complete suite; require all passing with no non-finite coordinates.
- [ ] Commit the behavior engine.

### Task 5: macOS screen and window geometry provider

**Files:**
- Create: `Sources/DesktopPets/Platform/GeometryProvider.swift`
- Create: `Sources/DesktopPets/Platform/MacScreenProvider.swift`
- Create: `Sources/DesktopPets/Platform/CGWindowGeometryProvider.swift`
- Create: `Tests/DesktopPetsTests/WindowFilteringTests.swift`

**Interfaces:**
- Produces: `GeometrySnapshot`; `GeometryProvider.snapshot() async -> GeometrySnapshot`; pure `WindowFilter.normalize(_:ownPID:displayBounds:)` for testability.

- [ ] Write fixture-driven tests for normal windows, hidden/transparent/system layers, own-process windows, invalid bounds, and coordinate-origin conversion.
- [ ] Run `swift test --filter WindowFilteringTests`; verify it fails before implementation.
- [ ] Implement Core Graphics metadata enumeration without image capture, titles, Accessibility, or ScreenCaptureKit.
- [ ] Add `--geometry-probe` JSON output reporting display count, accepted external rectangle count, and redacted owner PIDs.
- [ ] Run tests and `swift run DesktopPets --geometry-probe`; require at least one display and valid finite rectangles.
- [ ] Commit the platform geometry adapter.

### Task 6: Transparent pet panels and renderer

**Files:**
- Create: `Sources/DesktopPets/Rendering/PetPanel.swift`
- Create: `Sources/DesktopPets/Rendering/PetSpriteView.swift`
- Create: `Sources/DesktopPets/Rendering/ProceduralPetNode.swift`
- Create: `Sources/DesktopPets/Rendering/PetWindowCoordinator.swift`
- Create: `Tests/DesktopPetsTests/PanelConfigurationTests.swift`

**Interfaces:**
- Consumes: `[PetPose]`, `CharacterCatalog`.
- Produces: four `PetPanel` instances; `PetWindowCoordinator.apply(poses:)`; `PetWindowCoordinator.setClickThrough(_:)`; `renderVerificationSnapshot(url:)`.

- [ ] Write tests for nonactivating/borderless configuration values, click-through toggling, four stable panel identifiers, and pose-to-panel coordinate mapping.
- [ ] Run `swift test --filter PanelConfigurationTests`; verify failures precede implementation.
- [ ] Implement transparent non-key panels with all-Spaces/full-screen auxiliary behavior and SpriteKit rendering.
- [ ] Implement friendly procedural human fallback figures with identity-specific face/hair/glasses/clothing cues and crawling limb animation.
- [ ] Add `--render-snapshot <path>` that renders all four fallback figures into a transparent PNG without launching persistent panels.
- [ ] Run tests and verify the PNG is nonempty, has alpha, and contains four separated character bounds.
- [ ] Commit the rendering subsystem.

### Task 7: Approved four-person production character atlas

**Files:**
- Create: `Sources/DesktopPets/Resources/Characters/four-person-atlas.png`
- Modify: `Sources/DesktopPets/Resources/Characters/characters.json`
- Create: `docs/verification/character-asset-review.md`

**Interfaces:**
- Consumes: the supplied reference photo and manifest schema.
- Produces: one transparent atlas with consistent row-per-person crawl/action frames and reviewed frame rectangles.

- [ ] Generate a semi-realistic transparent-background atlas anchored to the supplied faces, hair, glasses, and clothing, with no animal anatomy and naturally reconstructed limbs.
- [ ] Inspect the original and generated atlas at original resolution; reject extra limbs, malformed hands, merged people, opaque background, identity swapping, or inconsistent row assignments.
- [ ] Update exact frame rectangles and animation clips in `characters.json`; retain procedural fallback for every sequence.
- [ ] Run catalog tests, render a verification snapshot from production assets, and visually compare all four identities with the reference.
- [ ] Record honest limitations and the accepted asset hash in the review document.
- [ ] Commit the reviewed production assets.

### Task 8: Menu-bar lifecycle, preferences, and command handling

**Files:**
- Create: `Sources/DesktopPets/App/AppController.swift`
- Create: `Sources/DesktopPets/App/StatusMenuController.swift`
- Create: `Sources/DesktopPets/App/PreferencesStore.swift`
- Create: `Sources/DesktopPets/App/WorldRunner.swift`
- Create: `Tests/DesktopPetsTests/PreferencesTests.swift`
- Create: `Tests/DesktopPetsTests/CommandRoutingTests.swift`

**Interfaces:**
- Consumes: `GeometryProvider`, `PetWorld`, `PetWindowCoordinator`.
- Produces: command handlers for pause/resume, hide/show, recall, click-through, launch-at-login preference, diagnostics, and quit.

- [ ] Write tests for default preferences, corrupt preference recovery, persistence, command state labels, pause/hide distinction, and recall.
- [ ] Run the targeted tests and verify failure before implementation.
- [ ] Implement a menu-bar-only lifecycle, 30 Hz fixed-step runner, 4 Hz geometry refresh, command routing, and structured unified logging.
- [ ] Implement launch-at-login as an availability-aware setting; if ServiceManagement registration fails, revert the toggle and log a readable error.
- [ ] Run all tests and `swift run DesktopPets --self-test`; require passing evidence.
- [ ] Commit the integrated application.

### Task 9: Packaging, smoke automation, and privacy audit

**Files:**
- Create: `Scripts/package-app.sh`
- Create: `Scripts/smoke-test.sh`
- Create: `Resources/Info.plist`
- Create: `Resources/DesktopPets.entitlements`
- Create: `docs/WINDOWS_PORT.md`
- Create: `docs/verification/privacy-audit.md`

**Interfaces:**
- Produces: `build/DesktopPets.app`; repeatable build and smoke commands.

- [ ] Implement a Release packaging script that creates a valid bundle with `LSUIElement`, copies resources, signs ad hoc, runs `codesign --verify --deep --strict`, and checks the plist.
- [ ] Add a smoke script that launches the app in diagnostic mode, confirms one process and four pet panels through app diagnostics, exercises command URLs or test hooks, and terminates cleanly.
- [ ] Document the Windows adapter boundary and macOS signing/notarization steps without claiming notarization was performed.
- [ ] Audit source and plist for Screen Recording, Accessibility, networking, window-title persistence, and unnecessary entitlements; record command output.
- [ ] Run `swift test`, Release build, packaging, bundle validation, privacy audit, and smoke test.
- [ ] Commit packaging and documentation.

### Task 10: Real runtime, visual, performance, and final acceptance

**Files:**
- Create: `docs/verification/final-acceptance.md`
- Create: `docs/verification/runtime-snapshot.png`
- Modify: `progress.md`
- Modify: `task_plan.md`

**Interfaces:**
- Consumes: packaged `build/DesktopPets.app` and every acceptance criterion in the design.
- Produces: requirement-by-requirement evidence and final handoff paths.

- [ ] Launch the packaged app normally and verify status item plus four visible panels in a real desktop session.
- [ ] Move, resize, minimize, and close an external test window; verify geometry refresh and pet platform/fall behavior through diagnostics and observation.
- [ ] Exercise pause/resume, hide/show, recall, click-through, and Quit; capture before/after diagnostics.
- [ ] Run accelerated 30-minute simulation, a real-time soak, Release process CPU/RSS sampling, and sanitizer-supported tests.
- [ ] Inspect the runtime snapshot visually for transparency, distinct identities, clipping, malformed assets, and desktop obstruction.
- [ ] Write the final acceptance matrix with PASS/FAIL and exact evidence; fix any failure and repeat the affected verification rather than weakening criteria.
- [ ] Mark the plan complete only when every required item passes; otherwise keep the goal active with the remaining evidence clearly identified.

