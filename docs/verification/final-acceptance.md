# Final Acceptance — Local macOS Build

Date: 2026-08-03

## Acceptance matrix

| Area | Result | Evidence |
|---|---|---|
| Configurable roster | PASS | The native `人物设置…` window supports 1–8 ordered characters, add/delete limits, names, full previews, 12 procedural avatars, imported local images, three clothing styles, six palettes, five personality templates, five advanced sliders, Save/Cancel, and current-avatar source labels. |
| Four safe defaults and legacy migration | PASS | New installs receive four non-identifiable procedural defaults; existing installs migrate the original four local identities, names, exact palettes, personalities, and clothing cues without replacement. |
| Transparent desktop rendering | PASS | Each configured character owns one borderless nonactivating panel; tests and packaged self-test cover 1, 4, and 8 panels. |
| Monkey-like human crawling | PASS | All figures use quadrupedal human poses with animated stride/tilt transforms; no literal animal anatomy is added. |
| Playful behavior | PASS | Deterministic states cover crawl, turn, jump, fall, climb, hang, chase, greet, play, idle, and sleep. |
| Screen boundaries | PASS | Visible-screen bounds exclude Dock/menu bar; safe anchor margins prevent panel clipping. |
| Adjustable character size | PASS | The shared `人物大小` menu offers 25%, 50%, and 100% presets with exactly one checked choice. New and migrated settings default to 50%; the selection persists, applies live, and scales panel bounds, rendered content, alpha hit regions, ground offsets, and screen-edge safety clearances together. |
| Discoverable action center | PASS | Both persistent control routes expose `动作中心`, each person's management and right-click menus expose `让他做动作…`, and every item has a stable typed ID, Chinese title, explanation, scope, feedback, and duration. No visible menu uses the ambiguous `做个动作` label. |
| Manual actions and feedback | PASS | `打个招呼`, `原地跳一下`, `翻个跟头`, and `叫爸爸` produce deterministic states; `全部人物一起喊爸爸` restores and affects the active roster. Rounded non-modal bubbles explain success or global-pause rejection and replace older messages safely. |
| Window obstacles | PASS | Live probe accepted an external window rectangle. Tests cover top landing, side-edge detection, turn/climb reaction geometry, filtering, coordinate conversion, and long-run invariants. |
| Persistent control center | PASS | A compact square `🐾` status item is strongly owned, health-checked, debounced across display/Space changes, and bounded-repaired. Its tooltip and accessibility label retain the full `桌面伙伴总台` meaning. The independent launch-visible `🐾 总台` remains the guaranteed recovery route if macOS suppresses status-item pixels for lack of space. |
| Direct interaction | PASS | Shape-aware alpha-mask routing keeps transparent pixels click-through. Single click, double click, drag/release, and right-click commands are covered by click, view, coordinator, and world tests. |
| Control commands | PASS | The shared menu exposes global pause/resume, hide/show, recall-all, dynamic per-character submenus, `人物设置…`, click-through, fallback visibility, launch at login, diagnostics, and quit. The app refuses to hide the last usable control while all pets are hidden or full click-through is enabled. |
| First-run guidance | PASS | Guidance is non-modal and names both the menu-bar `🐾` icon and desktop `🐾 总台`; launch no longer changes activation policy to surface an alert. |
| Live launch | PASS | Ordinary launch returned `status: ok`, `windowCount: 5`, `petWindowCount: 4`, and `fallbackControlPresent: true`. Diagnostics accept 1–8 uniformly sized pets across all size presets and Stage Manager scaling while rejecting mixed sets. |
| Relaunch reliability | PASS | Three consecutive ordinary Finder-style launches each produced the exact four-pet-plus-fallback window set. Early lifecycle protection remains as defensive hardening. |
| Live recovery | PASS | Real menu input hid all pets while preserving the fallback, recalled four panels, proved resume motion and pause stability from window coordinates, and terminated the process through Quit. |
| Stability | PASS | 117/117 normal tests and 117/117 AddressSanitizer tests pass. Coverage includes roster validation/storage, avatar normalization, editor behavior, native controls, runtime replacement, 1/4/8 panels, actions, migration, and Stage Manager inspection. |
| Swift concurrency | PASS | Release build with `-strict-concurrency=complete` succeeds. |
| Resource use | PASS | Release sampling stabilized around 5–6% CPU and 54 MB RSS on the Apple Silicon test host. |
| Privacy | PASS | Imported avatars are normalized locally under Application Support and never uploaded. Runtime obstacle detection remains geometry-only with no networking or nonempty entitlements. See `privacy-audit.md`. |
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
- Double click: all active people gather around the selected person and play.
- Drag/release: move a person and let platform physics resume on release.
- Right click: reaction, per-person pause/resume, recall, hide, recall all, open total station, or quit.
- `🐾 总台`: always visible at launch and automatically restored when all people are hidden; opens the full shared control menu.
- `🐾`: compact square native menu-bar entry when the current macOS menu-bar environment displays it; hover or VoiceOver exposes the full `桌面伙伴总台` name.
- `人物大小`: choose 25%（最小）, 50%（推荐）, or 100%（原样） from either persistent control entry; changes apply immediately and persist across launches.
- `人物设置…`: add, remove, reorder, rename, preview, restyle, tune personality, or import a local avatar; Save applies immediately and Cancel discards the draft.
- `动作中心` / `让他做动作…`: choose one of four explained individual actions or `全部人物一起喊爸爸`; affected people display immediate feedback.
