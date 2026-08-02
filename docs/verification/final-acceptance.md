# Final Acceptance — Local macOS Build

Date: 2026-08-02

## Acceptance matrix

| Area | Result | Evidence |
|---|---|---|
| Four distinct people | PASS | Runtime snapshot contains four separated figures using the four exact local face/hair crops and distinct plaid, black sleeveless, mint, and black/white clothing cues. |
| Transparent desktop rendering | PASS | `runtime-snapshot.png` is 1440×320 with alpha; packaged runtime exposes four borderless nonactivating panels. |
| Monkey-like human crawling | PASS | All figures use quadrupedal human poses with animated stride/tilt transforms; no literal animal anatomy is added. |
| Playful behavior | PASS | Deterministic states cover crawl, turn, jump, fall, climb, hang, chase, greet, play, idle, and sleep. |
| Screen boundaries | PASS | Visible-screen bounds exclude Dock/menu bar; safe anchor margins prevent panel clipping. |
| Window obstacles | PASS | Live probe accepted an external window rectangle. Tests cover top landing, side-edge detection, turn/climb reaction geometry, filtering, coordinate conversion, and long-run invariants. |
| Persistent control center | PASS | A labeled `🐾 桌宠` status item is strongly owned, health-checked, debounced across display/Space changes, and bounded-repaired. The current system suppresses its pixels despite healthy AppKit state, so the independent launch-visible `🐾 总台` provides the guaranteed route. |
| Direct interaction | PASS | Shape-aware alpha-mask routing keeps transparent pixels click-through. Single click, double click, drag/release, and right-click commands are covered by click, view, coordinator, and world tests. |
| Control commands | PASS | The shared menu exposes global pause/resume, hide/show, recall, four per-character submenus, click-through, fallback visibility, launch at login, diagnostics, and quit. Pet context menus add recall-all, open-total-station, and quit. The app refuses to hide the last usable control while all pets are hidden or full click-through is enabled. |
| First-run guidance | PASS | Guidance is non-modal and names both `🐾 桌宠` and `🐾 总台`; launch no longer changes activation policy to surface an alert. |
| Live launch | PASS | Packaged inspection precisely matched four 180×160 pet windows plus the named 96×38 fallback and returned `status: ok`, `windowCount: 5`, `petWindowCount: 4`, and `fallbackControlPresent: true`. |
| Live recovery | PASS | Real menu input hid all pets while preserving the fallback, recalled four panels, proved resume motion and pause stability from window coordinates, and terminated the process through Quit. |
| Stability | PASS | 73/73 normal tests and 73/73 AddressSanitizer tests pass, including an accelerated 30-minute simulation. |
| Swift concurrency | PASS | Release build with `-strict-concurrency=complete` succeeds. |
| Resource use | PASS | Release sampling stabilized around 5–6% CPU and 54 MB RSS on the Apple Silicon test host. |
| Privacy | PASS | Geometry-only inspection; no capture, Accessibility, networking, titles, or nonempty entitlements. See `privacy-audit.md`. |
| Bundle integrity | PASS | Info.plist lint and `codesign --verify --deep --strict` pass. |
| Public distribution | NOT PERFORMED | The machine has no Developer ID identity. The bundle is ad-hoc signed for local use; public distribution still requires Developer ID signing and notarization. |

## Visual limitation

The app uses the exact photographed faces, hair, and glasses over clean procedural crawling bodies. Because the identity-preserving generation service failed twice before returning an artifact, the clothing/limbs are stylized reconstructions rather than photorealistic full-body generations. This is an honest MVP limitation, not hidden behind the procedural fallback.

## Deliverables

- Local app: `build/DesktopPets.app`
- Runtime preview: `docs/verification/runtime-snapshot.png`
- Character review: `docs/verification/character-asset-review.md`
- Windows boundary: `docs/WINDOWS_PORT.md`

## Interaction controls

- Single click: the selected person greets.
- Double click: all four gather around the selected person and play.
- Drag/release: move a person and let platform physics resume on release.
- Right click: reaction, per-person pause/resume, recall, hide, recall all, open total station, or quit.
- `🐾 总台`: always visible at launch and automatically restored when all people are hidden; opens the full shared control menu.
- `🐾 桌宠`: labeled native menu-bar entry when the current macOS menu-bar environment displays it.
