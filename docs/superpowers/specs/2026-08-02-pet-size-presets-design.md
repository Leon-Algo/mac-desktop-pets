# Pet Size Presets Design

## Goal

Make the four desktop people less obstructive by default while letting the user choose a predictable global size from the existing control center.

## Approaches considered

1. **Fixed 50% size:** smallest implementation, but users on external displays cannot restore the larger presentation without another build.
2. **Three global presets — selected:** `25%`, `50%`, and `100%` cover compact, recommended, and original appearances with deterministic geometry.
3. **Continuous slider:** more flexible, but introduces arbitrary window dimensions, harder menu interaction, and unnecessary collision/test complexity.

## Product behavior

- Add a `人物大小` submenu to the shared menu used by both the compact `🐾` status item and floating `🐾 总台`.
- Options are `25%（最小）`, `50%（推荐）`, and `100%（原样）`; the current option has a checkmark.
- The setting applies immediately and globally to all four people.
- New installs and upgrades from preferences without a size field use `50%`.
- The choice persists across relaunches.
- Animation speed and world positions remain unchanged. Only visual/window footprint and display-edge safety clearances scale.

## Architecture and data flow

`PetScalePreset` is a string-backed `Codable`, `CaseIterable`, `Sendable` enum with scale factors `0.25`, `0.5`, and `1.0`. `AppPreferences` stores the selected preset using backward-compatible decoding.

`StatusMenuController` renders the submenu. A represented raw value reaches `AppController.setPetScale(_:)`, which updates preferences and calls `WorldRunner.setScale(_:)`. `WorldRunner` updates `PetWorld` safety geometry and `PetWindowCoordinator` panel geometry, then reapplies the current poses.

`PetWindowCoordinator` keeps the original 180×160 design canvas as its base size. It resizes every panel to the selected factor, keeps each pose anchored to the same feet/ground coordinate, and updates `PetSpriteView` layer geometry so visible pixels and alpha hit-testing shrink together.

`RunningAppInspection` accepts exactly four pet windows at one of the supported size pairs plus the named fallback window, allowing packaged smoke tests to remain meaningful at the new 50% default.

## Geometry rules

- Panel sizes: 45×40, 90×80, or 180×160 points.
- Ground offset: base 20 points multiplied by the selected factor.
- Screen-edge half-width and top clearance: base 90 and 140 points multiplied by the selected factor.
- Window obstacle surfaces remain unscaled because they describe external applications.
- Drag coordinates and behavior velocities remain in screen points and are not scaled.

## Error handling and migration

- Missing size fields decode as `.half`.
- Unknown/corrupt preference data falls back to all application defaults, as today.
- Invalid menu represented values are ignored without changing the current size.

## Acceptance criteria

1. Default and migrated size is 50%; all three values round-trip through preferences.
2. The shared menu contains all three choices and marks exactly the active one.
3. Switching presets immediately produces four panels at the expected dimensions while preserving their ground anchors.
4. Shape-aware hit testing uses the resized panel rather than the old 180×160 transparent area.
5. World clamping uses scale-aware clearances.
6. Packaged inspection recognizes the supported 25%, 50%, and 100% window sizes and rejects unrelated windows.
7. Normal tests, AddressSanitizer tests, strict-concurrency Release build, package smoke, signing verification, and live launch pass.

## Non-goals

- Per-person independent sizes.
- Arbitrary percentages or a continuous slider.
- Scaling movement speed, jump height, or external window geometry.
