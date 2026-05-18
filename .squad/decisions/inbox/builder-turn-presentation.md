# Decision: Turn Presentation System Architecture

**Date:** 2026-05-18
**By:** Builder
**Status:** Implemented

## Decision

Turn results are now shown via a full-screen presentation overlay (`TurnPresentationOverlay`) driven by pure data from `TurnSummaryBuilder`. The overlay:
- Shows each NPC's turn actions one at a time (5s auto-advance, skippable with Escape)
- Then shows a detailed player summary (routes with pax/cargo served, financials, events)
- Stays until player clicks Continue or presses Enter/Escape

## Key Design Choices

1. **TurnSummaryBuilder is pure data** — no UI, no scene references. Receives TurnResult + GameState + pre-turn snapshots, returns Dictionary of CarrierTurnSummary objects. Unit-testable.

2. **Presentation skipped in test-mode** — `_on_next_turn()` checks `OS.get_cmdline_user_args().has("--test-mode")` and skips the await. This keeps all validation scenarios working without modification.

3. **Toast notifications removed from turn flow** — The `_show_turn_notifications()` call is no longer invoked during `_on_next_turn()`. The presentation overlay covers all the information toasts used to show. Toast system remains available for other uses.

4. **Pre-turn snapshot pattern** — `cash_before` dict and `prev_financials` (from `game_state.last_turn_financials`) are captured BEFORE `run_next_turn()` so the summary can show before/after deltas.

## Impact

- `main.gd` `_on_next_turn()` is now async (uses `await`)
- New files: `turn_summary_builder.gd`, `turn_presentation_overlay.gd/.tscn`
- `main.tscn` has new CanvasLayer node for the overlay
- All 258 GUT tests pass, all 31+ validation scenarios pass
