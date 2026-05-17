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
