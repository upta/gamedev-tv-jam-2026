# Astrobiz — Implementation Plan

**Status:** Approved by Brady. Ready for Builder and Validator.
**Date:** 2025-07-14

---

## File & Folder Structure

```
src/game/
├── main.gd                     # Game scene root (entry from app_root)
├── main.tscn
├── state/
│   ├── game_state.gd           # Central GameState autoload — owns all simulation data
│   ├── galaxy_data.gd          # Resource: planets, lanes, distances
│   ├── carrier_data.gd         # Resource: carrier state (cash, ships, slots, routes)
│   ├── demand_data.gd          # Resource: demand tables per lane+direction
│   ├── ship_catalog.gd         # Resource: ship type definitions
│   └── turn_result.gd          # Resource: output of one turn resolution
├── simulation/
│   ├── turn_pipeline.gd        # Pure function: resolve one turn on GameState
│   ├── demand_calculator.gd    # Demand splitting, price_factor math
│   ├── auction_resolver.gd     # Slot auction resolution
│   ├── financial_calculator.gd # Revenue, costs, bankruptcy check
│   ├── route_validator.gd      # Route creation/modification rule checks
│   └── score_calculator.gd     # Composite company value at any turn
├── carriers/
│   ├── carrier_controller.gd   # Abstract base: interface for carrier decisions
│   ├── npc_controller.gd       # NPC AI: simple rule-based
│   └── player_controller.gd    # Player: receives intents from UI (Phase 3)
└── events/
    └── event_system.gd         # Random demand modifier events

src/validation/
├── harnesses/
│   └── simulation_harness.tscn # Headless harness — loads GameState, no UI
├── scripts/harness_controllers/
│   └── simulation_harness_controller.gd  # Exposes full GameState to scenarios
└── scenarios/
    ├── galaxy_setup.json
    ├── carrier_initialization.json
    ├── route_creation.json
    ├── route_frequency.json
    ├── demand_basic.json
    ├── demand_competition.json
    ├── slot_auction.json
    ├── financial_basics.json
    ├── turn_pipeline.json
    ├── bankruptcy.json
    ├── ship_ordering.json
    ├── ship_capacity.json
    └── score_calculation.json
```

---

## Phase 1: Headless Simulation Core

### Dependency Graph

```
P1.1 Galaxy Data ─────────────┐
P1.2 Ship Catalog ────────────┤
P1.3 Carrier Data ────────────┼──→ P1.5 Route Logic ──→ P1.7 Demand ──→ P1.9 Turn Pipeline
P1.4 GameState Autoload ──────┘         │                     │              │
                                        │                     │              ▼
P1.6 Slot Auction ─────────────────────-┘                     │         P1.10 Score
                                                              ▼
                                                     P1.8 Financials ──→ P1.11 Events
                                                              │
                                                              ▼
                                                     P1.12 Harness + Full Suite
```

**Can be parallelized:** P1.1, P1.2, P1.3 (no deps). P1.6 can parallel with P1.5 after P1.3+P1.4.

---

### P1.1 — Galaxy Data

**Produces:**
- `src/game/state/galaxy_data.gd` — Resource class

**Data structures:**
```
Planet: { id: String, name: String, system: String, total_slots: int }
Lane:   { id: String, origin_id: String, dest_id: String, distance: float }
GalaxyData: { planets: Array[Planet], lanes: Array[Lane] }
```

**Methods:**
- `get_planet(id) -> Planet`
- `get_lane(origin_id, dest_id) -> Lane` (order-independent — lanes are bidirectional paths)
- `get_lanes_from(planet_id) -> Array[Lane]`
- `get_distance(origin_id, dest_id) -> float`
- `create_default_galaxy() -> GalaxyData` — static factory for the prototype map (3 systems, ~12 planets)

**Depends on:** Nothing.

**Validation scenarios:**
- `galaxy_setup.json` — Galaxy has expected planet count, lanes connect valid planets, distances are positive, lane lookup works bidirectionally.

---

### P1.2 — Ship Catalog

