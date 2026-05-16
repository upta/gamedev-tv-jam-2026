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
