# Decision: Duplicate Route Prevention & Efficiency Ratings

**Author:** Builder  
**Date:** 2026-05-25  

## Duplicate Route Prevention

**Decision:** A carrier cannot create a new route on a lane where they already have an active route or a pending route create. The Create button is disabled with a message directing the player to edit the existing route instead.

**Rationale:** Multiple routes on the same lane adds confusion without strategic depth. Players should adjust existing routes rather than stacking duplicates.

**Scope:** Create mode only — edit mode is exempt since you're modifying the existing route on that lane.

**Implementation:** Checks `carrier.routes[].lane_id` and `_player_controller.pending_intent.route_creates` using `GalaxyData.derive_lane_id()` for canonical comparison.

## Ship Efficiency Ratings

**Decision:** Ship efficiency (float 0.3–1.2) is surfaced to players as a letter grade (A–E) via `ShipType.get_efficiency_rating()`. Shown in Order Ship modal (dropdown + stats line) and Create Route modal ship selector.

**Rating Scale:** A ≥ 1.0, B ≥ 0.7, C ≥ 0.5, D ≥ 0.35, E < 0.35.

**Rationale:** Efficiency affects operating cost and speed but was invisible to players. Letter grades communicate relative quality without exposing raw floats.
