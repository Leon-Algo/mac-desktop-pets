# Compact Menu-Bar Item Design

## Goal

Reduce the desktop pet's native menu-bar footprint so the control remains available longer on notched Mac displays without removing any commands or recovery routes.

## Approved interaction

- Replace the variable-width `🐾 桌宠` label with one square AppKit status item displaying only `🐾`.
- Keep the tooltip and accessibility label as `桌面伙伴总台`, so compactness does not remove meaning for pointer and assistive-technology users.
- Keep the existing shared menu, status-item health checks, pet context menus, and independent `🐾 总台` fallback unchanged.
- Hiding the fallback remains independent from the native status item; no animation or transfer between the two controls is implied.

## AppKit boundary

`StatusMenuController` remains the sole owner of `NSStatusItem`. Both initial creation and health-repair recreation must use `NSStatusItem.squareLength`. A read-only test seam exposes the configured length so regression tests verify both the compact title and system square width.

## Acceptance criteria

1. The status button title is exactly `🐾`.
2. The status-item length is exactly `NSStatusItem.squareLength` after initial creation.
3. Health repair recreates the item with the same square length.
4. Tooltip, accessibility name, shared commands, fallback control, and recovery behavior remain intact.
5. Full tests, AddressSanitizer tests, strict-concurrency Release build, package smoke, and signing verification pass.

## Non-goals

- macOS cannot move third-party status items to the left side of the notch; this change does not attempt to override system menu-bar layout.
- No third-party menu-bar manager is installed.
- The floating fallback is not removed.
