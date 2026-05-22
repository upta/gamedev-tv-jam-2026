# Decision: Soft Bankruptcy (Elimination Without Game Over)

**Author:** Builder
**Date:** 2025-07-27
**Status:** Applied

## Context
DESIGN.md states "any carrier goes bankrupt → game over." In practice, an NPC going bankrupt on turn 4-5 would end the game abruptly and feel unfair to the player.

## Decision
Bankrupt carriers are **eliminated** (routes disabled, pending orders cleared, NPC controller already returns empty intent when cash ≤ 0) but the **game continues until turn 30**. The bankrupted carrier stays on the scoreboard with whatever score they had at elimination.

## Rationale
- Better gameplay: player doesn't lose because an NPC overspent early
- The carrier is effectively dead — no routes, no ships incoming, no actions
- Scoreboard still shows them so the player can see what happened
- Player bankruptcy is still meaningful — they can't recover either, but the game continues so they see final standings

## Deviation from DESIGN.md
This softens the "any bankruptcy = game over" rule. DESIGN.md should be updated to reflect elimination semantics.
