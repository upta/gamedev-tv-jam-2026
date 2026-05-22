# Builder Decision Inbox: Economy Rebalance

## Summary
- Monetary values are now expressed at 10x the previous scale so pricing can use finer increments without large percentage jumps.
- Operating cost now scales by `pow(distance, 1.2) * max_capacity * FUEL_COST_PER_UNIT / efficiency`, then by route frequency.

## Rationale
- The old coarse money scale made small integer changes too swingy for balancing.
- The old fuel model ignored ship size and made long routes too efficient relative to revenue.
- Capacity-aware, super-linear fuel costs create meaningful route-length and ship-selection tradeoffs.

## Impact
- Default ship prices, starting cash, slot upkeep, NPC reserves, and slot valuation all increased by 10x.
- Suggested route pricing and NPC route/bid heuristics moved to the same scale.
- Existing validation scenarios continue to pass after updating starting-cash assertions.
