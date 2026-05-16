# Decision: ShipRef as Lightweight Ship Mirror

**Author:** Builder  
**Date:** 2026-05-17  
**Scope:** P1.3 — Carrier Data

## Decision
CarrierData defines its own `ShipRef` inner class with the same fields as ship_catalog.gd's `ShipInstance` (id, type_id, name, available_turn). This avoids a compile-time dependency between carrier_data.gd and ship_catalog.gd while both are being built in parallel.

## Rationale
P1.1–P1.3 are designed to be built in parallel. Importing ShipInstance from ship_catalog.gd would create a dependency that blocks parallel work. ShipRef mirrors the same fields, and P1.4 (GameState) will unify the types when it wires everything together.

## Impact
- Carrier ships and pending_orders use `ShipRef` temporarily.
- P1.4 must reconcile ShipRef with ShipInstance (likely by replacing ShipRef usage or aliasing).
