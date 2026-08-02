# Progress Log

## Session: 2026-08-01

### Phase 1 — Requirements and feasibility
- **Status:** in_progress

### Phase 11 — Replace sleep/play commands with “叫爸爸”

- User requested replacing the individual sleep command with `叫爸爸` and the group play command with a collective `喊爸爸` action.
- Selected a semantic replacement rather than label-only relabeling: new typed IDs, catalog copy, deterministic routing, menus, feedback, tests, and packaged self-test will all agree.
- Autonomous sleep behavior remains unchanged; no audio dependency is added in this iteration.
- RED: focused tests failed because `PetActionID.callDad` and `.groupCallDad` did not exist.
- GREEN: catalog, world routing, menus, four-person feedback, and packaged self-test now use the new typed actions; 27 focused tests pass.
- Final verification: 94/94 normal and 94/94 AddressSanitizer tests pass; strict-concurrency Release, fresh app packaging, signing, smoke test, 14-command interaction self-test, and ordinary live launch pass.
- The newly packaged app is running as PID 64251 with four pet windows and the fallback controller.
- **Status:** complete

### Phase 12 — Design configurable character profiles

- Fast-forward merged `feature/action-center-v2` into local `main` at `aad9023`; the merged 94-test suite passed and the feature branch was removed.
- Created `feature/custom-character-profiles` for design work so the accepted main milestone remains stable.
- Began architecture inspection. The manifest model is reusable, but face loading, asset storage, fixed-four copy, persistence, and runtime roster rebuilding need explicit design.
- Confirmed that the renderer can support option-based face/body customization, but current runtime objects are immutable and require an atomic roster rebuild after Save.
- Confirmed that a native settings window is a new UI surface; no current settings or open-panel implementation can be reused.
- Recommended a preset-first editor with optional local image import, 1–8 active characters, four synthetic defaults, twelve built-in faces, six outfits, and five personality presets.
- Prepared the product, storage, migration, and runtime-apply design for user approval before writing the formal spec or implementation plan.
- **Status:** awaiting_design_approval
- User approved the recommended design and requested an acceptance-ready implementation without further checkpoints.
- Wrote the formal specification covering 1–8 limits, native editor UX, procedural presets, local imports, migration, atomic runner rebuild, dynamic copy, diagnostics, and release acceptance.
- **Status:** design_complete
- Task 1 RED: roster tests failed on missing profile, preset, avatar-source, and validation types.
- Task 1 GREEN: four safe defaults, 12 built-in avatar choices, five personalities, six outfits, safe source validation, name normalization, unique IDs, and the 1–8 invariant pass four focused tests.
- Task 2 RED: store and avatar-processing tests failed on missing APIs.
- Task 2 GREEN: atomic roster round-trip/recovery, invalid-save protection, safe local avatar import, 512-square PNG normalization, and orphan cleanup pass five focused tests.
- Task 3 RED: editor and avatar tests failed on absent model/renderer APIs.
- Task 3 GREEN: 12 distinct procedural avatars, explicit body styles, imported/legacy avatar resolution, roster-to-manifest conversion, and draft add/delete/reorder/template/cancel behavior pass 15 focused tests.
- Task 4 RED: native-window and menu tests failed on missing settings controller and selector.
- Task 4 GREEN: a fixed native AppKit editor exposes roster list, preview, add/delete/order controls, 12 avatars, three body styles, six outfits, five templates, five advanced sliders, local import, save/cancel, and menu routing; 15 focused tests pass.
- **Status:** in_progress
- Read the required workflow skills.
- Inspected the shared workspace and protected unrelated planning records.
- Captured the confirmed macOS-first scope and Windows-follow-up direction.
- Recorded initial source-image feasibility, design principles, and open questions.
- Verified relevant macOS capabilities against current Apple documentation.
- Compared native, game-engine, and web-shell approaches; recorded a provisional native recommendation.
- No character generation, source-image modification, code scaffolding, or application implementation has started.

## Test Results
| Test | Result |
|---|---|
| Workspace isolation check | Passed: records stored under `mac-desktop-pets/` |

## Error Log
| Error | Resolution |
|---|---|
| Existing root planning files belong to another task | Used a dedicated project subdirectory. |

## Session: 2026-08-02

### Phase 3 — Specification and implementation planning
- **Status:** complete
- User approved the recommended macOS-native scheme and authorized implementation.
- Recorded the complete design specification and a ten-task TDD implementation plan.
- Self-review found no placeholders or incomplete plan steps.
- Confirmed build host: Apple Silicon, macOS 26.5.2, Xcode 26.5, Swift 6.3.2.

### Phase 4 — Implementation
- **Status:** complete
- Selected inline plan execution because proactive subagent dispatch is not permitted by the active collaboration rules.
- Completed and committed the SwiftPM application skeleton, geometry model, character manifest contract, deterministic behavior engine, Core Graphics window provider, and transparent panel renderer.
- Completed the native menu-bar lifecycle, four transparent panels, Core Animation renderer, exact face assets, deterministic state machine, live Core Graphics window geometry, preferences, diagnostics, packaging, and Windows adapter notes.
- Added safe visible-screen bounds and direct window-side collision handling after final review.
- Current automated suite: 39 tests.
- Verified a live geometry probe and generated/inspected a transparent four-character procedural preview.

