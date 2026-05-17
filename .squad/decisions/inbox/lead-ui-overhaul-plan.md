# Phase 4: UI Overhaul — Full-Screen Star Map + Modal Dialogs

**Author:** Lead (Architect)  
**Date:** 2025-07-17  
**Status:** Proposed  
**Supersedes:** D020 (Single-screen HSplitContainer layout), D022 (Turn log in side panel), D023 (Context-sensitive action panel in side panel)

---

## 1. Architecture Decisions

### D025: Full-Screen Star Map with Modal Dialogs

**Decision:** Replace the HSplitContainer (star map + side panel) layout with a full-screen star map. All panel content (Dashboard, Routes, Ships, Slots, Turn Log) moves into modal dialogs opened from toolbar buttons in the TopBar.

**Rationale:** Side panel was too cluttered — three panels crammed into a narrow column. Full-screen map gives the galaxy the visual weight it deserves. Modals provide full-width space for forms and data when needed, then get out of the way.

**Impact:** `main.tscn` becomes simpler (no HSplitContainer/SidePanel). ActionPanel is retired as a scene; its form logic is redistributed into per-category modals. DashboardPanel and TurnLogPanel become modal content.

### D026: Modal Implementation — Custom Overlay Control

**Decision:** Use a custom `ModalDialog` base scene: a full-screen `ColorRect` (dim overlay, `mouse_filter=STOP`) containing a centered `PanelContainer` with a title bar and close button. NOT Godot's built-in `Window`/`PopupPanel` — those create OS-level windows that fight with the game viewport and don't work well in web exports.

**Structure:**
```
ModalDialog (Control, anchors full-screen, mouse_filter=STOP)
  ├── Overlay (ColorRect, dim background, mouse_filter=STOP → closes on click)
  └── Panel (PanelContainer, centered, ~70% screen)
       ├── TitleBar (HBoxContainer)
       │    ├── TitleLabel (Label)
       │    └── CloseButton (Button)
       └── ContentContainer (MarginContainer → user content goes here)
```

**Rationale:** Custom overlay gives full control. No OS window chrome. Works in web exports. Dim overlay makes it clear you're in a modal. Click-outside-to-close is natural.

**API:**
- `open()` / `close()` — show/hide the modal
- `set_title(text)` — set title bar text
- Signal `closed` — emitted on close (button or overlay click)
- Subclasses add their content to `ContentContainer`

### D027: Toolbar Button → Modal Wiring

**Decision:** TopBar gains a row of toolbar buttons (Dashboard, Routes, Ships, Slots, Turn Log). Each button toggles its corresponding modal. Modals are children of GameScene (siblings of StarMap, above it in z-order). GameScene owns the button→modal wiring.

**Signal flow:**
1. TopBar emits `toolbar_button_pressed(modal_name: String)`
2. GameScene receives signal, calls `_toggle_modal(modal_name)`
3. GameScene closes any open modal, then opens the requested one (or just closes if it was already open)
4. Modal reads GameState directly for display data
5. Modal action forms call PlayerController methods (same as ActionPanel did)
6. Modal emits `closed` → GameScene updates toolbar button states

### D028: ActionPanel Decomposition

**Decision:** ActionPanel is retired. Its form-building code is split:
- **Slot bid/sell forms** → `SlotsModal` (planet selection within the modal via dropdown, not map clicks)
- **Route create/modify/cancel forms** → `RoutesModal` (lane selection within the modal via dropdown)
- **Ship order form** → `ShipsModal`
- **Pending actions summary** → shown in each relevant modal + optionally in Dashboard

**Rationale:** Each modal has room for its own forms. No need for context-switching based on map selection. Map clicks are deferred to a future phase (contextual popups).

---

## 2. Work Items

### P4.1: Fix ToastManager mouse_filter ⚡ (trivial)
**Dependencies:** None  
**Files:** `toast_manager.tscn`  
**Task:** Set ToastManager root Control `mouse_filter = 2` (IGNORE) in the .tscn. The full-screen Control with default `mouse_filter=STOP` blocks all clicks underneath. Individual toast PanelContainers can keep their default filter.  
**Validation:** Existing `ui_game_harness` scenarios should still pass. Manual confirmation that clicks reach the star map.

### P4.2: Create ModalDialog base component
**Dependencies:** None  
**Files:** New `src/game/ui/modal_dialog.gd`, new `src/game/ui/modal_dialog.tscn`  
**Task:** Build the reusable modal base per D026. Features: open/close, title, dim overlay, click-outside-to-close, close button, `closed` signal. Content container for subclasses. Start hidden. `mouse_filter=IGNORE` when closed so it doesn't block.  
**Validation:** Unit-test-level scenario: modal opens, modal closes, doesn't block input when closed.

