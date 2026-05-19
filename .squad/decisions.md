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
