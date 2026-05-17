# Decision: Route Performance Metrics via GameState.last_turn_financials

**By:** Builder
**Date:** 2026-05-19

## Context

Brady requested per-route performance metrics (pax served/capacity, cargo served/capacity, profit/loss) in the Routes modal. The financial data existed during turn processing but was discarded after `process_financials()` returned.

## Decision

Store last turn's financial result on `GameState.last_turn_financials` (set in `advance_turn()`). The routes modal reads this dictionary to display per-route metrics. The financial calculator's route summaries were enriched with `passengers_served`, `cargo_served`, `passenger_capacity`, and `cargo_capacity`.

## Rationale

- Minimal change: one new property on GameState, populated in the existing `advance_turn()` flow
- No new signals or observer patterns needed — UI reads the dictionary on refresh
- Per-route demand served uses the carrier-level demand split (since carriers typically have one route per lane/direction)
- Cleared on `initialize()` to avoid stale data across game resets

## Impact

- Routes modal shows two lines per route: config + performance metrics
- Profit colored green/red for quick visual feedback
- Simulation harness exposes `route_performance` array for validation
- New scenario `sim_route_performance_metrics` proves the pipeline end-to-end
