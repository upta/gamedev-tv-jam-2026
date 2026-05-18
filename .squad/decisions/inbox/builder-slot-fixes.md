# D017: Routes Consume Slots at Both Endpoints

**Decision:** Each active route consumes 1 slot at its origin and 1 slot at its destination. "Available slots" = owned - used_by_routes. Route creation and modification now check available slots, not just owned slots.

**Rationale:** Previously `has_slots_at()` only checked ownership (count > 0). A carrier with 1 slot at Mars could create unlimited routes through Mars. This broke the economic constraint that slots are meant to represent — limited port capacity. Now slots are a real bottleneck: you need available (unconsumed) slots to create new routes.

**Impact:**
- `CarrierData` gained `get_slots_used_by_routes()` and `get_available_slots_at()`
- `RouteValidator` checks available slots via `_count_routes_at_planet()` helper
- `CreateRouteModal` accounts for pending route creates when showing available slots
- UI shows "X owned, Y available" instead of just "X slots"
- NPC route creation is also constrained (same RouteValidator path)

---

# D018: ManageSlotsModal Extraction

**Decision:** Separated slot bidding/selling into a dedicated ManageSlotsModal. SlotsModal is now a read-only overview (holdings + pending actions + "Buy/Sell Slots" button).

**Rationale:** Follows the same pattern as RoutesModal→CreateRouteModal and ShipsModal→OrderShipModal. Overview modals show status; form modals handle input. Consistency across all three resource types.

**Impact:** New files: `manage_slots_modal.gd`, `manage_slots_modal.tscn`. Main.gd wires with close→open→close→reopen pattern.
