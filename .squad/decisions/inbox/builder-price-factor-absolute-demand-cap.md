# Decision: Price Factor Now Caps Absolute Demand

**Author:** Builder  
**Date:** 2026-05-17  
**Status:** Implemented

## Context
The proportional demand split formula used `capacity × price_factor` as weights. With a single carrier on a lane, the factor cancelled out (weight/total = 1.0), so any price filled ships to capacity.

## Decision
Price factor now serves two roles:
1. **Competitive weight** (existing) — influences market share split
2. **Absolute demand cap** (new) — `demand_at_price = effective_demand × price_factor` limits passengers willing to fly at that price

The price_factor floor was also lowered from 0.2 to 0.05. At 2x+ suggested price, only 5% of demand will fly.

## Impact
- Monopolists can no longer charge extreme prices and fill ships
- Routes modal now defaults pricing to suggested values
- All existing tests updated, 3 new tests added
- All 24 validation scenarios still pass
