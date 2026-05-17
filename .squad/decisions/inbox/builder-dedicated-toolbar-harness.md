# Decision: Dedicated harness controllers per UI concern

**By:** Builder  
**Date:** 2026-05-17  

## Context
Bug 5 required a validation scenario for toolbar modal toggling. The existing `ui_game_harness_controller.gd` drives turn-advance actions at fixed physics steps and is shared by 7+ scenarios.

## Decision
Created a separate `ui_toolbar_harness_controller.gd` that only drives modal open/close at known steps, rather than adding modal toggling to the shared harness.

## Rationale
- Keeps existing scenarios deterministic — no risk of modal state interfering with turn-based assertions
- Each harness controller has a single responsibility
- New toolbar scenarios can evolve independently without affecting game-flow scenarios

## Impact
New files: `ui_toolbar_harness_controller.gd`, `ui_toolbar_harness.tscn`, `ui_toolbar_clickable.json`