### P4.3: Rework main.tscn — full-screen star map
**Dependencies:** P4.1, P4.2  
**Files:** `main.tscn`, `main.gd`  
**Task:**
- Remove `HSplitContainer` and `SidePanel` (with DashboardPanel, ActionPanel, TurnLogPanel children)
- StarMap becomes direct child of VBoxContainer, `size_flags_vertical = SIZE_EXPAND_FILL`
- StarMapPanel wrapper Control may no longer be needed — evaluate
- ToastManager and GameOverScreen stay as overlay children of GameScene root
- Add placeholder modal instances (empty ModalDialogs) as children of GameScene
- Update `main.gd`: remove `_dashboard_panel`, `_action_panel`, `_turn_log_panel` references. Remove `_on_planet_selected` / `_on_lane_selected` handlers (map click → modal is deferred). Keep `_on_next_turn` logic but remove panel refresh calls that no longer apply.  
**Validation:** Game launches, star map fills screen, turns still work, toasts appear without blocking.

### P4.4: Add toolbar buttons to TopBar
**Dependencies:** P4.3  
**Files:** `top_bar.tscn`, `top_bar.gd`  
**Task:**
- Add buttons between the status labels and Next Turn: Dashboard, Routes, Ships, Slots, Turn Log
- Emit `toolbar_button_pressed(name)` signal
- Visual feedback: pressed/active state for the button whose modal is open (TopBar gets `set_active_toolbar(name)` method)
- Keep existing turn counter, cash, score, rank, events labels  
**Validation:** Buttons render, signal emits on click, active state toggles.

### P4.5: Dashboard Modal
**Dependencies:** P4.2, P4.4  
**Files:** New `src/game/ui/modals/dashboard_modal.gd`, new `src/game/ui/modals/dashboard_modal.tscn`  
**Task:** Move DashboardPanel's display logic (fleet, slots, routes, score) into a modal. The modal's `bind()` takes GameState + carrier_id. `refresh()` updates content. Reuse `_refresh_fleet()`, `_refresh_slots()`, `_refresh_routes()` logic from `dashboard_panel.gd` — either copy or keep DashboardPanel as an inner content scene instanced inside the modal.  
**Recommendation:** Instance DashboardPanel.tscn inside the modal's ContentContainer. Minimal code change — DashboardPanel doesn't know it's in a modal.  
**Validation:** Modal opens showing fleet/slots/routes. Data matches GameState. Closes cleanly.

### P4.6: Turn Log Modal
**Dependencies:** P4.2, P4.4  
**Files:** New `src/game/ui/modals/turn_log_modal.gd`, new `src/game/ui/modals/turn_log_modal.tscn`  
**Task:** Similar to P4.5 — instance TurnLogPanel inside a modal. TurnLogPanel already works standalone.  
**Recommendation:** Instance TurnLogPanel.tscn inside modal ContentContainer. Wire `add_turn_result()` through from GameScene.  
**Validation:** Modal opens with turn history. New turns append. Scrolls correctly.

