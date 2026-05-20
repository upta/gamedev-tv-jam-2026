# Route Creation UX Analysis

**Author:** Lead (Game Architect)
**Date:** 2025-07-18
**Status:** Proposed — awaiting Brian's decision
**Triggered by:** Brian's playtest feedback: "Can't tell the distance between planets so I don't know what ships to order."

---

## Current Flow Summary

### Route creation (CreateRouteModal)

1. Player opens Routes modal → clicks "Create Route" → CreateRouteModal opens.
2. **Select Origin** — opens a planet selector sub-dialog. Only planets where the player owns slots appear as selectable. Planets with no slots are shown grayed out with "No slots" label.
3. **Select Destination** — same pattern. The already-selected origin is excluded.
4. **Select Ships** — only available after both planets are chosen. Ships with insufficient range shown grayed out as "Out of range."
5. **Configure** — distance, slot availability, suggested prices, and max frequency are shown. Player sets frequency and pricing via SpinBoxes.
6. **Create** — button is disabled if no ships selected or no available slots at either endpoint.

### Where distance is visible today

- **Inside CreateRouteModal only**, at step 5 (line 205): `"Distance: X.X ly"` — but only AFTER origin + destination are both selected AND ships are assigned.
- **Star map hover panel** shows slots/demand for individual planets but **no lane distances**.
- **Star map lanes** are dumb Line2D with no hover or click — zero interactivity.
- **No lane distance labels** anywhere on the map.

### The two core problems

1. **Distance is hidden until too late.** The player must commit to an origin and destination before seeing lane distance. They need distance to decide which ships to order (ships have range constraints), but the ship ordering flow (ShipsModal → OrderShipModal) is a completely separate modal with no cross-reference to lane distances.

2. **Slot-gating hides the possibility space.** Planet selection only shows planets where the player has slots. A new player can't even browse what routes *could* exist — they can't see "Earth to Proxima is 8.2 ly, I'd need an SD-300 or better" unless they already own slots at both endpoints.

---

## Proposal A: Lane Distance Labels on Star Map

**What:** Add distance labels (e.g., "8.2 ly") on each lane line on the star map, rendered at the midpoint of each LaneLine. Optionally, show distance only on hover (lane hover detection via distance-to-line-segment math).

**Pros:**
- Lowest-effort fix. Addresses the "can't tell distance" problem directly.
- Player can visually plan routes by scanning the map before opening any modal.
- No changes to the route creation flow itself.

**Cons:**
- Doesn't solve the slot-gating problem — player still can't explore routes to un-slotted planets in the create route modal.
- 15 lanes with labels may clutter the map. Hover-only variant mitigates this but adds interaction complexity.

**Complexity:** Small
- Add distance text to `LaneLine` or render `Label` nodes at lane midpoints in `star_map.gd`.
- ~30-50 lines of code. One file (`star_map.gd`), possibly `lane_line.gd`.

**Key files:** `src/game/ui/star_map/star_map.gd`, `src/game/ui/star_map/lane_line.gd`

---

## Proposal B: Browse-First Route Explorer (Brian's Idea)

**What:** Decouple planet *browsing* from slot *requirement*. The planet selector in CreateRouteModal shows ALL planets (not just slotted ones). After selecting any origin+destination pair, the modal shows:
- Lane distance
- Required ship range
- Which ships in your fleet can serve it
- Whether you have slots at both endpoints (and how many)

The "Create" button remains disabled if slots are missing, but now shows a clear message: "Need slots at [Planet X] to create this route." Optionally, a "Buy Slots" shortcut button that opens the SlotsModal pre-filtered to the needed planet.

**Pros:**
- Solves both problems: distance visibility AND possibility-space browsing.
- Player can plan ahead: "I want Earth→Proxima, so I need to bid for Proxima slots and order an SD-300."
- Natural information flow: explore → plan → acquire prerequisites → execute.
- The "Buy Slots" shortcut creates a smooth multi-step workflow without leaving context.

**Cons:**
- Medium effort — planet selector logic changes, validation messaging needs work.
- Planet list gets longer (12 planets instead of 2-4), needs good visual grouping (by system).
- Risk of confusion: "Why can I select this planet but can't create the route?" Needs clear UI messaging.

**Complexity:** Medium
- Modify `_open_planet_selector()` in `create_route_modal.gd` to show all planets, with slot status as metadata rather than a gate.
- Add a "missing slots" warning + optional shortcut in the details section.
- Add ship range summary info when only origin+dest are selected (before ship selection).
- ~80-120 lines changed across 1-2 files.

**Key files:** `src/game/ui/modals/create_route_modal.gd`, possibly `src/game/ui/modals/manage_slots_modal.gd` (for pre-filtered open)

---

## Proposal C: Route Planner with Ship Catalog Reference

**What:** Combine Proposal B with an inline ship catalog reference panel inside the route creation flow. After selecting origin+destination, show a compact table of ship types that can serve this lane (range ≥ distance), with their cost, build time, and capacity. This replaces the need to open ShipsModal separately to figure out what to order.

**Pros:**
- Full information loop in one place: pick planets → see distance → see which ships work → see costs → decide whether to commit.
- Most complete solution to Brian's feedback.
- Reduces modal-hopping between Routes and Ships screens.

**Cons:**
- Largest effort of the three.
- CreateRouteModal becomes more complex — risk of information overload in a single modal.
- Ship catalog data is already in OrderShipModal; duplication concern (mitigated by reading from `GameState.catalog` directly).

**Complexity:** Medium-Large
- Everything from Proposal B, plus a new ship catalog summary section in the details area.
- Ship catalog section needs to respect unlock turns (don't show ships that aren't available yet).
- ~120-180 lines changed, all in `create_route_modal.gd`.

**Key files:** `src/game/ui/modals/create_route_modal.gd`

---

## Recommendation

**Do A + B together.** Complexity is still Medium overall.

- **A (lane labels on map)** is cheap and immediately useful even outside route creation. Players should always be able to glance at the map and see distances. This is a "should have had it from the start" fix.

- **B (browse-first explorer)** directly addresses Brian's core frustration. The slot-gating on the planet selector was a premature constraint — it optimized for preventing errors at the cost of preventing discovery. Let the player explore freely, gate only the final action.

- **Skip C for now.** The ship catalog reference is nice-to-have but risks scope creep. The player can open the Ships modal in a separate step — it's one click away from TopBar. If playtesting reveals that modal-hopping is still painful, revisit C later.

### Implementation order
1. A first (small, independent, no risk).
2. B second (medium, touches route creation flow, needs validation scenarios).

### Validation impact
- A: New scenario asserting lane labels are visible and show correct distances.
- B: Existing `ui_create_route` scenarios will need updates. New scenarios for: browsing un-slotted planets, slot-missing warning display, "Create" button disabled state with correct messaging.
