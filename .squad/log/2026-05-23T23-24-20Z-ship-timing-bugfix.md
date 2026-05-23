# Session: Ship Arrival Timing Bug Fix (2026-05-23T23:24:20Z)

## Problem
Ships showed up a turn after their promised arrival in the UI, despite the simulation working correctly.

## Root Cause
`ShipInstance.available_turn` is the turn when the Deliver pipeline step fires. The player's planning phase happens BEFORE the pipeline, so a ship with `available_turn = N` is delivered during turn N but only usable starting turn N+1's planning.

UI displayed `available_turn` directly without the +1 offset.

## Solution
Display `available_turn + 1` in both UI locations (`ships_modal.gd`, `dashboard_panel.gd`).

## Changes
- `src/game/ui/modals/ships_modal.gd` — Updated pending ship ready turn
- `src/game/ui/panels/dashboard_panel.gd` — Updated pending ship display

## Verification
✅ Headless launch clean  
✅ GUT tests pass  
✅ 42/43 validation scenarios pass  

## Decisions Added
- **D029: Ship Availability Turn Display**

