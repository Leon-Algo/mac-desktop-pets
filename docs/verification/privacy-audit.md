# Privacy Audit

Date: 2026-08-02

## Result

PASS for the local macOS build.

- Window interaction uses `CGWindowListCopyWindowInfo` geometry metadata only.
- The filter reads window number, owner PID/name, layer, alpha, bounds, and on-screen state. Owner names are used only in memory to exclude system surfaces; they are not persisted or included in user-facing diagnostics.
- No window titles or pixels are read, stored, or transmitted.
- No ScreenCaptureKit, display-image capture, Accessibility `AXUIElement`, `URLSession`, Network framework, or socket implementation exists in source.
- The app bundle contains an empty entitlement dictionary and no Screen Recording, camera, microphone, or Accessibility usage descriptions.
- Character assets are bundled locally. The original full photograph is not included.
- Preferences contain only pause, visibility, click-through, and launch-at-login booleans.

## Evidence

- Source/plist symbol scan returned only the status-item image's accessibility description; it found none of the prohibited APIs.
- `plutil -p Resources/DesktopPets.entitlements` returned `{}`.
- `codesign -d --entitlements :- build/DesktopPets.app` returned an empty dictionary.

Uninstall consists of quitting the app, disabling Login at Launch if enabled, and deleting `DesktopPets.app`. Its small preferences domain may be removed separately if desired.
