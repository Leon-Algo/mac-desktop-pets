# Progress Log

## Session: 2026-08-01

### Phase 1 — Requirements and feasibility
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
