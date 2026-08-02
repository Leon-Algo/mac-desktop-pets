# Task Plan: macOS Desktop Pets

## Goal
Design and, after explicit approval, build a testable macOS desktop-pet app featuring four recognizable people derived from the supplied group photo, with playful monkey-like crawling animation and interaction with visible window boundaries. Preserve a clear path to a later Windows edition.

## Current Phase
Phase 7 — Persistent control center design

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
- [ ] Implement status-item lifecycle diagnostics and robust presentation
- [ ] Add global and per-character control-center commands
- [ ] Verify visibility after first launch, relaunch, full-screen transitions, and hiding characters
- **Status:** in_progress

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