### Phase 5 — Verification and handoff
- **Status:** complete for local development distribution
- Normal and AddressSanitizer suites: 39/39 passing.
- Strict-concurrency Release build: passing.
- Packaged app: ad-hoc signed and strict deep-signature validation passing.
- Live smoke: one process, four on-screen pet windows.
- Live geometry: one display and one accepted external application rectangle on the test session.
- Runtime sampling: approximately 5–6% CPU and 54 MB RSS after startup.
- Privacy audit: no screen capture, Accessibility, networking, window-title collection, or nonempty entitlements.
- Generated and visually inspected a 1440×320 alpha-enabled runtime snapshot.
- Public Developer ID signing/notarization is unavailable on this machine and is documented rather than claimed.

### Phase 6 — Direct pet interaction
- **Status:** complete
- User reported that stop/quit controls were difficult to discover and pets could not be clicked.
- Confirmed the existing cause: default full-window click-through plus no view mouse-event routing.
- User approved the recommended single-click, double-click, drag/release, right-click, and first-launch guidance design.
- Added deterministic interaction commands and shape-aware panel input. One menu-copy test initially used the wrong boolean fixture; corrected it before continuing.
- Packaged smoke exposed a first-run preference side effect. Added a tested verification-only suppression policy and cleared the test-created hint flag so the user's next manual launch still shows guidance.
- Foreground UI inspection then showed the accessory app could mark the hint as shown without surfacing it. Added explicit application activation before `NSAlert.runModal()` and scheduled a fresh live-window check.
- Activation alone did not surface the modal from an accessory app. The second targeted fix temporarily switches to regular activation policy for the alert and restores accessory mode after dismissal.
- Computer Use confirmed the final first-run dialog is visible, focused, readable, and exposes its “好” button. The dialog was dismissed and the test-created hint flag was cleared for the user's next launch.
- Direct UI coordinate automation could not target the moving nonactivating panels reliably; event delivery is instead covered at the click interpreter, alpha mask, coordinator, world-command, and packaged interaction-self-test layers.
- Final automated count after interaction edge-case review: 55/55 normal tests and 55/55 AddressSanitizer tests.
- Strict-concurrency Release build, ad-hoc signing, four-window smoke, and nine-command packaged interaction self-test all pass.
- Final review also ensures a click resumes an individually paused pet and double-click group play restores any individually hidden pets.

### Phase 7 — Persistent control center
- **Status:** written specification review
- Reproduced the missing menu-bar item with the current packaged process running.
- Captured normal and full-screen desktop states; no paw item was visible.
- Ran a same-session minimal `TEST` status-item control experiment; it was also not visible, ruling out simple controller deallocation as the sole cause.
- User approved the recommended labeled status-item plus independent fallback-control design.
- Wrote and self-reviewed `docs/superpowers/specs/2026-08-02-persistent-control-center-design.md`; no production code has been changed pending written-spec review.
- User authorized uninterrupted execution without further approval gates.
- Wrote the TDD implementation plan at `docs/superpowers/plans/2026-08-02-persistent-control-center.md` and selected inline execution because subagent delegation is not authorized.
- Task 1 RED: focused tests failed because control snapshots and status-item health types did not exist.
- Task 1 GREEN: 3 focused control-center tests and all 58 tests passed.
- Task 2 RED: focused tests failed on the absent shared menu API, UI command channel, and global pet context commands.
- Task 2 GREEN: shared `🐾 桌宠` menu, four per-character submenus, and right-click recovery/open/quit entries passed focused tests and all 62 tests.
- Task 3 RED: panel/guidance tests failed because the independent fallback controller and dual-route guidance did not exist; an additional regression test failed on the absent all-hidden fallback policy.
- Task 3 GREEN: non-activating all-Spaces `🐾 总台`, bounded status-item repair, non-modal guidance, and forced fallback for all-hidden state passed focused tests and all 66 tests.
- Task 4 RED/GREEN: packaged inspection first failed on the absent fallback-report contract; it now requires five visible app windows (four pets plus the fallback) and reports `fallbackControlPresent`.
- Live telemetry captured labeled status-item creation, fallback presentation, and a healthy AppKit lifecycle snapshot. The current system still suppresses the menu-bar pixels, which is why the independent fallback remains necessary.
- Live UI acceptance opened the shared menu, hid all four pets while preserving the fallback, recalled all four, verified moving versus frozen coordinates for resume/pause, and quit the process through the menu.
- Final edge-case TDD added accessible fallback window naming, effective global visibility after four individual hides, and deterministic force-visible packaged verification.
- Final fresh verification: 69/69 normal tests, 69/69 AddressSanitizer tests, strict Swift 6 concurrency Release build, five-window packaged smoke, and strict deep signing all pass.
- Independent code review identified one control-lockout risk and three state/lifecycle weaknesses. TDD fixes now keep the fallback visible during full click-through or all-hidden states, synchronize global hidden state into every character snapshot (including startup), reposition the fallback after screen/Space changes, debounce status health checks, and require exact pet/fallback window signatures in packaged inspection.
- Post-review fresh verification: 73/73 normal tests, 73/73 AddressSanitizer tests, strict Swift 6 concurrency Release build, exact four-pet-plus-fallback packaged smoke, nine-command interaction self-test, and strict deep signing all pass.
- A final ordinary launch appeared to end early; the user later clarified that it may have been closed manually, so this is not recorded as a reproduced product defect. Early lifecycle protection remains as defensive hardening, and three consecutive ordinary launches each reached the exact five-window healthy state.

