# Lead — Project History

## Learnings

### Architectural Decisions (2025-07-14, approved by Brady)

1. **Route vs Lane separation:** Route = carrier's scheduled service (owned). Lane = geographic path between two planets (shared, static). Multiple carriers can operate Routes on the same Lane. This prevents confusion between the geographic concept and the business concept.

2. **Frequency model:** Integer round-trips per turn. Constrained by ship count × travel time (distance / ship speed). Short lanes allow more trips per ship; long lanes need more ships for same frequency. Keeps math simple and intuitive.

3. **Symmetric carrier model:** One `Carrier` resource, four instances. Player and NPCs are identical in data. `CarrierController` interface with `PlayerController` (UI-driven) and `NpcController` (AI-driven) implementations. No special-casing the player.

4. **Simultaneous turns, fixed pipeline:** Collect → Auctions → Routes → Ships → Demand → Financials → Events → Report. All carriers processed identically. Tie-breaking: carrier index (deterministic). No hidden advantages.

5. **GameState as single source of truth:** Central autoload owns all simulation data. Scene tree is presentation only. Turn resolution is a pure function on GameState. UI reads GameState and emits intents. Harness observes GameState directly. This makes headless testing trivial.

6. **Slots are fungible permits:** Carrier owns N slots at a planet (int). Planet has total_slots cap. Need slots at both endpoints to operate a Route. Not physical berths — abstract operating rights.

7. **Demand model — minimal but competitive:** base_demand × price_factor per lane+direction. price_factor = clamp(1.0 - (price - suggested) / suggested, 0.2, 1.5). Competition splits proportional to capacity × price_factor. Cargo and passenger are separate demand lanes, same formula. Player sees qualitative tiers (Low/Med/High), not exact numbers.

8. **Three build phases:** Phase 1 = headless sim core (all game logic, no UI). Phase 2 = full turn loop with NPCs. Phase 3 = UI shell. This ensures the game works before any human touches it.

9. **Ship capacity is permanent:** Set at order time as two integers (passenger_capacity, cargo_capacity) totaling the ship type's max_capacity. No retrofitting in prototype scope.

10. **Reports are data, not prose:** Per-route revenue breakdown (numbers). Financial summary with categories. Event notes. No causal narrative sentences — detailed labeled deltas are sufficient.

11. **Validation observability designed upfront:** harness_state exposes carriers, galaxy, demand, and signals as structured observable state. Scenarios can assert on any aspect of simulation state.
