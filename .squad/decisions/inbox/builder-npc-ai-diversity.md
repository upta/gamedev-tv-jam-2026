# Decision: NPC AI Behavioral Diversity

**By:** Builder  
**Date:** 2026-05-19  
**Status:** Implemented

## Context

Playtesting revealed all NPCs behave identically: same route picks, same ship type (cheapest SD-100), price-only modifications. Personality weights existed but didn't drive meaningful strategic differences.

## Decision

Four fixes to `npc_controller.gd`:

1. **Competition-aware route scoring**: Candidates scored by `demand - competition_penalty * (1 - slot_aggression)` plus distance and jitter. Replaces fixed-order iteration.
2. **Personality-driven ship selection**: Aggressive NPCs prefer large ships, cautious prefer cheap, balanced match route needs.
3. **Route mods beyond price**: Overloaded routes can gain ships (high `route_preference`) or frequency increases. Underloaded routes reduce frequency alongside price.
4. **Per-NPC scoring jitter**: ±15% RNG variance breaks ties between identically-weighted NPCs.

## Impact

- `npc_controller.gd` expanded from ~460 to ~530 lines
- New helper: `_count_competitors_on_lane()`
- `GameTelemetry.get_turns()` accessor added for test analysis
- New test file: `test_npc_behavior_analysis.gd` (6 tests, full 30-turn simulation)
- All 293 GUT tests pass, all validation scenarios pass
- No changes to personality weight values in `game_setup.gd`
