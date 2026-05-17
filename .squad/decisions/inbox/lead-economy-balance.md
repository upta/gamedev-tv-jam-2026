# Economy Balance Fix — Decision Proposal

**Author:** Lead (Game Architect)  
**Date:** 2026-05-17  
**Status:** Proposed  
**Triggered by:** Brady's report — game is trivially winnable with "max price, max frequency, wait" strategy.

---

## Problem Summary

Four compounding bugs collapse the decision space to a single dominant strategy:

1. **Operating cost doesn't scale with frequency.** Cost is `distance / efficiency` per ship, not per trip. Frequency 4 costs the same as frequency 1. More trips = free revenue.
2. **Max frequency ignores travel time.** `calculate_max_frequency()` returns `ship_ids.size()` — no distance constraint. DESIGN.md specifies "constrained by ship count and travel time (distance / ship speed)" but the implementation skips travel time entirely.
3. **Price factor floor of 0.05 is too generous.** Even at absurd prices you serve 5% of demand. As the only carrier on a lane, 5% × huge price = profit.
4. **Frequency SpinBox is hardcoded 1–4.** UI doesn't reflect actual max frequency from ships selected.

Combined effect: create one route on a short lane (Earth–Mars, d=1.44), max price, max frequency, click Next Turn 30 times → win. No decisions required.

---

## Fix 1: Operating Cost Scales with Frequency

**Current:** `total_cost += lane.distance / ship_type.efficiency` (per ship, flat)

**Proposed:** `total_cost += (lane.distance / ship_type.efficiency) * route.frequency` (per ship, per trip)

Each round-trip costs fuel. More trips = more fuel. This is the single most impactful fix.

**Where:** `financial_calculator.gd` line 73

```gdscript
# Before
total_cost += lane.distance / ship_type.efficiency

# After
total_cost += (lane.distance / ship_type.efficiency) * route.frequency
```

**Impact example (Earth–Mars, SD-100):**
- Freq 1: cost = 1.44/0.8 × 1 = §1.80/ship
- Freq 4: cost = 1.44/0.8 × 4 = §7.20/ship (was §1.80)

---

## Fix 2: Speed-Based Frequency Constraint

**Current:** `calculate_max_frequency()` returns `ship_ids.size()` — every ship adds 1 frequency.

**Proposed:** Derive `speed` from efficiency, then:

```
ship_speed = efficiency × 5.0
trips_per_ship = floor(ship_speed / lane_distance)  # min 1 if in range
max_frequency = sum of trips_per_ship across all assigned ships
```

**Where:** `route_validator.gd` — `calculate_max_frequency()` needs the lane distance and catalog.

New signature: `calculate_max_frequency(ship_ids, carrier, catalog, lane_distance) -> int`

**Why `efficiency × 5.0`?** This constant produces the right gameplay spread:

| Ship | Efficiency | Speed | Earth–Mars (1.44) | Earth–Titan (2.12) | Inter-system (7.28) | Long haul (10.5) |
|------|-----------|-------|-------------------|-------------------|---------------------|------------------|
| SD-100 Shuttle | 0.8 | 4.0 | 2 trips/ship | 1 trip/ship | — | — |
| SD-300 Freighter | 0.5 | 2.5 | 1 | 1 | 1 (if in range) | — |
| FW-10 Scout | 1.0 | 5.0 | 3 | 2 | 1 | 1 |
| SD-500 Cruiser | 0.6 | 3.0 | 2 | 1 | 1 | 1 |
| FW-50 Hauler | 0.3 | 1.5 | 1 | 1 | — | — |
| FW-70 Express | 1.2 | 6.0 | 4 | 2 | 1 | 1 |
| SD-900 Titan | 0.4 | 2.0 | 1 | 1 | 1 | 1 |

This creates real differentiation: the FW-70 Express (high efficiency, moderate capacity) is the frequency king. The SD-900 Titan (massive capacity, low efficiency) is a one-trip-per-turn beast. Players choose between "many small trips" and "one big haul."

**Note:** No new `speed` stat on ShipType needed. `efficiency × 5.0` is a derived constant inside `calculate_max_frequency`. If we later want speed as an independent stat, it's a trivial refactor.

---

## Fix 3: Steeper Price Sensitivity

**Current:** `clampf(1.0 - (price - suggested) / suggested, 0.05, 1.5)` — floor at 5%.

