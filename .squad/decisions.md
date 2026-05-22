# Architectural Decisions

## Grilling Session — 2026-05-16T23:11:53Z
**Source:** Lead agent design grilling + Brady approval  
**Plan:** lead-implementation-plan.md

---

### D001: GameState as Single Source of Truth
**Decision:** GameState is the centralized, mutable data store for all game simulation state. All game logic is isolated from the scene tree; turn resolution is a pure function that consumes GameState and CarrierIntents and produces TurnResult.

**Rationale:** Decouples UI/presentation from core game logic. Enables deterministic replay, automated testing, and easy NPC integration.

**Impact:** Core simulation code has zero dependencies on Godot scene nodes.

---

### D002: Carrier Identity is Symmetric
**Decision:** Player and NPC carriers are identical Carrier data structures. Identity is expressed only through the controller (PlayerController vs NPCController). All simulation logic treats carriers uniformly.

**Rationale:** Eliminates special-case logic for different carrier types. Simplifies testing and reduces bugs.

**Impact:** Player and NPC share identical game rules, balance, and capabilities.

---

### D003: Lanes are Shared, Routes are Owned
**Decision:** A Lane is a geographic path (planet → planet, bidirectional, owned by the galaxy). A Route is a carrier's scheduled service on a lane (directional, owned by the carrier). Multiple carriers can own routes on the same lane.

**Rationale:** Separates topology (fixed) from competition (dynamic). Enables lane-level demand calculation without carrier knowledge.

**Impact:** Demand tables are keyed by (lane_id, direction); routes are keyed by (carrier_id, lane_id, direction).

---

### D004: Simultaneous Turns with Deterministic Ordering
**Decision:** All carriers execute in a single turn. Intents are collected from all carriers, then the turn pipeline processes them in a deterministic order (tie-breaking by carrier index). Results are generated atomically.

**Rationale:** Prevents cascading state changes during a turn. Ensures fairness — no carrier gains advantage by turn order.

**Impact:** Replay is deterministic given the same intents and RNG seed.

---

### D005: Demand is Directional and Competitive
**Decision:** Each (lane, direction) has independent passenger and cargo demand. When multiple carriers service the same (lane, direction), demand is split by (capacity × price_factor). Higher-capacity or lower-price carriers capture more demand.

**Rationale:** Creates competition without complex bidding. Player/NPC strategy depends on route pricing and ship selection.

**Impact:** Revenue is proportional to service quality (price_factor and capacity match).

---

### D006: Inner Classes for Galaxy Data Structures
**Decision:** Use inner classes (`Planet`, `Lane`) inside `GalaxyData` rather than separate Resource subclasses in their own files.

**Rationale:** Planet and Lane are pure data containers with no behavior. They are never used independently. Single-file approach keeps topology definition self-contained.

**Impact:** GalaxyData is the single source of truth for galaxy topology.

---

### D007: Ship Instance ID Format
**Decision:** Ship instance IDs use format `{type_id}-{counter}` (e.g., `sd-100-0001`). Counter is zero-padded 4-digit integer scoped to ShipCatalog instance.

**Rationale:** Human-readable, simple, deterministic. No external UUID dependency. Unique within game session.

**Impact:** ShipInstance IDs are easily debuggable; counter must be persisted if catalogs are serialized.

---

### D008: ShipRef as Lightweight Ship Mirror
**Decision:** CarrierData defines its own `ShipRef` inner class mirroring `ShipInstance` fields (id, type_id, name, available_turn). Avoids compile-time dependency while P1.1–P1.3 are built in parallel.

**Rationale:** Enables parallel development of galaxy_data.gd, ship_catalog.gd, and carrier_data.gd. P1.4 (GameState) will unify types.

**Impact:** Temporary duplication until P1.4 unification. Carrier ships and pending_orders use ShipRef temporarily.

---

---

## D009: Economy Balance — Five-Fix Proposal (Approved)

**Decision:** Implemented 5 strategic fixes to collapse the dominant "max price, max frequency, wait" strategy:

1. **Operating cost scales with frequency** — `total_cost = (distance / efficiency) × frequency` per ship, not flat
2. **Speed-based frequency constraint** — `max_frequency = sum(trips_per_ship)` where `trips_per_ship = floor(efficiency × 5.0 / lane_distance)`, min 1 if in range
3. **Price factor floor 0.0** — at 2× suggested price, demand drops to 0 (was 0.05 floor)
4. **Dynamic frequency SpinBox** — max value updates when ships are selected, shows "/ N" label
5. **NPC frequency tuning** — NPCs use `max(1, int(max_freq × route_preference))` instead of hardcoded 1

**Rationale:** These fixes create real decision space: frequency vs. cost tradeoff, ship selection impact, pricing as a real lever, and tension between short (cheap, low revenue) vs. long (expensive, high revenue) lanes.

**Impact:** Game economy now balanced and meaningful. 242+ GUT tests pass. 31+ validation scenarios confirm behavior.

