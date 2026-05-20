# Lead — Project History

## Learnings

### Architectural Decisions (2025-07-14, approved by Brady)

1. **Route vs Lane separation:** Route = carrier's scheduled service (owned). Lane = geographic path between two planets (shared, static). Multiple carriers can operate Routes on the same Lane. This prevents confusion between the geographic concept and the business concept.

2. **Frequency model:** Integer round-trips per turn. Constrained by ship count × travel time (distance / ship speed). Short lanes allow more trips per ship; long lanes need more ships for same frequency. Keeps math simple and intuitive.

3. **Symmetric carrier model:** One `Carrier` resource, four instances. Player and NPCs are identical in data. `CarrierController` interface with `PlayerController` (UI-driven) and `NpcController` (AI-driven) implementations. No special-casing the player.

4. **Simultaneous turns, fixed pipeline:** Collect → Auctions → Routes → Ships → Demand → Financials → Events → Report. All carriers processed identically. Tie-breaking: carrier index (deterministic). No hidden advantages.

5. **GameState as single source of truth:** Central autoload owns all simulation data. Scene tree is presentation only. Turn resolution is a pure function on GameState. UI reads GameState and emits intents. Harness observes GameState directly. This makes headless testing trivial.

6. **Slots are fungible permits:** Carrier owns N slots at a planet (int). Planet has total_slots cap. Need slots at both endpoints to operate a Route. Not physical berths — abstract operating rights.

7. **Demand model — minimal but competitive:** base_demand × price_factor per lane+direction. price_factor = clamp(1.0 - (price - suggested) / suggested, 0.2, 1.5). Competition splits proportional to capacity × price_factor. Cargo and passenger are separate demand lanes, same formula. Player sees qualitative tiers (Low/Med/High), not exact numbers.

8. **Three build phases:** Phase 1 = headless sim core (all game logic, no UI). Phase 2 = full turn loop with NPCs. Phase 3 = UI shell. This ensures the game works before any human touches it.

9. **Ship capacity is permanent:** Set at order time as two integers (passenger_capacity, cargo_capacity) totaling the ship type's max_capacity. No retrofitting in prototype scope.

10. **Reports are data, not prose:** Per-route revenue breakdown (numbers). Financial summary with categories. Event notes. No causal narrative sentences — detailed labeled deltas are sufficient.

11. **Validation observability designed upfront:** harness_state exposes carriers, galaxy, demand, and signals as structured observable state. Scenarios can assert on any aspect of simulation state.

### Phase 2 Architecture (2025-07-15, proposed)

12. **Controller abstraction:** `CarrierController` base class (RefCounted) with `generate_intent(game_state, carrier_id) -> CarrierIntent`. IdleController (empty intents) and NpcController (heuristic AI) extend it. Player controller will extend it in Phase 3.

13. **NPC AI is one class, not composed strategies.** Game jam scope. Personality differences are weight tuning (`slot_aggression`, `price_offset`), not pluggable strategy objects. Refactor if needed post-jam.

14. **GameSession is RefCounted, not Node.** Owns GameState + controller map. `run_all_turns()` for headless, `run_next_turn()` for Phase 3 UI pacing. Validation harness wraps it in a Node for frame-stepping.

15. **GameState owns the RNG.** `RandomNumberGenerator` with configurable seed. Extends D004 determinism guarantee to randomized systems (events, NPC variance). Same seed → same game.

16. **GameSetup factory wires configuration.** `create_default_session()` and `create_all_npc_session()` produce ready-to-run GameSession instances. Keeps session runner separate from configuration.

17. **Two validation harnesses:** Existing `simulation_harness` stays for unit-level turn testing. New `game_session_harness` tests integrated 30-turn game loop with controllers and events.

**Key file paths (Phase 2):**
- `src/game/controllers/carrier_controller.gd` — base class
- `src/game/controllers/idle_controller.gd` — empty intents
- `src/game/controllers/npc_controller.gd` — heuristic AI
- `src/game/session/game_session.gd` — 30-turn orchestrator
- `src/game/session/game_setup.gd` — configuration factory
- `src/game/events/event_system.gd` — existing file, stub replaced
- `src/validation/harnesses/game_session_harness.tscn` — new harness
- `src/validation/scripts/harness_controllers/game_session_harness_controller.gd` — new controller