**Proposed:** `clampf(1.0 - (price - suggested) / suggested, 0.0, 1.5)` — floor at 0%.

At price ≥ 2× suggested, demand = 0. No passengers will pay double the going rate. This kills the "max price" exploit dead.

**Where:** `demand_calculator.gd` line 18

```gdscript
# Before
return clampf(1.0 - (price - suggested_price) / suggested_price, 0.05, 1.5)

# After
return clampf(1.0 - (price - suggested_price) / suggested_price, 0.0, 1.5)
```

Also update DESIGN.md to match (currently says 0.05).

**Design rationale:** The interesting pricing decision is between suggested price (factor 1.0, full demand) and slightly above (factor 0.7–0.9, reduced demand but higher per-unit revenue). The sweet spot should be around 1.2–1.4× suggested. Going above 2× should be suicidal, not "slightly less optimal."

---

## Fix 4: Dynamic Frequency SpinBox

**Current:** `_create_label_spinbox("Flights per Month:", 1, 4, 1, 1)` — hardcoded max 4.

**Proposed:** After ship selection changes, recalculate max frequency and update the SpinBox max.

**Where:** `create_route_modal.gd`

1. When `_selected_ship_ids` changes (in `_open_ship_selector` callback and `select_ships`), recalculate `RouteValidator.calculate_max_frequency(...)`.
2. Set `_freq_spin.max_value` to the calculated max.
3. Clamp `_freq_spin.value` to new max if it exceeds it.
4. Display the max next to the spinbox: "Flights per Month: [spin] / {max}"

**Builder note:** The `_rebuild_route_details` method currently creates the SpinBox before ships are selected, so max starts at 0 (no ships). After ships are picked, call a helper to update the SpinBox max. If no ships selected, disable the SpinBox entirely.

---

## Fix 5: NPC Controller Updates

The NPC controller (`npc_controller.gd` line 170) hardcodes `"frequency": 1`. After Fix 2, NPCs should use `calculate_max_frequency` to set a reasonable frequency (e.g., use 50–75% of max based on `route_preference`).

**Where:** `npc_controller.gd` around line 168

---

## What Makes Decisions Interesting Now

With these fixes, the decision space opens up:

1. **Frequency vs. cost tradeoff.** More trips = more revenue but linearly more operating cost. On short lanes with fast ships, high frequency is efficient. On long lanes, each extra trip is expensive.

2. **Ship selection matters.** The FW-70 Express can do 4 trips on Earth–Mars but only carries 60. The SD-900 Titan does 1 trip but carries 200. Which is better? Depends on demand volume and competition.

3. **Pricing is a real lever.** Below suggested = more demand share in competition. Above suggested = higher margins but rapidly falling demand. The 0% floor means there's a hard ceiling where greed kills you.

4. **Route selection creates tension.** Short lanes are cheap to operate but low revenue per trip. Long lanes have high suggested prices but ships are slow (fewer trips) and expensive to run.

---

## Implementation Order

1. **Fix 1 (cost × frequency)** — One line change, biggest impact. Do first.
2. **Fix 3 (price floor 0.0)** — One line change, kills price exploit.
3. **Fix 2 (speed-based frequency)** — Moderate change, affects route_validator + callers.
4. **Fix 4 (dynamic SpinBox)** — UI-only, depends on Fix 2.
5. **Fix 5 (NPC frequency)** — AI update, depends on Fix 2.

Each fix should include validation scenarios proving the behavior change. Specifically:
- Scenario: operating cost increases linearly with frequency.
- Scenario: demand drops to 0 at 2× suggested price.
- Scenario: max frequency is speed-limited, not just ship-count-limited.
- Scenario: frequency SpinBox max updates when ships are selected (UI harness test).

---

## Constants Summary

| Constant | Current | Proposed | Location |
|----------|---------|----------|----------|
| Speed multiplier | N/A | `efficiency × 5.0` | `route_validator.gd` |
| Price factor floor | 0.05 | 0.0 | `demand_calculator.gd` |
| Price factor ceiling | 1.5 | 1.5 (unchanged) | `demand_calculator.gd` |
| Freq SpinBox max | 4 (hardcoded) | dynamic from `calculate_max_frequency` | `create_route_modal.gd` |
| Op cost formula | `dist/eff` per ship | `(dist/eff) × freq` per ship | `financial_calculator.gd` |
