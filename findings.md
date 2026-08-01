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

## Open questions
1. Should the character art look like realistic photo cutouts, semi-realistic illustrated miniatures, or deliberately cartoonish chibi figures?
2. What Mac model/processor and macOS version will be used for testing?
3. Should pets ignore mouse input by default, or be draggable/clickable?
4. Is sending the source image to an external image-generation service acceptable, or must all processing remain local?
