# Task Plan: macOS Desktop Pets

## Goal
Design and, after explicit approval, build a testable macOS desktop-pet app featuring four recognizable people derived from the supplied group photo, with playful monkey-like crawling animation and interaction with visible window boundaries. Preserve a clear path to a later Windows edition.

## Current Phase
Phase 10 — Discoverable action center complete

## Phases

### Phase 1: Requirements and feasibility
- [x] Capture the confirmed product intent
- [x] Isolate this project's planning records from unrelated workspace tasks
- [x] Confirm the intended visual treatment of the four characters
- [x] Confirm the target Mac hardware and minimum macOS version
- **Status:** complete

### Phase 2: Product and technical design
- [x] Compare implementation approaches and recommend one
- [x] Define character-asset and animation pipeline
- [x] Define desktop integration, obstacle behavior, controls, permissions, and privacy
- [x] Define MVP scope and measurable acceptance criteria
- [x] Present the design in reviewable sections and obtain user approval
- **Status:** complete

### Phase 3: Written specification and implementation plan
- [x] Write the approved design specification
- [x] Self-review it for ambiguity, contradictions, placeholders, and scope
- [x] Obtain user approval of the design and authorization to implement
- [x] Produce a detailed implementation plan
- **Status:** complete

### Phase 4: Implementation
- [x] Prepare and review character assets
- [x] Build the macOS MVP
- [x] Add tests and diagnostics
- **Status:** complete

### Phase 5: Verification and handoff
- [x] Verify rendering, behaviors, resource use, permissions, packaging, and uninstall behavior
- [x] Produce an ad-hoc signed local app and document Developer ID/notarization constraints
- [x] Record Windows-porting design notes
- **Status:** complete

### Phase 6: Direct pet interaction
- [x] Confirm interaction design with the user
- [x] Record the design and implementation plan
- [x] Implement shape-aware mouse acceptance and interaction routing with TDD
- [x] Implement click, double-click, drag/release, and per-pet context commands
- [x] Add discoverable stop/quit guidance
- [x] Rebuild, launch, exercise, and package the updated app
- **Status:** complete

### Phase 7: Persistent control center
- [x] Reproduce the missing status item in the user's real desktop session
- [x] Compare against a minimal standalone status item in the same session
- [x] Obtain approval for a persistent, visible control-center design
- [x] Write and self-review the persistent control-center specification
- [x] Obtain user review of the written specification
- [x] Write and self-review the implementation plan
- [x] Implement status-item lifecycle diagnostics and robust presentation
- [x] Add global and per-character control-center commands
- [x] Verify visibility after first launch, relaunch, full-screen transitions, and hiding characters
- **Status:** complete

### Phase 8: Compact menu-bar item
- [x] Confirm the compact single-paw design and preserve accessibility/recovery behavior
- [x] Write and self-review the design specification
- [x] Write the TDD implementation plan
- [x] Implement square status-item sizing and compact labeling
- [x] Run full automated, package, signing, and live-launch verification
- **Status:** complete

### Phase 9: Adjustable pet sizes
- [x] Select the three-preset design with 50% default
- [x] Inspect rendering, hit-testing, world geometry, preferences, and packaged diagnostics
- [x] Write and self-review the design specification
- [x] Write the detailed TDD implementation plan
- [x] Implement preferences and shared menu controls
- [x] Implement scale-aware panels, hit testing, and world bounds
- [x] Update packaged inspection and run full release verification
- **Status:** complete

### Phase 10: Discoverable action center
- [x] Confirm the recommended action-center direction and obtain authorization to proceed
- [x] Inspect current world states, rendering transforms, menus, panels, and command routing
- [x] Write and self-review the action-center design specification
- [x] Write the detailed TDD implementation plan
- [x] Implement the action catalog and deterministic action commands
- [x] Implement discoverable action menus and transient feedback bubbles
- [x] Add the first four clearly differentiated manual actions
- [x] Run full automated, package, signing, and live-launch verification
- **Status:** complete

## Initial Decisions
| Decision | Rationale |
|---|---|
| macOS first, Windows later | Faster testing on the user's current machine while preserving a cross-platform product path. |
| No implementation before design approval | The user explicitly requested a scheme and alignment first. |
| Store project records in `mac-desktop-pets/` | Root planning files belong to a different task and must not be overwritten. |
| Native Swift/AppKit + Core Animation | Strongest fit for macOS desktop/window integration; Core Animation avoided an unnecessary display-link failure and reduced runtime overhead. |
| Avoid Screen Recording as an MVP requirement | Window geometry should be enough; capturing pixels adds unnecessary privacy and permission costs. |
| Prototype with placeholder art before finalizing four characters | Retires the highest platform-integration risk before expensive asset production. |
| Use semi-realistic 2D miniature people | User approved the recommended option and directed implementation using best practices. |
| Support macOS 13+ and verify on Apple Silicon macOS 26.5.2 | Matches available APIs while covering a broader practical deployment floor than the test machine. |
| Shape-aware interaction mode by default | Enables direct pet interaction while transparent panel regions continue passing mouse input to the desktop. |
| Use a labeled status item plus an independent fallback control | A same-session minimal status item was also suppressed, so a menu-bar-only fix cannot guarantee a stop/restore/quit route. |
| Use a square single-paw native status item | The user prioritized minimizing menu-bar width on a notched display; tooltip, accessibility text, and the independent fallback preserve discoverability. |
| Use global 25%, 50%, and 100% pet-size presets with 50% default | Presets cover compact and original layouts while keeping rendering, collision, persistence, and testing deterministic. |
| Make actions understandable before expanding their count | A catalog with names, explanations, scope, duration, and deterministic routing prevents opaque state names and creates a stable extension point. |