**Produces:**
- `src/game/state/ship_catalog.gd` — Resource class

**Data structures:**
```
ShipType:  { id: String, name: String, manufacturer: String, range: float,
             max_capacity: int, efficiency: float, cost: int, build_turns: int,
             unlock_turn: int }
ShipInstance: { id: String, type_id: String, passenger_capacity: int,
                cargo_capacity: int, owner_id: String, available_turn: int }
ShipCatalog: { types: Array[ShipType] }
```

**Methods:**
- `get_type(id) -> ShipType`
- `get_available_types(turn: int) -> Array[ShipType]` — filters by unlock_turn
- `create_default_catalog() -> ShipCatalog` — 3 starting types + 4 unlockable

**Depends on:** Nothing.

**Validation scenarios:**
- `ship_catalog.json` — 3 types available at turn 1, 7 total, capacity split must equal max_capacity, build_turns within 2-5 range.

---

### P1.3 — Carrier Data

**Produces:**
- `src/game/state/carrier_data.gd` — Resource class

**Data structures:**
```
Route:   { id: String, lane_id: String, origin_id: String, dest_id: String,
           ship_ids: Array[String], passenger_price: float, cargo_price: float,
           frequency: int, active: bool }
Carrier: { id: String, name: String, cash: float, slots: Dictionary[String, int],
           ships: Array[ShipInstance], routes: Array[Route],
           pending_orders: Array[ShipInstance] }
```

**Methods:**
- `get_slot_count(planet_id) -> int`
- `get_available_ships() -> Array[ShipInstance]` — ships not assigned to any route
- `get_routes() -> Array[Route]`
- `total_ship_count() -> int`

**Depends on:** Nothing (references ShipInstance by structure, not import).

**Validation scenarios:**
- `carrier_initialization.json` — 4 carriers created, each starts with correct cash, 2 slots on different planets, 1 ship. Available ships = ships not on routes.

---

### P1.4 — GameState Autoload

**Produces:**
- `src/game/state/game_state.gd` — Autoload singleton

**Data structures:**
```
GameState: { galaxy: GalaxyData, catalog: ShipCatalog,
             carriers: Array[Carrier], current_turn: int,
             demand_table: DemandData, events: Array }
```

**Methods:**
- `initialize(galaxy, catalog, carriers)` — set up a new game
- `get_carrier(id) -> Carrier`
- `get_all_carriers() -> Array[Carrier]`
- Signals: `turn_resolved(turn_number: int)`, `game_over(carrier_id: String, reason: String)`

**Depends on:** P1.1, P1.2, P1.3.

**Validation scenarios:**
- Covered by downstream scenarios (turn_pipeline, etc.). GameState initialization validated as part of carrier_initialization.

---

### P1.5 — Route Logic

**Produces:**
- `src/game/simulation/route_validator.gd` — static utility

**Rules enforced:**
- Carrier must own slots at both origin AND destination planets
- Ship range must cover lane distance
- Ship must be available (not assigned to another route)
- Frequency constrained by: `max_frequency = ship_count × floor(1.0 / (distance / ship_speed))` — but simplified for prototype: frequency ≤ ship_count (each ship = 1 round-trip/turn on short lanes)
- Actually: `frequency = min(requested, sum_over_ships(floor(ship_speed / (2 * distance))))` — each ship contributes trips based on speed vs distance

**Methods:**
- `validate_route_creation(carrier, lane, ships, frequency) -> { valid: bool, reason: String }`
- `calculate_max_frequency(ships: Array[ShipInstance], distance: float) -> int`
- `get_route_capacity(route: Route, catalog: ShipCatalog) -> { passenger: int, cargo: int }` — total capacity across all assigned ships × frequency

**Depends on:** P1.1, P1.2, P1.3, P1.4.

**Validation scenarios:**
- `route_creation.json` — Can create route with valid slots + ships. Rejected without slots. Rejected with out-of-range ship. Rejected with no available ships.
- `route_frequency.json` — Max frequency calculation correct for short/long lanes. Requested frequency clamped to max.

---

### P1.6 — Slot Auction

