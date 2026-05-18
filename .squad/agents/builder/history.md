# Builder History

## Recent Sessions

### Session Completion: Economy Balance & Debug Stability (2026-05-17T185810Z)

**By:** Builder (background agents: builder-debug-fix, builder-economy-balance)

**Deliverables:**
1. **Debug State Saver Fix:** Fixed GameEvent type annotation in `_serialize_events()`. Added console error logging to debug state JSON export.
2. **Economy Balance (5 fixes):** Operating cost × frequency, speed-based max frequency, price floor 0.0, dynamic frequency SpinBox, NPC frequency tuning. All 5 implemented, tested, deployed.

**Testing Complete:**
- 242+ GUT unit tests (financial_calculator, demand_calculator, route_validator, and related)
- 31+ validation scenarios covering economy, pricing, frequency, NPC behavior
- Zero regressions — all existing scenarios pass

**Decision Records:** D009–D015 in `.squad/decisions.md`

**Status:** Code pushed to origin. Ready for playtesting.

---

## Core Context

### Phase 1 Implementation Summary

Phase 1 delivered the headless simulation core (12 work items, P1.1–P1.12). All items complete with validation scenarios passing.

**Key components built:**
- **P1.1–P1.3:** Galaxy Data, Ship Catalog, Carrier Data (resources with inner classes)
- **P1.4:** GameState autoload with carrier indexing and type unification (removed ShipRef)
- **P1.5–P1.6:** Route Logic validation and Slot Auction resolver
- **P1.7–P1.8:** Demand Calculator (directional, price-factor-based) and Financial Calculator (with operating costs)
- **P1.9:** Turn Pipeline (deterministic, 8-stage)
- **P1.10–P1.11:** Score Calculator and Event System (demand modifiers)
- **P1.12:** Simulation harness and validation scenarios

