# Phase 3: UI Shell — Play a Full Game

**Author:** Lead  
**Date:** 2025-07-16  
**Status:** Proposed — awaiting Brady approval

---

## Summary

Phases 1–2 built the entire simulation: headless game state, 8-step turn pipeline, NPC AI, events, 30-turn orchestration. 208 unit tests, 13 validation scenarios — all green. The game *works*. Nobody can *play* it.

Phase 3 adds the visual layer: a star map, carrier dashboard, intent-building UI, turn results display, and the "Next Turn" button that ties it all together. After Phase 3, a human sits down, plays 30 turns, and either wins or doesn't. Game jam submission-ready.

**Design principle:** The UI is a *skin* over the headless simulation. It reads GameState, builds CarrierIntents through UI interactions, and displays TurnResults. Zero game logic in the UI layer.

---

## Architectural Decisions

### A1: Scene Tree Structure

```
GameScene (Control — root of main.tscn)
├── TopBar (HBoxContainer)
│   ├── TurnLabel ("Turn 7 / 30")
│   ├── CashLabel ("§2,450")
│   ├── ScoreLabel ("Score: 4,200")
│   └── NextTurnButton
├── HSplitContainer
│   ├── StarMapPanel (Control, left ~60%)
│   │   └── StarMap (Node2D inside SubViewportContainer)
│   │       ├── PlanetNodes (clickable)
│   │       ├── LaneLines (clickable)
│   │       └── CarrierMarkers (visual indicators)
│   └── SidePanel (VBoxContainer, right ~40%)
│       ├── DashboardPanel (carrier overview: ships, slots, routes)
│       ├── ActionPanel (intent-building forms)
│       └── TurnLogPanel (scrollable turn results feed)
├── GameOverOverlay (hidden until game ends)
└── NotificationArea (event toasts, auction results)
```

**Rationale:** Single-screen layout. No scene transitions mid-game. Left side is spatial (map), right side is informational (dashboard + actions). The player's eye path is: map → dashboard → actions → Next Turn. Everything visible at once — no hidden panels or tabs.

### A2: PlayerController Intent Collection

PlayerController extends CarrierController. It holds a mutable `pending_intent: CarrierIntent` that the UI builds up incrementally. When `generate_intent()` is called (by GameSession during turn resolution), it returns the accumulated intent and resets.

```
class PlayerController extends CarrierController:
    signal intent_changed(intent: CarrierIntent)

    var pending_intent: CarrierIntent

    func add_slot_bid(planet_id, quantity, price) -> void
    func add_route_create(lane_id, origin_id, dest_id, ship_ids, pax_price, cargo_price) -> void
    func modify_route(route_id, ship_ids, pax_price, cargo_price) -> void
    func cancel_route(route_id) -> void
    func add_ship_order(type_id, pax_cap, cargo_cap) -> void
    func add_slot_sale(planet_id, count) -> void
    func clear_intent() -> void
    func generate_intent(game_state, carrier_id) -> CarrierIntent  # returns & resets
```

UI panels call these methods. `intent_changed` signal lets the UI display a "pending actions" summary before the player commits.

**Rationale:** Keeps the UI→simulation bridge clean. UI panels don't touch CarrierIntent directly. PlayerController is the single point of intent aggregation. Same interface as NpcController — D002 symmetry preserved.

### A3: GameState Autoload Resolution

GameState extends Node (needed for signals like `turn_resolved`, `game_over`). It was removed from project.godot autoloads due to class_name conflicts.

**Solution:** Don't re-add it as autoload. GameSession already owns the GameState instance. The GameScene holds a reference to the GameSession (created via GameSetup). UI panels receive GameState through dependency injection (GameScene passes it down), not through a global autoload.

```
GameScene._ready():
    session = GameSetup.create_default_session_with_player(player_controller)
    dashboard.bind(session.game_state)
    star_map.bind(session.game_state)
```

**Rationale:** Avoids the autoload/class_name conflict entirely. Explicit dependency injection is cleaner than global state for a single-scene game. GameSession is already the owner — don't fight it.

### A4: Star Map — Minimal Viable Implementation

Static layout. Hardcoded planet positions (12 planets across 4 systems). Lines for lanes. Colored circles for planets. Small indicators showing carrier presence (slot ownership).

