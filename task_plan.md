# Task Plan: macOS Desktop Pets

## Goal
Design and, after explicit approval, build a testable macOS desktop-pet app featuring four recognizable people derived from the supplied group photo, with playful monkey-like crawling animation and interaction with visible window boundaries. Preserve a clear path to a later Windows edition.

## Current Phase
Phase 4 — Implementation

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
- [ ] Prepare and approve character assets
- [ ] Build the macOS MVP
- [ ] Add tests and diagnostics
- **Status:** in_progress

### Phase 5: Verification and handoff
- [ ] Verify rendering, behaviors, resource use, permissions, packaging, and uninstall behavior
- [ ] Produce a signed/notarization-ready macOS app build or document local-development signing constraints
- [ ] Record Windows-porting design notes
- **Status:** pending

## Initial Decisions
| Decision | Rationale |
|---|---|
| macOS first, Windows later | Faster testing on the user's current machine while preserving a cross-platform product path. |
| No implementation before design approval | The user explicitly requested a scheme and alignment first. |
| Store project records in `mac-desktop-pets/` | Root planning files belong to a different task and must not be overwritten. |
| Recommend native Swift/AppKit + SpriteKit | Strongest fit for macOS desktop/window integration and low-overhead 2D pets; portability is preserved at the asset/behavior layer. |
| Avoid Screen Recording as an MVP requirement | Window geometry should be enough; capturing pixels adds unnecessary privacy and permission costs. |
| Prototype with placeholder art before finalizing four characters | Retires the highest platform-integration risk before expensive asset production. |
| Use semi-realistic 2D miniature people | User approved the recommended option and directed implementation using best practices. |
| Support macOS 13+ and verify on Apple Silicon macOS 26.5.2 | Matches available APIs while covering a broader practical deployment floor than the test machine. |

## Errors Encountered
| Error | Attempt | Resolution |
|---|---:|---|
| Root planning files are for an unrelated project | 1 | Created an isolated project directory and records. |