**Work items:** P2.1–P2.11 (see `.squad/decisions/inbox/lead-phase2-plan.md`)

### Phase 3 Architecture (2025-07-16, proposed)

18. **PlayerController intent accumulation.** PlayerController extends CarrierController, holds a mutable `pending_intent` that UI forms build up. `generate_intent()` returns and resets. Signal `intent_changed` lets UI show pending action summary. Same interface as NpcController — D002 symmetry preserved.

19. **No GameState autoload.** GameSession owns GameState. GameScene holds GameSession reference. UI panels receive GameState via dependency injection from GameScene, not a global autoload. Avoids class_name conflict entirely.

20. **Single-screen layout.** HSplitContainer: Star Map (left 60%) + Side Panel (right 40%). Top bar with turn counter, cash, score, Next Turn button. No scene transitions. All info visible at once.

21. **Star Map is Node2D in SubViewportContainer.** Planets as Area2D (click detection), lanes as Line2D. Hardcoded positions for 12 planets. System-colored clusters. Click-to-select drives ActionPanel context.

22. **Turn log, not modal results.** TurnResult displayed as scrollable log entries in side panel + notification toasts for critical events. No blocking overlays mid-game. Game Over is the only overlay.

23. **Context-sensitive action panel.** Side panel switches content based on star map selection: planet selected → slot bid/sell forms; lane selected → route create/modify forms; no selection → ship order form + pending actions summary.

24. **UI validation via PlayerController API.** UI harness drives the game through PlayerController methods (add_slot_bid, add_route_create, etc.), not mouse click simulation. Keeps scenarios deterministic and decoupled from visual layout.

**Key file paths (Phase 3):**
- `src/game/controllers/player_controller.gd` — intent accumulator
- `src/game/ui/star_map/star_map.gd` — star map display
- `src/game/ui/panels/dashboard_panel.gd` — carrier state display
- `src/game/ui/panels/action_panel.gd` — intent-building forms
- `src/game/ui/panels/turn_log_panel.gd` — turn results feed
- `src/game/ui/top_bar.gd` — turn counter + Next Turn button
- `src/game/ui/notifications/toast_manager.gd` — event toasts
- `src/game/ui/game_over_screen.gd` — end-game overlay
- `src/game/main.gd` — game scene orchestrator (replaces placeholder)
- `src/validation/harnesses/ui_game_harness.tscn` — UI integration harness

**Work items:** P3.1–P3.12 (see `.squad/decisions/inbox/lead-phase3-plan.md`)

### Phase 4 Architecture — UI Overhaul (2025-07-17, proposed)

25. **Full-screen star map + modal dialogs.** HSplitContainer/SidePanel layout retired. Star map fills the screen below TopBar. Dashboard, Routes, Ships, Slots, and Turn Log each become modal dialogs opened from toolbar buttons in TopBar. Contextual map-click popups deferred.

26. **Custom overlay modals, not Godot Window/PopupPanel.** ModalDialog base: full-screen Control with dim ColorRect overlay + centered PanelContainer. Works in web exports. Click-outside-to-close. `mouse_filter=IGNORE` when hidden.

27. **Toolbar wiring through GameScene.** TopBar emits `toolbar_button_pressed(name)`. GameScene toggles modals. Only one modal open at a time. Modals read GameState directly, call PlayerController methods for actions.

28. **ActionPanel retired, forms distributed.** Slot bid/sell → SlotsModal. Route create/cancel → RoutesModal. Ship order → ShipsModal. Each modal has its own planet/lane selector dropdown instead of relying on map clicks.

29. **DashboardPanel and TurnLogPanel reused inside modals.** Instanced as content children of their respective modals. Zero rewrite of display logic.

