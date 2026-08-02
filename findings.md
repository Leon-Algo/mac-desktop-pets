# Findings and Decisions

## Confirmed intent
- First deliverable is a macOS desktop application for convenient local testing.
- A later Windows application may share assets and core behavior but can use a platform-specific shell.
- Four people must be extracted from the supplied group photo.
- Faces, hairstyles, glasses, and clothing cues should remain recognizable.
- The background must be removed and occluded limbs/body areas naturally reconstructed.
- All four characters should crawl and play in a humorous, monkey-like manner without becoming literal monkeys.
- Pets should move across the desktop and react to screen and visible application-window boundaries as obstacles or platforms.
- The prior summarized intent is confirmed by the user.

## Source-image feasibility notes
- The photo contains four distinct faces with useful facial and clothing detail.
- Bodies are partially cropped and mutually occluded, so full-body crawling poses cannot be recovered literally; they will require generative reconstruction and human review.
- A single still image cannot provide accurate animation views by itself. The practical asset pipeline must create approved character sheets and multiple pose/direction states while anchoring facial identity to the photo.

## Design principles
- Separate character art and cross-platform behavior rules from platform-specific desktop/window integration.
- Keep all source-image processing local where practical; disclose any external generative service before sending the photo.
- Start with a bounded MVP and add richer social behaviors after stability is proven.
- Avoid permanent Accessibility permission for the MVP unless testing proves it is necessary.

## Verified macOS platform capabilities
- AppKit `NSWindow` supports transparent mouse-event behavior and configurable window levels, which fits non-blocking desktop-pet overlays.
- `NSWindow.CollectionBehavior` supports joining all Spaces and appearing alongside full-screen apps; Stage Manager/full-screen behavior needs explicit testing because some options are mutually exclusive.
- Core Graphics can enumerate on-screen windows in front-to-back order, exclude desktop elements, and expose bounds in screen coordinates. This is the preferred geometry-only MVP path.
- ScreenCaptureKit can enumerate displays, applications, and windows, but Apple's sample notes a Screen Recording permission prompt for capture. Since the MVP needs geometry rather than pixels, capture should not be the default.
- Accessibility `AXUIElement` exposes UI positions and notifications but may be disabled and requires user authorization. Reserve it as an opt-in precision enhancement rather than a baseline dependency.

## Candidate implementation approaches
1. **Native Swift/AppKit + SpriteKit:** best macOS integration, smallest permission footprint, and efficient 2D animation; later Windows shell is separate while assets and behavior definitions remain portable.
2. **Godot:** better engine-code reuse across macOS and Windows, but transparent desktop overlays, Spaces, window enumeration, and click-through behavior still require native plugins and more packaging work.
3. **Web shell (Electron/Tauri + canvas):** quick UI development, but weaker fit for multiple transparent desktop windows, native window geometry integration, and low idle resource use.

## Provisional recommendation
- Use native Swift/AppKit for lifecycle, menu-bar controls, transparent pet windows, multi-display/Space handling, and window geometry.
- Use SpriteKit for animation and light 2D physics.
- Use a platform-neutral character pack: transparent PNG parts, a JSON skeleton, animation clips, hit shapes, personality parameters, and metadata. A later Windows renderer can consume the same pack.
- Prefer a layered 2D puppet over fully generated frame-by-frame animation. It preserves each face and outfit more consistently and makes crawling/climbing transitions easier to tune.
- Prove overlay/window collision with placeholder art before investing in all four final character packs.

## Official Apple references
- AppKit NSWindow: https://developer.apple.com/documentation/appkit/nswindow
- Window collection behaviors: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct
- Core Graphics window list options: https://developer.apple.com/documentation/coregraphics/window-list-option-constants
- ScreenCaptureKit shareable content: https://developer.apple.com/documentation/screencapturekit/scshareablecontent
- Accessibility AXUIElement: https://developer.apple.com/documentation/applicationservices/axuielement_h

