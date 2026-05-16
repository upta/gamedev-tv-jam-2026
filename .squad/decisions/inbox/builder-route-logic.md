# Decision: Simplified Frequency Model

**Date:** 2026-05-17  
**Author:** Builder  
**Context:** P1.5 Route Logic  

## Decision

Each ship assigned to a route contributes exactly 1 round-trip per turn, regardless of lane distance or ship efficiency. `max_frequency = number of assigned ships`.

## Alternatives Considered

- **Speed-based frequency:** `trips_per_ship = max(1, floor(efficiency / (2.0 * distance)))` — more realistic but adds complexity without clear gameplay payoff at prototype stage.

## Rationale

For the prototype, the interesting strategic decision is *how many ships to assign* to a route, not micro-optimizing frequency via ship speed. This keeps the mental model simple: more ships = more trips = more capacity. Ship efficiency can be repurposed later for operating cost calculations (P1.8) where it already has a clear role.

## Impact

- `calculate_max_frequency()` is trivially `ship_ids.size()`
- Frequency clamping is straightforward: `min(requested, ship_count)`
- If we want speed-based frequency later, only `calculate_max_frequency` needs to change
