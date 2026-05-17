# Decision: Dynamic Lane Topology

**Date:** 2026-05-18  
**Author:** Builder  
**Status:** Implemented

## Decision
Lanes are no longer pre-defined in `GalaxyData`. Any planet can connect to any other. `get_lane()` creates Lane objects dynamically using Euclidean distance from 2D planet positions. `derive_lane_id()` generates canonical IDs in `"alpha::beta"` format (alphabetical sort).

## Impact
- **DemandData** now has 132 entries (66 unique pairs × 2 directions) instead of 30
- **Route.lane_id** is always derived from origin/dest — never passed as a parameter
- **NpcController** iterates all slot-planet pairs instead of `galaxy.lanes`
- **EventSystem** targets random planet pairs instead of random lanes
- **UI files** (`star_map.gd`, `routes_modal.gd`, `debug_state_saver.gd`) still reference `galaxy.lanes` — will break at runtime until updated
- **Game balance** has shifted — some seeds produce earlier bankruptcies

## Rationale
Enables free-form galaxy topology where route decisions are unconstrained. Foundation for Phase 5 star map and route UI rework.
