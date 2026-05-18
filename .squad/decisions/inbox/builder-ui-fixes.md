# UI Fixes Decision Record

## Planet Radius Formula Change

**Decision:** Reduced planet radius from `12 + slots*2` to `8 + slots*1.2`. Slot dot radius from 4px to 3px. Map padding from 60 to 100.

**Rationale:** Large planets (10 slots = 32px radius) were crowding the star map and obscuring labels. New formula keeps proportional differentiation (4-slot ≈ 13px, 10-slot = 20px) while giving more breathing room.

**Impact:** Visual-only. No gameplay logic affected. All validation scenarios still pass.

## Route Details Section Gating

**Decision:** Route creation details (pricing/frequency/create button) now require ships to be selected, not just origin+dest.

**Rationale:** Showing pricing controls before ship selection was confusing — frequency depends on ships and was always 0. Now shows "Select ships to configure route" hint until ships are chosen.

**Impact:** Programmatic API `select_ships()` now triggers `_rebuild_route_details()`. All existing validation scenarios pass unchanged.

## Star Map Hover Panel

**Decision:** Added a floating info panel on planet hover showing name, system, slot ownership, route count, and demand tier.

**Rationale:** Players needed at-a-glance planet info without clicking. Panel is positioned near the planet and clamped to viewport edges.

**Impact:** New UI element, no existing behavior changed. Uses `mouse_entered`/`mouse_exited` signals on PlanetNode's Area2D.
