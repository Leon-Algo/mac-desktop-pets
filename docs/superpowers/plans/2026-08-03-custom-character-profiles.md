# Configurable Character Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an acceptance-ready native editor for 1–8 configurable desktop characters with preset or imported avatars and immediate safe runtime application.

**Architecture:** A pure Swift versioned roster owns validated user-facing profiles. Metadata and normalized image assets are persisted separately under Application Support; a native AppKit editor edits a draft and applies it through an atomic runner replacement. Existing `CharacterManifest` remains the simulation/rendering DTO.

**Tech Stack:** Swift 6, SwiftPM, AppKit, Core Animation, XCTest

## Global Constraints

- Support macOS 13+ with no third-party dependencies.
- Enforce 1–8 active characters and unique stable IDs.
- Imported avatar data remains local and normalized to 512×512 PNG.
- New public defaults use non-identifiable procedural illustrations.
- Existing four-person installs retain their current local appearance.
- All edits are draft-based; invalid saves do not change the running roster.

---

### Task 1: Versioned roster domain

**Files:**
- Create: `Sources/DesktopPets/Characters/CharacterProfile.swift`
- Create: `Sources/DesktopPets/Characters/CharacterRoster.swift`
- Create: `Tests/DesktopPetsTests/CharacterRosterTests.swift`

**Interfaces:**
- Produces: `AvatarSource`, `BodyStyle`, `OutfitPreset`, `PersonalityPreset`, `CharacterProfile`, `CharacterRoster.validated()` and `CharacterRoster.default`

- [x] Write tests requiring four safe defaults, 12 avatar presets, five personality templates, 1–8 validation, unique IDs, trimmed 1–20 character names, and safe imported filenames.
- [x] Run `swift test --filter CharacterRosterTests` and verify failure because the types are absent.
- [x] Implement only the validated value types, defaults, and conversion to `CharacterManifest`.
- [x] Run focused tests and commit.

### Task 2: Roster and avatar persistence

**Files:**
- Create: `Sources/DesktopPets/Characters/CharacterRosterStore.swift`
- Create: `Sources/DesktopPets/Rendering/AvatarImageProcessor.swift`
- Create: `Tests/DesktopPetsTests/CharacterRosterStoreTests.swift`
- Create: `Tests/DesktopPetsTests/AvatarImageProcessorTests.swift`

**Interfaces:**
- Produces: `CharacterRosterStore.load/save`, `importAvatar(data:)`, `removeUnreferencedAvatars(roster:)`, and an injected root directory for tests.

- [x] Write tests for round-trip JSON, corrupt recovery, atomic rejection, PNG/JPEG decoding, 512-square output, safe UUID filenames, and orphan cleanup.
- [x] Run focused tests and verify the missing APIs fail.
- [x] Implement atomic JSON persistence and local normalized avatar storage.
- [x] Run focused tests and commit.

### Task 3: Preset/import rendering and editor model

**Files:**
- Modify: `Sources/DesktopPets/Characters/CharacterManifest.swift`
- Modify: `Sources/DesktopPets/Rendering/FaceAssetLoader.swift`
- Modify: `Sources/DesktopPets/Rendering/ProceduralPetRenderer.swift`
- Create: `Sources/DesktopPets/App/CharacterEditorModel.swift`
- Create: `Tests/DesktopPetsTests/CharacterEditorModelTests.swift`
- Modify: `Tests/DesktopPetsTests/FaceAssetTests.swift`

**Interfaces:**
- Produces: explicit avatar/body-style fields on manifests, asset resolution without magic IDs, draft add/delete/move/update/apply-template APIs, `canAdd` and `canDelete`.

- [x] Write failing rendering/editor tests covering all 12 presets, imported images, add-to-eight, delete-to-one, reorder, template application, and validation.
- [x] Run focused tests to observe RED.
- [x] Implement deterministic procedural faces, imported/legacy loading, explicit styles, and pure draft editing.
- [x] Run focused tests and commit.

### Task 4: Native character settings window

**Files:**
- Create: `Sources/DesktopPets/App/CharacterSettingsWindowController.swift`
- Modify: `Sources/DesktopPets/App/AppController.swift`
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`
- Create: `Tests/DesktopPetsTests/CharacterSettingsWindowTests.swift`
- Modify: `Tests/DesktopPetsTests/CommandRoutingTests.swift`

**Interfaces:**
- Produces: `showCharacterSettings`, native list/preview/form controls, import panel action, save/cancel callbacks, and menu item `人物设置…`.

- [x] Write failing tests for menu routing, 1/8 button states, editing controls, save/cancel, and preview refresh.
- [x] Run focused tests to observe RED.
- [x] Implement one reusable AppKit window controller and wire it to the menu.
- [x] Run focused tests and commit.

### Task 5: Dynamic runtime application and count-neutral behavior

**Files:**
- Modify: `Sources/DesktopPets/App/AppController.swift`
- Modify: `Sources/DesktopPets/App/WorldRunner.swift`
- Modify: `Sources/DesktopPets/App/StatusMenuController.swift`
- Modify: `Sources/DesktopPets/Rendering/PetSpriteView.swift`
- Modify: `Sources/DesktopPets/Interaction/PetActionCatalog.swift`
- Modify: `Sources/DesktopPets/App/DesktopPetsApplication.swift`
- Modify: `Tests/DesktopPetsTests/PetInteractionTests.swift`
- Modify: `Tests/DesktopPetsTests/AppLaunchTests.swift`

**Interfaces:**
- Produces: roster save/apply, atomic runner replacement, stable-ID hidden/pause restoration, count-neutral menu copy, and 1–8 window inspection.

- [x] Write failing tests for 1/4/8 runners, old-window shutdown, stable state restoration, all-person group action, dynamic inspection, and neutral labels.
- [x] Run focused tests to observe RED.
- [x] Implement controlled runner replacement and remove fixed-four runtime assumptions.
- [x] Run focused tests and commit.

### Task 6: Package acceptance and documentation

**Files:**
- Modify: `Sources/DesktopPets/App/DesktopPetsApplication.swift`
- Modify: `Scripts/smoke-test.sh`
- Modify: `docs/verification/final-acceptance.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Interfaces:**
- Verifies: deterministic four-default self-test plus 1/4/8 roster simulations and live packaged app.

- [ ] Add failing self-test expectations for roster defaults and 1/4/8 finite simulations.
- [ ] Implement expanded JSON self-test diagnostics and dynamic smoke verification.
- [ ] Run full tests, AddressSanitizer, strict-concurrency Release, package, signing, smoke, 1/4/8 self-tests, and ordinary live launch.
- [ ] Record evidence, commit, and leave the app running for acceptance.