- **Planets:** Colored circles sized by total_slots. Label with name. Click to see planet info and slot actions.
- **Lanes:** Lines between planets. Thickness or color hints at demand level. Click to see lane info and route actions.
- **Systems:** Background regions or subtle grouping (color-coded clusters).
- **No pan/zoom.** 12 planets fit on one screen at 1280×720. Fixed layout.

Planet positions (approximate, tuned for readability):

```
Sol (center-left):        Earth(200,300) Mars(300,250) Titan(150,400) Europa(250,450)
Alpha Centauri (top-right): Proxima_b(700,150) Centauri_Prime(850,200) Haven(750,280)
Wolf 359 (bottom-right):  Wolf_Station(800,450) Forge(900,400) Outpost(950,500)
Tau Ceti (far-right):     Tau_Haven(1050,250) Frosthold(1100,350)
```

**Rationale:** Game jam. A readable node-and-edge diagram is sufficient. The information density matters more than visual polish. Players need to see: where are my slots, where are my routes, where is demand.

### A5: Turn Results Display

Turn results appear in the **TurnLogPanel** (right sidebar, scrollable) and as **notification toasts** for important events.

- **TurnLogPanel:** After each turn, append a summary block: revenue, costs, net cash change, auction outcomes, event notifications, ranking position. Scrollable history — player can review past turns.
- **Notification toasts:** Temporary popups for: "Ship SD-100 delivered!", "Lost auction at Mars", "Demand Surge on Earth↔Mars lane!", "NPC_1 went bankrupt!". Auto-dismiss after 3 seconds.
- **No modal overlay.** The game is paced but not interrupted. Click Next Turn → results appear → player reads and plans → click Next Turn again.

**Rationale:** Log-style is faster than modal popups for a 30-turn game where each turn should take 15–30 seconds. Toasts catch the eye for critical events without blocking interaction.

### A6: Validation Strategy for UI

UI validation scenarios use a **new UI harness** that instantiates the full GameScene in the scene tree. The harness can:
- Simulate UI actions (click buttons, select planets, set prices)
- Observe displayed state (labels, panels, map markers)
- Run turns via the Next Turn button
- Verify the game completes without errors

This is *integration* testing — the headless simulation is already proven by 13 scenarios. UI scenarios verify the wiring works.

---

## Work Items

### P3.1: PlayerController
**Deps:** None  
**Path:** `src/game/controllers/player_controller.gd`  

Extends CarrierController. Implements the intent accumulation pattern from A2.

**Spec:**
- `pending_intent: CarrierIntent` — mutable, built up by UI
- `add_slot_bid(planet_id: String, quantity: int, price_per_slot: float)` — appends to `pending_intent.slot_bids`
- `add_route_create(lane_id: String, origin_id: String, dest_id: String, ship_ids: Array[String], passenger_price: float, cargo_price: float)` — appends to `pending_intent.route_creates`. Frequency auto-calculated or default 1.
- `modify_route(route_id: String, ship_ids: Array[String], passenger_price: float, cargo_price: float)` — appends to `pending_intent.route_modifications`
- `cancel_route(route_id: String)` — appends to `pending_intent.route_cancellations`
- `add_ship_order(type_id: String, passenger_capacity: int, cargo_capacity: int)` — appends to `pending_intent.ship_orders`
- `add_slot_sale(planet_id: String, count: int)` — appends to `pending_intent.slot_sales`
- `clear_intent()` — resets `pending_intent` to empty
- `remove_slot_bid(index: int)`, `remove_route_create(index: int)`, etc. — let player undo pending actions
- `get_pending_summary() -> Dictionary` — returns counts of each action type for display
- `generate_intent(game_state, carrier_id) -> CarrierIntent` — override: returns `pending_intent`, resets to new empty intent
- Signal `intent_changed(intent: CarrierIntent)` — emitted on every add/remove/clear

**Validation:** Unit-test the accumulation and reset cycle. Verify `generate_intent()` returns accumulated intent and resets.

---

### P3.2: GameSetup — Player Session Factory
**Deps:** P3.1  
**Path:** `src/game/session/game_setup.gd` (modify)  

Add `create_player_session(player_controller: PlayerController, seed: int = 0) -> GameSession` that wires the player's carrier to the PlayerController and NPCs to NpcControllers.

