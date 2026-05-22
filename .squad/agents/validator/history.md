# Validator History

## Session: Implementation Planning (2026-05-16T23:11:53Z)
**Status:** Ready to validate Phase 1  
**Plan Location:** `.squad/decisions/inbox/lead-implementation-plan.md`  
**Decisions Location:** `.squad/decisions.md`

### Phase 1 Validation Scenarios
The implementation plan includes 13 validation scenarios (JSON contracts) covering:

1. `galaxy_setup.json` — Galaxy data structures and accessors
2. `carrier_initialization.json` — Carrier creation with cash, ship inventory, slots
3. `route_creation.json` — Route validation (capacity, frequency, slot conflicts)
4. `route_frequency.json` — Valid frequency ranges and edge cases
5. `demand_basic.json` — Demand calculation for single route
6. `demand_competition.json` — Demand splitting when multiple carriers compete
7. `slot_auction.json` — Auction resolution, winner determination, ties
8. `financial_basics.json` — Revenue, cost, cash update calculations
9. `turn_pipeline.json` — Full turn order: intents → auction → routes → demand → financials
10. `bankruptcy.json` — Cash < 0 detection and carrier elimination
11. `ship_ordering.json` — Ship build time, delivery, inventory integration
12. `ship_capacity.json` — Capacity split (passenger/cargo) preservation
13. `score_calculation.json` — Score formula and winner determination

### Harness Design
Simulation harness (simulation_harness.tscn + simulation_harness_controller.gd):
- Headless — no scene tree presentation
- Exposes GameState metrics, carriers, galaxy, demand, signals
- Operations: initialize_game, submit_intent, advance_turn, create_route, set_carrier_cash

### Validator Tasks
1. Review each work item's scenarios for coverage gaps
2. Ensure harness_state exposes enough for all scenarios
3. Run full suite after each work item merge
4. Flag flaky or non-deterministic scenarios

**Next:** Await Phase 1 work items and run scenarios upon each merge.

---

### Star Map Guide Mode Validation (2026-05-22)
**Status:** Complete — 2 new scenarios, full suite passing  
**Commit:** `<builder+validator team>`

### Task
Created validation scenarios for the star map "planet selection guide line" feature implemented by Builder per Lead design D011.

**Feature behavior:**
- Click planet → enters guide mode, dashed line follows cursor from planet center
- Hover another planet → line snaps to center, hover shows distance
- Click second planet → emits `route_requested(origin, dest)` signal, cancels guide
- Click same planet or non-planet → cancels guide mode

### Scenarios Created

**1. `star_map_guide_mode.json`**
- Tests core guide mode lifecycle
- Verifies guide activation on first planet click (earth)
- Verifies route_requested emission on second planet click (mars)
- Verifies guide auto-cancels after route request
- **Result:** PASS

**2. `star_map_guide_cancel.json`**
- Tests guide mode cancellation paths
- Same planet click → cancels, no route request
- Re-enter guide mode with different planet
- Explicit `cancel_guide_mode()` call → cancels
- **Result:** PASS

### Harness Assets
- `star_map_guide_mode_harness_controller.gd` — drives clicks at steps 40, 60
- `star_map_guide_mode_harness.tscn` — harness scene
- `star_map_guide_cancel_harness_controller.gd` — drives clicks at steps 40, 60, 80, 100
- `star_map_guide_cancel_harness.tscn` — harness scene

**Harness pattern:** Extends Control, uses `_physics_process()` with step counter to drive planet clicks programmatically via `star_map._on_planet_clicked(planet_id)`.

**Exposed state:** Reuses existing `star_map_harness_controller.gd` exposed state:
- `harness_state.guide_active` (bool)
- `harness_state.guide_origin_id` (String)
- `harness_state.guide_snap_planet_id` (String)
- `harness_state.last_route_requested_origin` (String)
- `harness_state.last_route_requested_dest` (String)
- `harness_state.route_request_count` (int)

### Full Suite Status
- **56 scenarios total, 56 passed, 0 failed**
- All existing scenarios still pass
- New scenarios integrated successfully

**Next:** Ready for next feature validation request.

---

## Star Map Context Menu Validation (2026-05-22)
**Status:** Complete — 2 new scenarios, full suite passing  
**Commit:** `fbdc8b6`

### Task
Created validation scenarios for the star map planet right-click context menu feature implemented by Builder.

**Feature behavior:**
- Right-click planet → shows context menu with "Buy Slots" button
- Context menu hides hover panel while visible
- Left-click anywhere → dismisses context menu
- When no slots available → button shows "No Slots" and is disabled
- Clicking "Buy Slots" → emits `slot_purchase_requested(planet_id)` signal

### Scenarios Created

**1. `star_map_context_menu.json`**
- Tests context menu lifecycle
- Right-click planet earth → menu visible, button enabled, text "Buy Slots"
- Verifies hover panel hidden when menu is visible
- Left-click to dismiss → menu hidden, no slot purchase signal
- **Result:** PASS

**2. `star_map_context_menu_no_slots.json`**
- Tests disabled state when no slots available
- Harness sets earth to have all slots owned (no available slots)
- Right-click earth → menu visible, button disabled, text "No Slots"
- **Result:** PASS

### Harness Assets
- `star_map_context_menu_harness_controller.gd` — drives right-click at step 40, dismiss at step 80
- `star_map_context_menu_harness.tscn` — harness scene
- `star_map_context_menu_no_slots_harness_controller.gd` — sets up no-slots state, right-clicks at step 40
- `star_map_context_menu_no_slots_harness.tscn` — harness scene

**Harness pattern:** Extends Control, uses `_physics_process()` with step counter to programmatically call `star_map._show_context_menu(planet_id)` and `star_map._dismiss_context_menu()`.

**Exposed state:** Updated `star_map_harness_controller.gd` to expose:
- `harness_state.context_menu_visible` (bool)
- `harness_state.context_menu_planet_id` (String)
- `harness_state.context_menu_button_text` (String)
- `harness_state.context_menu_button_disabled` (bool)
- `harness_state.hover_panel_visible` (bool)
- `harness_state.last_slot_purchase_planet_id` (String)
- `harness_state.slot_purchase_request_count` (int)

Access pattern: Read `star_map._context_buy_btn` directly for button state (text, disabled).

### Full Suite Status
- **58 scenarios total, 58 passed, 0 failed**
- All existing scenarios still pass
- 2 new scenarios integrated successfully

### Learnings
- **Direct method calls over input simulation:** When validating UI state changes triggered by input events, calling internal state-change methods (`_show_context_menu()`, `_dismiss_context_menu()`) is simpler and more deterministic than simulating raw input events.
- **Access patterns for private state:** Builder's context menu uses direct member references (`_context_buy_btn`) rather than node paths. Harness controllers can safely access these for validation without breaking encapsulation — they're test infrastructure, not production code.
- **Harness state setup for edge cases:** The "no slots available" scenario demonstrates setting up game state in `reset_harness()` to force specific conditions (all slots owned). This pattern works for any edge case that's hard to trigger through normal interaction.

**Next:** Ready for next feature validation request.