### P4.7: Ships Modal (Order Ships)
**Dependencies:** P4.2, P4.4  
**Files:** New `src/game/ui/modals/ships_modal.gd`, new `src/game/ui/modals/ships_modal.tscn`  
**Task:** Extract ship order form from ActionPanel. Add a fleet overview section (from DashboardPanel's fleet display) at the top so the player sees their current ships while ordering. Form calls `PlayerController.add_ship_order()`.  
**Validation:** Ship order form works. Capacity spinboxes auto-adjust. Order appears in pending actions.

### P4.8: Slots Modal (Bid & Sell)
**Dependencies:** P4.2, P4.4  
**Files:** New `src/game/ui/modals/slots_modal.gd`, new `src/game/ui/modals/slots_modal.tscn`  
**Task:** Extract slot bid/sell forms from ActionPanel. Add a planet selector dropdown (OptionButton listing all planets with slot availability info). Show current player slots at selected planet. Forms call `PlayerController.add_slot_bid()` / `add_slot_sale()`.  
**Validation:** Can select planet, bid for slots, sell slots. Pending actions update.

### P4.9: Routes Modal (Create, Modify, Cancel)
**Dependencies:** P4.2, P4.4  
**Files:** New `src/game/ui/modals/routes_modal.gd`, new `src/game/ui/modals/routes_modal.tscn`  
**Task:** Extract route forms from ActionPanel. Add a lane selector dropdown. Show existing active routes with cancel buttons. Route create form with ship checkboxes and pricing. Calls `PlayerController.add_route_create()` / `cancel_route()`.  
**Validation:** Can select lane, create route, cancel route. Pending actions update.

### P4.10: Wire modals into GameScene orchestrator
**Dependencies:** P4.5, P4.6, P4.7, P4.8, P4.9  
**Files:** `main.gd`, `main.tscn`  
**Task:**
- Replace placeholder modals with actual modal instances in main.tscn
- Wire `TopBar.toolbar_button_pressed` → `_toggle_modal()` in main.gd
- Wire `_on_next_turn()` to refresh Dashboard modal (if open) and append to Turn Log modal
- Pass GameState and PlayerController to all modals via `bind()`
- On `_on_play_again()`, rebind all modals  
**Validation:** Full game flow works: open/close modals, submit actions, run turns, see results.

### P4.11: Retire old panel files
**Dependencies:** P4.10  
**Files:** `action_panel.gd/.tscn`, potentially `dashboard_panel.gd/.tscn`, `turn_log_panel.gd/.tscn`  
**Task:**
- If P4.5/P4.6 instanced the old panels inside modals → keep them, just remove from main.tscn (already done in P4.3)
- If P4.5/P4.6 rewrote the content → delete old panel files
- Delete `action_panel.gd/.tscn` — its code has been distributed across modals  
**Validation:** No dangling references. Game still runs.

### P4.12: Update validation harness and scenarios
**Dependencies:** P4.10  
**Files:** `ui_game_harness_controller.gd`, `ui_game_harness.tscn`, scenarios in `src/validation/scenarios/`  
**Task:**
- Harness controller accesses `game_scene._dashboard_panel` etc. → update to access modal content or remove those references
- The harness calls `game_scene._on_next_turn()` and `game_scene._player_controller.*` — these should still work unchanged
- References like `game_scene._game_over_screen.visible` and `game_scene._top_bar._turn_label.text` → should still work
- Add observed state for modal visibility: `modals_open: Array[String]`
- Run all existing scenarios to confirm green
- Add new scenario: toolbar opens/closes modals correctly  
**Validation:** All existing scenarios pass. New modal scenario passes.

---

## 3. Keep vs. Rewrite

| Component | Verdict | Rationale |
|-----------|---------|-----------|
| `star_map.gd/.tscn` | **Keep as-is** | Already works. Just needs full-screen sizing (layout change in main.tscn). |
| `top_bar.gd/.tscn` | **Extend** | Add toolbar buttons and signal. Keep all existing status display logic. |
| `toast_manager.gd/.tscn` | **Keep + fix** | One property change (mouse_filter). Code is fine. |
| `game_over_screen.gd/.tscn` | **Keep as-is** | Already an overlay. No changes needed. |
| `dashboard_panel.gd/.tscn` | **Keep, embed in modal** | Instance inside DashboardModal's content container. Zero rewrite. |
| `turn_log_panel.gd/.tscn` | **Keep, embed in modal** | Instance inside TurnLogModal's content container. Zero rewrite. |
| `action_panel.gd/.tscn` | **Retire** | Form logic redistributed to Ships/Slots/Routes modals. Helper methods (`_create_label_spinbox`, `_get_eligible_ships`) can be copied to a shared utility or duplicated per modal (game jam — duplication is fine). |
| `main.gd` | **Major rework** | Scene tree changes, modal wiring replaces panel wiring. Core turn logic stays. |
| `main.tscn` | **Major rework** | Remove HSplitContainer/SidePanel, add modal instances. |
| `ui_game_harness_controller.gd` | **Update references** | Fix any broken references from removed nodes. Core test flow unchanged. |

---

## 4. Scope Guard — NOT in Phase 4

- ❌ **Contextual map popups** (click planet → popup, click lane → popup). Deferred. Modals with dropdowns handle selection for now.
- ❌ **Star map visual improvements** (zoom, pan, hover highlights). Future work.
- ❌ **Modal animations** (slide in, fade in). Instant show/hide is fine for jam.
- ❌ **Route modification form** (adjust ships/pricing on existing route). Cancel-and-recreate is sufficient for jam scope.
- ❌ **Keyboard shortcuts** for modal access. Mouse-only is fine.
- ❌ **Theming/styling** of modals. Default Godot theme. Functional, not beautiful.
- ❌ **Drag-and-drop** ship assignment. Checkboxes work.
- ❌ **NPC carrier viewing** in Dashboard. Player carrier only.

---

## 5. Implementation Order Summary

```
P4.1 (toast fix) ──────────────────────────────┐
P4.2 (modal base) ─────────────────────────────┤
                                                ├─► P4.3 (main.tscn rework)
                                                │        │
                                                │        ▼
                                                │   P4.4 (toolbar buttons)
                                                │        │
                                                │        ▼
                                                ├─► P4.5 (dashboard modal)
                                                ├─► P4.6 (turn log modal)
                                                ├─► P4.7 (ships modal)
                                                ├─► P4.8 (slots modal)
                                                ├─► P4.9 (routes modal)
                                                │        │
                                                │        ▼ (all modals done)
                                                ├─► P4.10 (wire into main.gd)
                                                │        │
                                                │        ▼
                                                ├─► P4.11 (retire old panels)
                                                └─► P4.12 (update validation)
```

P4.1 and P4.2 are independent and can be done in parallel.  
P4.5–P4.9 are independent of each other and can be done in any order or in parallel.  
P4.10–P4.12 are sequential and depend on everything above.
