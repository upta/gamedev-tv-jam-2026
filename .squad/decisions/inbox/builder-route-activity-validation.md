# Builder Decision: Route Activity Validation

## Context
All carriers now start with an Earth slot, but the cautious NPC's unique home lane is longer-range and ramps more slowly than the aggressive and balanced carriers.

## Decision
Validate mid-game route health using aggregate activity metrics instead of requiring every NPC to have an active route by turn 10.

## Why
- The design goal is shared-lane competition and strategic diversity, not identical timing across personalities.
- The cautious carrier now prioritizes efficient, range-capable expansion and can be intentionally later to market.
- Aggregate route-activity checks are more stable and still catch regressions where the session stalls.

## Validation Impact
- `session_all_carriers_active.json` now waits slightly longer and asserts broad route activity.
- Harness metrics expose `carriers_with_active_routes` and `npcs_with_active_routes` to support that check.