**Spec:**
- Same as `create_default_session()` but accepts an external PlayerController instead of creating IdleController
- Player carrier ("player") gets the provided PlayerController
- NPC carriers get NpcControllers as before

**Rationale:** GameScene creates the PlayerController (so it can wire UI signals to it), then passes it to GameSetup. Clean dependency direction.

---

### P3.3: Star Map
**Deps:** None (pure visual, reads GalaxyData)  
**Paths:**
- `src/game/ui/star_map/star_map.gd`
- `src/game/ui/star_map/star_map.tscn`
- `src/game/ui/star_map/planet_node.gd`
- `src/game/ui/star_map/planet_node.tscn`
- `src/game/ui/star_map/lane_line.gd`

**Spec:**
- `star_map.gd` — Control node. `bind(game_state: GameState)` to initialize.
- Creates PlanetNode instances at hardcoded positions (A4 layout).
- Draws LaneLine instances between connected planets.
- PlanetNode: colored circle + label. Color by system (Sol=blue, AC=green, Wolf=red, Tau=yellow). Size scales with total_slots. Shows slot ownership indicators (small colored dots per carrier that has slots there).
- LaneLine: Line2D between planet positions. Color/thickness hint at demand level (optional — can be uniform for MVP).
- Signals: `planet_selected(planet_id: String)`, `lane_selected(lane_id: String, origin_id: String, dest_id: String)`.
- `refresh(game_state: GameState)` — called after each turn to update slot indicators, route visualizations.
- Route visualization: highlight lanes where the player has active routes (thicker line, player color).

**MVP scope:** Static positions, click-to-select, visual indicators for ownership. No animation, no pan/zoom.

---

### P3.4: Dashboard Panel
**Deps:** None (pure visual, reads CarrierData)  
**Paths:**
- `src/game/ui/panels/dashboard_panel.gd`
- `src/game/ui/panels/dashboard_panel.tscn`

**Spec:**
- Shows player's carrier state: cash, score, ship count, slot count, route count.
- **Fleet section:** List of ships with type, capacity split, assignment status (route name or "Idle").
- **Slots section:** List of planets where player has slots, with count.
- **Routes section:** List of active routes with lane, pricing, frequency, assigned ships.
- `bind(game_state: GameState, carrier_id: String)` — initializes.
- `refresh()` — updates all displayed values from game_state.

**Key:** This is read-only. All *actions* go through the ActionPanel. Dashboard is information display.

---

### P3.5: Action Panel — Intent Builder
**Deps:** P3.1 (PlayerController)  
**Paths:**
- `src/game/ui/panels/action_panel.gd`
- `src/game/ui/panels/action_panel.tscn`
- `src/game/ui/panels/slot_bid_form.gd`
- `src/game/ui/panels/route_form.gd`
- `src/game/ui/panels/ship_order_form.gd`

**Spec:**
- Context-sensitive: shows relevant actions based on star map selection.
  - **Planet selected:** Show "Bid on Slots" form (quantity spinner, price input). Show "Sell Slots" if player owns slots here.
  - **Lane selected:** Show "Create Route" form (ship picker, price inputs). Show existing route modifications if player has route on this lane.
  - **No selection:** Show general actions: "Order Ship" (type picker, capacity sliders).
- Each form calls the corresponding `PlayerController.add_*()` method on submit.
- **Pending Actions summary:** Shows count of queued actions ("2 bids, 1 route, 1 ship order"). Each expandable/removable.
- **Ship Order form:** Dropdown of available ship types (filtered by unlock_turn ≤ current_turn). Capacity split sliders (passenger + cargo = max_capacity). Shows cost and build time.
- **Route form:** Shows lane info (distance, demand level). Ship picker (checkboxes for available ships — filtered by range ≥ lane distance). Price inputs with suggested price displayed. Frequency auto-calculated from ship count and distance.
- **Slot Bid form:** Planet name, available slots, current occupancy. Quantity spinner (1–remaining). Price input with minimum guidance.

**Key:** Forms validate inputs before allowing submit (enough cash for bids, ships in range for routes, capacity split sums correctly). Show clear error messages.

---

### P3.6: Turn Flow & Top Bar
**Deps:** P3.1, P3.2  
**Paths:**
- `src/game/ui/top_bar.gd`
- `src/game/ui/top_bar.tscn`

