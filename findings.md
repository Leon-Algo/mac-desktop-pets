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
