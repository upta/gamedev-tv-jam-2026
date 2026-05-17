# Economy Balance Implementation — Decision Record

**Author:** Builder  
**Date:** 2026-07-25  
**Status:** Implemented  
**Triggered by:** Lead's economy balance proposal (lead-economy-balance.md), approved by Brady.

## What Was Done

Implemented all 5 fixes from Lead's proposal exactly as specified:

1. **Operating cost × frequency** — one-line change in `financial_calculator.gd`
2. **Speed-based max frequency** — new `calculate_max_frequency` signature with backward-compat fallback. All 4 callers updated (validate_route_creation, validate_route_modification, create_route_modal, npc_controller).
3. **Price factor floor 0.0** — one-line change in `demand_calculator.gd`
4. **Dynamic frequency SpinBox** — new `_compute_max_frequency()` and `_update_frequency_max()` helpers. SpinBox updates on ship selection change. Shows "/ N" max label.
5. **NPC frequency** — `_choose_frequency()` helper uses `max(1, int(max_freq × route_preference))`. Also updated NPC reserve estimation to account for frequency in operating costs.

## Implementation Decision: NPC Reserve Estimation

The NPC controller's `_consider_route_creation` estimates operating costs to decide if a route is affordable. With Fix 1, operating cost now depends on frequency. I updated the reserve estimation to use `_choose_frequency()` so NPCs correctly predict their costs before committing. Without this, NPCs would underestimate costs and go bankrupt more often.

## Files Changed

- `src/game/simulation/financial_calculator.gd` — Fix 1
- `src/game/simulation/route_validator.gd` — Fix 2
- `src/game/simulation/demand_calculator.gd` — Fix 3
- `src/game/ui/modals/create_route_modal.gd` — Fix 4
- `src/game/controllers/npc_controller.gd` — Fix 5
- `src/tests/unit/test_financial_calculator.gd` — updated + new tests
- `src/tests/unit/test_demand_calculator.gd` — updated assertions
- `src/tests/unit/test_route_validator.gd` — updated + new tests
- `src/validation/scripts/harness_controllers/simulation_harness_controller.gd` — economy metrics
- `src/validation/scenarios/economy_*.json` — 3 new scenarios
- `DESIGN.md` — price_factor floor + frequency formula
