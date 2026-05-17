# D017: Ship Order Modal Extraction

**Decision:** Extracted the "Order New Ship" form from ShipsModal into a dedicated OrderShipModal, following the same parent→child modal pattern used by RoutesModal→CreateRouteModal.

**Pattern:**
- ShipsModal shows fleet overview + pending orders + "Order Ship" button
- OrderShipModal contains the full order form (type dropdown, capacity spinboxes, stats, order button)
- main.gd wires: `order_ship_requested` → close ships modal, open order modal; `closed` → reopen ships modal

**Rationale:** Consistent modal architecture across the UI. All "create/order" flows use the same pattern: overview modal with action button → dedicated form modal. Keeps overview modals focused on display, form modals focused on input.

**Impact:**
- New files: `order_ship_modal.gd`, `order_ship_modal.tscn`
- ShipsModal reduced from 263 to ~147 lines
- New validation: `ui_order_ship_flow.json` scenario + `ui_order_ship_harness_controller.gd`
- main.gd updated with signal wiring (matches create route pattern exactly)
