# Persistent Control Center Design

## Purpose

Desktop Pets must always leave the user with an obvious way to pause, restore, configure, and quit the application. The current icon-only status item is not visible in the user's menu-bar session, and a same-session minimal status-item experiment was also suppressed. The design therefore strengthens the native menu-bar control while adding an independent in-app fallback so that the user cannot become trapped when the menu bar is hidden or a status item is suppressed.

## Scope

This phase changes control discoverability and command routing. It does not change character artwork, motion physics, obstacle detection, or the later Windows port.

## User Experience

### Primary menu-bar control

- The status item uses a variable-width, text-and-symbol label: `🐾 桌宠`.
- Its tooltip and accessibility label identify it as the Desktop Pets control center.
- Clicking it opens one global control menu.
- The app records whether the status item has a button, is marked visible, and is attached to a window. It re-creates the item once when its AppKit lifecycle state is invalid.
- Returning from a full-screen Space or changing the active Space triggers a fresh health check and menu refresh.

### Independent fallback control

- A small floating `🐾 总台` panel appears near the top-right of the current screen on launch. The user may hide it from the shared control menu after confirming another control route is available.
- The panel is non-activating, joins all Spaces, remains available when all characters are hidden, and opens the same control menu as the status item.
- The panel never relies on a character window, so hiding all four people cannot remove the final control path.
- The fallback does not close merely because AppKit reports the native status item as healthy: macOS does not expose reliable pixel-level visibility for every system or third-party menu-bar arrangement.
- The app also exposes the fallback from every character's context menu. Hiding all characters automatically presents it again, even if the user previously closed it, so the last control route cannot disappear.

### Global control menu

The main menu contains:

1. Pause or resume all activity.
2. Hide or show all characters.
3. Recall all four characters to a visible screen.
4. A `四人管理` submenu.
5. Enable character interaction or full click-through.
6. Show or hide the fallback control panel.
7. Enable or disable launch at login.
8. Open diagnostics.
9. Quit Desktop Pets.

The label and check state of each item refresh immediately after a command.

### Per-character controls

The `四人管理` submenu contains one submenu per character, using the character's display name. Each character submenu supports:

- Show or hide.
- Recall to a visible screen.
- Pause or resume.
- Trigger an action.

Each character's existing right-click menu keeps its local commands and adds:

- Recall all four characters.
- Open the control center.
- Quit Desktop Pets.

These global entries ensure there is a route to the control center before the user hides the last visible character.

## Architecture

### Control state

A platform-neutral snapshot describes the four characters' visibility and paused state. `PetWorld` remains the source of per-character pause state, while `WorldRunner` owns panel visibility and combines both into the snapshot. Global preference state remains in `AppController`.

### Command routing

- Character gestures and context menus emit typed commands.
- `WorldRunner` handles simulation commands and reports state changes.
- UI-level commands such as opening the fallback and quitting are delegated to `AppController`.
- `AppController` is the single coordinator that persists global preferences and asks both control surfaces to refresh.
- The status item and fallback panel share one `NSMenu`; command definitions are not duplicated.

### Status-item lifecycle

`StatusMenuController` owns a replaceable `NSStatusItem` instead of an immutable item. A health snapshot is derived from `isVisible`, the presence of its button, and attachment to a window. A bounded repair policy permits one recreation per unhealthy episode and resets after a healthy observation. This prevents a runaway recreation loop.

The controller listens for screen/Space/application activation notifications and performs a debounced health check. High-signal unified logs record creation, health transitions, repair, fallback presentation, and menu commands without recording personal data.

### Fallback panel

`ControlCenterPanelController` owns a small borderless `NSPanel` containing one accessible button. The panel uses a system material, stays inside the active screen's visible frame, and avoids taking keyboard focus. Clicking the button opens the shared menu at the panel anchor. It is excluded from obstacle handling automatically because the geometry provider already ignores this application's own process.

## Startup and Recovery

1. Load preferences and characters.
2. Start the world runner.
3. Create the status item and menu.
4. Check status-item health after the application reaches the run loop.
5. Show the fallback. The user may close it from the shared menu, but hiding all characters presents it again.
6. Replace the old modal first-run alert with non-modal control guidance. The guidance names both `🐾 桌宠` and `🐾 总台` and never changes the application's activation policy.

If every character is hidden, at least one control surface must remain visible. Recall-all both clears individual hidden state and restores all panels to valid visible-screen positions.

## Failure Handling

- Missing status-item button/window: log, perform one bounded recreation, and keep the fallback available.
- Status item suppressed despite healthy AppKit properties: the launch-visible `🐾 总台` remains independent; diagnostics explain the limitation without claiming system-level visibility.
- No available display during a transient display change: retain the last valid fallback position and retry on the next screen notification.
- Launch-at-login registration failure: leave the previous setting unchanged and show the existing error alert.
- Unknown character command: ignore safely, log one warning, and preserve the menu state.

## Testing

### Automated

- Menu-state tests cover global labels and all four per-character states.
- Health-policy tests cover healthy, unhealthy, one repair, recovery, and repeated unhealthy observations.
- World tests prove individual pause/visibility snapshots and recall-all behavior.
- Command-routing tests prove local versus UI-level command delegation.
- Panel configuration tests prove non-activation, all-Spaces behavior, accessibility naming, and visible-frame placement.
- Existing 55 tests remain green under normal and AddressSanitizer runs.
- A strict Swift 6 concurrency release build remains green.

### Live acceptance

On the current Mac:

1. Launch and relaunch the packaged application.
2. Confirm `🐾 桌宠` is visible when the environment permits it; otherwise confirm `🐾 总台` appears.
3. Open the global menu and verify every global and per-character command.
4. Hide one character, restore it from `四人管理`, then hide all and recall all.
5. Enter and leave a full-screen Space and confirm a control route remains.
6. Open the fallback from a character's context menu and use it to pause, resume, and quit.
7. Capture filtered unified logs for status-item health, fallback presentation, and commands.
8. Repackage, ad-hoc sign, and verify the app bundle with strict deep validation.

## Acceptance Criteria

- The app never relies solely on character windows for stop or quit controls.
- The primary status item is labeled `🐾 桌宠`, strongly owned, health-checked, and repaired only within a bounded policy.
- Hiding all characters automatically presents `🐾 总台`, leaving a control route even when the status item is suppressed.
- Every character can be shown, hidden, recalled, paused, resumed, and triggered from the control center.
- Recall-all restores all four characters to a visible screen.
- Both the primary and fallback control surfaces open the same current menu state.
- Diagnostics report AppKit status-item health and fallback state without claiming whether pixels are visible when the OS does not expose that fact.
- Automated, live UI, packaging, and signing verification pass before handoff.
