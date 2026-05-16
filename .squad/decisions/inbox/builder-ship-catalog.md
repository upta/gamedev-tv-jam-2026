# Decision: Ship Instance ID Format

**Author:** Builder
**Date:** 2026-05-16
**Scope:** P1.2 Ship Catalog

## Decision
Ship instance IDs use the format `{type_id}-{counter}` (e.g., `sd-100-0001`). The counter is a zero-padded 4-digit integer scoped to the ShipCatalog instance.

## Rationale
- Human-readable: you can tell the ship type from the ID at a glance
- Simple and deterministic: no external UUID dependency
- Counter is per-catalog, so IDs are unique within a game session

## Trade-offs
- If catalogs are serialized/deserialized, the counter must be persisted too (or IDs will collide)
- If we ever need globally unique IDs across save files, we'd need to switch to UUIDs