## Resolved product choices
1. The local MVP uses recognizable photo faces with semi-realistic/stylized miniature crawling bodies.
2. The build supports macOS 13+ and was verified on Apple Silicon macOS 26.5.2.
3. Pets ignore mouse input by default; the menu can disable click-through.
4. Runtime assets and processing are local. The attempted built-in identity-preserving generation never produced an uploaded-result artifact, so the shipped assets use deterministic local crops.

## Implementation findings — 2026-08-02
- The live Core Graphics probe returned one display and one accepted external application-window rectangle without ScreenCaptureKit or Accessibility APIs.
- The first behavior test exposed an x-motion cancellation caused by reversing direction after vertical floor clamping. The implementation now reverses only when horizontal clamping occurs; the regression test passes.
- The procedural renderer produced a transparent 1440×320 Retina PNG containing four separated crawling human figures with distinct clothing cues.
- Visual inspection: pose, transparency, glasses, plaid shirt, mint shirt, and black/white clothing cues are clear. The procedural faces are not sufficiently recognizable as the four people and are only an operational fallback; production identity-preserving assets remain mandatory.
- The built-in identity-preserving edit failed twice at the image service network boundary and produced no artifact. Per the image-generation workflow, no unapproved CLI/model fallback was used.
- A deterministic local extraction from the 6528×4896 source produced four separately reviewed portrait crops. The runtime composite now uses the exact photographed faces/hair/glasses over the stylized crawling bodies; a transparent 1440×320 Retina verification image shows four recognizable separated identities.
- Core Animation replaced SpriteKit for the single-layer procedural figures after an asleep-display run exposed CVDisplayLink startup errors. This removes an unnecessary display-link dependency while retaining pose transforms.
- The final simulation cadence is 20 Hz with window metadata refreshed at 1 Hz. A release run stabilized around 5–6% CPU and 54 MB RSS on the test host.
- The final obstacle model supports window-top landing, side-edge crossing detection, turn-or-climb reactions, falls, screen-safe clamping, and exclusion of Dock/menu-bar areas via `visibleFrame`.
- All 39 tests pass normally and under AddressSanitizer. A strict Swift 6 concurrency release build also passes.
- The packaged app launches as one menu-bar process with four on-screen pet panels, uses empty entitlements, and passes `codesign --verify --deep --strict` with ad-hoc signing.
- No Developer ID certificate is installed (`0 valid identities found`), so Gatekeeper correctly rejects the local ad-hoc build for public distribution. Developer ID signing and Apple notarization remain release operations, not functional defects.

## Direct-interaction findings — 2026-08-02
- The existing paw status menu already exposes pause, hide, and quit, but there is no first-launch guidance, so the control path is not discoverable.
- Default `clickThrough = true` makes every pet panel ignore mouse events. Turning it off only makes the rectangular panel receive clicks; `PetSpriteView` currently has no mouse handlers.
- AppKit windows are rectangular at the WindowServer level. Shape-aware pass-through therefore requires dynamically toggling `ignoresMouseEvents` from the rendered alpha mask at the current mouse location, while pinning acceptance during a drag.
- The approved interaction set is: single-click reaction, double-click group play, drag/release with falling, right-click per-pet commands, and an explicit first-launch explanation of the paw menu.