**Produces:**
- `src/game/simulation/auction_resolver.gd` — static utility

**Rules:**
- Each planet has total_slots cap
- Bids: `{ carrier_id, planet_id, quantity, price_per_slot }`
- Resolution: sort bids by price_per_slot descending. Award slots in order until planet cap reached. Ties broken by carrier index.
- Cost deducted from carrier cash
- Selling: instant, slot returned, refund = 0 (sunk cost)

**Methods:**
- `resolve_auctions(bids: Array, galaxy: GalaxyData, carriers: Array[Carrier]) -> AuctionResult`
- `AuctionResult: { awards: Array[{ carrier_id, planet_id, slots_won, cost }], rejections: Array }`

**Depends on:** P1.1, P1.3, P1.4.

**Validation scenarios:**
- `slot_auction.json` — Single bidder wins at bid price. Multiple bidders: highest wins. Planet cap respected. Insufficient cash = bid rejected. Tie broken by carrier index.

---

### P1.7 — Demand Calculator

**Produces:**
- `src/game/state/demand_data.gd` — Resource class
- `src/game/simulation/demand_calculator.gd` — static utility

**Data structures:**
```
DemandEntry: { lane_id: String, direction: String, # "origin_to_dest" or "dest_to_origin"
               base_demand_passenger: int, base_demand_cargo: int,
               suggested_price_passenger: float, suggested_price_cargo: float }
DemandData: { entries: Array[DemandEntry] }
```

**Formulas:**
- `price_factor = clamp(1.0 - (price - suggested) / suggested, 0.2, 1.5)`
- `effective_demand = base_demand × price_factor`
- Competition split: each carrier's share = `(capacity × price_factor) / sum(all carriers' capacity × price_factor)`
- Passenger and cargo are independent demand lanes, same formula

**Methods:**
- `calculate_price_factor(price, suggested_price) -> float`
- `calculate_demand_split(routes_on_lane: Array, direction: String, demand_entry: DemandEntry, catalog: ShipCatalog) -> Dictionary[String, { passengers: int, cargo: int }]`
- `get_demand_tier(base_demand: int) -> String` — returns "Low"/"Medium"/"High" for player-facing estimates

**Depends on:** P1.1, P1.2, P1.3, P1.5.

**Validation scenarios:**
- `demand_basic.json` — price_factor at suggested price = 1.0, at double = 0.2, at zero = 1.5 (clamped). Effective demand scales correctly.
- `demand_competition.json` — Single carrier gets 100% of demand. Two carriers split proportionally. Carrier with lower price gets larger share. Cargo and passenger independent.

---

### P1.8 — Financial Calculator

**Produces:**
- `src/game/simulation/financial_calculator.gd` — static utility

**Formulas:**
- Revenue per route per turn: `passengers_carried × passenger_price + cargo_carried × cargo_price` (per direction, summed)
- Operating cost per route: `distance × (1.0 / ship_efficiency) × frequency × cost_per_fuel_unit`
- Net income = total revenue - total operating costs
- Bankruptcy: cash ≤ 0 after financials

**Methods:**
- `calculate_route_revenue(route, demand_split, catalog) -> { revenue: float, breakdown: Dictionary }`
- `calculate_route_cost(route, lane, catalog) -> float`
- `calculate_carrier_financials(carrier, demand_splits, galaxy, catalog) -> FinancialResult`
- `FinancialResult: { total_revenue, total_costs, net_income, route_details: Array, is_bankrupt: bool }`

**Depends on:** P1.7.

**Validation scenarios:**
- `financial_basics.json` — Revenue = passengers × price + cargo × price. Cost proportional to distance and frequency. Net income = revenue - cost. Bankruptcy triggers at cash ≤ 0.
- `bankruptcy.json` — Carrier with insufficient revenue goes bankrupt. Game over signal emitted.

---

### P1.9 — Turn Pipeline

**Produces:**
- `src/game/simulation/turn_pipeline.gd` — static utility
- `src/game/state/turn_result.gd` — Resource class

**Pipeline order (simultaneous, fixed):**
1. **Collect** — Gather all carrier intents (routes created/modified/cancelled, bids, ship orders)
2. **Auctions** — Resolve slot bids
3. **Routes** — Validate and activate new/modified routes
4. **Ships** — Deliver ships whose build time elapsed, process new orders
5. **Demand** — Calculate demand splits for all active routes
6. **Financials** — Calculate revenue, costs, update cash, check bankruptcy
7. **Events** — Apply any random events for next turn
8. **Report** — Generate TurnResult for each carrier

**Data structures:**
```
CarrierIntent: { carrier_id: String, new_routes: Array, modified_routes: Array,
                 cancelled_routes: Array[String], bids: Array, ship_orders: Array }
