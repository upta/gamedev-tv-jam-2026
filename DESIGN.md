# Astrobiz

> Build a galactic transportation empire across multiple star systems — an airline management simulator where every route, ship, and slot bid is a readable decision against three NPC rivals, all racing for market leadership by turn 30.

## Target Player
Strategy/tycoon fans who enjoy **readable decision-making** — players who loved the route economics of Mini Motorways, the competitive tension of Offworld Trading Company, or the fleet management of something like Airline Tycoon. They want to see the consequences of their choices play out clearly, not buried in opaque systems.

## Core Fantasy
The satisfaction of building a transportation network that *clicks* — connecting the right planets, pricing routes shrewdly, timing ship orders to match demand, and outmaneuvering rivals who are doing the same thing. You should feel like a savvy executive, not a spreadsheet operator.

## Unique Angle
Most tycoon games bury decisions in complexity. Astrobiz keeps the decision space small (routes, ships, slots, pricing) but makes every choice *legible* — you can see why you're winning or losing. The 30-turn fixed length creates urgency: there's no turtling. You must expand or die.

## Reference Points
- **Offworld Trading Company** — competitive market pressure, simultaneous turns, readable economy
- **Mini Motorways** — spatial network building, route optimization, clean visual language
- **Airline Tycoon** — fleet management, route economics, slot scarcity

## Core Loop
The player **reviews** the galaxy state (demand, competitors, finances), **decides** actions for the turn (bid on slots, create routes, order ships, adjust pricing), then **advances** the turn to see results — which reveals new opportunities and threats, motivating the next round of decisions.

### Player Actions
| Action | Input | Effect |
|--------|-------|--------|
| Bid on Slots | Select planet, set bid price and quantity | Blind auction — highest bidder wins operating permits at a planet |
| Create Route | Select lane, assign ships, set passenger/cargo prices | Begins transport service on a lane, earning revenue from demand |
| Modify Route | Adjust ships, pricing, or frequency on existing route | Tunes revenue vs. cost tradeoff |
| Cancel Route | Select active route to cancel | Ships return to inventory, slots retained |
| Order Ship | Select ship type, set passenger/cargo capacity split | Ship arrives after build time; capacity is locked at order time |
| Sell Slots | Select planet, choose quantity | Frees up dead capital at planets you've abandoned |
| Advance Turn | Click "Next Turn" | Resolves all actions simultaneously, shows results |

### Rules & Numbers

**Galaxy**
- 4 star systems: Sol (4 planets), Alpha Centauri (3), Wolf 359 (3), Tau Ceti (2) — 12 planets total
- 15 lanes connecting planets: intra-system (distance 1–3) and inter-system (distance 5–15)
- Each planet has a fixed slot cap (3–10 slots)

**Carriers**
- 4 carriers: 1 player + 3 NPCs, all identical in rules (D002)
- Starting cash: §30,000
- Starting assets: 1 shuttle (SD-100), 1 slot at each of 2 home planets
- Home systems: Player (Sol/Earth+Mars), NPC1 (Alpha Centauri), NPC2 (Sol/Titan+Europa), NPC3 (Wolf 359)

**Ships** (7 types, 2 manufacturers)
| Type | Manufacturer | Range | Capacity | Efficiency | Cost | Build Time | Unlocks |
|------|-------------|-------|----------|------------|------|------------|---------|
| SD-100 Shuttle | Sol Dynamics | 5 | 40 | 0.8 | §5,000 | 2 turns | Turn 0 |
| SD-300 Freighter | Sol Dynamics | 8 | 80 | 0.5 | §12,000 | 3 turns | Turn 0 |
| FW-10 Scout | Frontier Works | 10 | 20 | 0.6 | §2,500 | 2 turns | Turn 0 |
| SD-500 Cruiser | Sol Dynamics | 12 | 120 | 0.6 | §20,000 | 4 turns | Turn 8 |
| FW-50 Hauler | Frontier Works | 6 | 150 | 0.3 | §18,000 | 4 turns | Turn 12 |
| FW-70 Express | Frontier Works | 10 | 60 | 1.2 | §15,000 | 3 turns | Turn 16 |
| SD-900 Titan | Sol Dynamics | 15 | 200 | 0.4 | §40,000 | 5 turns | Turn 20 |

- Capacity split (passenger vs. cargo) is set at order time and locked
- Ships with range < lane distance cannot serve that lane
- Efficiency affects operating cost: cost per ship = (distance^1.2 × capacity × fuel_rate / efficiency) × frequency, where fuel_rate = 3.0. Bigger ships and longer routes burn proportionally more fuel; high-efficiency ships offset this.

**Slots & Auctions**
- Slots are fungible operating permits at a planet
- A route requires slots at both endpoints
- Blind auction: all bids submitted simultaneously, highest price wins, ties broken by carrier index
- Slot upkeep: §100 per slot per turn
- Slots can be sold back (freed) if no active routes depend on them

