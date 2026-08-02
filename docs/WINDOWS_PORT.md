# Windows Port Boundary

The macOS binary is not cross-platform. A Windows edition should reuse the portable files and behavior semantics, then replace the platform shell.

## Reuse unchanged

- Character identifiers, face/atlas PNG assets, palette values, personalities, normalized anchors, collision bodies, animation names, and JSON validation rules.
- `PetState` names and fixed-step behavior semantics.
- Deterministic geometry and 30-minute invariant fixtures translated byte-for-byte into the Windows test target.

## Replace on Windows

- `NSPanel` and Core Animation rendering: use transparent layered windows with a native Windows renderer.
- `NSScreen`: use monitor enumeration and per-monitor DPI conversion.
- `CGWindowListCopyWindowInfo`: use `EnumWindows`, DWM frame bounds, visibility, owner PID, and z-order filtering.
- Menu-bar status item: use a notification-area icon and native context menu.
- `SMAppService`: use the approved Windows startup registration mechanism.

Keep geometry in logical, bottom-left-origin world coordinates at the domain boundary. Convert Windows top-left physical/logical coordinates only inside the Windows platform adapter.
