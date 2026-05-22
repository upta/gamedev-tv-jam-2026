# Builder History

## Recent Sessions

### Session: Shared Earth Starts + NPC Competition Rebalance (2026-05-22)

**Deliverables:**
1. **Shared Earth starts:** Updated default carriers so all NPCs start with Earth plus one unique home planet, forcing immediate overlap around the core hub.
2. **NPC strategy spread:** Widened route pricing, increased route-choice jitter, added personality-based starting frequency, and made cautious ship orders lane-aware so they buy efficient ships that can actually unlock new routes.
3. **Demand accessibility:** Added lane service-quality scaling so low-frequency service only unlocks part of the demand pool while higher frequency exposes more total demand.
4. **Validation refresh:** Expanded starting-state validation coverage for the new slot layout and relaxed the mid-game carrier-activity scenario to assert broad route activity instead of every NPC being live by turn 10.
5. **Welcome overlay check:** Verified the player-facing starting-slots copy still reads correctly and left it unchanged.

**Decision:** Validation should measure broad route activity at mid-game rather than require every NPC to be active by turn 10, because the cautious carrier now ramps through long-range expansion. See `.squad/decisions/inbox/builder-route-activity-validation.md`.

**Files changed:** `carrier_data.gd`, `npc_controller.gd`, `demand_calculator.gd`, `test_carrier_data.gd`, `test_demand_calculator.gd`, `test_npc_controller.gd`, `sim_initial_state.json`, `session_all_carriers_active.json`, `simulation_harness_controller.gd`, `game_session_harness_controller.gd`

**Testing:** Headless launch clean. GUT unit suite passes. Full validation suite passes.

---

### Session: Scoreboard UI Cleanup + Scoring Fixes + Bankruptcy (2025-07-27)

**Deliverables:**
1. **Game over screen cleanup:** Simplified winner text ("You win!" / "X wins!"), added column widths/right-alignment for numeric columns, § formatting on all values, muted header row, spacer between header and data, player row highlighting, larger Play Again button with styled padding, VBox spacing.
2. **Removed score from top bar:** Deleted `ScoreLabel` node + `VSeparator2` from `top_bar.tscn`, removed `_score_label` onready + score calculation + color styling from `top_bar.gd`.
3. **Removed score from dashboard:** Dashboard header now shows `Name | §cash` instead of `Name | §cash | Score: N`. Uses `FormatHelpers.format_cash()`.
4. **Standings panel shows rank:** Replaced raw score number with `#N Name` format. Removed score label column entirely.
5. **FormatHelpers utility:** Extracted cash formatting to `FormatHelpers.format_cash()` static class for reuse across UI scripts.
6. **Bankruptcy elimination:** Bankrupt carriers now have routes disabled and pending orders cleared. NPC controller already returns empty intent. Game continues until turn 30 (soft bankruptcy — see decision doc).
7. **Bankruptcy toast fix:** Shows carrier display name instead of raw ID.

**Decision:** Soft bankruptcy — eliminated carriers stay on scoreboard but game doesn't end (deviates from DESIGN.md). See `.squad/decisions/inbox/builder-bankruptcy-soft.md`.

**Files changed:** `game_over_screen.gd`, `game_over_screen.tscn`, `top_bar.gd`, `top_bar.tscn`, `dashboard_panel.gd`, `scoreboard_panel.gd`, `turn_pipeline.gd`, `main.gd`, `format_helpers.gd` (new)

**Testing:** Headless launch clean. GUT tests pass. 42/42 validation scenarios pass.

---

### Session: Economy Rebalance — Monetary Scale & Fuel Costs (2026-05-22)

**Deliverables:**
1. **10x economy scale:** Starting cash, default ship costs, slot upkeep, slot UI bid defaults, score slot value, suggested route prices, and NPC price/bid heuristics all moved to the new §10x scale.
2. **Operating cost rebalance:** Route fuel cost now scales with `distance^1.2`, ship `max_capacity`, and efficiency via `FUEL_COST_PER_UNIT`, making long routes and inefficient ships materially riskier.
3. **Validation updates:** Updated `sim_financials` and `ui_game_starts` expectations to §30000, refreshed economy-aligned unit fixtures, and updated the welcome overlay to show the new starting cash.
4. **Protected-doc note:** `DESIGN.md` is now stale on starting cash, ship prices, and slot value, but was left untouched per project protection rules.

