# macOS Desktop Pets Design

## Product goal

Build a native macOS menu-bar application that presents four recognizable desktop-pet characters based on the supplied group photo. The characters crawl on all fours in an intentionally playful, monkey-like human pose, roam across the desktop, climb and rest on visible application-window edges, and interact with one another without obstructing normal computer use.

The first deliverable is a locally runnable macOS `.app`. Character assets and behavior data must use portable formats so a later Windows renderer can reuse them.

## Confirmed visual direction

Use semi-realistic two-dimensional miniature people. Preserve recognizable facial structure, hair, glasses, and clothing cues. Bodies may be proportionally simplified to support expressive animation, but the characters remain human: no monkey faces, fur, tails, or other animal anatomy.

The source image contains incomplete and mutually occluded bodies. Missing arms, hands, legs, and clothing must be reconstructed. Generated art is treated as a derivative asset requiring visual review; the original photograph is never modified.

## Scope

### Version 1 includes

- Four individually recognizable characters.
- Crawl, idle, turn, climb, hang, jump/fall, sleep, chase, greet, and paired-play states.
- Independent personality parameters for speed, curiosity, sociability, courage, and sleepiness.
- Screen-edge, menu-bar, Dock-safe-area, and visible-window-rectangle collision.
- Window top edges as walkable platforms and side edges as climbable surfaces.
- Transparent always-on-top pet windows that do not take keyboard focus.
- Click-through mode enabled by default.
- Menu-bar commands: pause/resume, hide/show, recall, click-through, launch at login, diagnostics, and quit.
- Multiple-display awareness and repositioning when displays change.
- Local preferences and logs without analytics or network access.
- A locally runnable `.app` and a repeatable packaging script.

### Explicitly deferred

- Reading window pixels or application content.
- Speech, sound effects, online services, auto-update, App Store distribution, and cloud sync.
- Direct manipulation of other applications.
- Guaranteed behavior over every full-screen game, protected-content window, or third-party window manager.
- Windows implementation; only portable data contracts and migration notes are required now.

## Architecture

### Native shell

Swift and AppKit own application lifecycle, status-bar menus, transparent nonactivating panels, Spaces/full-screen collection behavior, screen discovery, and Core Graphics window enumeration. SwiftUI is unnecessary for the pet surfaces and is limited to a small diagnostics/settings panel only if it reduces code.

### World model

A platform-neutral `PetWorld` operates in global screen coordinates. It consumes display bounds, safe areas, and normalized obstacle rectangles. At a fixed simulation step it updates four `PetAgent` values and produces poses. A seeded random source makes tests deterministic.

### Window geometry

`CGWindowListCopyWindowInfo` enumerates on-screen normal application windows and their bounds. The provider excludes desktop elements, the app's own windows, transparent/zero-size windows, menu extras, and obvious system overlays. Geometry refreshes four times per second. No pixels are captured.

The initial implementation does not request Screen Recording or Accessibility access. If a future macOS release withholds useful bounds, diagnostics report reduced behavior and the pets fall back to screen-only movement rather than prompting unexpectedly.

### Rendering

Each character owns a small borderless `NSPanel` with a transparent SpriteKit view. The panel never becomes key or main, floats above ordinary application windows, joins all Spaces where supported, and ignores mouse events while click-through is enabled. Pet world positions determine panel frames; sprite animation and procedural secondary motion are local to the view.

The renderer supports a production texture atlas and a bundled procedural fallback. A missing or malformed character pack must never prevent app launch.

### Character package

Each character package contains:

- `manifest.json`: stable identifier, display name, atlas name, frame rectangles, anchor, collision body, and personality.
- A transparent PNG atlas with named sequences.
- Attribution/source metadata that never embeds the source photograph in the distributed application unless needed by an approved asset.

The JSON schema uses points normalized to character height and contains no AppKit types. Windows can implement the same contract.

## Behavior rules

The high-level states are `idle`, `crawl`, `turn`, `climb`, `hang`, `jump`, `fall`, `sleep`, `chase`, `greet`, and `play`. State transitions use explicit cooldowns so agents do not flicker between actions.

- Agents prefer reachable window tops and screen-safe-area floors.
- A nearby agent can trigger greet, chase, or play when both cooldowns permit.
- A moving or disappearing obstacle triggers fall/recovery rather than teleportation.
- An off-screen or invalid position is clamped to the nearest safe display and logged.
- Reduced Motion disables jumps and reduces bobbing/rotation.
- Pause freezes simulation without terminating the app.

## Privacy and permissions

- The app does not record the screen, inspect window content, transmit window metadata, or perform analytics.
- Window titles are neither persisted nor logged; only process identifier and rectangles are needed transiently.
- Character generation may use the user-provided reference image during development. Runtime builds contain only approved derivative assets.
- Accessibility and Screen Recording permissions are not requested in Version 1.

## Error handling and recovery

- Corrupt preferences reset to documented defaults.
- Invalid character manifests fall back to procedural characters and produce a structured log entry.
- Window enumeration failure falls back to screen edges.
- Display removal relocates affected characters to the primary display.
- Rendering failure hides only the affected pet panel; the menu remains available for recall and diagnostics.
- Uncaught startup configuration problems display a readable diagnostics window and retain Quit access.

## Verification and acceptance

The build is accepted only when all of the following have direct evidence:

1. `swift test` passes all domain, manifest, geometry, state-machine, and integration tests.
2. Release build and application bundle validation complete successfully.
3. A launch smoke test confirms a running process, menu-bar item, and four visible pet windows.
4. A window-obstacle integration probe observes at least one external window rectangle and demonstrates a pet selecting its top edge as a platform.
5. A rendered snapshot shows four distinct, nonempty character images on a transparent background.
6. Pause/resume, hide/show, recall, click-through, and quit commands are exercised.
7. Thirty-minute accelerated simulation finds no non-finite coordinates, invalid transitions, or permanently stuck agents; a shorter real-time app soak verifies process stability.
8. Debug builds run with Swift strict-concurrency checks and sanitizers where supported; Release runs without crash or fatal log entries.
9. The app requests neither Screen Recording nor Accessibility permission.
10. On the test Mac, idle CPU targets 5% or less and resident memory targets 200 MB or less. Results are reported honestly rather than converted into hard pass claims if measurement noise is significant.

## Platform and build constraints

- Minimum supported macOS: 13.0.
- Primary verification machine: Apple Silicon, macOS 26.5.2, Xcode 26.5, Swift 6.3.2.
- No third-party runtime dependencies.
- Swift Package Manager is the source-of-truth build system.
- Local packaging must not require a paid Apple Developer account. Distribution signing and notarization are documented separately.

## Windows migration boundary

Windows reuses character atlases, JSON manifests, state names, normalized coordinates, personality fields, and deterministic behavior tests. The Windows-specific layer replaces AppKit panels, NSScreen discovery, and Core Graphics enumeration with Windows APIs. No claim is made that the macOS binary itself is cross-platform.