## Persistent control-center investigation — 2026-08-02
- The user reported that the paw status item is absent, leaving no obvious global pause/quit/restore path.
- Reproduced on the live packaged app: process and four pet panels were active, while a full-screen capture of a normal desktop Space showed no paw item in the visible menu bar.
- Ownership is not the immediate failure: `DesktopPetsApplication` strongly retains `AppController`, which strongly retains `StatusMenuController`, which strongly retains the `NSStatusItem`.
- The status item is currently icon-only with `NSStatusItem.squareLength`; it does not set a text label, explicit visibility, or any lifecycle telemetry.
- A separate minimal `TEST` status item launched in the same session was also absent from the visible menu bar. This indicates the environment/menu-bar presentation path can suppress new status items, so merely recreating the same icon-only item is not a reliable fix.
- Full-screen Spaces also hide the macOS menu bar until it is revealed. The control design needs both a robust status item and an in-app fallback so users cannot become trapped after hiding all pets.
- The completed status item reports healthy AppKit lifecycle properties (`isVisible`, button, and window all true) but remains pixel-suppressed in the current menu-bar environment. Diagnostics deliberately report this distinction instead of claiming visual visibility.
- The launch-visible `🐾 总台` was captured at the top-right in both ordinary and full-screen desktop states. Its shared menu rendered global controls, `四人管理`, click-through, launch-at-login, diagnostics, and quit.
- Live input acceptance proved: hide-all removes the four pet windows but leaves the fallback; recall restores four windows; resume changes window positions over 1.5 seconds; pause keeps all positions identical; quit removes the process.
- A final review found that individually hiding all four characters must affect the global show/hide label. The effective visibility policy now changes the label to `显示宠物` and makes the next global click restore everyone.
# 2026-08-02 — Pet size presets

- Current pet panels and rendered canvases are fixed at 180×160 points.
- Pose positions represent the feet/ground anchor; panel origin currently subtracts a fixed 20-point ground offset.
- `PetSpriteView` uses a normalized alpha mask, so resized layer bounds can preserve accurate click-through without regenerating the identity image.
- `PetWorld` clamps against fixed 90-point half-width and 140-point top clearance; these must become scale-aware to prevent small pets retaining oversized invisible boundaries.
- Packaged inspection currently recognizes only four 180×160 windows and must accept the active supported preset.
- Preferences use synthesized Codable without a size field, so explicit backward-compatible decoding is required for upgrades.
- AppKit quantizes the origin of the odd-width 45-point quarter-size panel to a whole point, creating at most 0.5 point of horizontal anchor variance.

# Phase 10 action-center findings (2026-08-02)

- The current behavior engine exposes 11 low-level `PetState` cases, but the user-facing menu collapses all of them into the ambiguous command `做个动作`.
- `PetWorld.handle` already provides deterministic per-character and group routing, so a typed manual-action catalog can be added without replacing autonomous behavior.
- The shared `StatusMenuController` and each pet context menu already carry character IDs through `representedObject`; action commands should carry a small typed payload containing both character ID and action ID.
- AppKit menus are the existing native UI surface. The smallest bridge is to add nested action submenus and keep catalog/world state in pure Swift value types.
- New action visuals should reuse Core Animation transforms and existing procedural character rendering; no new dependency or sprite framework is needed.
- Each character is currently rendered as one composited bitmap layer, so the first action set must use whole-character transforms and physics. True limb-specific waving would require a later segmented-rig asset pipeline.
- The first release action set will therefore use four visually separable and reliable commands: `打招呼`, `原地跳`, `翻个跟头`, and `趴下睡觉`; the existing group gather/play command remains available as `四人集合玩耍`.
- Feedback should be a non-modal `CATextLayer` bubble owned by each `PetSpriteView`, with a generation token so a newer message cannot be dismissed by an older timer.
- Manual commands use typed IDs and outcomes. Per-person pause is cleared on a direct command, while global pause rejects the command with a visible explanation instead of silently changing the global setting.
- `PetAgent.pose.phase` currently wraps every second. For a 1.4-second roll, it must emit normalized roll progress instead of the ordinary repeating gait phase, otherwise the rotation snaps after one second.
- Manual duration needs lightweight agent state (`manualActionID`) so manual greet and sleep can expire at catalog-defined durations without changing unrelated autonomous behavior.
- `PetWindowCoordinator` is the narrow feedback bridge: it can expose `showFeedback(for:message:duration:)` while keeping feedback-layer ownership inside `PetSpriteView`.
- Stage Manager applies a compositor transform to inactive window groups, so `CGWindowList` can report 90×80/96×38 logical windows as 82×73/88×36. Packaged inspection must validate a uniformly scaled five-window set rather than only absolute logical sizes.

# Phase 11 “叫爸爸” findings (2026-08-03)

