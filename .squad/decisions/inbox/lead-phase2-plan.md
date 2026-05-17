# Phase 2: Full 30-Turn Game Loop + NPC AI

**Author:** Lead  
**Date:** 2025-07-15  
**Status:** Proposed — awaiting Brady approval

---

## Summary

Phase 1 delivered the headless simulation core: turn pipeline, state management, demand, financials, scoring. Phase 2 makes it a *game* — something that runs 30 turns from start to finish with four carriers making real decisions, events disrupting the market, and a winner at the end. No UI yet — that's Phase 3.

---

## Work Items

### P2.1: CarrierController Interface
**Deps:** None  
**Path:** `src/game/controllers/carrier_controller.gd`  

Base class that all controllers extend. Single responsibility: given game state and a carrier ID, produce a `CarrierIntent`.

```
class_name CarrierController extends RefCounted

func generate_intent(game_state: GameState, carrier_id: String) -> TurnPipeline.CarrierIntent
```

Why a class and not just a Callable: controllers will need internal state later (e.g., NPC personality weights, player intent queue from UI). Keep the door open.

---

### P2.2: IdleController
**Deps:** P2.1  
**Path:** `src/game/controllers/idle_controller.gd`  

Returns an empty `CarrierIntent` every turn. Used for:
- Headless player slot (no UI yet)
- Testing individual systems in isolation
- Any carrier you want to "park"

Trivial implementation but important for the controller contract — every carrier must have a controller, always.

---

### P2.3: NPC Controller
**Deps:** P2.1  
**Path:** `src/game/controllers/npc_controller.gd`  

Heuristic AI that generates meaningful intents. Game jam scope — good enough to be interesting, not trying to be optimal. One class, no strategy pattern. Personality differences come from tuning weights, not architecture.

**Decision logic per turn (in priority order):**

1. **Slots:** If cash > threshold and fewer than N routes, bid on slots at planets reachable from current slots. Prefer planets with fewer competitors. Bid price = base + small random variance.

2. **Routes:** If has slot pairs without routes and has unassigned ships, create routes. Price near suggested price ± personality offset. Frequency = max achievable with assigned ships.

3. **Ships:** If cash > ship cost and fleet is fully deployed (no idle ships), order cheapest available ship type. Balanced capacity split (prototype simplicity).

4. **Slot Sales:** If holding slots at planets with no routes for 3+ turns, sell them. (Prevents dead capital.)

Key design: NPCs don't need to be smart. They need to *do things* so the game has competition. A mediocre AI that actively plays beats a brilliant AI that takes 2 weeks to build.

---

### P2.4: Event System Implementation
**Deps:** None (standalone, event_system.gd structure already exists)  
**Path:** `src/game/events/event_system.gd` (modify existing)  

Replace the stub `generate_events()` with probability-based event generation.

**Event types (prototype set):**
- **Demand Surge** — +30-50% demand on a random lane, 2-4 turns
- **Demand Slump** — -20-40% demand on a random lane, 2-3 turns  
- **Gold Rush** — +50% cargo demand at a specific planet's lanes, 3 turns
- **Tourism Boom** — +40% passenger demand at a specific planet's lanes, 3 turns

**Generation rules:**
- Check probability each turn (e.g., 25% chance per turn)
- Max 2 active events at once (prevent chaos)
- No events before turn 3 (let carriers establish routes first)
- Events use the existing `GameEvent` class — no structural changes needed
- Seeded RNG for deterministic replay

**Architectural question 🔥:** Should `generate_events` take a seed/RNG parameter for determinism, or should GameState own an RNG instance? I lean toward GameState owning a `RandomNumberGenerator` that gets passed through. This keeps replay deterministic without threading RNG through every call site.

---

### P2.5: GameSession — 30-Turn Orchestrator  
**Deps:** P2.1  
**Path:** `src/game/session/game_session.gd`  

The top-level game runner. Owns the game state and controller assignments. Runs the turn loop.