**Spec:**
- **Turn counter:** "Turn {N} / 30"
- **Cash display:** "§{amount}" — updates after each turn
- **Score display:** "Score: {total}" — updates after each turn
- **Ranking indicator:** "Rank: {position}/4" — updates after each turn
- **Next Turn button:** Primary action button. Disabled during turn resolution. Click triggers:
  1. Disable button
  2. Call `session.run_next_turn()` → returns TurnResult
  3. Update all panels (star_map.refresh(), dashboard.refresh())
  4. Display turn results in TurnLogPanel + toasts
  5. Re-enable button (or show Game Over)
- **Active Events indicator:** Shows count of active events with tooltip listing them.

---

### P3.7: Turn Log Panel
**Deps:** None (pure visual)  
**Paths:**
- `src/game/ui/panels/turn_log_panel.gd`
- `src/game/ui/panels/turn_log_panel.tscn`

**Spec:**
- Scrollable VBoxContainer of turn summary blocks.
- Each block shows:
  - Turn number header
  - Revenue / costs / net change (from TurnResult.financials for player carrier)
  - Auction results (won/lost, prices paid)
  - Ship deliveries
  - Event notifications (new events, expired events)
  - Ranking change (↑↓→)
- `add_turn_result(turn_number: int, result: TurnResult, carrier_id: String)` — adds a new block.
- Auto-scrolls to latest entry.
- Color-coded: green for positive (revenue, won auctions), red for negative (costs, lost auctions), yellow for events.

---

### P3.8: Notification Toasts
**Deps:** None (pure visual)  
**Paths:**
- `src/game/ui/notifications/toast_manager.gd`
- `src/game/ui/notifications/toast_manager.tscn`

**Spec:**
- Stacking toasts in top-right corner.
- `show_toast(message: String, type: String = "info")` — types: "info", "success", "warning", "danger".
- Auto-dismiss after 3 seconds with fade-out.
- Used for: ship deliveries, auction results, event start/end, bankruptcy alerts.
- Maximum 4 visible toasts; queue additional.

---

### P3.9: Game Over Screen
**Deps:** None (pure visual)  
**Paths:**
- `src/game/ui/game_over_screen.gd`
- `src/game/ui/game_over_screen.tscn`

**Spec:**
- Full-screen overlay (semi-transparent background).
- Shows: "Game Over — Turn {N}"
- Winner announcement: "{Carrier Name} wins with score {total}!"
- Full rankings table: Rank, Carrier Name, Score breakdown (cash, ships, slots, routes).
- "Play Again" button → restarts game (new GameSession).
- If player won: congratulatory message. If player lost: their rank.

---

### P3.10: Game Scene — Main Orchestrator
**Deps:** P3.1–P3.9 (integrates everything)  
**Paths:**
- `src/game/main.gd` (replace placeholder)
- `src/game/main.tscn` (replace placeholder)

**Spec:**
- Root Control node. Replaces the current placeholder main.tscn.
- **_ready():**
  1. Create PlayerController
  2. Create GameSession via `GameSetup.create_player_session(player_controller)`
  3. Wire star_map.bind(game_state), dashboard.bind(game_state, "player"), etc.
  4. Connect star_map selection signals to action_panel context switching
  5. Connect NextTurn button to `_on_next_turn()`
- **_on_next_turn():**
  1. `var result = session.run_next_turn()`
  2. `star_map.refresh(game_state)`
  3. `dashboard.refresh()`
  4. `turn_log.add_turn_result(turn, result, "player")`
  5. `_show_turn_notifications(result)`
  6. Update top_bar (turn, cash, score, rank)
  7. If `result.game_over`: show GameOverScreen
- **Signal wiring:**
  - `star_map.planet_selected → action_panel.show_planet_actions(planet_id)`
  - `star_map.lane_selected → action_panel.show_lane_actions(lane_id, origin_id, dest_id)`
  - `player_controller.intent_changed → action_panel.refresh_pending_summary()`
  - `next_turn_button.pressed → _on_next_turn()`

---

### P3.11: UI Validation Harness
**Deps:** P3.10  
**Paths:**
- `src/validation/harnesses/ui_game_harness.tscn`
- `src/validation/scripts/harness_controllers/ui_game_harness_controller.gd`