---

## D010: Type Unification — ShipRef Removed

**Decision:** Removed `ShipRef` inner class from `CarrierData`. Ships now stored as `ShipCatalog.ShipInstance` directly. The `create_default_carriers()` factory now accepts a `ShipCatalog` parameter.

**Rationale:** Eliminates parallel type hierarchy. Starting ships reference real catalog type `sd-100` instead of nonexistent `"basic"`. Capacity split (20 passenger / 20 cargo = 40 max) validated by catalog.

**Impact:** `CarrierData.create_default_carriers()` signature changed — requires `ShipCatalog` argument.

---

## D011: NPC Cash Reserve Constants

**Decision:** NPCs maintain dynamic cash reserve = `max(8 turns × ongoing costs, §1200 floor)`. All spending (slots, ships, routes) gated against this reserve.

**Rationale:** After phase topology changes, aggressive NPCs went bankrupt. Buffer multiplier alone insufficient — NPCs overextend in early turns with few obligations. §1200 floor prevents early overexpansion.

**Constants:**
- `RESERVE_BUFFER_TURNS = 8`
- `MIN_CASH_RESERVE = 1200.0` (40% of starting §3000)

**Impact:** All NPCs remain solvent to turn 30. Fewer routes/ships but no bankruptcies.

---

## D012: Price Factor as Dual-Role Modifier

**Decision:** Price factor now serves two roles:
1. **Competitive weight** — influences market share split (existing)
2. **Absolute demand cap** — `demand_at_price = effective_demand × price_factor` limits passengers willing to fly

Price factor floor lowered from 0.2 to 0.05. At 2x+ suggested price, only 5% of demand will fly.

**Rationale:** Monopolists can no longer charge extreme prices and fill ships. Pricing creates real strategy.

**Impact:** All existing tests updated, 3 new tests added. All 24 validation scenarios pass.

---

## D013: Dynamic Lane Topology

**Decision:** Lanes no longer pre-defined in `GalaxyData`. Any planet can connect to any other. `get_lane()` creates Lane objects dynamically using Euclidean distance from 2D planet positions. `derive_lane_id()` generates canonical IDs in `"alpha::beta"` format.

**Impact:**
- **DemandData** now has 132 entries (66 unique pairs × 2 directions) instead of 30
- **Route.lane_id** derived from origin/dest — never passed as parameter
- **NpcController** iterates all slot-planet pairs instead of `galaxy.lanes`
- **EventSystem** targets random planet pairs instead of random lanes
- Game balance shifted — some seeds produce earlier bankruptcies

**Rationale:** Enables free-form galaxy topology. Foundation for Phase 5 star map rework.

---

## D014: Dedicated Harness Controllers per UI Concern

**Decision:** Created separate `ui_toolbar_harness_controller.gd` for modal open/close testing, rather than adding to shared `ui_game_harness_controller.gd`.

**Rationale:** Keeps existing scenarios deterministic. Each harness controller has single responsibility. New toolbar scenarios evolve independently without affecting game-flow scenarios.

**Impact:** New files: `ui_toolbar_harness_controller.gd`, `ui_toolbar_harness.tscn`, `ui_toolbar_clickable.json`.

---

## D015: Simplified Frequency Model (Phase 1)

**Decision:** Each ship assigned to route contributes exactly 1 round-trip per turn, regardless of lane distance or ship efficiency. `max_frequency = number of assigned ships`.

**Rationale:** For prototype, interesting decision is *how many ships to assign*, not micro-optimizing frequency via ship speed. Mental model simple: more ships = more trips = more capacity. Ship efficiency already repurposed for operating cost calculations (P1.8).

**Impact:** `calculate_max_frequency()` is trivially `ship_ids.size()`. If speed-based frequency needed later, only one function changes.

**Note:** Later revised to D009 (speed-based frequency constraint) for better gameplay balance.

---

## D016: Route Performance Metrics via GameState.last_turn_financials

**Decision:** Store last turn's financial result on `GameState.last_turn_financials` (set in `advance_turn()`). Routes modal reads this dictionary to display per-route metrics.

**Enrichment:** Financial calculator's route summaries now include `passengers_served`, `cargo_served`, `passenger_capacity`, and `cargo_capacity`.

**Rationale:** Minimal change — one new property on GameState, populated in existing `advance_turn()` flow. No new signals needed; UI reads on refresh. Per-route demand served uses carrier-level demand split.

**Impact:**
- Routes modal displays two lines per route: config + performance metrics
- Profit colored green/red for visual feedback
- Validation harness exposes `route_performance` array
- New scenario `sim_route_performance_metrics` validates end-to-end

---

## D017: Per-Turn Game Telemetry

**Decision:** GameTelemetry is a RefCounted instance owned by GameSession (not static/autoload). Records every turn's intents, results, and post-turn state snapshot. Saves to `user://game_telemetry.json` on demand (F12 / debug save button).

