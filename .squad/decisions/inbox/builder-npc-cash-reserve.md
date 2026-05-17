# Decision: NPC Cash Reserve Constants

**Date:** 2026-05-17
**Author:** Builder
**Status:** Implemented

## Decision
NPCs maintain a dynamic cash reserve = max(8 turns × ongoing costs, §1200 floor). All spending (slots, ships, routes) is gated against this reserve.

## Rationale
After Phase 5 lane removal changed inter-planet distances, aggressive NPCs went bankrupt. A buffer multiplier alone wasn't sufficient because NPCs overextend in early turns when they have few obligations. The §1200 floor prevents early overexpansion.

## Constants
- `RESERVE_BUFFER_TURNS = 8` — how many turns of operating costs to keep in reserve
- `MIN_CASH_RESERVE = 1200.0` — absolute minimum cash floor (40% of starting §3000)

## Impact
- NPC_2 (Stellar Lines, slot_aggression=0.8) survives to turn 30 with §364 cash
- All other NPCs remain solvent with comfortable margins
- NPCs are more conservative overall — fewer routes/ships but no bankruptcies