**Spec:**
- Instantiates the full GameScene in the scene tree.
- Exposes observed state:
  - `harness_state.session_status` — "not_started" | "running" | "completed"
  - `harness_state.current_turn` — int
  - `harness_state.player_cash` — float
  - `harness_state.player_score` — float
  - `harness_state.player_routes` — count
  - `harness_state.player_ships` — count
  - `harness_state.ui_visible` — whether main UI elements are present in tree
  - `harness_state.game_over_visible` — whether game over screen is showing
- Harness operations:
  - `advance_turn` — programmatically clicks Next Turn button
  - `add_slot_bid` — calls player_controller.add_slot_bid() with params
  - `create_route` — calls player_controller.add_route_create() with params
  - `order_ship` — calls player_controller.add_ship_order() with params
- The harness drives the game through the PlayerController API, not by simulating mouse clicks. This keeps scenarios deterministic.

---

### P3.12: Validation Scenarios — UI Integration
**Deps:** P3.11  
**Paths:** `src/validation/scenarios/ui_*.json`

**Scenarios:**

1. **`ui_game_starts.json`** — Game scene loads, turn 1 is displayed, player cash is §3,000, star map shows 12 planets. Verifies the UI initializes correctly.

2. **`ui_advance_turn.json`** — Advance 5 turns with no player actions (idle). Verify turn counter increments, cash changes (slot upkeep drains it), NPCs take actions. Proves the turn flow works end-to-end through the UI.

3. **`ui_player_creates_route.json`** — Player bids on a slot, orders a ship, creates a route, advances turns. Verify the route appears in dashboard, revenue shows in turn log. Proves the intent pipeline works from PlayerController through turn resolution to UI display.

4. **`ui_full_game_completes.json`** — Play 30 turns (mix of player actions and idle turns). Game over screen appears with rankings. Proves the full game loop works through the UI layer.

5. **`ui_player_actions_reflected.json`** — After submitting intents (bid, route, ship order), verify pending actions summary shows correct counts. After turn advances, verify results reflect the submitted actions.

---

## Dependency Graph & Parallelism

```
P3.1 (PlayerController) ──── P3.2 (GameSetup mod) ─────┐
                          │                               │
P3.3 (Star Map) ──────────┤                               │
P3.4 (Dashboard) ─────────┤                               ├── P3.10 (Game Scene)
P3.5 (Action Panel) ──────┤  [needs P3.1]                │         │
P3.6 (Top Bar + Turn) ────┤  [needs P3.1, P3.2]          │         │
P3.7 (Turn Log) ──────────┤                               │    P3.11 (UI Harness)
P3.8 (Toasts) ────────────┤                               │         │
P3.9 (Game Over) ─────────┘                               │    P3.12 (Scenarios)
```

**Parallel tracks:**
- **Track A (no deps):** P3.3 (Star Map), P3.4 (Dashboard), P3.7 (Turn Log), P3.8 (Toasts), P3.9 (Game Over) — all pure visual, can be built simultaneously
- **Track B:** P3.1 (PlayerController) → P3.2 (GameSetup mod) → P3.5 (Action Panel), P3.6 (Top Bar)
- **Convergence:** P3.10 (Game Scene) wires everything together. Then P3.11 → P3.12.

**Recommended build order for a single Builder:**

1. **P3.1** — PlayerController (foundational, small)
2. **P3.2** — GameSetup modification (tiny, unblocks integration)
3. **P3.3** — Star Map (biggest visual piece, highest risk)
4. **P3.4** — Dashboard Panel (straightforward data display)
5. **P3.7 + P3.8** — Turn Log + Toasts (simple display components)
6. **P3.9** — Game Over Screen (standalone overlay)
7. **P3.5** — Action Panel (most complex UI — needs P3.1 and star map context)
8. **P3.6** — Top Bar + Turn Flow (needs P3.1, P3.2)
9. **P3.10** — Game Scene (integration — wires everything)
10. **P3.11** — UI Harness
11. **P3.12** — Validation Scenarios

**For two Builders in parallel:**
- Builder 1: P3.1 → P3.2 → P3.5 → P3.6 → P3.10 → P3.11 → P3.12 (logic + integration)
- Builder 2: P3.3 → P3.4 → P3.7 → P3.8 → P3.9 (visual components)