## Errors Encountered
| Error | Attempt | Resolution |
|---|---:|---|
| Root planning files are for an unrelated project | 1 | Created an isolated project directory and records. |
| Identity-preserving generation failed at the service boundary | 2 | Used deterministic local face/hair crops over transparent procedural crawling bodies; documented the visual limitation. |
| SpriteKit display link failed while the display was asleep | 1 | Replaced the static sprite host with Core Animation; regression test proves no display link is required. |
| Resource bundle placement initially invalidated deep signing | 1 | Packaged the SwiftPM resource bundle under `Contents/Resources` and verified strict deep signing. |
| Menu-label test configured interactive mode while expecting full pass-through copy | 1 | Corrected the fixture to `clickThrough: true`; production wording already matched the approved state model. |
| Smoke launch consumed the real first-run control hint and created a fifth alert window | 1 | Added a tested verification-only environment switch; automated launches now suppress the hint without persisting the shown flag. |
| First-run hint was marked shown but not presented by the accessory app | 2 | Activation alone was insufficient; temporarily use regular activation policy for modal alerts, then restore accessory policy after dismissal. |
| A zsh-only `$pipestatus` assertion was written with bash syntax during a RED test command | 1 | Read the compiler failure directly and used ordinary `&&` commands for subsequent Swift test runs. |
| Computer Use could read pet windows but returned `AXError.notImplemented` for the nonactivating fallback panel | 1 | Added an accessible panel title, then used the screenshot workflow plus Core Graphics input on the read-only resolved panel coordinates for live menu acceptance. |
| AppKit quantized the 45-point-wide quarter-size panel origin to a whole point | 1 | Kept the exact 45×40 size and accepted the unavoidable maximum 0.5-point horizontal anchor variance. |
| Manual sleep expiry test tried to advance 4.1 seconds in one call | 1 | The world intentionally caps one `step` call to 1 second; advanced five deterministic 0.9-second steps instead. |
| First Task 4 patch referenced a nonexistent standalone runner test file | 1 | Located `WorldRunnerInteractionTests` inside `PetInteractionTests.swift` and reapplied the complete test patch to the real file. |
| Packaged smoke rejected five Stage Manager-scaled windows | 1 | Core Graphics reported 90×80/96×38 logical windows as 82×73/88×36 compositor bounds; added proportional-group inspection instead of absolute-pixel-only matching. |
| Final verification referenced nonexistent `Scripts/build-app.sh` | 1 | Repository evidence showed the real packaging entry point is `Scripts/package-app.sh`; discarded the stale-bundle result and reran packaging plus all bundle checks from the correct script. |
| Avatar normalization test compared two PNG encodings byte-for-byte | 1 | PNG encoders may emit different metadata/compression for identical pixels; replaced the invalid assertion with PNG signature, decodability, and exact pixel-dimension checks. |
| Settings actions `moveUp:`/`moveDown:` collided with `NSResponder` | 1 | Renamed selectors to `moveCharacterUp:` and `moveCharacterDown:` so they remain ordinary target-action handlers instead of accidental overrides. |
| Settings test hung after `NSPopUpButton.performClick` | 1 | `performClick` opens a real popup menu event loop in headless XCTest; terminated the exact test PIDs and invoked the controller's existing target action directly after selecting the item. |
| Headless settings test still hung on `NSButton.performClick` | 2 | Isolated AppKit click animation/event dispatch as the remaining wait; tests now invoke the same bound target-action methods directly and inspect button enabled state separately. |

## Phase 11 — “叫爸爸”动作替换
- [x] Write and review the focused behavior-change design
- [x] Add failing catalog, world-routing, menu, and packaged-self-test expectations
- [x] Replace individual sleep with `叫爸爸` and group play with `四人一起喊爸爸`
- [x] Run focused, full, release, signing, smoke, and live-launch verification
- **Status:** complete

## Phase 12 — 可选式人物与头像自定义设计
- [x] Merge the accepted action-center milestone into `main`
- [x] Inspect current character, preference, asset, menu, and lifecycle boundaries
- [x] Define 2–3 product/architecture approaches and recommend one
- [x] Present defaults, eight-character limit, UX, persistence, and migration design for approval
- [x] Write and commit the approved design specification
- **Status:** design_complete