**Key file paths (Phase 4):**
- `src/game/ui/modal_dialog.gd/.tscn` — reusable modal base (new)
- `src/game/ui/modals/dashboard_modal.gd/.tscn` — dashboard in modal (new)
- `src/game/ui/modals/turn_log_modal.gd/.tscn` — turn log in modal (new)
- `src/game/ui/modals/ships_modal.gd/.tscn` — ship orders (new)
- `src/game/ui/modals/slots_modal.gd/.tscn` — slot bid/sell (new)
- `src/game/ui/modals/routes_modal.gd/.tscn` — route management (new)
- `src/game/ui/top_bar.gd/.tscn` — extended with toolbar buttons
- `src/game/main.gd/.tscn` — major rework for modal layout
- `src/game/ui/notifications/toast_manager.tscn` — mouse_filter fix

**Work items:** P4.1–P4.12 (see `.squad/decisions/inbox/lead-ui-overhaul-plan.md`)

### Economy Balance Analysis (2025-05-17, proposed)

30. **Operating cost must scale with frequency.** `(distance / efficiency) × frequency` per ship, not flat per ship. One-line fix in `financial_calculator.gd:73`.

31. **Speed-based frequency constraint.** `ship_speed = efficiency × 5.0`, `trips_per_ship = floor(speed / distance)`, `max_freq = sum(trips_per_ship)`. Changes `route_validator.gd:calculate_max_frequency()` signature to include lane distance and catalog.

32. **Price factor floor → 0.0.** At 2× suggested price, demand drops to zero. Kills the "max price" exploit. One-line fix in `demand_calculator.gd:18`.

33. **Dynamic frequency SpinBox.** `create_route_modal.gd` must recalculate max frequency when ship selection changes, not hardcode max=4.

34. **NPC frequency awareness.** `npc_controller.gd` must use calculated max frequency instead of hardcoded `frequency: 1`.

**Key file paths (Economy Balance):**
- `src/game/simulation/financial_calculator.gd` — operating cost formula (line 73)
- `src/game/simulation/route_validator.gd` — max frequency calculation (line 72-73)
- `src/game/simulation/demand_calculator.gd` — price factor clamp (line 18)
- `src/game/ui/modals/create_route_modal.gd` — frequency SpinBox (line 168)
- `src/game/controllers/npc_controller.gd` — NPC frequency hardcode (line 170)
- `.squad/decisions.md` — D009 (merged from lead-economy-balance.md)

### Economy Balance Implementation Complete (2026-05-17)

**By:** builder-economy-balance agent (background, claude-opus-4.6)

All 5 fixes implemented and deployed:
1. Cost × Frequency — operating cost now scales linearly with frequency
2. Speed-based max frequency — `ship_speed = efficiency × 5.0`, trips capped by distance
3. Price floor 0.0 — demand drops to zero at 2× suggested price
4. Dynamic frequency SpinBox — max updates when ships selected, displays "/ N" label
5. NPC frequency tuning — NPCs use `max(1, int(max_freq × route_preference))`

**Validation:**
- 242+ GUT unit tests pass (financial_calculator, demand_calculator, route_validator)
- 31+ validation scenarios pass (economy_*, price_*, frequency_*, npc_* scenarios)
- All existing scenarios remain green (no regressions)
- Code pushed to origin

**Outcome:** Game economy now balanced. Decision space opened: frequency vs. cost tradeoff, ship selection matters, pricing creates strategy, route selection tension between short (cheap, low revenue) and long (expensive, high revenue) lanes.

**Brady approval:** ✓ Proposal approved. Implementation delivered exactly as specified.

**Decision record:** D009 in `.squad/decisions.md`

### Route Creation UX Analysis (2025-07-18, proposed)

35. **Lane distances invisible until too late.** CreateRouteModal shows distance only after both planets selected AND ships assigned. Star map has zero lane interactivity — no hover, no click, no distance labels. Players can't plan ship orders without knowing lane distances first.

36. **Slot-gating hides possibility space.** Planet selector in route creation only shows planets where player owns slots. New players can't discover what routes *could* exist, preventing strategic planning ("I need slots at Proxima for an 8.2 ly route → order SD-300").

37. **Recommended fix: lane labels + browse-first explorer.** (a) Add distance labels on star map lanes (small). (b) Show all planets in route creation selector regardless of slots, gate only the Create button, show clear "need slots" messaging (medium). Skip inline ship catalog for now — one click to Ships modal is acceptable.

**Analysis document:** `.squad/decisions/inbox/lead-route-creation-ux.md`