- The public action IDs still encode the old semantics (`sleep`, `gatherPlay`), so a best-practice replacement must rename the typed IDs as well as the visible labels.
- The single-character composite artwork cannot animate a mouth or isolated limb. A short hop plus a `爸爸！` feedback bubble is a clear, dependency-free first implementation.
- Group routing already restores and gathers all four characters. It can remain the physical behavior while the typed action becomes `groupCallDad` and all four receive the same `爸爸！` feedback.
- Autonomous sleeping remains valid world behavior and is not removed; only the user-triggered sleep command is being replaced.
- The completed implementation uses typed IDs `callDad` and `groupCallDad`; no production or test menu copy retains the removed sleep/play labels.
- Final verification passed 94/94 normal tests, 94/94 AddressSanitizer tests, strict-concurrency Release build, fresh packaging, deep signing, five-window smoke inspection, and the 14-command self-test.

# Phase 12 custom-character findings (2026-08-03)

- The accepted action-center branch was fast-forward merged into local `main` at `aad9023`; 94/94 tests passed on the merged result, and the merged feature branch was deleted.
- `CharacterManifest` already separates identity, palette, personality, collision geometry, and animation metadata, which is a sound basis for user-editable profiles.
- Bundled defaults currently come from `characters.json`, but face assets are hard-coded as bundled JPEGs resolved from each fixed character ID. User imports therefore need a separate application-support asset store and a stable asset reference rather than arbitrary external file paths.
- Rendering composites one face image over a procedural body, so the first customization version can safely offer face, name, palette, and personality choices without building a segmented body rig.
- Menus and window coordination iterate over the supplied character list, but product copy still says “四人” in several places. Supporting 1–8 active characters requires count-neutral labels and validation at the catalog/profile boundary.
- `WorldRunner` owns an immutable character array and constructs its world/windows once, so applying roster edits requires a controlled runner rebuild that stops and hides old panels before replacing them; palette/name-only mutation cannot safely be bolted onto the current runner.
- The packaged smoke inspector and interaction self-test hard-code exactly four pets. They must accept an expected active count in the supported range while retaining a deterministic four-person default fixture.
- `ProceduralPetRenderer` uses character IDs to special-case two clothing details. Custom profiles need explicit style options (for example `plain`, `plaid`, `jacket`) instead of magic IDs.
- There is no settings window today. A dedicated native editor window is preferable to placing image import, preview, reordering, and deletion inside nested status menus.
- Existing preference storage is one JSON blob in `UserDefaults`, which is suitable for lightweight app switches but not imported image bytes. Profile metadata should use versioned Codable storage, while copied/normalized images live under Application Support.
- Three approaches were assessed: preset-only (simple but not truly customizable), preset-first plus local image import (recommended), and fully external JSON/character packages (powerful but too technical as the primary UX).
- Recommended initial product defaults: four active, non-identifiable illustrated characters; a twelve-avatar built-in face library; six outfit palettes; five personality presets plus optional advanced sliders; roster add/remove/reorder with a hard 1–8 active-character invariant.
- Imported images should be copied, normalized, and stored locally only. The app should never retain security-scoped access to an arbitrary original path and should expose Replace/Remove controls.
- The current four real-person face assets should not be the open-source distribution defaults without explicit likeness and redistribution permission. They can remain a private/local profile set while public defaults use original synthetic illustrations.
- The implemented upgrade path detects existing preferences and migrates the four bundled identities into versioned local profiles; a clean install receives four procedural defaults from a 12-avatar library.
- Native visual QA confirmed the 820×560 dark-mode editor fits without clipping and exposes all required controls. It also found two issues that automated model tests alone missed: misleading legacy source copy and selection resetting after Add; both now have UI regression tests.
- Final package verification covers 119 normal and AddressSanitizer tests, including the added avatar crop editor with zoom and horizontal/vertical positioning, plus strict-concurrency Release, deep signing, dynamic smoke, 14 commands, and finite 1/4/8 roster simulations.
