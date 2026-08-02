# Direct Pet Interaction Design

Date: 2026-08-02
Status: Approved in conversation

## Goal

Make shutdown controls discoverable and let users interact directly with each desktop pet without transparent panel regions blocking normal desktop clicks.

## Interaction contract

- The first launch shows one concise explanation that global controls and Quit live under the paw icon in the macOS menu bar.
- Single-clicking a visible pet makes that pet greet or perform a short reaction.
- Double-clicking a pet gathers all four pets near it and starts a group-play reaction. A recognized double click must not also execute a delayed single click.
- Dragging a pet moves its world anchor with the pointer. Releasing it transitions it to falling so normal platform physics resumes.
- Right-clicking a pet opens a menu for reaction, pause/resume that pet, recall that pet, and hide that pet.
- The paw menu remains the reliable global control path for pause/resume, hide/show, recall, click-through mode, diagnostics, and Quit.

## Mouse routing

Each pet keeps its existing borderless nonactivating `NSPanel`. In interactive mode the runner samples the mouse location at its existing 20 Hz tick. A panel accepts mouse events only when the pointer maps to a nontransparent pixel of the rendered pet image. Transparent pixels and panels not under the pointer remain click-through. Once a drag begins, that panel continues accepting events until mouse-up.

The existing “click-through” preference becomes an explicit full pass-through override. Its default changes to interactive mode for new users; an existing explicit preference is preserved.

## Architecture

- `PetInteraction` is a platform-neutral command enum.
- `PetSpriteView` owns click disambiguation, drag gesture tracking, alpha-mask hit testing, and context-menu command emission.
- `PetWindowCoordinator` maps view events to a narrow callback and manages per-panel event acceptance/visibility.
- `WorldRunner` routes interaction commands to `PetWorld` and panels.
- `PetWorld` owns reaction, gathering, per-pet pause, recall, drag, and release state changes.
- `PreferencesStore` owns the separate one-time control-hint flag without changing the existing Codable preference schema.

## Safety and lifecycle

- No global mouse hook, Accessibility permission, Input Monitoring permission, or screen capture is introduced.
- Invalid or unknown pet identifiers are ignored safely.
- Drag coordinates are clamped to visible screen-safe bounds by the world step.
- Hidden individual pets are restored by global recall/show.
- The status-menu Quit command remains reachable regardless of interaction state.

## Verification

Automated tests cover click disambiguation, interaction routing, alpha-mask hit decisions, world reaction/drag/pause/recall behavior, preference migration/defaults, and menu copy. Final verification includes the full suite, AddressSanitizer, strict-concurrency Release build, packaged-app signature validation, a four-window smoke test, and an interaction self-test that exercises each command without UI automation.