TurnResult:    { turn: int, carrier_results: Dictionary[String, CarrierTurnResult] }
CarrierTurnResult: { revenue_breakdown: Array, financial_summary: Dictionary,
                     ships_delivered: Array, slots_won: Array, events: Array[String] }
```

**Methods:**
- `resolve_turn(game_state: GameState, intents: Array[CarrierIntent]) -> TurnResult`

**Depends on:** P1.5, P1.6, P1.7, P1.8.

**Validation scenarios:**
- `turn_pipeline.json` — Full turn with one carrier creating a route: correct pipeline order. Revenue appears in result. Turn counter increments. Multiple carriers processed identically.
- `ship_ordering.json` — Ship ordered on turn 1 with build_turns=3 arrives on turn 4. Ship appears in carrier inventory after delivery.
- `ship_capacity.json` — Ship ordered with passenger_capacity + cargo_capacity = max_capacity. Split preserved after delivery.

---

### P1.10 — Score Calculator

**Produces:**
- `src/game/simulation/score_calculator.gd` — static utility

**Formula:**
- `score = cash + ship_asset_value + slot_value + route_value`
- ship_asset_value = sum of ship purchase costs (depreciation not modeled in prototype)
- slot_value = sum of slots × base_slot_value
- route_value = sum of route last-turn revenue × multiplier (e.g., 5×)
- Exact weights TBD — start with these defaults, tune via playtesting

**Methods:**
- `calculate_score(carrier: Carrier, catalog: ShipCatalog) -> { total: float, breakdown: Dictionary }`
- `determine_winner(carriers: Array[Carrier], catalog: ShipCatalog) -> Carrier`

**Depends on:** P1.3.

**Validation scenarios:**
- `score_calculation.json` — Score includes all components. Carrier with more assets scores higher. Winner is highest scorer. Tie broken by carrier index.

---

### P1.11 — Event System (Minimal)

**Produces:**
- `src/game/events/event_system.gd`

**Data structures:**
```
GameEvent: { id: String, description: String, target_lane_id: String,
             demand_modifier: float, duration_turns: int, remaining_turns: int }
```

**Methods:**
- `generate_events(turn: int, galaxy: GalaxyData) -> Array[GameEvent]`
- `apply_events(events: Array[GameEvent], demand_data: DemandData) -> void`
- `tick_events(events: Array[GameEvent]) -> Array[GameEvent]` — decrement remaining, remove expired

**Depends on:** P1.7.

**Validation scenarios:**
- Deferred to Phase 2. Phase 1 includes the structure but events array starts empty. Turn pipeline calls the event system but it's a no-op.

---

### P1.12 — Validation Harness + Full Suite

**Produces:**
- `src/validation/harnesses/simulation_harness.tscn`
- `src/validation/scripts/harness_controllers/simulation_harness_controller.gd`

**Harness design:**
- Headless — no scene tree presentation, just GameState
- Controller initializes GameState with a test galaxy (small: 2 systems, 4 planets, 3 lanes)
- `get_observed_state()` exposes:

```
harness_state:
  nodes: {}  # No scene nodes — headless
  metrics:
    current_turn: int
    carrier_count: int
  carriers:
    - id, name, cash, slot_counts, ship_count, route_count, score
  galaxy:
    planet_count: int
    lane_count: int
    planets: [{ id, name, system, total_slots }]
    lanes: [{ id, origin, dest, distance }]
  demand:
    entries: [{ lane_id, direction, base_passenger, base_cargo }]
  signals:
    - turn_resolved
    - game_over
