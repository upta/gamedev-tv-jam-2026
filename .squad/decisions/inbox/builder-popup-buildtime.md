# Decision: Ship Build Time Formula

**Date:** 2026-05-25
**Author:** Builder
**Status:** Implemented

## Context

Ship build time formula was `current_turn + build_turns`, but ships are delivered during turn resolution (step 1 of turn_pipeline) and aren't usable until the NEXT planning phase. This made "Build: 2 turns" effectively cost 3 planning turns.

## Decision

Changed formula to `current_turn + build_turns - 1`. A ship ordered on turn T with build_turns=N is delivered during turn T+N-1 resolution, making it usable starting turn T+N planning — exactly N planning turns after ordering.

## Impact

- `ship_catalog.gd`: Formula change
- `ships_modal.gd`: Label changed from "Ready turn" to "Delivered turn" for clarity
- Unit test updated to expect new value
- All 308 passing tests unaffected (2 pre-existing separator test failures unrelated)
