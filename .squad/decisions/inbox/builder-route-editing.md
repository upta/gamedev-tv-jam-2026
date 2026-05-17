# D017: Route Editing via Dual-Mode Modal

**Decision:** The CreateRouteModal serves double duty as create and edit modal rather than building a separate EditRouteModal. Edit mode is controlled by `_edit_mode` flag and `_editing_route` reference.

**Key constraints in edit mode:**
- Origin and destination are displayed but NOT editable (changing endpoints = cancel + create new)
- Ships, frequency, and pricing ARE editable
- Ships currently assigned to the route are included in the available ship pool
- "Cancel Route" action moves inside the edit modal (bottom, red-styled)

**Rationale:** Reusing the same modal avoids UI duplication and keeps the form-building logic in one place. The mode flag cleanly separates behavior without complex inheritance. Route endpoint changes are intentionally blocked because changing origin/dest fundamentally creates a different route (different lane, different demand market).

**Impact:** RoutesModal "Cancel Route" button replaced with "Edit" button. Cancel route is now a secondary action inside the edit view. Pending route modifications displayed in RoutesModal pending actions section.
