# D011: Planet Selection Guide Line

**Status:** Proposed  
**Author:** Lead (Game Architect)  
**Requested by:** Brian  
**Date:** 2025-07-19

## Summary

Add a "selection mode" to the star map: click a planet to start drawing a dashed guide line from that planet to the cursor. When hovering a second planet, the line snaps to it and the hover panel shows route distance. Clicking the second planet opens CreateRouteModal with both planets pre-selected. Clicking empty space cancels.

---

## 1. State Management

### New state in `star_map.gd`

```
var _guide_origin_id: String = ""        # planet that started guide mode
var _guide_mouse_pos: Vector2 = Vector2.ZERO  # current mouse position (for line endpoint)
var _guide_snap_planet_id: String = ""   # planet the cursor is snapping to (or "" if freeform)
```

**Interaction with existing state:**

- `_selected_planet_id` is **repurposed as the guide origin.** Currently, clicking a planet sets `_selected_planet_id` and emits `planet_selected` — but nothing consumes the selection meaningfully. The new behavior replaces this: first click enters guide mode (`_guide_origin_id = planet_id`), second click completes it.
- `_hovered_planet_id` stays as-is. When in guide mode AND hovering a planet that isn't the origin, set `_guide_snap_planet_id = _hovered_planet_id`.
- **No new signals needed on StarMap** for internal guide state. The existing `planet_selected` signal is replaced with a new signal for the two-planet handoff (see §5).

### Mode detection

A simple helper:
```gdscript
func _is_guide_active() -> bool:
    return _guide_origin_id != ""
```

No enum needed — the feature is binary (guide active or not).

---

## 2. Guide Line Rendering

### Approach: `_draw()` override (extend existing)

StarMap already has a `_draw()` method for the star field. Add the guide line drawing at the end of that method.

**Why `_draw()` over Line2D:**
- The line is ephemeral (follows cursor, no children to manage).
- Dashed lines are trivial with `draw_dashed_line()` (Godot 4.x built-in).
- No scene tree nodes to create/destroy per frame.

### Drawing logic (appended to `_draw()`)

```gdscript
if _guide_origin_id != "":
    var from: Vector2 = _planet_positions.get(_guide_origin_id, Vector2.ZERO)
    var to: Vector2
    if _guide_snap_planet_id != "":
        to = _planet_positions.get(_guide_snap_planet_id, _guide_mouse_pos)
    else:
        to = _guide_mouse_pos
    var guide_color := Color(1.0, 1.0, 1.0, 0.6)
    draw_dashed_line(from, to, guide_color, 2.0, 6.0)
```

### Cursor-following

In `_gui_input()` for `InputEventMouseMotion`, update `_guide_mouse_pos = motion.position` and call `queue_redraw()` when guide is active. This is cheap — `_draw()` is already called for star field.

### Snap behavior

In `_update_hover()`, when guide is active:
- If `_hovered_planet_id != ""` and `_hovered_planet_id != _guide_origin_id`: set `_guide_snap_planet_id = _hovered_planet_id`
- Otherwise: set `_guide_snap_planet_id = ""`

The snap is visual only (line endpoint moves to planet center). No physics/collision changes.

---

## 3. Hover Panel Enhancement

### Conditional route distance section

When **all three conditions are true:**
1. Guide mode is active (`_guide_origin_id != ""`)
2. Hovering a planet (`_hovered_planet_id != ""`)
3. Hovered planet is not the origin (`_hovered_planet_id != _guide_origin_id`)

…append a new section to the hover panel below the Demand row:

```
─────────────────
Distance   8.2 ly
```

### Data source

```gdscript
var distance: float = _game_state.galaxy.calculate_distance(_guide_origin_id, _hovered_planet_id)
```

`GalaxyData.calculate_distance()` already exists and returns Euclidean distance between any two planets.

### Implementation

In `_on_planet_hovered()`, after the Demand row block, add:

```gdscript
if _guide_origin_id != "" and planet_id != _guide_origin_id:
    _hover_content.add_child(_hover_make_separator())
    var dist := _game_state.galaxy.calculate_distance(_guide_origin_id, planet_id)
    var dist_text := "%.1f ly" % dist
    _hover_content.add_child(_hover_make_info_row("Distance", [
        [dist_text, ThemeBuilder.ACCENT],
    ]))
```

Uses the existing `_hover_make_info_row()` helper — no new UI primitives needed.

### Origin planet hover

When hovering the origin planet itself while in guide mode, show the standard hover panel (no distance row). The guide line is suppressed (`_guide_snap_planet_id` stays empty).

---

## 4. Route Screen Handoff

### New method on CreateRouteModal

```gdscript
func open_with_planets(origin_id: String, dest_id: String) -> void:
    _edit_mode = false
    _editing_route = null
    _reset_form()
    _origin_id = origin_id
    _dest_id = dest_id
    set_title("New Route")
    super.open()
    _rebuild_form()
```

This is identical to `open()` except it pre-sets `_origin_id` and `_dest_id` before rebuilding. The planet selectors will show the pre-selected values. The player still needs to select ships, set pricing, etc.