### Phase 8 — Compact menu-bar item
- **Status:** in_progress
- User selected the compact approach after confirming that macOS does not move overflowing status items across the notch.
- Wrote and committed the focused design and TDD implementation plan.
- RED: initial and repair-path tests observed the old `🐾 桌宠` title and variable status-item length.
- GREEN: both construction paths now use `NSStatusItem.squareLength` and display only `🐾`; tooltip, accessibility label, shared menu, and fallback behavior remain unchanged.
- RED/GREEN: first-run guidance now accurately describes the compact menu-bar `🐾` icon.
- Final verification: 74/74 normal tests, 74/74 AddressSanitizer tests, strict Swift 6 concurrency Release build, exact four-pet-plus-fallback packaged smoke, nine-command interaction self-test, and strict deep signing all pass.

### Phase 9 — Adjustable pet sizes

- Task 1: added persistent 25% / 50% / 100% presets, defaulted new and migrated settings to 50%, and exposed the shared checked `人物大小` menu.
- Task 2: resized AppKit panels, sprite layers, ground offsets, and alpha hit regions together; focused geometry tests cover all three presets.
- Task 3: scaled screen-edge safety clearances and immediate world clamping with the selected preset; all seven `PetWorldTests` pass.
- Selected global 25%, 50%, and 100% presets with a 50% default; continuous and per-person sizing are out of scope.
- Added a backward-compatible Codable preset model. Legacy preference JSON keeps all booleans and gains the 50% size; all three presets round-trip.
- Added the shared `人物大小` submenu with exactly one checked preset and validated represented values.
- Preference and command-routing slices pass their focused tests.
- Added live panel and Core Animation resizing for all three presets. The content view and normalized alpha hit region now match the actual panel footprint, and the ground offset scales with the visible character.
- AppKit's unavoidable 0.5-point horizontal quantization at the odd 45-point width is documented and covered by the panel test.
- Packaged inspection now accepts exactly four uniformly sized pet windows at any supported preset and rejects mixed sizes.
- Final verification: 80/80 normal tests, 80/80 AddressSanitizer tests, strict Swift concurrency Release build, packaged smoke, nine-command interaction self-test, and strict deep signing all pass.
- The ordinary app launch is left running at the default 50% preset with four 90×80 pet windows and the 96×38 fallback controller.
- **Status:** complete

### Phase 10 — Discoverable action center

- Created `feature/action-center-v2` from the accepted `main` milestone.
- Began context inspection: existing menus expose only `做个动作`, while the world already has deterministic state transitions suitable for a typed action layer.
- Completed the approved written design for a typed catalog, nested native menus, four individual actions, group play, and non-modal feedback bubbles. Self-review found no placeholders, contradictions, or unresolved scope decisions.
- Wrote the five-task TDD implementation plan covering catalog/state, deterministic world actions, native menus, feedback rendering, and full release verification.
- Task 1 RED: catalog and feedback tests failed on the absent typed APIs. GREEN: five stable action definitions and generation-safe feedback state pass focused tests and all 83 tests.
- Task 2 RED: manual-action tests failed on absent routing and roll state. GREEN: four distinct individual states, deterministic durations, non-wrapping roll progress, group execution, individual resume, global-pause rejection, and invalid-request safety pass all 87 tests.
- Task 3 RED: menu tests failed on the absent action-center and context APIs. GREEN: both persistent controls and per-pet right-click menus expose typed, explained action lists with no ambiguous `做个动作` label; all 89 tests pass.
- Task 4 RED: rendering, feedback, coordinator, and runner tests failed on missing APIs. GREEN: roll uses normalized full rotation, bubbles remain 11-point readable, newer feedback replaces older feedback safely, and typed outcomes restore/show the correct panels; all 93 tests pass.
- Task 5 self-test RED/GREEN: packaged interaction coverage increased from 9 to 14 commands by exercising all four manual actions and group play while preserving four finite pets.
- Release diagnosis: the first smoke run was correctly rejected because Stage Manager exposed compositor-scaled bounds. A RED/GREEN inspection test now accepts one uniformly scaled supported window set while mixed sizes remain degraded.
- Final verification: 94/94 normal tests, 94/94 AddressSanitizer tests, strict-concurrency Release build, packaged smoke, 14-command self-test, deep signing, and ordinary live launch pass. The final app is running as PID 60130.
- **Status:** complete
- **Status:** in_progress