**Rationale:** Point-in-time debug snapshots (DebugStateSaver) don't capture turn history. Telemetry enables NPC behavior analysis over time. Instance-based design avoids global state and naturally resets with new sessions.

**Key design choices:**
- Untyped `result` parameter to avoid circular dependency with TurnPipeline (same pattern as `GameState.advance_turn()`)
- Serialized inline (not deferred) so the snapshot reflects exact post-turn state
- Saved alongside debug state — single F12 press captures both

**Impact:** No changes to game logic or existing validation scenarios. Additive only.

---

## D018: Star Map UI Fixes

**Decision:** 
1. **Planet radius formula:** Reduced from `12 + slots*2` to `8 + slots*1.2`. Slot dot radius from 4px to 3px. Map padding from 60 to 100.
2. **Route details section gating:** Route creation details (pricing/frequency/create button) now require ships to be selected, not just origin+dest.
3. **Hover panel:** Added floating info panel on planet hover showing name, system, slot ownership, route count, and demand tier. Positioned near planet and clamped to viewport edges.

**Rationale:**
- Large planets were crowding map and obscuring labels. New formula keeps proportional differentiation while giving breathing room.
- Showing pricing controls before ship selection was confusing — frequency depends on ships. Hint now guides selection order.
- Players needed at-a-glance planet info without clicking.

**Impact:** Visual-only. No gameplay logic affected. Programmatic API `select_ships()` triggers `_rebuild_route_details()`. All existing validation scenarios pass unchanged.

---

## D019: Turn Presentation System Architecture

**Decision:** Turn results now shown via full-screen presentation overlay (`TurnPresentationOverlay`) driven by pure data from `TurnSummaryBuilder`. The overlay:
- Shows each NPC's turn actions one at a time (5s auto-advance, skippable with Escape)
- Then shows detailed player summary (routes with pax/cargo served, financials, events)
- Stays until player clicks Continue or presses Enter/Escape

**Key design choices:**
1. **TurnSummaryBuilder is pure data** — no UI, no scene references. Receives TurnResult + GameState + pre-turn snapshots, returns Dictionary of CarrierTurnSummary objects. Unit-testable.
2. **Presentation skipped in test-mode** — `_on_next_turn()` checks `OS.get_cmdline_user_args().has("--test-mode")` and skips the await. This keeps all validation scenarios working without modification.
3. **Toast notifications removed from turn flow** — The `_show_turn_notifications()` call is no longer invoked during `_on_next_turn()`. The presentation overlay covers all information toasts used to show.
4. **Pre-turn snapshot pattern** — `cash_before` dict and `prev_financials` (from `game_state.last_turn_financials`) captured BEFORE `run_next_turn()` so summary can show before/after deltas.

**Impact:**
- `main.gd` `_on_next_turn()` is now async (uses `await`)
- New files: `turn_summary_builder.gd`, `turn_presentation_overlay.gd/.tscn`
- `main.tscn` has new CanvasLayer node for the overlay
- All 258 GUT tests pass, all 31+ validation scenarios pass

---

## D020: Money Escrow for Player Actions

**Decision:** PlayerController immediately deducts `carrier.cash` when the player adds slot bids or ship orders (escrow), and refunds all escrowed amounts in `generate_intent()` / `clear_intent()` before the turn pipeline processes the intent.

**Rationale:**
- Players see accurate available cash during the planning phase — no "phantom money" confusion
- Turn pipeline remains untouched: it still deducts for successful awards/orders as before
- Replacing a bid for the same planet correctly swaps escrow amounts (refund old, deduct new)
- Slot sales are NOT escrowed (income arrives when pipeline processes them)
- Route creates/modifications are NOT escrowed (routes are free to create; the cost is operational)

**Impact:**
- `PlayerController` gains `bind_carrier()`, `_escrowed` state, and helper methods
- `main.gd` must call `bind_carrier()` after session creation
- TopBar refreshes on `intent_changed` signal to show updated cash
- 10 new GUT tests covering escrow add/remove/replace/generate/clear flows

---

## D021: Route Editing via Dual-Mode Modal

**Decision:** The CreateRouteModal serves double duty as create and edit modal rather than building a separate EditRouteModal. Edit mode is controlled by `_edit_mode` flag and `_editing_route` reference.

**Key constraints in edit mode:**
- Origin and destination are displayed but NOT editable (changing endpoints = cancel + create new)
- Ships, frequency, and pricing ARE editable
- Ships currently assigned to the route are included in the available ship pool
- "Cancel Route" action moves inside the edit modal (bottom, red-styled)

**Rationale:** Reusing the same modal avoids UI duplication and keeps the form-building logic in one place. The mode flag cleanly separates behavior without complex inheritance. Route endpoint changes are intentionally blocked because changing origin/dest fundamentally creates a different route (different lane, different demand market).

**Impact:** RoutesModal "Cancel Route" button replaced with "Edit" button. Cancel route is now a secondary action inside the edit view. Pending route modifications displayed in RoutesModal pending actions section.