---

## Architectural Questions for Brady 🔥

### Q1: Should the star map use Node2D (drawn) or Control (UI widgets)?
**My position:** Node2D inside a SubViewportContainer. Planets are Area2D with collision for click detection. Lines are Line2D. This gives us pixel-level positioning and potential for future animation/zoom. Control nodes are awkward for spatial layouts.

### Q2: How much route visualization on the map?
**My position:** MVP = highlight lanes where the player has active routes (player-colored thicker line). No ship animation, no traffic flow visualization. Demand heatmap is nice-to-have but not MVP. The dashboard already shows route details — the map shows *where*, the dashboard shows *what*.

### Q3: Should action forms be inline in the side panel or modal popups?
**My position:** Inline in the side panel. Modals interrupt flow. Context-switch the side panel content based on star map selection. "Create Route" form replaces the dashboard content when a lane is selected; ESC or deselect returns to dashboard view. Keeps the player's eyes in one place.

### Q4: Do we need a separate "planning phase" before each turn?
**My position:** No. The player can queue actions at any time while viewing the current state. The "Next Turn" button is the only commit point. No explicit "plan → confirm → execute" flow. Simpler, faster, game-jam-appropriate. The pending actions summary provides enough review before committing.

### Q5: What happens if the player submits no actions for a turn?
**My position:** The turn advances normally. Player's routes keep running and earning revenue. Slots keep costing upkeep. This is fine — sometimes doing nothing is the right move. No confirmation dialog ("Are you sure you want to skip?"). Just advance.

---

## Scope Guard

### In scope (Phase 3):
- Full playable 30-turn game via UI
- Star map with planet/lane selection
- Carrier dashboard (read-only state display)
- Intent-building action panel (all 6 action types)
- Turn advancement with result display
- Game over screen with rankings
- 5 UI validation scenarios

### Out of scope (explicitly deferred):
- Planet/lane tooltips with detailed stats (nice-to-have, post-MVP)
- NPC action visibility ("Nova Transit created a route on...") — player only sees their own results + rankings
- Demand heatmap on star map
- Ship animation on routes
- Pan/zoom on star map
- Sound effects or music
- Tutorial or help text
- Undo for submitted turn (intent queue reset via "Clear All" is sufficient)
- Keyboard shortcuts (mouse-only is fine for jam)
- Save/load (DESIGN.md explicitly defers this)
- Settings menu

### Risk items:
- **Action Panel complexity:** 6 action types × context sensitivity = lots of forms. This is the highest-risk item. If time is tight, cut route modification (let players cancel + recreate instead) and slot selling (niche action).
- **Star map readability:** 12 planets + 15 lanes + 4 carriers' indicators could get cluttered. May need iteration on spacing and visual hierarchy.
- **Information overload:** The player needs to absorb a lot of state each turn. The turn log helps, but we may need to highlight "what changed" more aggressively.

---

## Definition of Done (Phase 3)

1. A human can launch the game, see the star map, and interact with all UI elements
2. A human can play a full 30-turn game making meaningful decisions (bid, route, ship, sell)
3. Turn results are displayed clearly after each "Next Turn" press
4. Game over screen shows final rankings with score breakdown
5. All 5 P3.12 UI validation scenarios pass
6. All 13 existing P1+P2 scenarios still pass (no regressions)
7. Game runs at 60fps on a mid-range machine (UI shouldn't be a bottleneck, but verify)
8. `git push origin`

---

## Estimated Effort

| Item | Size | Risk |
|------|------|------|
| P3.1 PlayerController | S | Low |
| P3.2 GameSetup mod | XS | Low |
| P3.3 Star Map | L | Medium |
| P3.4 Dashboard | M | Low |
| P3.5 Action Panel | L | High |
| P3.6 Top Bar + Turn Flow | M | Low |
| P3.7 Turn Log | M | Low |
| P3.8 Toasts | S | Low |
| P3.9 Game Over | S | Low |
| P3.10 Game Scene | M | Medium |
| P3.11 UI Harness | M | Low |
| P3.12 Scenarios | M | Low |

**Total:** ~12 work items. Heaviest items are Star Map and Action Panel. If time is tight, those two are where to cut scope (simplify map to text labels, cut route modification forms).
