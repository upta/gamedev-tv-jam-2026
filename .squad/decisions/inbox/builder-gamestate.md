# Decision: Type Unification — ShipRef Removed

**Author:** Builder  
**Date:** P1.4 (GameState autoload)  
**Status:** Implemented

## Decision

Removed `ShipRef` inner class from `CarrierData`. Ships are now stored as `ShipCatalog.ShipInstance` directly. The `create_default_carriers()` factory now accepts a `ShipCatalog` parameter and uses `catalog.create_ship_instance()` to create proper starting ships.

## Rationale

- Eliminates parallel type hierarchy (ShipRef vs ShipInstance)
- Starting ships now reference real catalog type `sd-100` instead of nonexistent `"basic"`
- Ship instances get proper IDs from the catalog's ID generator
- Capacity split (20 passenger / 20 cargo = 40 max) is validated by the catalog

## Impact

- `CarrierData.create_default_carriers()` signature changed: now requires a `ShipCatalog` argument
- Any code calling `create_default_carriers()` must pass a catalog (currently only used in setup)
- `ShipRef` class no longer exists — all ship references are `ShipCatalog.ShipInstance`
