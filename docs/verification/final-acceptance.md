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
| Menu-bar lifecycle | PASS | App launches as an accessory/menu-bar process; commands implement pause/resume, hide/show, recall, click-through, launch at login, diagnostics, and quit. |
| Direct interaction | PASS | Shape-aware alpha-mask routing keeps transparent pixels click-through. Single click, double click, drag/release, and right-click commands are covered by click, view, coordinator, and world tests. |
| First-run guidance | PASS | A real foreground launch displayed and focused the control dialog explaining direct interaction and the paw-menu pause/quit path; automated smoke suppresses it without consuming the user's flag. |
| Live launch | PASS | Packaged Release app remained alive with exactly four on-screen pet windows (`status: ok`, `windowCount: 4`). |
| Stability | PASS | 55/55 normal tests and 55/55 AddressSanitizer tests pass, including an accelerated 30-minute simulation. |
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
- Right click: reaction, per-person pause/resume, recall, or hide.
- Paw menu: global pause/resume, hide/show, recall, full click-through, diagnostics, and Quit.