```

**Harness operations:**
- `initialize_game` — set up GameState with test galaxy
- `submit_intent` — submit a CarrierIntent for a specific carrier
- `advance_turn` — resolve one turn
- `create_route` — convenience: create intent + advance
- `set_carrier_cash` — test helper for financial edge cases

**Depends on:** All of P1.1–P1.11.

**Validation scenarios:**
- All scenarios listed above run against this harness. This work item is about building the harness itself, not the scenarios (those are delivered with each work item).

---

## Phase 2: Full Turn Loop + NPCs (Outline)

**Scope:** Wire up the complete game loop — all 30 turns playable headless with NPC AI making decisions.

- **P2.1 — NPC Controller:** Rule-based AI. Expand toward high-demand planets. Bid for slots, create routes, order ships. Encapsulated behind CarrierController interface.
- **P2.2 — Player Controller (Headless):** Accepts intents programmatically (for testing). No UI yet.
- **P2.3 — Game Loop Manager:** Orchestrates turns. Collects intents from all controllers, runs turn_pipeline, distributes results. Manages turn 30 end condition.
- **P2.4 — Tech Progression:** New ship types unlock at specified turns. Catalog filtering by turn already exists (P1.2).
- **P2.5 — Event System Live:** Random events fire with probability. Demand modifiers applied. Events reported in turn results.
- **P2.6 — Full 30-Turn Game Scenario:** End-to-end: 4 carriers, 30 turns, NPCs make decisions, one winner declared, no bankruptcies in default config (unless NPC is bad). This is the integration test.

---

## Phase 3: UI Shell (Outline)

**Scope:** Presentation layer. Scene tree reads GameState, emits intents. All game logic stays in Phase 1/2 code.

- **P3.1 — Star Map:** 2D node layout of planets + lanes. Visual indicators for owned slots, active routes.
- **P3.2 — Route Creation Panel:** Select origin/dest, configure ships/price/frequency. Validates via route_validator.
- **P3.3 — Ship Catalog Panel:** Browse available ships, order with capacity split config.
- **P3.4 — Slot Bidding Panel:** Select planet, enter bid amount.
- **P3.5 — Turn Report Panel:** Revenue breakdown, financial summary, events.
- **P3.6 — HUD:** Cash, turn counter, score, carrier standings.
- **P3.7 — End Game Screen:** Winner announcement, final scores.
- **P3.8 — Guided First Turn:** Welcome message + prompt to create first route.

---

## Work Order for Builder

**Build in this order (sequential unless noted):**

1. P1.1 + P1.2 + P1.3 (parallel — no dependencies)
2. P1.4 (needs 1-3)
3. P1.12 harness (needs P1.4 — build early so scenarios can run)
4. P1.5 + P1.6 (parallel — both need P1.4)
5. P1.7 (needs P1.5)
6. P1.8 (needs P1.7)
7. P1.9 (needs P1.5-P1.8)
8. P1.10 (can parallel with P1.9)
9. P1.11 (stub — can parallel with P1.9)

**Each work item ships with its validation scenarios. No exceptions.**

---

## Work Order for Validator

- Review each work item's scenarios for coverage gaps
- Ensure harness_state exposes enough for all planned scenarios
- Run full suite after each work item merges
- Flag any scenario that's flaky or non-deterministic

---

## Key Architectural Decisions

1. **GameState is the single source of truth.** No game logic in scene tree. Turn resolution is a pure function.
2. **Carrier identity is symmetric.** Player and NPCs use identical Carrier data. Only the controller differs.
3. **Lanes are shared, Routes are owned.** Lane = geographic path. Route = carrier's scheduled service on a lane.
4. **Simultaneous turns with deterministic ordering.** All carriers processed identically. Tie-breaking by carrier index.
5. **Demand is directional and competitive.** Each lane+direction has independent demand for passengers and cargo. Competition splits by capacity × price_factor.