**Testing:** Headless launch clean. GUT unit suite passes. Full validation suite passes.

---

### Session: Star Map Visual Polish (2025-07-26)

Three visual fixes to the star map:
1. **Route z-ordering**: Replaced fragile `move_child` hack with `z_index = -1` on route Line2Ds. Planets (z_index 0) now always render on top. Also set LaneLine `z_index = -2`.
2. **Label outlines**: Added black outline (size 3) to planet name labels via theme overrides for readability when routes pass underneath.
3. **Desaturated system colors**: Muted planet system colors (steel-blue, sage, dusty rose, khaki) so they don't compete with carrier route colors.

Files changed: `star_map.gd`, `planet_node.gd`, `lane_line.gd`. All validation scenarios pass. 3 pre-existing GUT failures (separator theming, ship name casing) unrelated.

### Session: UI Display Name Cleanup (2025-07-25)

**Deliverables:**
1. **Fixed turn log financials** — revenue/costs always showed $0 because keys were `revenue`/`costs` instead of `total_revenue`/`total_costs`
2. **Resolved raw IDs to display names** across 10 files: ship type_ids show catalog names (e.g. "Scout FW-10"), lane_ids show "Origin → Dest", route_ids show planet names, planet_ids show display names
3. **Files changed:** turn_log_panel, turn_log_modal, main, dashboard_panel, ships_modal, pending_actions_panel, turn_summary_builder, turn_presentation_overlay, create_route_modal, routes_modal
4. **Approach:** Added helper methods (`_get_ship_name`, `_get_planet_name`, `_resolve_route_display`) to each file, passed GameState to turn_log_panel via turn_log_modal for catalog/galaxy access

**Commit:** `8a7ed14` — all validation scenarios pass, GUT tests pass, clean headless launch

### Session: Star Map Context Menu (2026-05-22)

**Deliverables:**
1. **Right-Click Context Menu on StarMap:** Click planet → shows context menu with "Buy Slots" button
2. **Button States:** "Buy Slots" (enabled when slots available), "No Slots" (disabled when all slots owned)
3. **Dismissal Behavior:** Left-click anywhere or click outside → dismisses menu
4. **Signal Wiring:** Context menu button emits `slot_purchase_requested(planet_id)` signal connected in main.gd to open manage_slots_modal
5. **Hover Panel Integration:** Hover panel hides while context menu visible

**Files changed:** `star_map.gd`, `manage_slots_modal.gd`, `main.gd`

**Testing:** Headless launch clean. All tests pass. No regressions.

**Commit:** bb3d62b

---

### Session: Planet Selection Guide Line (2025-07-19)

**Deliverables:**
1. **Guide Line on StarMap:** Click a planet to enter guide mode — draws a dashed line from origin to cursor. Snap to hovered planets. Second click emits `route_requested` signal. Empty space or same-planet click cancels.
2. **Distance in Hover Panel:** When guide is active and hovering a non-origin planet, shows "Distance X.X ly" row below demand.
3. **CreateRouteModal.open_with_planets():** Pre-selects origin and destination planets when opening from star map guide.
4. **GameScene wiring:** Connects `route_requested` → opens CreateRouteModal with pre-selected planets (or edits existing route on same lane). Cancels guide mode on toolbar press.
5. **Harness controller update:** Exposes `guide_origin_id`, `guide_snap_planet_id`, `guide_active`, `last_route_requested_origin`, `last_route_requested_dest`, `route_request_count` for validation.

**Files changed:** `star_map.gd`, `create_route_modal.gd`, `main.gd`, `star_map_harness_controller.gd`

**Testing:** Headless launch clean. 308 passing, 2 pre-existing separator test failures (unrelated).

**Notes:** `planet_selected` signal kept declared but no longer emitted — guide mode fully replaces old single-click selection.

---

### Session: Three UI Fixes — Icons, Hover Panel, Ship Cards (2026-05-18b)

