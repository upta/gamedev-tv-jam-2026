# Decision: Pending Route Awareness in RouteValidator

**Author:** Builder
**Date:** 2026-05-19

## Context
Two bugs found: (1) route edit save button always disabled, (2) NPCs could over-commit slots by creating multiple routes in one turn.

## Decision
- `RouteValidator.validate_route_creation()` now accepts an optional `pending_creates` array parameter (defaults to `[]`). It counts pending creates against slot availability and marks pending ships as assigned.
- This makes the validator the single source of truth for route creation validity, regardless of whether the caller is the UI, NPC controller, or turn pipeline.
- The turn pipeline doesn't need to pass pending_creates because it commits routes sequentially (appending to `carrier.routes` before validating the next one).
- The NPC controller tracks `pending_slot_usage` locally in its route creation loop.

## Impact
- No breaking changes — the new parameter defaults to empty.
- NPC behavior may change: NPCs that were previously over-committing slots will now correctly stop when slots run out.
