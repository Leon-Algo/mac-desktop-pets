# Desktop Pets Action Center V2 Design

Date: 2026-08-02

## Goal

Make manual actions understandable before increasing their number. A user must be able to discover an action, read what it will do, trigger it for a specific person, see immediate feedback, and distinguish the resulting motion from the other actions.

## Scope

This milestone adds a typed action catalog, shared and per-person action menus, transient feedback bubbles, four individual actions, and one existing group action exposed through the same system.

Individual actions:

- `wave`: `👋 打个招呼` — sways toward the user for about 1.8 seconds and displays `嗨！`.
- `hop`: `⬆️ 原地跳一下` — performs one physics-driven vertical hop and displays `看我跳！`.
- `roll`: `🙈 翻个跟头` — performs a complete whole-body rotation for about 1.4 seconds and displays `翻个跟头！`.
- `sleep`: `💤 趴下睡觉` — lies down and dims for about 4 seconds and displays `先睡一会儿…`.

Group action:

- `gatherPlay`: `🎉 四人集合玩耍` — recalls hidden people, gathers all four around a leader, and starts the existing group play behavior.

Environment-seeking actions such as selecting and climbing a nearby window are deliberately deferred. They require path selection and a visible failure/fallback design of their own.

## Product Behavior

The shared `🐾` / `🐾 总台` menu gains a top-level `动作中心` submenu. It contains one submenu for each person and a separate group-action section. Each person's existing management menu replaces the opaque `做个动作` item with `让他做动作…` and the same individual action list. A person's right-click menu exposes that list as a submenu as well.

Every action item includes a stable title and a one-line tooltip description. The user-facing UI never exposes internal state names such as `greet`, `roll`, or `sleep`.

Triggering an individual action automatically resumes that person if only that person was paused. Triggering an action for a hidden person recalls and shows that person first. A global pause remains authoritative: the action is rejected without changing the global preference, and the person's feedback bubble says `当前已暂停，请先继续活动`.

Unknown action or character identifiers are rejected without changing world state. No modal alert is used for normal action feedback.

## Architecture

### Typed action catalog

`PetActionCatalog.swift` owns:

- `PetActionID`: stable Codable IDs.
- `PetActionScope`: individual or group.
- `PetActionDefinition`: title, explanation, feedback, nominal duration, and scope.
- `PetActionRequest`: action ID plus an optional target character ID.
- `PetActionOutcome`: performed or unavailable, affected IDs, and feedback text.

The catalog is the only source of user-facing action metadata. Menus and the world consume it rather than duplicating strings.

### World command routing

`PetInteraction` gains `performAction(PetActionRequest)`. `PetWorld` validates scope and target, clears only per-character pause when allowed, and applies deterministic state transitions. `roll` becomes a new `PetState`; the existing `greet`, `jump`, `sleep`, and group-play behavior are reused with manual timing made explicit where necessary.

`WorldRunner` receives `PetActionOutcome`, recalls/shows affected hidden panels, applies poses immediately, and forwards feedback to the window coordinator. Autonomous behavior continues unchanged after a manual action completes.

### Rendering and feedback

The current character asset is one composited bitmap, so this milestone uses whole-character Core Animation transforms and existing physics. `roll` rotates the layer through one full turn. `wave`, `hop`, and `sleep` remain visually distinct through sway, vertical motion, rotation, angle, and opacity.

Each `PetSpriteView` owns a small rounded `CATextLayer` feedback bubble. Messages disappear after their definition's nominal feedback duration. A monotonically increasing generation token prevents an older delayed dismissal from hiding a newer message. Bubble text remains readable at every pet-size preset instead of shrinking to 25% with the character.

### AppKit boundary

Native `NSMenu` remains the smallest appropriate UI surface. Menu items store a typed `PetActionRequest` in `representedObject` and route through one `AppController.performPetAction(_:)` selector. No new window, framework, permission, or dependency is introduced.

## Error and Interruption Rules

- Global pause: no state change; show the pause explanation.
- Per-person pause: resume the target and perform the action.
- Hidden target: recall/show the target and perform the action.
- Dragging: releasing the mouse remains authoritative; menu actions cannot occur during an active drag gesture.
- New manual command: immediately replaces the previous manual action and its feedback.
- Missing group member: operate on the catalog's available characters; packaged acceptance still requires four characters.
- Invalid request: return unavailable and do not mutate positions, pause state, or visibility.

## Testing

- Catalog tests verify stable ordering, unique IDs, exact Chinese copy, scopes, and positive durations.
- World tests cover all four individual transitions, group execution, per-person resume, global-pause rejection, hidden/unknown routing, deterministic expiry, and finite geometry.
- Menu tests verify the shared action center, per-person action submenu, group section, typed requests, and tooltips.
- View tests verify right-click discovery, action request emission, feedback replacement, expiry-token behavior, and scale-independent readability.
- Runner tests verify feedback reaches the correct visible panels and group actions restore hidden people.
- Full normal, AddressSanitizer, strict-concurrency Release, packaged smoke, signing, and live-launch checks remain required.

## Acceptance Criteria

- The user can reach every action from either persistent control route and from a person's right-click menu.
- No visible menu uses the ambiguous label `做个动作`.
- Four individual actions produce observably different motion and immediate Chinese feedback.
- The group action restores hidden people and starts group play.
- Size changes preserve action transforms, hit regions, and readable feedback.
- Existing pause, hide, recall, drag, click-through, obstacle, menu-bar, and quit behavior remains green.
