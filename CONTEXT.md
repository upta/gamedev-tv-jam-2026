# Astrobiz

A galactic transportation empire builder — airline management simulator set across multiple solar systems in ~2250.

## Language

**Carrier:**
One of four competing transportation companies (player + 3 NPCs), identical in rules and structure.
_Avoid:_ airline, company, player (when meaning the entity)

**Route:**
A carrier's scheduled transport service between two planets, with assigned ships, pricing, and frequency.
_Avoid:_ path, connection, line, service

**Lane:**
A static, shared geographic path between two planets with a fixed distance. Multiple carriers can operate Routes on the same Lane.
_Avoid:_ route (for the geographic path), link, edge

**Slot:**
A fungible operating permit at a planet. A carrier must own slots at both endpoints to operate a Route. Acquired via auction, finite per planet.
_Avoid:_ gate, berth, permit, license

**Frequency:**
Integer round-trips per turn on a Route. Constrained by ship count and travel time (distance / ship speed). Short lanes allow more trips per ship; long lanes need more ships for the same frequency.
_Avoid:_ trips, runs, schedule

**Planet:**
A location node on the star map. Has a name, belongs to a solar system, and has a total slot cap.
_Avoid:_ station, port, node

**Ship:**
A transport vessel with fixed passenger/cargo capacity split (set at order time), range, and efficiency. Assigned to Routes or held in inventory.
_Avoid:_ vessel, craft, vehicle

**Turn:**
One month of game time. All carriers act simultaneously; resolution follows a fixed pipeline.
_Avoid:_ round, tick, cycle

**GameState:**
The central autoload that owns all simulation data. Scene tree is presentation only. Turn resolution is a pure function on GameState.
_Avoid:_ world, game manager, singleton

**Intent:**
A carrier's declared actions for the upcoming turn (route changes, bids, ship orders). Collected before turn resolution.
_Avoid:_ action, command, order (as a general term)

## Relationships

- A **Lane** connects exactly two **Planets** (bidirectional path)
- A **Route** operates on exactly one **Lane**, owned by exactly one **Carrier**
- A **Carrier** may operate multiple **Routes** on different **Lanes** (or the same **Lane**)
- A **Slot** belongs to one **Planet**; a **Carrier** owns zero or more **Slots** at each **Planet**
- A **Route** requires **Slots** at both its origin and destination **Planets**
- A **Ship** is assigned to at most one **Route** at a time
- **Frequency** is a property of a **Route**, constrained by its assigned **Ships** and **Lane** distance
- **Demand** is per **Lane** + direction, split between **Passenger** and **Cargo**

## Example Dialogue

> **Dev:** "Can two carriers fly the same lane?"
> **Domain expert:** "Yes — the **Lane** is shared geography. Each carrier creates its own **Route** on that **Lane** with its own pricing and frequency. Demand splits between them based on capacity and price."

> **Dev:** "What happens when a carrier cancels a route?"
> **Domain expert:** "The **Route** is removed. Assigned **Ships** return to inventory. **Slots** are retained — they're permits at the **Planet**, not tied to a specific **Route**."

> **Dev:** "How does frequency work?"
> **Domain expert:** "**Frequency** is round-trips per **Turn**. A fast **Ship** on a short **Lane** can make multiple trips. A slow **Ship** on a long **Lane** might not even complete one. You increase **Frequency** by assigning more **Ships** or using faster ones."

## Flagged Ambiguities

- "route" was used to mean both the geographic path and the scheduled service — **resolved:** Route = scheduled service, Lane = geographic path.
- "order" is overloaded — ship purchase order vs. carrier intent — **resolved:** use "ship order" for purchases, "intent" for turn actions.
- "slot" could imply a physical berth — **resolved:** Slots are abstract fungible permits, not physical locations.

## Debug State Snapshot

Press **F12** or click the **💾** button in the TopBar to save a full game state snapshot to disk.

- **Godot path:** `user://debug_state.json`
- **Windows OS path:** `%APPDATA%/Godot/app_userdata/My Prototype/debug_state.json`
- **Contents:** current turn, all carrier data (cash, ships, routes, slots, pending orders, score), galaxy topology (planets + lanes), player's pending intent, active events.
- **Usage:** AI agents can read this file to inspect the full game state during debugging sessions. The file is overwritten on each save.
- **Git:** `debug_state.json` is in `.gitignore` — never committed.