**Demand & Revenue**
- Demand is per (lane, direction) — passenger and cargo are independent
- When multiple carriers serve the same (lane, direction), demand splits by (capacity × price_factor)
- Price factor: `clamp(1.0 - (price - suggested_price) / suggested_price, 0.0, 1.5)`
- Price factor also caps absolute demand served — high prices reduce the number of willing travelers, not just competitive market share.
- Suggested price: `(distance / 0.6) × 15.0` for passengers, `× 0.5` for cargo
- Cargo has ~3× the demand volume of passengers but thinner margins — strategic choice between premium passenger routes (fewer travelers, higher per-unit revenue) and volume cargo routes (need large-capacity ships to capture)
- Revenue = passengers_served × passenger_price + cargo_served × cargo_price
- Service quality: total flight frequency on a lane unlocks more of the available demand — `min(1.0, 0.6 + 0.1 × total_freq)`. A single freq-1 route captures only 70% of demand; freq 4+ unlocks 100%

**Frequency**
- Integer round-trips per turn on a route
- Constrained by ship count and travel time: `ship_speed = efficiency × 5.0`, `trips_per_ship = floor(speed / lane_distance)` (min 1)
- `max_frequency = sum of trips_per_ship` across all assigned ships
- Short lanes allow more trips per ship; long lanes need more ships for the same frequency

**Events** (4 types, random)
- 25% chance per turn, no events before turn 3, max 2 concurrent
- Demand Surge: +30–50% on a random lane, 2–4 turns
- Demand Slump: -20–40% on a random lane, 2–3 turns
- Gold Rush: +50% cargo demand at a planet's lanes, 3 turns
- Tourism Boom: +40% passenger demand at a planet's lanes, 3 turns

**Turn Pipeline** (8-step resolution order)
1. Deliver — pending ships that have completed build time enter fleet
2. Auctions — resolve all slot bids simultaneously
3. Routes — cancellations, modifications, then creations
4. Ships — process new ship orders
5. Slot Sales — process slot releases
6. Financials — calculate revenue, operating costs, slot upkeep, apply to cash
7. Events — generate new events, apply modifiers, tick durations
8. Report — calculate rankings, check for bankruptcy/game-over

**Scoring**
- Score = cash + ship_assets (purchase cost) + slot_value (§2,000/slot) + route_value (5× estimated revenue)
- Estimated revenue uses 50% fill rate assumption

### Win / Lose
- **Win:** Highest composite score at turn 30
- **Lose:** Go bankrupt (cash ≤ §0 at end of any turn) — eliminated from competition
- **Game Over:** Turn 30 reached OR any carrier goes bankrupt

### Difficulty
- NPCs have tunable personality weights (slot_aggression, route_preference, ship_eagerness)
- 3 distinct NPC personalities: balanced (0.5), aggressive (0.8/0.7/0.6), cautious (0.3/0.4/0.4)
- All carriers share Earth as a starting planet (forcing early competition) plus one unique second planet
- NPC pricing strategies vary widely by personality: aggressive undercuts deeply (×0.73), balanced is moderate (×0.85), cautious prices premium (×0.93)
- Cautious NPCs prefer fuel-efficient ships; aggressive NPCs prefer high-capacity ships
- Ship catalog unlocks create a natural tech progression curve
- Events add unpredictability mid-game (no events in first 2 turns for ramp-up)

## Prototype Scope

### In
1. Star map with 4 systems / 12 planets / 15 lanes
2. Route creation, modification, and cancellation
3. Ship catalog with 7 types and tech progression (unlock turns)
4. Ship ordering with build time and capacity split
5. Blind slot auction system
6. Slot selling
7. Directional demand model (passenger + cargo)
8. Competitive demand splitting between carriers
9. Financial calculator (revenue, operating costs, slot upkeep, bankruptcy)
10. Composite score calculator
11. 30-turn game loop with simultaneous resolution
12. 3 NPC opponents with heuristic AI and personality tuning
13. Random event system (4 event types)
14. 8-step deterministic turn pipeline
15. Turn-by-turn UI with paced play (advance button)

### Out (explicitly deferred)
1. Multiplayer
2. Save/load
3. Ship upgrades or retrofitting
4. NPC diplomacy or negotiation
5. Multiple galaxy maps
6. Difficulty settings (beyond NPC personality weights)
7. Sound and music
8. Tutorial or onboarding flow
9. Ship naming or cosmetic customization

### Art Direction
Minimal, clean UI — colored nodes on a star map, panels for carrier dashboard, tables for financials. Placeholder-quality visuals. Focus is on information clarity, not aesthetics. Think "readable spreadsheet with a map", not "pretty space game."

### Target Session
A full 30-turn game should take **5–10 minutes** to play through. Each turn decision should take 15–30 seconds.

## Open Questions & Risks
- **Demand balance:** Base demand values may need tuning after playtesting — if routes are always profitable or always unprofitable, the decision space collapses
- **NPC competitiveness:** Heuristic AI may be too passive or too aggressive — personality weights are tunable but untested against a human player
- **Event impact:** Events may be too disruptive or too mild — modifier ranges may need adjustment
- **Late-game stagnation:** If all lanes are saturated by turn 20, the last 10 turns may feel empty — may need late-game mechanics or escalation

## Proof Point
**Decisions feel meaningful and players want to experiment.** After a 30-turn game, the player should be able to point to 2–3 decisions that mattered ("I should have expanded to Wolf 359 earlier", "my cargo pricing was too high on that lane") and immediately want to try a different strategy. If the game produces meaningless or identical outcomes regardless of player choices, the prototype has failed.