```
class_name GameSession extends RefCounted

signal session_started()
signal turn_completed(turn_number: int, result: TurnPipeline.TurnResult)
signal session_ended(winner_id: String, reason: String)

var game_state: GameState
var controllers: Dictionary = {}  # carrier_id -> CarrierController
var is_running: bool = false

func setup(game_state: GameState, controllers: Dictionary) -> void
func run_all_turns() -> void        # Runs all 30 turns synchronously (headless)
func run_next_turn() -> TurnPipeline.TurnResult  # Step one turn (for UI pacing later)
func is_game_over() -> bool
func get_final_results() -> Dictionary
```

**Key design decisions:**
- **RefCounted, not Node.** GameSession has no scene tree dependency. Signals work on RefCounted in Godot 4. Validation harness wraps it in a Node if needed.
- **Synchronous `run_all_turns()` for headless.** No frame-stepping needed when there's no UI. Phase 3 adds `run_next_turn()` for paced play.
- **Owns GameState.** Single point of control. No ambiguity about who manages the state lifecycle.

**Turn loop pseudocode:**
```
for turn in range(1, 31):
    intents = []
    for carrier in game_state.carriers:
        intent = controllers[carrier.id].generate_intent(game_state, carrier.id)
        intents.append(intent)
    result = game_state.advance_turn(intents)
    turn_completed.emit(turn, result)
    if result.game_over:
        break
session_ended.emit(winner_id, reason)
```

---

### P2.6: GameSetup Factory
**Deps:** P2.2, P2.3, P2.5  
**Path:** `src/game/session/game_setup.gd`  

Factory that wires everything together for a standard game. Keeps configuration out of GameSession (which is a runner, not a configurator).

```
class_name GameSetup extends RefCounted

static func create_default_session() -> GameSession
    # Creates galaxy, catalog, carriers, demand
    # Assigns IdleController to player, NpcController to NPCs
    # Returns ready-to-run GameSession

static func create_all_npc_session() -> GameSession
    # All four carriers get NpcController (for full headless testing)
```

---

### P2.7: GameState RNG Integration
**Deps:** None  
**Path:** `src/game/state/game_state.gd` (modify existing)  

Add a `RandomNumberGenerator` to GameState with a configurable seed. Passed to event generation and NPC controllers for deterministic replay.

```
var rng: RandomNumberGenerator

func initialize(..., seed: int = 0) -> void:
    rng = RandomNumberGenerator.new()
    rng.seed = seed if seed != 0 else randi()
```

Small change but architecturally important — determinism is a Phase 1 principle (D004) that must extend to Phase 2's randomized systems.

---

### P2.8: Game Session Validation Harness
**Deps:** P2.5, P2.6  
**Path:** `src/validation/harnesses/game_session_harness.tscn`  
**Path:** `src/validation/scripts/harness_controllers/game_session_harness_controller.gd`  

New harness that runs a full GameSession and exposes rich observable state. The existing simulation_harness stays for unit-level turn testing; this one tests the integrated game loop.

**Observed state includes:**
- `harness_state.session_status` — "not_started" | "running" | "completed"
- `harness_state.turns_completed` — count
- `harness_state.carriers` — per-carrier cash, ships, routes, slots, score
- `harness_state.winner` — carrier_id and score (after completion)
- `harness_state.events_generated` — count of events that fired
- `metrics.game_duration_turns` — how many turns ran
- `metrics.total_routes_created` — across all carriers

---

### P2.9: Validation — Full Game Completion Scenarios
**Deps:** P2.8  
**Paths:** `src/validation/scenarios/session_*.json`

**Scenarios:**
1. **`session_completes_30_turns.json`** — Game runs to turn 30, game_over is true, winner exists. No crashes. This is the "it works" scenario.
2. **`session_all_carriers_active.json`** — After 10 turns, every carrier has at least 1 active route (proves NPCs are doing things, not sitting idle).
3. **`session_scores_diverge.json`** — Final scores are not all identical (proves the game produces differentiated outcomes).

---

### P2.10: Validation — NPC Behavior Scenarios
**Deps:** P2.3, P2.8  
**Paths:** `src/validation/scenarios/npc_*.json`

**Scenarios:**
1. **`npc_creates_routes.json`** — After 5 turns, at least 2 of 3 NPCs have active routes.
2. **`npc_orders_ships.json`** — After 10 turns, at least 1 NPC has more ships than it started with.
3. **`npc_bids_on_slots.json`** — After 5 turns, at least 1 NPC has more slots than it started with.