---

## D022: Ship Order Modal Extraction

**Decision:** Extracted the "Order New Ship" form from ShipsModal into a dedicated OrderShipModal, following the same parent→child modal pattern used by RoutesModal→CreateRouteModal.

**Pattern:**
- ShipsModal shows fleet overview + pending orders + "Order Ship" button
- OrderShipModal contains the full order form (type dropdown, capacity spinboxes, stats, order button)
- main.gd wires: `order_ship_requested` → close ships modal, open order modal; `closed` → reopen ships modal

**Rationale:** Consistent modal architecture across the UI. All "create/order" flows use the same pattern: overview modal with action button → dedicated form modal. Keeps overview modals focused on display, form modals focused on input.

**Impact:**
- New files: `order_ship_modal.gd`, `order_ship_modal.tscn`
- ShipsModal reduced from 263 to ~147 lines
- New validation: `ui_order_ship_flow.json` scenario + `ui_order_ship_harness_controller.gd`
- main.gd updated with signal wiring (matches create route pattern exactly)

---

## D023: Routes Consume Slots at Both Endpoints

**Decision:** Each active route consumes 1 slot at its origin and 1 slot at its destination. "Available slots" = owned - used_by_routes. Route creation and modification now check available slots, not just owned slots.

**Rationale:** Previously `has_slots_at()` only checked ownership (count > 0). A carrier with 1 slot at Mars could create unlimited routes through Mars. This broke the economic constraint that slots are meant to represent — limited port capacity. Now slots are a real bottleneck: you need available (unconsumed) slots to create new routes.

**Impact:**
- `CarrierData` gained `get_slots_used_by_routes()` and `get_available_slots_at()`
- `RouteValidator` checks available slots via `_count_routes_at_planet()` helper
- `CreateRouteModal` accounts for pending route creates when showing available slots
- UI shows "X owned, Y available" instead of just "X slots"
- NPC route creation is also constrained (same RouteValidator path)

---

## D024: ManageSlotsModal Extraction

**Decision:** Separated slot bidding/selling into a dedicated ManageSlotsModal. SlotsModal is now a read-only overview (holdings + pending actions + "Buy/Sell Slots" button).

**Rationale:** Follows the same pattern as RoutesModal→CreateRouteModal and ShipsModal→OrderShipModal. Overview modals show status; form modals handle input. Consistency across all three resource types.

**Impact:** New files: `manage_slots_modal.gd`, `manage_slots_modal.tscn`. Main.gd wires with close→open→close→reopen pattern.

---

## User Directives

### 2026-05-17T03-30-23Z: Testing Responsibility
**By:** Brady (via Copilot)

The team runs all tests — humans never run tests for QA. The dev team (agents) is responsible for running GUT unit tests and validation scenarios, confirming they pass, and fixing failures before presenting work as done.

### 2026-05-17T01:01Z: Debug State Save
**By:** Brady (via Copilot)

Add a button/shortcut to save the current game state to a well-known file location so agents can look it up during debugging. Define the file path in instructions so all agents know where to find it.

---

## Work Order & Phases

**Phase 1:** Headless simulation core (12 work items, P1.1–P1.12) — **COMPLETE**
**Phase 2:** Full 30-turn game loop + NPC AI — In progress  
**Phase 3:** UI shell — Proposed  
**Phase 4:** Full-screen star map + modal dialogs — Proposed

See lead-implementation-plan.md (Phase 1), lead-phase2-plan.md (Phase 2), and lead-ui-overhaul-plan.md (Phase 4) for full specifications.

---

## D025: NPC AI Behavioral Diversity

**Decision:** Implemented four behavioral diversity fixes to NPC route selection and strategy:

1. **Competition-aware route scoring**: Route candidates scored by `demand - competition_penalty × (1 - slot_aggression)` + distance + jitter. Crowded lanes penalized for cautious NPCs, ignored by aggressive ones.
2. **Personality-driven ship selection**: Aggressive NPCs prefer large ships, cautious prefer cheap, balanced match route needs.
3. **Route modifications beyond price**: Overloaded routes gain ships or frequency increases (high `route_preference`). Underloaded routes reduce frequency alongside price.
4. **Per-NPC scoring jitter**: ±15% RNG variance breaks ties between equally-weighted candidates.

**Rationale:** Playtesting showed all NPCs behaved identically despite personality weights existing. These fixes create visible strategic differences — aggressive NPCs take risky high-demand routes and large ships, cautious NPCs avoid competition and prefer cheap ships, balanced NPCs adapt to route characteristics.

**Impact:**
- `npc_controller.gd` expanded from ~460 to ~530 lines
- New helper: `_count_competitors_on_lane()`
- `GameTelemetry.get_turns()` accessor added for test analysis
- New test file: `test_npc_behavior_analysis.gd` (6 tests, full 30-turn simulation)
- All 293 GUT tests pass, all validation scenarios pass
- Personality weights in `game_setup.gd` unchanged — only decision logic improved