**Deliverables:**
1. **Icon Revert:** Restored `pax_bb()`/`cargo_bb()`/`fuel_bb()` to use `[img]` BBCode via `icon_bb()`. The Unicode glyph approach was a mistake — SVG icons work everywhere except the hover panel.
2. **Hover Panel Fix:** Rewrote `_on_planet_hovered()` in `star_map.gd` to use programmatic RichTextLabel API (`add_text()`, `push_color()`, `add_image()`) instead of string BBCode. Textures loaded once in `_build_hover_panel()`.
3. **Ship Card Restyle:** Replaced ad-hoc rows with a `GridContainer` (4 columns) for tabular stats. Labels muted, values white. No pax icon on "Capacity" (it's generic). Select button stays bottom-right.

**Testing:** 308 passing, 2 pre-existing separator test failures (unrelated).

**Status:** Code pushed to origin.

---

### Session: Icon Fix & Order Ship Modal Redesign (2026-05-18)

**Deliverables:**
1. **Icon Fix:** Replaced broken SVG `[img]` BBCode tags with colored Unicode glyphs (● pax, ◼ cargo, ◆ fuel). Added `ThemeBuilder.load_icon_texture()` for TextureRect usage.
2. **Order Ship Modal Redesign:** Two-step card-based flow — Step 1 browses all ship types as styled cards, Step 2 customizes capacity/quantity. Programmatic harness API preserved.

**Testing:** 308 passing, 2 pre-existing separator test failures (unrelated).

**Status:** Code pushed to origin.

---

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

### SVG BBCode Broken → Unicode Glyphs (2026-05-18)

- Godot's `[img=WxH]res://path.svg[/img]` BBCode renders broken rectangles for SVGs. Root cause: SVG import rasterization size mismatch with display size, and CompressedTexture2D handling in BBCode.
- **Correction (2026-05-18b):** The Unicode glyph approach was reverted. SVG `[img]` tags actually work fine in most RichTextLabels — the only failure was the hover panel in `star_map.gd`. Fix: use programmatic RichTextLabel API (`add_image()` with pre-loaded ImageTexture) for that one panel, keep `[img]` BBCode everywhere else.
- `pax_bb()` / `cargo_bb()` / `fuel_bb()` restored to return `[img=NxN]path[/img]` via `icon_bb()`.
- For TextureRect usage (spinbox icon rows), `ThemeBuilder.load_icon_texture()` loads SVG, gets Image, resizes, returns ImageTexture.

### Hover Panel: Programmatic RichTextLabel API (2026-05-18b)

- When `[img]` BBCode fails in a specific RichTextLabel, use the programmatic API: `clear()`, `push_bold()`, `add_text()`, `push_color()`, `pop()`, `add_image()`, `newline()`.
- `add_image(texture, width, height)` works with in-memory ImageTextures (unlike `[img]` BBCode which needs file paths).
- Pre-load icon textures once (member variables) to avoid per-hover allocation.

### Ship Card GridContainer Layout (2026-05-18b)

- `GridContainer` with `columns = 4` gives clean tabular stat layout: [label][value][label][value] per row.
- Use `custom_minimum_size.x = 80` on both label and value cells for consistent column widths.
- "Capacity" is generic (not pax-specific) — don't use pax icon for it.
- Labels in MUTED color, values in default TEXT (white).

- SVGs must be imported by Godot before `load()` works — run `--import --quit` or open the editor to generate `.import` files for new SVGs.
- Inline icons in RichTextLabel use `[img=WxH]res://path[/img]` BBCode syntax. 14x14 works well for inline text-sized icons.
- `ThemeBuilder.make_icon_label()` creates a pre-configured RichTextLabel (bbcode_enabled, fit_content, no scroll) for icon+text labels.
- When adding a TextureRect before a Label in an HBoxContainer, child indices shift — use `get_child(count - 1)` instead of hardcoded index to find the SpinBox.
- For selection list items that mix plain text and BBCode, added `use_bbcode` flag to item dictionaries and conditionally render RichTextLabel vs Label.

### Selection Popup Theming & Ship Build Timing (2026-05-25)

- Popups added via `get_tree().root.add_child()` don't inherit any theme from the scene tree. Must assign `ThemeBuilder.build_theme()` directly to the popup's PanelContainer so children (labels, buttons, separators) pick up themed styles.
- Ship build off-by-one: formula was `current_turn + build_turns` but ships aren't usable until the turn AFTER delivery. Changed to `current_turn + build_turns - 1` so "Build: N turns" matches the number of planning turns the player actually waits.

### Duplicate Route Blocking & Efficiency Ratings (2026-05-25)

- `GalaxyData.derive_lane_id()` is the canonical way to compare lanes regardless of direction — use it to detect duplicate routes by comparing against `carrier.routes[].lane_id` and pending `route_creates`.
- `ShipType.get_efficiency_rating()` added as instance method (not static) since it reads `self.efficiency`. Thresholds: A≥1.0, B≥0.7, C≥0.5, D≥0.35, E<0.35.
- Duplicate route check intentionally skipped in edit mode (`_edit_mode == true`) — editing an existing route on the same lane is valid.

### ThemeBuilder on CanvasLayer Overlays (2026-05-24)

- CanvasLayer nodes don't inherit parent themes. Must explicitly set `ThemeBuilder.build_theme()` on a child container (MarginContainer) so descendants pick up fonts/colors.
- Pattern: set theme in `_ready()`, apply per-node overrides for title (SpaceGrotesk-Bold + ACCENT), hints (MUTED), and accent buttons (StyleBoxFlat with ACCENT border + darkened bg).
- Overlay background color uses SURFACE RGB with custom alpha in the `.tscn` literal since `Color()` in scene files can't reference constants.
- Same pattern used by WelcomeOverlay and now TurnPresentationOverlay.

### Centralized Carrier Colors (2026-05-22)

- **Single source of truth**: `ThemeBuilder.CARRIER_COLORS` dictionary in `src/game/ui/theme_builder.gd`. Player=ACCENT teal-green, NPC1=muted coral, NPC2=soft lavender-blue, NPC3=warm amber.
- `star_map.gd` and `planet_node.gd` now alias `ThemeBuilder.CARRIER_COLORS` instead of defining their own (previously divergent) copies.
- `scoreboard_panel.gd` `_create_row()` takes `carrier_id` parameter to look up per-carrier color for both the ● indicator and name label.
- Color design principle: desaturated hues that belong in the dark sci-fi palette. Player is brightest (ACCENT), NPCs are muted but distinguishable.

### Per-Turn Game Telemetry (2026-05-19)

- `GameTelemetry` (`src/game/utils/game_telemetry.gd`): RefCounted instance on `GameSession`, not static. Accumulates per-turn snapshots of intents, results, and post-turn carrier state. Saves to `user://game_telemetry.json`.
- Avoids type annotations on `result` parameter (TurnResult) to prevent circular dependency — `GameState.advance_turn()` already returns untyped for the same reason.
- Reuses `DebugStateSaver` serialization patterns (ships, routes, events) but keeps its own copies since telemetry is instance-based (not static).
- `record_turn()` called in `GameSession.run_next_turn()` right after `advance_turn()` returns — captures post-turn state including updated cash and scores.
- `save_to_file()` called from `GameScene._save_debug_state()` alongside `DebugStateSaver.save()`.
- Tests in `src/tests/unit/test_game_telemetry.gd` — 5 tests covering record/clear/save/intents/state_after.

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

### NPC AI Behavioral Diversity (2026-05-19)

- **Competition-aware routing**: `_count_competitors_on_lane()` checks all carriers' active routes. Score = `demand - competition * penalty * (1 - slot_aggression)`. Aggressive NPCs tolerate crowded lanes; cautious NPCs avoid them.
- **Candidate scoring replaces fixed iteration**: Route candidates are scored by demand, competition, distance, and personality jitter (±15% from `game_state.rng`). Sorted descending, top N picked. Eliminates deterministic same-pick problem.
- **Personality-driven ship selection**: `ship_eagerness >= 0.7` → sort by capacity desc (bigger ships). `<= 0.35` → sort by cost asc (cheapest). Middle → match to route needs (range for long routes, cost for short).
- **Route modifications beyond price**: Overloaded routes (avg_load > 0.85) now trigger ship additions (if `route_preference >= 0.5` and available ships exist) and frequency increases. Underloaded routes reduce both price and frequency.
- **Diagnostic testing pattern**: `GameSetup.create_all_npc_session(seed)` + `session.run_all_turns()` + `telemetry.get_turns()` provides full 30-turn intent/state history for behavioral assertions without needing scene tree.
- Added `get_turns() -> Array` to `GameTelemetry` to expose `_turns` for test analysis.

### Route Edit & Pending Slot Bugs (2026-05-19)

- **Edit mode save button fix**: `_update_create_button_state()` in `create_route_modal.gd` counted the editing route's own slot usage against availability, making the Save button permanently disabled. Fix: add back +1 for each endpoint matching the editing route's origin/dest.
- **Pending slot tracking in RouteValidator**: `validate_route_creation()` now accepts `pending_creates: Array = []` parameter. Counts pending route creates against slot availability at both endpoints, and marks ships from pending creates as assigned. This makes the validator correct regardless of caller (UI, NPC, pipeline).
- **NPC controller slot tracking**: `_consider_route_creation()` now maintains a `pending_slot_usage` dictionary, incrementing per-planet counts as routes are added to the intent. Prevents NPCs from over-committing slots when creating multiple routes in one turn.
- **Test update**: `test_npc_creates_multiple_routes` was asserting the buggy behavior (2+ routes with only 1 slot per planet). Updated to give 2 slots per planet so 2 routes are legitimately possible.
- Added 4 unit tests for `pending_creates`: origin slot blocking, dest slot blocking, allowing with sufficient slots, and ship reuse prevention.

### UI Theme: Space Control Room Polish (2026-05-20)

- **ThemeBuilder** (`src/game/ui/theme_builder.gd`): Static class with color palette constants and `build_theme()` factory. Colors: SURFACE (#1A1A26), BORDER (#343B52), TEXT (#E8EEF7), ACCENT (#6EC8FF), POSITIVE/NEGATIVE/WARNING for states. Styles for Button, PanelContainer, ScrollBar, HSeparator, RichTextLabel.
- **Fonts**: Downloaded Inter (regular/bold) for body/data, SpaceGrotesk (bold) for headings from official GitHub repos. Placed in `src/assets/fonts/`. Updated `project.godot` gui/theme/custom_font to Inter-Regular.
- **Background**: Set rendering/environment/defaults/default_clear_color to #14161C in project.godot.
- **Toolbar icons**: Downloaded 5 Tabler Icons (MIT) SVGs (layout-dashboard, route, rocket, grid-dots, list) to `src/assets/icons/`. Updated `TOOLBAR_BUTTONS` constant in `top_bar.gd` to include icon paths. `_create_toolbar_buttons()` loads icons and assigns to buttons.
- **StarMap hover panel**: Updated `_build_hover_panel()` to use `ThemeBuilder.SURFACE` and `ThemeBuilder.BORDER` instead of hardcoded colors.
- **Theme application**: `main.gd` calls `theme = ThemeBuilder.build_theme()` in `_ready()` before any other setup, propagating the theme to all child controls.
- Headless launch test passed — no script errors. All pushed to origin.

### OptionButton, PopupMenu, SpinBox Theme Styling (2026-05-20)

- **OptionButton** reuses Button's `btn_normal/hover/pressed/disabled` styleboxes and font colors for visual consistency. Arrow icon set to null (Godot uses built-in fallback), `arrow_margin` set to 8.
- **PopupMenu** uses `MODAL_SURFACE` background with `BORDER` outline. Hover items get an `ACCENT.darkened(0.75)` background with `ACCENT` font color. Separator styled to match HSeparator. Item padding 8px on both sides.
- **SpinBox styling** achieved via **LineEdit** theme entries (SpinBox wraps a LineEdit internally). Normal state: light SURFACE bg + BORDER. Focus state: ACCENT border. Caret and selection colors use ACCENT.
- The SpinBox up/down buttons inherit from Button theme automatically — no separate styling needed.
- Key insight: Godot's SpinBox doesn't have its own theme type — it delegates to LineEdit for the text field and Button for the arrows. Styling those two covers SpinBox completely.

### Scoreboard Panel & Top Bar Cleanup (2026-05-22)

- Removed Rank and Events labels from `top_bar.gd/.tscn` — cleaner header with just Turn, Cash, Score + toolbar.
- `ScoreboardPanel` (`src/game/ui/scoreboard_panel.gd` + `.tscn`) builds UI programmatically (no scene-tree dependencies). Uses `ScoreCalculator.get_rankings()` for data.
- Panel overlaid on star map as child of `VBoxContainer/StarMap` node in `main.tscn`. Positioned top-left with absolute offsets (16px padding). `mouse_filter = IGNORE` so clicks pass through to star map.
- Semi-transparent `SURFACE` bg (alpha 0.85) with `BORDER` outline. Player row: filled circle indicator `●` in `ACCENT`. Other carriers: dim `○`. Scores in `MUTED`.
- `.uid` files for new scripts are generated by `--headless --editor --quit` (not by `--headless --quit`). The editor scan registers the file and writes the uid.
- Scoreboard `refresh()` called alongside `_top_bar.refresh()` in `_on_next_turn()` and `_on_intent_changed_refresh_top_bar()`.