---

### P2.11: Validation — Event System Scenarios  
**Deps:** P2.4, P2.8  
**Paths:** `src/validation/scenarios/event_*.json`

**Scenarios:**
1. **`event_generation_occurs.json`** — Over 30 turns with a known seed, at least 1 event fires.
2. **`event_modifies_demand.json`** — When an event is active, demand modifiers are != 1.0 on affected lanes.
3. **`event_expires.json`** — Events with duration N are gone after N turns.

---

## Dependency Graph & Parallelism

```
P2.1 (Controller Interface)  ──┬── P2.2 (IdleController)     ──┐
                                ├── P2.3 (NPC Controller)      ──┤
                                └── P2.5 (GameSession)         ──┤
                                                                 ├── P2.6 (GameSetup) ── P2.8 (Harness)
P2.4 (Event System) ────────────────────────────────────────────┘        │
P2.7 (RNG Integration) ─────────────────────────────────────────────────┘
                                                                         │
                                                              ┌──────────┤
                                                              │          │
                                                        P2.9 (Game)  P2.10 (NPC)  P2.11 (Events)
```

**Parallel tracks:**
- **Track A:** P2.1 → P2.2 + P2.3 (parallel) → P2.6
- **Track B:** P2.4 (standalone, can start immediately)
- **Track C:** P2.7 (standalone, can start immediately)
- **Track D:** P2.5 (needs only P2.1)
- **Convergence:** P2.8 needs P2.5 + P2.6. Then P2.9-P2.11 can parallel.

**Recommended build order for a single Builder:**
1. P2.1 + P2.7 (small, foundational)
2. P2.4 (standalone, unblocks event scenarios)
3. P2.2 + P2.5 (idle controller + session runner)
4. P2.3 (NPC — biggest item, but P2.5 can test with IdleControllers first)
5. P2.6 (factory, wires everything)
6. P2.8 (harness)
7. P2.9, P2.10, P2.11 (validation scenarios)

---

## Architectural Questions to Grill 🔥

### Q1: Should NPC AI be one class or composed from strategies?
**My position:** One class. This is a game jam. Strategy pattern adds abstraction layers we won't benefit from in 30 days. Personality differences are weight tuning (`slot_aggression: 0.7`), not different strategy implementations. If we need smarter AI later, refactor then.

### Q2: Should GameSession be RefCounted or Node?
**My position:** RefCounted. It has no scene tree needs. The validation harness wraps it in a Node for `_physics_process` stepping. Keeping it RefCounted means it's testable without any Godot scene infrastructure.

### Q3: Who owns the RNG?
**My position:** GameState. It already owns all simulation state (D001). Adding RNG there means every system that needs randomness gets it from the same source. Deterministic replay = same seed → same game, guaranteed.

### Q4: Turn pacing — instant or frame-stepped?
**My position:** Both. `run_all_turns()` for headless/validation (instant). `run_next_turn()` for UI in Phase 3 (one turn per player action). The harness controller decides which to use. For Phase 2, everything uses `run_all_turns()`.

### Q5: Should events target planets or lanes?
**My position:** Both. The `GameEvent` structure already supports `target_lane_id` and `target_planet_id`. Planet-targeted events affect all lanes touching that planet. Lane-targeted events affect just that lane. This is already designed into the Phase 1 stub.

---

## Scope Guard

**In scope:** Everything above.  
**Out of scope (Phase 3+):**
- Any UI (buttons, panels, star map)
- Player controller that takes real input
- Save/load
- Difficulty settings
- NPC negotiation or diplomacy
- Ship upgrades or retrofitting
- Multiple galaxy maps

---

## Definition of Done (Phase 2)

1. `GameSetup.create_all_npc_session()` produces a session that runs 30 turns without error
2. All 4 carriers actively participate (routes, ships, slots change over time)
3. Events fire and affect demand
4. Scores diverge — the game produces meaningful outcomes
5. All P2 scenarios pass
6. All P1 scenarios still pass (no regressions)
7. `git push origin`