---

## D026: Route Creation UX — Distance Visibility

**Date:** 2026-05-20T18:24:00Z  
**Status:** Approved — user decision overrides design recommendation

**Decision:** Show lane distance prominently in CreateRouteModal immediately after both origin and destination are selected, before ship selection. Skip map-level lane distance labels (Proposal A — too cluttered).

**Rationale:** User feedback from Brian (playtester) — the primary need is seeing distance *in context* when planning a route, not cluttering the star map with 15 labels. Distance shown in the modal's config section addresses the core problem: players can see range requirements before choosing ships.

**Supersedes:** Lead's Proposal A+B recommendation (lane labels + browse-first explorer). Only the "show distance earlier" aspect of B is adopted.

**Impact:** Route creation flow remains unchanged structurally. UI text added to route details section to display computed distance. No game logic impact.

---

## D027: Centralized UI Theme System

**Date:** 2026-05-20  
**Author:** Builder  
**Status:** Implemented

**Decision:** Created `ThemeBuilder` static utility class to centralize the game's UI design system:

1. **Color Palette as Constants:** All colors defined once (SURFACE, BORDER, TEXT, ACCENT, POSITIVE, NEGATIVE, WARNING, MODAL_SURFACE) exposed as public constants.
2. **Programmatic Theme Generation:** `build_theme()` creates a Theme resource at runtime with styles for all core controls (Button, PanelContainer, ScrollBar, OptionButton, PopupMenu, etc.). Applied in `main.gd` before scene setup.
3. **Font Management:** Inter (body/data) and Space Grotesk (headings) downloaded from official GitHub repos. Fonts loaded via `res://` paths in ThemeBuilder.
4. **Icons via Tabler Icons:** Downloaded 5 MIT-licensed SVGs for toolbar buttons. Loaded as Texture2D and assigned to Button.icon property.
5. **Background Clear Color:** Set in `project.godot` rendering settings (#14161C) for dark space aesthetic.

**Rationale:** Programmatic theme is faster than hand-editing .tres files in the Godot editor. One source of truth for all colors enables instant global design updates.

**Impact:**
- `main.gd` applies theme: `theme = ThemeBuilder.build_theme()`
- All controls inherit sci-fi HUD styling automatically
- Harness compatibility preserved — theme applied before validation binding
- All existing scenarios pass unchanged

---

## D028: OptionButton/PopupMenu/SpinBox Theme Styling

**Date:** 2026-05-20  
**Author:** Builder  
**Status:** Implemented

**Decision:** Extended ThemeBuilder with dropdown and spinner control styling:

1. **OptionButton:** Inherits Button styles (blue sci-fi look) for visual consistency across all interactive controls.
2. **PopupMenu:** Gets dedicated panel styling (MODAL_SURFACE + BORDER) and hover effects (ACCENT-tinted) since it's a floating overlay, not an inline control.
3. **SpinBox:** Themed by styling its underlying LineEdit (text field) and Button (increment/decrement arrows). No separate SpinBox theme type exists in Godot — theming the components covers it completely.

**Rationale:** OptionButtons and SpinBoxes appear throughout route/ship/slot creation modals. Consistent theming reduces visual fragmentation and reinforces the unified HUD aesthetic.

**Impact:** All OptionButtons, PopupMenus, and SpinBoxes in the game inherit sci-fi theme automatically. No per-instance overrides needed. Headless validation confirmed no script errors; all existing scenarios pass.

---

## D011: Planet Selection Guide Line

**Date:** 2026-05-22  
**Author:** Lead (Game Architect)  
**Status:** Implemented

**Summary**

Add a "selection mode" to the star map: click a planet to start drawing a dashed guide line from that planet to the cursor. When hovering a second planet, the line snaps to it and the hover panel shows route distance. Clicking the second planet opens CreateRouteModal with both planets pre-selected. Clicking empty space cancels.

**State Management**

New state in `star_map.gd`:
- `_guide_origin_id: String` — planet that started guide mode
- `_guide_mouse_pos: Vector2` — current mouse position (for line endpoint)
- `_guide_snap_planet_id: String` — planet the cursor is snapping to

`_selected_planet_id` is repurposed as the guide origin. First click enters guide mode, second click completes it and emits `route_requested`.

**Guide Line Rendering**

Approach: `_draw()` override (extend existing)
- StarMap already has a `_draw()` method for the star field. Add the guide line drawing at the end.
- Why `_draw()` over Line2D: The line is ephemeral (follows cursor, no children to manage). Dashed lines are trivial with `draw_dashed_line()` (Godot 4.x built-in).

Drawing logic:
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

Cursor-following: In `_gui_input()` for `InputEventMouseMotion`, update `_guide_mouse_pos = motion.position` and call `queue_redraw()` when guide is active.

Snap behavior: In `_update_hover()`, when guide is active:
- If `_hovered_planet_id != ""` and `_hovered_planet_id != _guide_origin_id`: set `_guide_snap_planet_id = _hovered_planet_id`
- Otherwise: set `_guide_snap_planet_id = ""`

**Hover Panel Enhancement**

When **all three conditions are true:**
1. Guide mode is active (`_guide_origin_id != ""`)
2. Hovering a planet (`_hovered_planet_id != ""`)
3. Hovered planet is not the origin (`_hovered_planet_id != _guide_origin_id`)

…append a new section to the hover panel below the Demand row:

```
─────────────────
Distance   8.2 ly
```

Use `GalaxyData.calculate_distance()` which already exists and returns Euclidean distance.

**Route Screen Handoff**

New method on CreateRouteModal:
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

New signal on StarMap:
```gdscript
signal route_requested(origin_id: String, dest_id: String)
```

In GameScene `_connect_signals()`:
```gdscript
_star_map.route_requested.connect(_on_star_map_route_requested)
```

New handler in GameScene:
```gdscript
func _on_star_map_route_requested(origin_id: String, dest_id: String) -> void:
    if not _active_modal.is_empty():
        _modals[_active_modal].close()
        _active_modal = ""
        _top_bar.set_active_toolbar("")
    _create_route_modal.open_with_planets(origin_id, dest_id)
```

**Edge Cases**

- **Same planet twice:** First click enters guide mode. Second click on the same planet: cancel guide mode (same as clicking empty space). Do NOT open the route modal with identical origin/dest.
- **Hovering the origin planet:** Show the normal hover panel (name, system, slots, routes, demand). No distance row. Guide line is not snapped.
- **Window resize during guide mode:** Cancel guide mode. `_on_resized()` calls `_build_map()` which rebuilds planet positions; guide mode state would be stale.
- **Modal open during guide mode:** Cancel guide mode. The dim overlay would obscure the star map anyway.
- **Turn advance during guide mode:** Guide mode can safely persist through a turn advance — the origin planet position hasn't changed. No special handling needed.
- **CreateRouteModal close:** When the user closes CreateRouteModal without creating a route, guide mode is already inactive (it was cancelled when the modal opened).

**File Changes**

| File | Change |
|------|--------|
| `src/game/ui/star_map/star_map.gd` | Add guide mode state vars, `route_requested` signal, update `_on_planet_clicked()` for two-phase selection, extend `_gui_input()` for cursor tracking, extend `_draw()` for dashed line, extend `_on_planet_hovered()` for distance row, add `cancel_guide_mode()` public method |
| `src/game/ui/modals/create_route_modal.gd` | Add `open_with_planets(origin_id, dest_id)` method |
| `src/game/main.gd` | Connect `route_requested` signal, add `_on_star_map_route_requested()` handler, call `cancel_guide_mode()` on toolbar press |

**Rationale**

Repurposes dead `_selected_planet_id` click behavior (nothing consumed the old `planet_selected` signal). Two-phase click enables users to see route distance before committing to CreateRouteModal, reducing trial-and-error in route planning. Dashed line rendering uses Godot's built-in `draw_dashed_line()` — no shader or custom drawing. Snap behavior is visual only (line endpoint moves to planet center). Implementation is minimal — three files, no new scenes or classes.

**Impact**

- New route creation UX: guide mode provides spatial awareness of distance before modal opens
- Maintains signal-driven architecture (D001, D002)
- No breaking changes to GameState, carrier model, or existing signals
- Validation scenarios cover guide activation, snapping, cancellation paths, and edge cases

---

## D019: Star Map Resize-Aware Rebuild + CanvasLayer Theme Pattern

**Date:** 2026-05-20  
**Author:** Builder

**Context:**
- Star map bottom planets clipped after top bar grew
- Star map lacked visual depth
- Welcome overlay didn't use project theme

**Decisions:**

1. **Star Map Deferred Build via `resized` Signal** — The star map now connects to `resized` and rebuilds when the Control receives its actual post-layout size. Previously `_build_map()` ran at bind-time before VBoxContainer allocated space, causing stale dimensions.

2. **Background Starfield** — 200 seeded (seed=42) random stars drawn in `_draw()` behind all map content. Alpha range 0.05–0.25 using ThemeBuilder.TEXT. Regenerated on resize.

3. **CanvasLayer Theme Application** — Pattern: assign `ThemeBuilder.build_theme()` to a child Control (MarginContainer) in `_ready()`. Font/color overrides applied per-label via script.

**Impact:**
- Star map correctly fills available space regardless of top bar height
- Starfield adds visual depth without distracting from gameplay
- Welcome overlay matches the rest of the UI visually

---

## D020: ThemeBuilder Pattern for CanvasLayer Overlays

**Date:** 2026-05-24  
**By:** Builder

**Context:** CanvasLayer nodes (layer 100+) don't inherit parent scene themes. Both WelcomeOverlay and TurnPresentationOverlay need explicit theme application.

**Decision:** Standardized pattern: in `_ready()`, set `ThemeBuilder.build_theme()` on the MarginContainer child of the Overlay ColorRect, then apply per-node overrides (title font/color, hint colors, accent button styling). Background color uses SURFACE RGB with custom alpha as a literal in the `.tscn` file.

**Implications:** Any future CanvasLayer-based overlay (game over screen, pause menu, etc.) should follow this same pattern. Consider extracting a helper method if more overlays are added.

---

## D021: Unicode Icon Glyphs & Card-Based Ship Selection

**Date:** 2026-05-18  
**Author:** Builder

**Context:** UI used text labels "Pax", "Cargo", "Fuel". Ship selection was dropdown + stats line (hard to compare).

**Decisions:**

1. **Unicode Glyphs Replace SVG BBCode** — Replace `[img=WxH]res://path.svg[/img]` BBCode with colored Unicode glyphs: `●` (pax/#6bedc4), `◼` (cargo/#e8c56d), `◆` (fuel/#73948c). SVG `[img]` tags render as broken rectangles in RichTextLabel. Unicode shapes are universally supported and render reliably.

2. **Two-Step Card-Based Order Ship Modal** — Step 0 shows all available ship types as browsable cards. Step 1 shows customization (capacity split, quantity, order). Card layout shows all stats at a glance for every ship type simultaneously.

**Impact:**
- `pax_bb()`, `cargo_bb()`, `fuel_bb()` return BBCode text strings
- All existing call sites work unchanged
- `load_icon_texture()` added for TextureRect usage
- Removed OptionButton from OrderShipModal
- Programmatic API preserved — `select_type(index)` triggers step transition internally

---

## D022: Scoreboard Panel as Star Map Overlay

**By:** Builder  
**Date:** 2026-05-22

**Context:** Top bar had Rank and Events labels cluttering the header. Request: standalone scoreboard panel overlaid on star map instead.

**Decision:**
- ScoreboardPanel is a child of the StarMap node in main.tscn (not direct child of GameScene or top bar)
- Built programmatically in GDScript (no complex scene tree)
- Uses `mouse_filter = IGNORE` so star map interactions pass through
- Positioned with absolute offsets (16px from top-left of star map area)

**Rationale:** Placing it as a StarMap child means it naturally clips to the star map area and moves with it. Mouse filter ignore ensures planet clicks still work. Programmatic build avoids coupling to scene tree node names.

---

## D023: Duplicate Route Prevention & Efficiency Ratings

**Author:** Builder  
**Date:** 2026-05-25

**Decision 1: Duplicate Route Prevention**
- A carrier cannot create a new route on a lane where they already have an active route or pending route create
- Create button disabled with message directing to edit existing route
- Scope: Create mode only — edit mode exempt (you're modifying existing route)
- Implementation: Checks `carrier.routes[].lane_id` and `_player_controller.pending_intent.route_creates` using `GalaxyData.derive_lane_id()` for canonical comparison

**Rationale:** Multiple routes on same lane adds confusion without strategic depth. Players should adjust existing routes rather than stacking duplicates.

**Decision 2: Ship Efficiency Ratings**
- Ship efficiency (float 0.3–1.2) surfaced to players as letter grade (A–E) via `ShipType.get_efficiency_rating()`
- Rating scale: A ≥ 1.0, B ≥ 0.7, C ≥ 0.5, D ≥ 0.35, E < 0.35
- Shown in Order Ship modal and Create Route modal ship selector

**Rationale:** Efficiency affects operating cost and speed but was invisible. Letter grades communicate relative quality without exposing raw floats.

---

## D024: Programmatic Radio Icons Over Asset Files

**Context:** Default Godot radio button icons are dark circles, invisible against dark PopupMenu background (MODAL_SURFACE #121A1A).

**Decision:** Generate radio icons programmatically in `ThemeBuilder._make_radio_icon()` using `Image` + `ImageTexture` rather than shipping SVG/PNG asset files.

**Rationale:**
- Zero external dependencies — no icon files to manage
- Colors stay in sync with palette constants (MUTED for unchecked ring, ACCENT for filled checked dot)
- Antialiased pixel rendering at 16px produces crisp results
- If palette changes, icons update automatically

**Alternatives rejected:**
- SVG/PNG assets in `src/assets/icons/`: adds file management overhead, palette drift risk
- Godot icon color modulation: PopupMenu doesn't expose per-icon color modulation for radio items

---

## D025: Ship Build Time Formula

**Date:** 2026-05-25  
**Author:** Builder

**Context:** Formula was `current_turn + build_turns`, but ships delivered during turn resolution (step 1 of turn_pipeline) and aren't usable until NEXT planning phase. This made "Build: 2 turns" effectively cost 3 planning turns.

**Decision:** Changed formula to `current_turn + build_turns - 1`. A ship ordered on turn T with build_turns=N is delivered during turn T+N-1 resolution, making it usable starting turn T+N planning — exactly N planning turns after ordering.

**Impact:**
- `ship_catalog.gd`: Formula change
- `ships_modal.gd`: Label changed from "Ready turn" to "Delivered turn" for clarity
- Unit test updated to expect new value
- All 308 tests pass

---

## D026: Icon System & Hover Panel Redesign

**Author:** Builder  
**Date:** 2026-05-25

**Context:** UI used text labels "Pax", "Cargo", "Fuel". Planet hover tooltip was unstructured text blob.

**Decisions:**

1. **Tabler Icons via SVG** — Downloaded 3 Tabler Icons (users, package, gas-station) as SVGs with `stroke="#E6F5F0"` to match ThemeBuilder.TEXT. Stored in `src/assets/icons/`.

2. **BBCode `[img]` for inline icons** — Use RichTextLabel with BBCode `[img=14x14]` tags for most icon placements. Keeps layout simple and allows mixing icons with formatted text. ThemeBuilder provides `pax_bb()`, `cargo_bb()`, `fuel_bb()` helpers.

3. **`use_bbcode` flag pattern** — For generic selection lists (rendering both plain-text and icon-rich items), added opt-in `use_bbcode` flag on item dictionaries rather than converting all items to BBCode.

4. **Hover panel structured layout** — Used BBCode formatting (bold, color, separator lines) to create visually structured tooltip. Planet name as bold header, system name in MUTED, stats with accent-colored "yours" values, demand line with icons.

**Impact:**
- All 8 UI files updated to use icons instead of text labels
- ThemeBuilder gains icon constants, BBCode helpers, `make_icon_label()` factory
- UI-only changes — no behavioral changes

---

## D027: Centralized Carrier Colors

**By:** Builder  
**Date:** 2026-05-22

**Context:** Carrier colors duplicated in `star_map.gd` and `planet_node.gd` with divergent values. `scoreboard_panel.gd` used ACCENT/TEXT/MUTED instead of carrier-specific colors.

**Decision:**
- Single source of truth: `ThemeBuilder.CARRIER_COLORS` dictionary constant
- Colors chosen to fit dark sci-fi palette:
  - player = ACCENT (teal-green)
  - NPC1 = muted coral `(0.85, 0.45, 0.42)`
  - NPC2 = soft lavender-blue `(0.55, 0.65, 0.90)`
  - NPC3 = warm amber `(0.90, 0.72, 0.35)`
- All consumers (`star_map.gd`, `planet_node.gd`, `scoreboard_panel.gd`) reference `ThemeBuilder.CARRIER_COLORS`
- Scoreboard rows now show each carrier in its identity color (indicator dot + name label)

**Rationale:**
- Eliminates color drift between map elements and UI panels
- Desaturated palette feels cohesive with existing theme constants
- Adding a new carrier only requires updating one dictionary

---

## D028: Icon Strategy — SVG [img] BBCode + Programmatic Fallback

**Date:** 2026-05-18  
**Author:** Builder

**Context:** The previous session replaced all SVG `[img]` BBCode with Unicode glyphs after observing rendering failures. Brian reported SVG icons were actually working everywhere except the hover panel.

**Decision:**
- **Default:** Use `[img=NxN]res://path.svg[/img]` BBCode for inline icons (via `icon_bb()`). Works in all standard RichTextLabels.
- **Fallback:** For specific RichTextLabels where `[img]` fails (currently only star map hover panel), use programmatic API (`add_image()` with pre-loaded `ImageTexture`).
- **Ship cards:** Use plain `Label` nodes with `GridContainer` for tabular stats. "Capacity" is generic (no icon) since it covers both pax and cargo pre-split.

**Rationale:** One broken panel doesn't justify changing the icon strategy for the entire app. Fix the broken panel specifically, keep simpler BBCode approach everywhere else.

---

## D029: Display Name Resolution Pattern

**Author:** Builder  
**Date:** 2026-05-22

**Context:** Raw IDs (type_id, lane_id, route_id, planet_id) were leaking into UI text across many panels and modals.

**Decision:** Each UI component resolves IDs locally using small helper methods (`_get_ship_name`, `_get_planet_name`, `_resolve_route_display`) rather than a centralized formatter. This keeps each file self-contained and avoids adding a new utility class.

For `turn_log_panel`, which previously had no access to GameState, we added a `set_game_state()` method called from `main.gd` via `turn_log_modal`.

**Pattern:**
- **Ship type_id → name:** `_game_state.catalog.get_type(type_id).name` with null fallback to raw type_id
- **Planet ID → name:** `_game_state.galaxy.get_planet(planet_id).name` with null fallback
- **Route ID → display:** Look up route from carrier, resolve origin/dest planet names
- **Lane ID → display:** Replaced with "Origin → Dest" string built from route origin/dest

**Impact:**
- 10 UI files updated (inventory, ship_panel, route_summary, trade_lane_detail, turn_log_panel, planet_facts, economy_panel, metrics_panel, status_panel, hud_summary)
- Financial key references corrected (revenue/cost → total_revenue/total_cost)
- All 42 validation scenarios pass
