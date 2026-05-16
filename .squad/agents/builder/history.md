# Builder History

## Session: Implementation Planning (2026-05-16T23:11:53Z)
**Status:** Ready to begin Phase 1  
**Plan Location:** `.squad/decisions/inbox/lead-implementation-plan.md`  
**Decisions Location:** `.squad/decisions.md`

### Phase 1 Work Order (12 Items)
The implementation plan specifies Phase 1 as a sequence of 12 work items (P1.1–P1.12) covering:

1. **P1.1–P1.3 (parallel):** Galaxy, Ship Catalog, Carrier Data resources
2. **P1.4:** GameState autoload
3. **P1.12 harness (early):** Simulation harness for scenario testing
4. **P1.5–P1.6 (parallel):** Route logic, Slot auction
5. **P1.7:** Demand calculator
6. **P1.8:** Financial calculator
7. **P1.9:** Turn pipeline
8. **P1.10–P1.11 (parallel):** Score calculator, Event system

Each work item ships with validation scenarios. No exceptions.

### Key Architectural Decisions
See `.squad/decisions.md` for 5 core decisions:
- GameState as single source of truth
- Symmetric carrier identity
- Lane/Route ownership distinction
- Deterministic simultaneous turns
- Directional competitive demand

### Dependencies & Parallelization
Dependency graph provided in plan. Can parallelize: P1.1–3, P1.5–6, P1.10–11.

**Next:** Begin P1.1–P1.3 in parallel.

## Learnings

### P1.3: Carrier Data (2026-05-17)
- **File:** `src/game/state/carrier_data.gd`
- **Pattern:** Resource class with inner classes `Route` and `ShipRef`. ShipRef is a lightweight mirror of ship_catalog.gd's ShipInstance — avoids hard dependency until P1.4 unifies types.
- **Naming:** Used `carrier_name` instead of `name` to avoid shadowing `Object.name`.
- **Slots:** Dictionary keyed by planet_id → int count. Missing key = 0.
- **Factory:** `create_default_carriers()` is a static method producing 4 carriers with 3000 cash, 2 slots each on different planets, and 1 basic ship. Planet IDs use lowercase descriptive strings (earth, mars, proxima_b, etc.) to match galaxy_data.gd conventions.
- **Ship assignment:** `get_available_ships()` collects all ship_ids from active routes into a set, then returns ships not in that set.
- **No validation scenarios** — harness doesn't exist yet (deferred to P1.12).

## Learnings

### P1.1: Galaxy Data (2026-05-17)
**File:** `src/game/state/galaxy_data.gd`

**What was built:**
- `GalaxyData` Resource class with inner classes `Planet` and `Lane`
- Lookup methods: `get_planet()`, `get_lane()` (bidirectional), `get_lanes_from()`, `get_distance()`
- `create_default_galaxy()` static factory producing 12 planets across 4 systems (Sol, Alpha Centauri, Wolf 359, Tau Ceti) with 15 lanes
- Internal hash indices (`_planet_index`, `_lane_index`, `_lanes_from_index`) built once via `_build_indices()` for O(1) lookups

**Patterns chosen:**
- Inner classes over separate Resource subclasses — keeps the entire topology definition in one file, simpler for a data-only structure
- String-keyed dictionaries for indices — `"origin::dest"` composite key for lane lookups, both directions stored
- `get_distance()` returns `-1.0` for missing lanes (sentinel value, not an error) — callers can check easily
- Lane distances: intra-system 1.0–2.5, inter-system 7.0–14.0 — meaningful gameplay variance

**Galaxy topology notes:**
- Earth and Centauri Prime are the major hubs (highest connectivity + slots)
- Outpost and Frosthold are remote endpoints connected by the longest lane (14.0) — creates a "frontier" feel
- Graph is fully connected but not complete — forces route planning tradeoffs

## Learnings

### P1.2: Ship Catalog (2026-05-16)
- **Built:** `src/game/state/ship_catalog.gd` — Resource class with inner classes `ShipType` and `ShipInstance`
- **Pattern:** Inner classes for data structs, static factory `create_default_catalog()`, instance factory with validation
- **Instance IDs:** Format `{type_id}-{counter}` (e.g., `sd-100-0001`), counter scoped to catalog instance
- **Capacity split validation:** `create_ship_instance()` enforces passenger + cargo == max_capacity, push_error on mismatch
- **Ship lineup:** 7 types across 2 manufacturers (Sol Dynamics: balanced; Frontier Works: specialized extremes)
- **Efficiency convention:** Higher = better. Operating cost = distance / efficiency

### P1.4: GameState Autoload (2026-05-17)
- **File:** `src/game/state/game_state.gd`
- **Type:** Node autoload (not Resource) — registered in project.godot as `GameState`
- **Signals:** `turn_resolved(turn_number)`, `game_over(carrier_id, reason)` — stubs for P1.9
- **Carrier index:** `_build_carrier_index()` creates O(1) lookup Dictionary keyed by carrier id
- **Placeholders:** `demand_table` is null (P1.7), `events` is empty Array (P1.10-P1.11)
- **Type unification:** Removed `ShipRef` from `carrier_data.gd`. Ships now stored as `ShipCatalog.ShipInstance`. Factory `create_default_carriers()` accepts a `ShipCatalog` and creates proper SD-100 instances (20/20 passenger/cargo split, available_turn 0). Decision documented in `.squad/decisions/inbox/builder-gamestate.md`.
- **No validation scenarios** — harness doesn't exist yet (deferred to P1.12).

### P1.5: Route Logic (2026-05-17)
- **File:** `src/game/simulation/route_validator.gd`
- **Pattern:** Static utility class (`RouteValidator`), all methods static, no state. Extends RefCounted.
- **Frequency simplified:** Each ship = 1 round-trip per turn regardless of distance. `max_frequency = ship_count`. Avoids speed-based frequency complexity — the interesting decision is how many ships to assign.
- **Validation order:** Slots at both endpoints → lane exists → per-ship checks (exists, range, availability, delivery turn) → clamp frequency.
- **Modification vs creation:** `validate_route_modification` excludes the route being modified when checking ship availability, so ships on the current route are considered "available" for reassignment.
- **`get_route_capacity` signature:** Added `carrier` parameter beyond the spec since ship lookup requires the carrier's fleet array. Capacity = sum of ship capacities × frequency.
- **No validation scenarios** — harness doesn't exist yet (deferred to P1.12).

### P1.6: Slot Auction Resolver (2026-05-17)
- **File:** `src/game/simulation/auction_resolver.gd`
- **Pattern:** Static utility class (`class_name AuctionResolver`, extends RefCounted). All methods static — returns results, never mutates state (D001).
- **Auction resolution:** Groups bids by planet, sorts descending by price_per_slot, tie-breaks by carrier_order index (D004). Awards min(requested, remaining) slots per bid. Full bid rejected if carrier can't afford total cost (no partial funding).
- **Slot sales:** Instant, zero refund (sunk cost). Validates carrier owns enough slots and that selling won't orphan active routes at that planet. Each active route with origin or dest at the planet counts as 1 slot used.
- **Helper:** `get_available_slots()` computes planet.total_slots minus sum of all carriers' slot counts.
- **Directory:** Created `src/game/simulation/` (first file in this directory).
- **No validation scenarios** — harness doesn't exist yet (deferred to P1.12).