**Architectural decisions (D001–D008):**
- GameState as single source of truth (all simulation state, no scene tree dependency)
- Symmetric carrier identity (Player and NPCs are identical data structures)
- Lane/Route ownership distinction (Lane = shared topology, Route = carrier's service)
- Deterministic simultaneous turns (fixed ordering, atomic results)
- Directional competitive demand (split by capacity × price_factor)
- Inner classes for data structures (kept in single files for cohesion)
- Ship instance ID format (type_id-counter for human readability)
- ShipRef removed in P1.4 (unified to ShipInstance)

**Testing:** 200+ GUT unit tests, 24+ validation scenarios, all passing.

**Key file paths:**
- `src/game/state/` — Galaxy, Ship Catalog, Carrier Data, GameState
- `src/game/simulation/` — Route logic, Auctions, Demand, Financial, Turn Pipeline, Scoring, Events
- `src/validation/harnesses/` — simulation_harness.tscn + harness_controller

### Implementation Details & Learnings

#### P1.1–P1.3: Foundational Resources (2026-05-17)

**Galaxy Data:** Inner classes for Planet and Lane, O(1) indexed lookups. 12 planets, 15 lanes. Default factory builds 4 solar systems (Sol, Alpha Centauri, Wolf 359, Tau Ceti). Lane distances: intra-system 1.0–2.5, inter-system 7.0–14.0.

**Ship Catalog:** 7 ship types (Sol Dynamics + Frontier Works). Inner classes for ShipType and ShipInstance. ID format: `type_id-counter` (e.g., `sd-100-0001`). Instance factory validates capacity split (passenger + cargo == max_capacity).

**Carrier Data:** Inner classes for Route and (removed) ShipRef. Factory creates 4 carriers with 3000 cash, 2 slots each, 1 starting ship (SD-100 with 20/20 capacity split). Routes indexed by lane_id; slots indexed by planet_id.

#### P1.5–P1.6: Route & Auction Logic (2026-05-17)

**Route Validator:** Static utility class. Frequency model: each ship = 1 round-trip/turn (simplified from speed-based). Validation: slots → lane → per-ship checks → clamp frequency. Modification excludes the route being modified from ship availability checks.

**Auction Resolver:** Static utility class. Resolution: sort bids descending by price_per_slot, tie-break by carrier_order (D004). Full bid or nothing (no partial funding). Slot sales instant with validation (can't orphan routes).

#### P1.7–P1.8: Demand & Financial (2026-05-17)

**Demand Calculator:** Directional lanes (planet_a→planet_b ≠ planet_b→planet_a). Demand = base_demand × price_factor. Price factor: `clamp(1.0 - (price - suggested) / suggested, 0.2, 1.5)` (later changed to 0.0 floor in economy balance). Competition splits proportional to capacity × price_factor. Separate passenger and cargo demand.

**Financial Calculator:** Counts revenue (demand × price × frequency) and operating costs (distance / efficiency per ship, later × frequency). NPC reserve estimation added to prevent overexpansion.

#### P1.9: Turn Pipeline (2026-05-17)

**Deterministic simultaneous turns:** 8-stage pipeline:
1. Collect intents from all carriers
2. Resolve auctions
3. Validate & apply routes
4. Validate & apply ships
5. Calculate demand
6. Calculate financials
7. Generate events
8. Report results + check game_over

All processed in carrier_order (index-based tie-breaking, D004).

#### P1.10–P1.11: Scoring & Events (2026-05-17)

**Score Calculator:** Weighted formula: `route_count × 10 + ship_count × 5 + cash × 0.01 + completed_turns × 5`. Routes weighted highest (strategic importance). Cash scaled down to avoid dominance.

**Event System:** GameEvent class with target_lane_id, target_planet_id, modifier (1.0–1.5), duration. Events expire after N turns. Demand modifiers applied in demand calculation. Stub replaced with probability-based generation in Phase 2.

#### P1.12: Simulation Harness (2026-05-17)

**Harness:** Wraps GameState in Node for _physics_process frame-stepping. Exposes harness_state with carriers, galaxy, demand, signals. Scenarios assert on numerical state (cash, routes, ships, scores). 24+ scenarios covering normal flow, edge cases, and regressions.

**Validation patterns:** `assert_value` for scalar checks, `assert_pipeline` for multi-step sequences, `nodes` for tree structure validation.

### Later Enhancements

#### Dynamic Lanes & UI Improvements (2026-05-18)

**Dynamic Lane Topology:** Lanes no longer pre-defined. `get_lane()` creates lanes dynamically using Euclidean distance. `derive_lane_id()` generates canonical IDs. Impact: DemandData expanded to 132 entries (66 pairs × 2 directions). **Decision D013.**

**Dedicated Harness Controllers:** Separated `ui_toolbar_harness_controller.gd` from `ui_game_harness_controller.gd` for independent modal testing. **Decision D014.**

**NPC Cash Reserve:** Dynamic reserve = `max(8 turns × ongoing costs, §1200 floor)`. Prevents early overexpansion. **Decision D011.**

#### Type & Price Decisions (2026-05-17)

**Type Unification (D010):** Removed ShipRef inner class. Ships now stored as ShipCatalog.ShipInstance directly. `create_default_carriers()` now accepts ShipCatalog parameter.

**Price Factor Dual Role (D012):** Price factor now caps absolute demand (in addition to competitive weight). Floor lowered from 0.2 to 0.05.

**Simplified Frequency (D015):** Each ship = 1 trip/turn. Later revised to speed-based in economy balance (D009).

---

## Learnings

### Route Performance Metrics (2026-05-19)

- `financial_calculator.gd` `process_financials()` already computes demand splits per (lane, direction) and per-carrier. Adding per-route served/capacity data was straightforward — the demand split result keyed by carrier_id is already available at the route iteration level.

### UI Polish: Route Gating, Planet Sizing, Hover Panel (2026-05-19)

- `_rebuild_route_details()` already rebuilds the entire details section — gating on `_selected_ship_ids.is_empty()` was trivial. The key insight: ship selection callback must call `_rebuild_route_details(carrier)` (not just `_update_frequency_max()`) so the section appears/disappears dynamically.
- Planet radius formula `8.0 + total_slots * 1.2` still differentiates planets (4-slot = 12.8px, 10-slot = 20px) without crowding. Paired with MAP_PADDING 100 to prevent label cutoff at edges.
- Hover panel uses `await get_tree().process_frame` before positioning to let the RichTextLabel compute its size. Without this, `_hover_panel.size` returns zero on first show.
- `DemandCalculator.get_demand_tier()` works on raw base_demand int. Averaging all entries touching a planet gives a meaningful "High/Medium/Low" tier for the tooltip.
- Panel position clamping checks all 4 edges. Default placement is to the right of the planet; falls back left if right edge overflows.

### Money Escrow System (2026-05-18)

- Escrow pattern: deduct on add, refund on remove, refund-all before pipeline runs. Keeps turn pipeline untouched while giving players accurate cash display during planning.
- `bind_carrier()` approach cleanly separates the escrow lifecycle from controller construction — tests can optionally skip binding to test non-escrow behavior.
- GUT catches `push_error()` as unexpected errors — any test using fake type IDs that hit catalog lookups will fail. Solution: use real catalog type IDs in tests when the controller is bound to a catalog.
- The TopBar doesn't inherently listen to `intent_changed` — main.gd bridges the signal to `_top_bar.refresh()`. This keeps TopBar decoupled from the controller.
- `GameState.last_turn_financials` is a simple pattern for exposing turn results to UI without changing signal signatures. Set it in `advance_turn()` before incrementing the turn counter.
- The simulation harness controller's `get_observed_state()` can expose nested arrays (e.g., `route_performance.0.passengers_served`) and the validation framework resolves dot-separated array indices correctly.
- Indentation matters critically in GDScript — an extra tab level causes parse errors that cascade through the entire class resolution chain, breaking unrelated scripts that reference the class.

### Turn Presentation System (2026-05-18)

- **TurnSummaryBuilder** (`src/game/simulation/turn_summary_builder.gd`): Pure data extraction from TurnResult. Uses `CarrierTurnSummary` inner class. Key pattern: capture `cash_before` dict BEFORE calling `advance_turn()`, pass `prev_financials` for delta display.
- **TurnPresentationOverlay** (`src/game/ui/turn_presentation_overlay.gd` + `.tscn`): CanvasLayer at layer 100, semi-transparent background, RichTextLabel with BBCode for content. Uses `_process()` for NPC auto-advance timer (5s per card). Emits `presentation_complete` signal.
- **Validation compatibility**: `_on_next_turn()` now uses `await` on the presentation. Skips presentation entirely when `--test-mode` user arg is present or headless feature detected. This keeps all 31+ validation scenarios passing without modification.
- **Integration pattern**: `main.gd` captures pre-turn state → runs turn → builds summaries → presents → refreshes UI. The `await` means UI doesn't update until player dismisses.
- Planet display names: `game_state.galaxy.get_planet(id).name` (GalaxyData.Planet has `name` field, not `planet_name`).
- Carrier display names: `carrier.carrier_name` (not `.name` which shadows Object.name).

### Route Editing Modal (2026-05-17)

- Adding edit mode to an existing create modal is clean: `_edit_mode` bool + `_editing_route` reference controls form behavior. The `open()` method resets to create mode, `open_for_edit()` sets edit mode — no state leakage between modes.
- In edit mode, ships assigned to the route being edited must be added back to the available pool for the ship selector, since `get_available_ships()` excludes them. Build a dictionary of idle IDs and append missing route ships from `carrier.ships`.
- Programmatic API methods (`get_form_state()`, `set_passenger_price()`, `confirm_save()`) are essential for validation harness controllers to drive and inspect the edit flow.
- PlayerController already had `modify_route()` and `route_modifications` — no pipeline changes needed.
- The RoutesModal pending actions section needed to display `route_modifications` alongside creates and cancellations.

### Ship Order Modal Extraction (2026-05-17)

- Extracting an inline form into a separate modal follows the same pattern as CreateRouteModal: parent modal emits `order_ship_requested`, main.gd closes parent and opens child modal, child's `closed` signal reopens parent.
- The `_on_toolbar_pressed` must also dismiss the child modal (order ship) the same way it dismisses CreateRouteModal — disconnect `closed` → close → reconnect to prevent the reopen handler from firing.
- After clearing `.godot` cache, Godot headless editor (`-e --quit`) must run before scenarios work again — the global class list rebuild is needed for type resolution.
- `.uid` files for new `.gd` scripts are NOT auto-generated by `--headless -e --quit`. Manual creation works (format: `uid://b<random_base36>`). However, class resolution still works without them once the cache is rebuilt.
- Programmatic API on modals (`get_form_state()`, `select_type()`, `confirm_order()`) is essential for harness controllers to drive the UI without real click events.

### ManageSlotsModal Table Redesign (2026-05-17)

- Replaced dropdown-based planet selector with flat table showing all planets. Each row has: name (system), "X available / Y total", owned count, Buy/Sell buttons. Much clearer at a glance.
- Buy/Sell buttons open an inline popup panel (PanelContainer within the content VBox) rather than a separate modal. Popup has quantity SpinBox (+ price for Buy), Confirm/Cancel. After confirm, emits `slot_action_submitted` and closes the modal.
- Sell button is disabled (`sell_btn.disabled = owned <= 0`) when player owns 0 slots at that planet.
- Programmatic API (`select_planet`, `confirm_bid`, `confirm_sell`) simplified: `select_planet(index)` just stores the planet ID from `galaxy.planets[index]`. `confirm_bid()` programmatically opens the buy popup and immediately confirms — no need for separate select + confirm steps in the harness.
- The existing harness controller and validation scenario (`ui_manage_slots_flow`) required zero changes — the programmatic API contract was preserved.