### GameScene wiring

**New signal on StarMap:**
```gdscript
signal route_requested(origin_id: String, dest_id: String)
```

Emitted from `_on_planet_clicked()` when the second planet is clicked during guide mode (replaces the old `planet_selected` emission in that case).

**In GameScene `_connect_signals()`:**
```gdscript
_star_map.route_requested.connect(_on_star_map_route_requested)
```

**New handler in GameScene:**
```gdscript
func _on_star_map_route_requested(origin_id: String, dest_id: String) -> void:
    # Close any active modal first
    if not _active_modal.is_empty():
        _modals[_active_modal].close()
        _active_modal = ""
        _top_bar.set_active_toolbar("")
    _create_route_modal.open_with_planets(origin_id, dest_id)
```

This follows the existing pattern of `_on_create_route_requested()` and `_on_edit_route_requested()`.

---

## 5. Signal Flow

```
StarMap click (planet 1)
  → enters guide mode (internal state only, no signal)

StarMap click (planet 2)
  → emits route_requested(origin_id, dest_id)
  → exits guide mode (internal state reset)

GameScene._on_star_map_route_requested()
  → closes active modal if any
  → calls _create_route_modal.open_with_planets(origin, dest)

CreateRouteModal
  → opens with both planets pre-selected
  → player completes form (ships, pricing, frequency)
  → emits route_created on submit
```

**Signal changes:**
- **New:** `StarMap.route_requested(origin_id: String, dest_id: String)` — two-planet selection complete
- **Existing `planet_selected` stays** — still useful if other features need single-planet selection later. But it is NOT emitted during guide mode's first click (only guide mode activates). It IS still emitted when guide mode is disabled (though currently nothing consumes it).

**Actually, simplify:** Since nothing consumes `planet_selected` today, and the new guide mode fully replaces the old click behavior, `planet_selected` can be kept for potential future use but the first click now only activates guide mode without emitting it.

---

## 6. Edge Cases

### Clicking the same planet twice
First click enters guide mode. Second click on the same planet: **cancel guide mode** (same as clicking empty space). Do NOT open the route modal with identical origin/dest.

### Hovering the origin planet
Show the normal hover panel (name, system, slots, routes, demand). No distance row. Guide line is not snapped. This avoids showing "0.0 ly" nonsense.

### Window resize during guide mode
`_on_resized()` calls `_build_map()` which clears and rebuilds planet positions. Guide mode should be **cancelled** on resize:
```gdscript
func _on_resized() -> void:
    _cancel_guide_mode()  # reset guide state
    # ... existing resize logic
```
This is the simplest safe approach. The alternative (recalculating guide origin position) adds complexity for zero UX value.

### Turn advance during guide mode
Turn advance calls `_star_map.refresh()` which updates route overlays and slot indicators but does NOT rebuild planet positions. Guide mode can safely **persist through a turn advance** — the origin planet position hasn't changed. No special handling needed.

### Modal open during guide mode
If a toolbar modal is opened (Dashboard, Ships, etc.) while guide mode is active, guide mode should be **cancelled.** The dim overlay would obscure the star map anyway.

In GameScene `_on_toolbar_pressed()`, add:
```gdscript
_star_map.cancel_guide_mode()
```

### CreateRouteModal close
When the user closes CreateRouteModal without creating a route, guide mode is already inactive (it was cancelled when the modal opened). The existing `_on_create_route_modal_closed()` returns to the routes modal as normal.

---

## 7. File Change List

| File | Change |
|------|--------|
| `src/game/ui/star_map/star_map.gd` | Add guide mode state vars, `route_requested` signal, update `_on_planet_clicked()` for two-phase selection, extend `_gui_input()` for cursor tracking, extend `_draw()` for dashed line, extend `_on_planet_hovered()` for distance row, add `cancel_guide_mode()` public method |
| `src/game/ui/modals/create_route_modal.gd` | Add `open_with_planets(origin_id, dest_id)` method |
| `src/game/main.gd` | Connect `route_requested` signal, add `_on_star_map_route_requested()` handler, call `cancel_guide_mode()` on toolbar press |

**No new files.** Three existing files modified. No new scenes, no new classes.

---

## 8. Implementation Notes

- **`draw_dashed_line()`** is a built-in Godot `CanvasItem` method (since 4.0). Signature: `draw_dashed_line(from, to, color, width, dash, aligned)`. No shader or custom drawing needed.
- The guide line draws in the StarMap's own coordinate space (same as star field), which is correct since `_planet_positions` are in that space.
- `queue_redraw()` on mouse move is cheap — StarMap is already a Control with `_draw()`. Godot batches redraws per frame.
- The hover panel rebuild on planet change is already the existing pattern. The only addition is the conditional distance row — no performance concern.

## 9. Scope Boundary

**Explicitly NOT in this feature:**
- Lane distance labels on the map (separate feature from lead-route-creation-ux.md)
- Range validation (showing which ships can reach the lane) — belongs in CreateRouteModal
- Multi-hop route planning — out of prototype scope
- Guide line animation or particle effects — art direction says minimal
