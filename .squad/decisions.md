# Architectural Decisions

## Grilling Session — 2026-05-16T23:11:53Z
**Source:** Lead agent design grilling + Brady approval  
**Plan:** lead-implementation-plan.md

---

### D001: GameState as Single Source of Truth
**Decision:** GameState is the centralized, mutable data store for all game simulation state. All game logic is isolated from the scene tree; turn resolution is a pure function that consumes GameState and CarrierIntents and produces TurnResult.

**Rationale:** Decouples UI/presentation from core game logic. Enables deterministic replay, automated testing, and easy NPC integration.

**Impact:** Core simulation code has zero dependencies on Godot scene nodes.

---

### D002: Carrier Identity is Symmetric
**Decision:** Player and NPC carriers are identical Carrier data structures. Identity is expressed only through the controller (PlayerController vs NPCController). All simulation logic treats carriers uniformly.

**Rationale:** Eliminates special-case logic for different carrier types. Simplifies testing and reduces bugs.

**Impact:** Player and NPC share identical game rules, balance, and capabilities.

---

### D003: Lanes are Shared, Routes are Owned
**Decision:** A Lane is a geographic path (planet → planet, bidirectional, owned by the galaxy). A Route is a carrier's scheduled service on a lane (directional, owned by the carrier). Multiple carriers can own routes on the same lane.

**Rationale:** Separates topology (fixed) from competition (dynamic). Enables lane-level demand calculation without carrier knowledge.

**Impact:** Demand tables are keyed by (lane_id, direction); routes are keyed by (carrier_id, lane_id, direction).

---

### D004: Simultaneous Turns with Deterministic Ordering
**Decision:** All carriers execute in a single turn. Intents are collected from all carriers, then the turn pipeline processes them in a deterministic order (tie-breaking by carrier index). Results are generated atomically.

**Rationale:** Prevents cascading state changes during a turn. Ensures fairness — no carrier gains advantage by turn order.

**Impact:** Replay is deterministic given the same intents and RNG seed.

---

### D005: Demand is Directional and Competitive
**Decision:** Each (lane, direction) has independent passenger and cargo demand. When multiple carriers service the same (lane, direction), demand is split by (capacity × price_factor). Higher-capacity or lower-price carriers capture more demand.

**Rationale:** Creates competition without complex bidding. Player/NPC strategy depends on route pricing and ship selection.

**Impact:** Revenue is proportional to service quality (price_factor and capacity match).

---

### D006: Inner Classes for Galaxy Data Structures
**Decision:** Use inner classes (`Planet`, `Lane`) inside `GalaxyData` rather than separate Resource subclasses in their own files.

**Rationale:** Planet and Lane are pure data containers with no behavior. They are never used independently. Single-file approach keeps topology definition self-contained.

**Impact:** GalaxyData is the single source of truth for galaxy topology.

---

### D007: Ship Instance ID Format
**Decision:** Ship instance IDs use format `{type_id}-{counter}` (e.g., `sd-100-0001`). Counter is zero-padded 4-digit integer scoped to ShipCatalog instance.

**Rationale:** Human-readable, simple, deterministic. No external UUID dependency. Unique within game session.

**Impact:** ShipInstance IDs are easily debuggable; counter must be persisted if catalogs are serialized.

---

### D008: ShipRef as Lightweight Ship Mirror
**Decision:** CarrierData defines its own `ShipRef` inner class mirroring `ShipInstance` fields (id, type_id, name, available_turn). Avoids compile-time dependency while P1.1–P1.3 are built in parallel.

**Rationale:** Enables parallel development of galaxy_data.gd, ship_catalog.gd, and carrier_data.gd. P1.4 (GameState) will unify types.

**Impact:** Temporary duplication until P1.4 unification. Carrier ships and pending_orders use ShipRef temporarily.

---

## Work Order & Phases

**Phase 1:** Headless simulation core (12 work items, P1.1–P1.12)  
**Phase 2:** Full 30-turn game loop + NPC AI  
**Phase 3:** UI shell  

See lead-implementation-plan.md for full specification.
