# Decision: Money Escrow for Player Actions

**By:** Builder  
**Date:** 2026-05-18

## Decision

PlayerController immediately deducts `carrier.cash` when the player adds slot bids or ship orders (escrow), and refunds all escrowed amounts in `generate_intent()` / `clear_intent()` before the turn pipeline processes the intent.

## Rationale

- Players see accurate available cash during the planning phase — no "phantom money" confusion
- Turn pipeline remains untouched: it still deducts for successful awards/orders as before
- Replacing a bid for the same planet correctly swaps escrow amounts (refund old, deduct new)
- Slot sales are NOT escrowed (income arrives when pipeline processes them)
- Route creates/modifications are NOT escrowed (routes are free to create; the cost is operational)

## Impact

- `PlayerController` gains `bind_carrier()`, `_escrowed` state, and helper methods
- `main.gd` must call `bind_carrier()` after session creation
- TopBar refreshes on `intent_changed` signal to show updated cash
- 10 new GUT tests covering escrow add/remove/replace/generate/clear flows
