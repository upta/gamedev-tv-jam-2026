class_name NpcController
extends CarrierController

## Heuristic AI that generates meaningful intents for NPC carriers.
## Jam scope: good enough to be interesting, not optimal.
## One class with tunable weights — no strategy pattern.

# Personality weights control intensity, not probability of acting
var slot_aggression: float = 0.5    # 0.0 = 1 conservative bid, 1.0 = 3 aggressive bids
var route_preference: float = 0.5   # 0.0 = few expensive routes, 1.0 = many cheap routes
var ship_eagerness: float = 0.5     # 0.0 = only when all deployed, 1.0 = proactive ordering


const RESERVE_BUFFER_TURNS: int = 4
const MIN_CASH_RESERVE: float = 5000.0
const SLOT_GRACE_PERIOD: int = 5

# Ephemeral state (persists across turns on the same controller instance)
var _slot_bid_turns: Dictionary = {}       # planet_id -> turn when last bid was placed
var _route_loss_streak: Dictionary = {}    # route_id -> consecutive unprofitable turns
var _route_created_turn: Dictionary = {}   # route_id -> turn when route was created


func generate_intent(game_state: GameState, carrier_id: String) -> TurnPipeline.CarrierIntent:
	var intent := TurnPipeline.CarrierIntent.new()
	intent.carrier_id = carrier_id

	var carrier := game_state.get_carrier(carrier_id)
	if carrier == null:
		return intent

	# Bankrupt carriers do nothing — can't spend and routes are losing money
	if carrier.cash <= 0.0:
		return intent

	var reserve := _estimate_cash_reserve(carrier, game_state)

	# Decision priority: Slots → Routes → Ships → Route Optimization → Slot Sales
	_consider_slot_bids(intent, carrier, game_state, reserve)
	_consider_route_creation(intent, carrier, game_state, reserve)
	_consider_ship_orders(intent, carrier, game_state, reserve)
	_consider_route_modifications(intent, carrier, game_state)
	_consider_slot_sales(intent, carrier, game_state, reserve)

	return intent


func _estimate_cash_reserve(carrier: CarrierData, game_state: GameState) -> float:
	var route_costs := 0.0
	for route: CarrierData.Route in carrier.get_active_routes():
		route_costs += FinancialCalculator.calculate_route_operating_cost(
			route, carrier, game_state.catalog, game_state.galaxy
		)
	var slot_upkeep := FinancialCalculator.calculate_slot_upkeep(carrier)
	var cost_based := (route_costs + slot_upkeep) * RESERVE_BUFFER_TURNS
	# Cap reserve at 40% of cash to prevent deadlocks where reserve exceeds income
	var cash_cap := carrier.cash * 0.4
	return maxf(minf(cost_based, cash_cap), MIN_CASH_RESERVE)


# ---------------------------------------------------------------------------
# 1. Slot Bids
# ---------------------------------------------------------------------------

func _consider_slot_bids(
	intent: TurnPipeline.CarrierIntent,
	carrier: CarrierData,
	game_state: GameState,
	reserve: float,
) -> void:
	var planets_with_slots := carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_slot_count(pid) > 0
	)

	# Max planets scales with aggression: low=3, mid=4, high=6
	var max_planets := 3 + int(slot_aggression * 3.0)
	var available_slot_planets := carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_available_slots_at(pid) > 0
	)

	# Override: allow bidding when idle ships exist but no usable slot pairs
	var idle_ships := carrier.get_available_ships()
	var has_usable_pair := false
	if not idle_ships.is_empty():
		for i in range(available_slot_planets.size()):
			for j in range(i + 1, available_slot_planets.size()):
				var d := game_state.galaxy.calculate_distance(
					available_slot_planets[i], available_slot_planets[j])
				for ship: ShipCatalog.ShipInstance in idle_ships:
					var st := game_state.catalog.get_type(ship.type_id)
					if st != null and st.range >= d:
						has_usable_pair = true
						break
				if has_usable_pair:
					break
			if has_usable_pair:
				break

	var force_bid := not idle_ships.is_empty() and not has_usable_pair

	if not force_bid and planets_with_slots.size() >= max_planets and available_slot_planets.size() >= 2:
		return

	# Find planets where we don't already have slots
	# Prefer planets reachable by owned ships
	var candidates: Array = []
	var max_ship_range := 0.0
	for ship: ShipCatalog.ShipInstance in carrier.ships:
		var st := game_state.catalog.get_type(ship.type_id)
		if st != null and st.range > max_ship_range:
			max_ship_range = st.range

	for planet_id: String in planets_with_slots:
		for planet: GalaxyData.Planet in game_state.galaxy.planets:
			if planet.id == planet_id:
				continue
			if carrier.has_slots_at(planet.id):
				continue
			var already := false
			for c: Dictionary in candidates:
				if c["planet_id"] == planet.id:
					already = true
					break
			if not already:
				var dist := game_state.galaxy.calculate_distance(planet_id, planet.id)
				var reachable := dist <= max_ship_range
				candidates.append({
					"planet_id": planet.id,
					"total_slots": planet.total_slots,
					"reachable": reachable,
				})

	# Sort: reachable planets first, then by market size
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["reachable"] != b["reachable"]:
			return a["reachable"]  # true before false
		return a["total_slots"] > b["total_slots"]
	)

	# Bid count scales with aggression: 0.3→1, 0.5→1, 0.8→2
	var bid_count := mini(candidates.size(), maxi(1, int(slot_aggression * 3.0)))
	var cumulative_cost := 0.0
	for i in range(bid_count):
		var base_price := 1200.0 + slot_aggression * 600.0
		var price := base_price + game_state.rng.randf_range(-300.0, 300.0)
		if carrier.cash - cumulative_cost - price <= reserve:
			break
		var planet_id: String = candidates[i]["planet_id"]
		intent.slot_bids.append({
			"planet_id": planet_id,
			"quantity": 1,
			"price_per_slot": price,
		})
		_slot_bid_turns[planet_id] = game_state.current_turn
		cumulative_cost += price


# ---------------------------------------------------------------------------
# 2. Route Creation
# ---------------------------------------------------------------------------

func _consider_route_creation(
	intent: TurnPipeline.CarrierIntent,
	carrier: CarrierData,
	game_state: GameState,
	reserve: float,
) -> void:
	var available_ships: Array = carrier.get_available_ships()
	if available_ships.is_empty():
		return

	# Find planet pairs where carrier has AVAILABLE slots (not consumed by routes)
	var slot_planets: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_available_slots_at(pid) > 0
	)

	# Score all candidate routes instead of picking first valid one (fixes Problem D)
	var candidates: Array = []
	for i in range(slot_planets.size()):
		for j in range(i + 1, slot_planets.size()):
			var origin_id: String = slot_planets[i]
			var dest_id: String = slot_planets[j]
			var lane_id := GalaxyData.derive_lane_id(origin_id, dest_id)
			if _has_route_on_lane(carrier, lane_id):
				continue

			var distance := game_state.galaxy.calculate_distance(origin_id, dest_id)
			if distance < 0.0:
				continue

			# Score the candidate — check both directions and use total demand
			var fwd_entry := game_state.demand_table.get_entry(lane_id, "forward")
			var rev_entry := game_state.demand_table.get_entry(lane_id, "reverse")
			var demand_score := 0.0
			if fwd_entry != null:
				demand_score += float(fwd_entry.base_demand_passenger + fwd_entry.base_demand_cargo)
			if rev_entry != null:
				demand_score += float(rev_entry.base_demand_passenger + rev_entry.base_demand_cargo)

			var competition_count := _count_competitors_on_lane(lane_id, carrier.id, game_state)
			# Aggressive NPCs barely penalize competition, cautious NPCs heavily penalize
			var competition_penalty := 0.3
			var score := demand_score - (competition_count * competition_penalty * demand_score * (1.0 - slot_aggression))
			# Distance penalty: cautious NPCs prefer short routes, aggressive tolerate long ones
			var distance_penalty := distance * (1.0 - slot_aggression * 0.5) * 2.0
			score -= distance_penalty
			# Per-NPC jitter (±30%) so identical-personality NPCs don't all pick the same route
			score *= 1.0 + game_state.rng.randf_range(-0.3, 0.3)

			candidates.append({
				"origin_id": origin_id,
				"dest_id": dest_id,
				"lane_id": lane_id,
				"distance": distance,
				"score": score,
			})

	# Sort by score descending — best candidates first
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)

	# Allow up to 3 routes per turn (limited by available ships)
	var max_routes := 3
	var routes_created := 0
	var used_ship_ids: Dictionary = {}
	var pending_slot_usage: Dictionary = {}  # planet_id -> count of slots consumed by pending creates

	for candidate: Dictionary in candidates:
		if routes_created >= max_routes:
			break

		var origin_id: String = candidate["origin_id"]
		var dest_id: String = candidate["dest_id"]
		var distance: float = candidate["distance"]

		# Check available slots accounting for pending creates this turn
		var origin_avail: int = carrier.get_available_slots_at(origin_id) - pending_slot_usage.get(origin_id, 0)
		var dest_avail: int = carrier.get_available_slots_at(dest_id) - pending_slot_usage.get(dest_id, 0)
		if origin_avail < 1 or dest_avail < 1:
			continue

		# Find an available ship with enough range (skip already-used this turn)
		var chosen_ship: ShipCatalog.ShipInstance = null
		for ship: ShipCatalog.ShipInstance in available_ships:
			if used_ship_ids.has(ship.id):
				continue
			var ship_type := game_state.catalog.get_type(ship.type_id)
			if ship_type != null and ship_type.range >= distance:
				chosen_ship = ship
				break

		if chosen_ship == null:
			continue

		# Check if NPC can sustain the new route's operating costs
		var ship_type := game_state.catalog.get_type(chosen_ship.type_id)
		var start_freq := 1
		if route_preference >= 0.6:
			start_freq = 2

		if ship_type != null:
			var new_route_cost: float = (
				pow(distance, 1.2)
				* ship_type.max_capacity
				* FinancialCalculator.FUEL_COST_PER_UNIT
				/ ship_type.efficiency
			) * start_freq
			var new_reserve := reserve + new_route_cost * RESERVE_BUFFER_TURNS
			if carrier.cash <= new_reserve:
				continue

		# Price based on suggested price (anchored to distance), not demand quantity
		var lane := game_state.galaxy.get_lane(origin_id, dest_id)
		var passenger_price := 50.0
		var cargo_price := 40.0
		if lane != null:
			passenger_price = DemandCalculator.calculate_suggested_price(lane, "passenger")
			cargo_price = DemandCalculator.calculate_suggested_price(lane, "cargo")
		# Personality discount: aggressive NPCs undercut deeply to grab share
		var price_factor := 1.05 - slot_aggression * 0.4
		passenger_price *= price_factor
		cargo_price *= price_factor
		# ±10% variance
		passenger_price *= 1.0 + game_state.rng.randf_range(-0.1, 0.1)
		cargo_price *= 1.0 + game_state.rng.randf_range(-0.1, 0.1)

		# Estimate profitability before committing
		# Revenue estimate at ~70% fill (new routes with unmet demand fill quickly)
		var pax_cap := ship_type.max_capacity / 2
		var cargo_cap := ship_type.max_capacity - pax_cap
		var est_revenue := (passenger_price * pax_cap + cargo_price * cargo_cap) * 0.7
		var est_op_cost: float = (
			pow(distance, 1.2)
			* ship_type.max_capacity
			* FinancialCalculator.FUEL_COST_PER_UNIT
			/ ship_type.efficiency
		)
		if est_revenue < est_op_cost:
			continue  # skip routes that won't break even

		# New routes start at a personality-driven frequency
		intent.route_creates.append({
			"origin_id": origin_id,
			"dest_id": dest_id,
			"ship_ids": [chosen_ship.id],
			"passenger_price": passenger_price,
			"cargo_price": cargo_price,
			"frequency": start_freq,
		})
		# Track creation turn for optimization grace period
		var future_route_id := "%s-route-%d" % [carrier.id, carrier.routes.size() + routes_created]
		_route_created_turn[future_route_id] = game_state.current_turn
		used_ship_ids[chosen_ship.id] = true
		pending_slot_usage[origin_id] = pending_slot_usage.get(origin_id, 0) + 1
		pending_slot_usage[dest_id] = pending_slot_usage.get(dest_id, 0) + 1
		routes_created += 1


# ---------------------------------------------------------------------------
# 3. Ship Orders
# ---------------------------------------------------------------------------

func _consider_ship_orders(
	intent: TurnPipeline.CarrierIntent,
	carrier: CarrierData,
	game_state: GameState,
	reserve: float,
) -> void:
	# Don't buy ships if existing routes are losing money
	var financials: Dictionary = game_state.last_turn_financials.get(carrier.id, {})
	var route_summaries: Array = financials.get("routes", [])
	if not route_summaries.is_empty():
		var losing_routes := 0
		for summary: Dictionary in route_summaries:
			var rev: float = summary.get("revenue", {}).get("total_revenue", 0.0)
			var cost: float = summary.get("operating_cost", 0.0)
			if rev < cost:
				losing_routes += 1
		if losing_routes > 0:
			return  # fix unprofitable routes before buying more ships

	# Cap pending orders to prevent over-spending while waiting for deliveries
	if carrier.pending_orders.size() >= 2:
		return

	var total_ships := carrier.ships.size()
	var available_ships := carrier.get_available_ships()
	var assigned_count := total_ships - available_ships.size()

	# Utilization threshold scales with eagerness: 0.3→100%, 0.5→80%, 0.8→50%
	var util_threshold := 1.0 - ship_eagerness * 0.6
	var utilization := 1.0 if total_ships == 0 else float(assigned_count) / float(total_ships)

	# Check if there are unserved planet pairs that could use a ship
	var slot_planets: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_available_slots_at(pid) > 0
	)
	var has_unrouted_pair := false
	for i in range(slot_planets.size()):
		for j in range(i + 1, slot_planets.size()):
			var lane_id := GalaxyData.derive_lane_id(slot_planets[i], slot_planets[j])
			if not _has_route_on_lane(carrier, lane_id):
				has_unrouted_pair = true
				break
		if has_unrouted_pair:
			break

	# Don't order if utilization is below threshold AND no actionable route pairs exist
	if utilization < util_threshold and not has_unrouted_pair:
		return

	# Don't order if we already have 2+ idle ships that can reach an unserved pair
	var _target_dist := _get_shortest_unserved_pair_distance(carrier, game_state)
	var idle_ships_in_range := 0
	for ship: ShipCatalog.ShipInstance in available_ships:
		var st := game_state.catalog.get_type(ship.type_id)
		if st != null and (_target_dist <= 0.0 or st.range >= _target_dist):
			idle_ships_in_range += 1
	if idle_ships_in_range >= 2:
		return

	var available_types := game_state.catalog.get_available_types(game_state.current_turn)
	if available_types.is_empty():
		return

	# All personalities consider range for unserved pairs
	var target_distance := _get_shortest_unserved_pair_distance(carrier, game_state)

	# Pick ship type based on personality
	var best_type: ShipCatalog.ShipType = null
	if ship_eagerness >= 0.55:
		# Aggressive: prefer higher capacity that can reach unserved pairs
		var max_spend := carrier.cash * 0.4
		for st: ShipCatalog.ShipType in available_types:
			if st.cost > max_spend:
				continue
			if target_distance > 0.0 and st.range < target_distance:
				continue
			if best_type == null or st.max_capacity > best_type.max_capacity:
				best_type = st
		# Fallback: relax budget but keep range requirement
		if best_type == null and target_distance > 0.0:
			for st: ShipCatalog.ShipType in available_types:
				if st.range < target_distance:
					continue
				if best_type == null or st.cost < best_type.cost:
					best_type = st
		# Last resort: cheapest anything
		if best_type == null:
			for st: ShipCatalog.ShipType in available_types:
				if best_type == null or st.cost < best_type.cost:
					best_type = st
	elif ship_eagerness < 0.45:
		# Cautious: prefer the most efficient affordable ship that can unlock a route.
		var max_spend := carrier.cash * 0.4
		var best_efficiency := 0.0
		for st: ShipCatalog.ShipType in available_types:
			if st.cost > max_spend:
				continue
			if target_distance > 0.0 and st.range < target_distance:
				continue
			if best_type == null or st.efficiency > best_efficiency:
				best_efficiency = st.efficiency
				best_type = st
		# Fallback: relax budget but keep range requirement
		if best_type == null and target_distance > 0.0:
			best_efficiency = 0.0
			for st: ShipCatalog.ShipType in available_types:
				if st.range < target_distance:
					continue
				if best_type == null or st.efficiency > best_efficiency:
					best_efficiency = st.efficiency
					best_type = st
		# Last resort: cheapest anything
		if best_type == null:
			for st: ShipCatalog.ShipType in available_types:
				if best_type == null or st.cost < best_type.cost:
					best_type = st
	else:
		# Balanced: pick best value (capacity × efficiency / cost) among
		# ships that can reach unserved pairs or existing routes
		var min_range := 0.0
		for route: CarrierData.Route in carrier.get_active_routes():
			var d := game_state.galaxy.calculate_distance(route.origin_id, route.dest_id)
			if d > min_range:
				min_range = d
		if target_distance > 0.0 and target_distance > min_range:
			min_range = target_distance
		var best_value := 0.0
		for st: ShipCatalog.ShipType in available_types:
			if st.range < min_range:
				continue
			var value := float(st.max_capacity) * st.efficiency / float(st.cost)
			if value > best_value:
				best_value = value
				best_type = st
		# Fallback: if no ship can reach, pick longest range
		if best_type == null:
			for st: ShipCatalog.ShipType in available_types:
				if best_type == null or st.range > best_type.range:
					best_type = st

	if best_type == null or carrier.cash - best_type.cost <= reserve:
		return

	# Set capacity based on existing route demand (if available)
	var pax_ratio := _estimate_demand_ratio(carrier, game_state)
	var pax_cap := int(best_type.max_capacity * pax_ratio)
	var cargo_cap := best_type.max_capacity - pax_cap

	intent.ship_orders.append({
		"type_id": best_type.id,
		"passenger_capacity": pax_cap,
		"cargo_capacity": cargo_cap,
	})


# ---------------------------------------------------------------------------
# 4. Slot Sales
# ---------------------------------------------------------------------------

func _consider_slot_sales(
	intent: TurnPipeline.CarrierIntent,
	carrier: CarrierData,
	game_state: GameState,
	reserve: float,
) -> void:
	var planets_with_slots: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_slot_count(pid) > 0
	)

	# Don't sell down to nothing
	if planets_with_slots.size() <= 2:
		return

	var active_routes := carrier.get_active_routes()

	# Phase 1: Always sell unreachable/useless slots (no route potential, no active route)
	for planet_id: String in planets_with_slots:
		if _slot_bid_turns.has(planet_id):
			if game_state.current_turn - _slot_bid_turns[planet_id] < SLOT_GRACE_PERIOD:
				continue
		var has_route := false
		for route: CarrierData.Route in active_routes:
			if route.origin_id == planet_id or route.dest_id == planet_id:
				has_route = true
				break
		if has_route:
			continue
		if _has_route_potential(planet_id, carrier, game_state):
			continue
		intent.slot_sales.append({"planet_id": planet_id, "count": 1})
		return  # sell at most 1 per turn

	# Phase 2: Under financial pressure, sell idle slots even with potential
	# But still don't sell if the slot has a reachable route pair
	if carrier.cash >= reserve * 0.5:
		return

	for planet_id: String in planets_with_slots:
		if _slot_bid_turns.has(planet_id):
			if game_state.current_turn - _slot_bid_turns[planet_id] < SLOT_GRACE_PERIOD:
				continue
		var has_route := false
		for route: CarrierData.Route in active_routes:
			if route.origin_id == planet_id or route.dest_id == planet_id:
				has_route = true
				break
		if has_route:
			continue
		# Under pressure, still check if a route could be created
		if _has_route_potential(planet_id, carrier, game_state):
			continue
		intent.slot_sales.append({"planet_id": planet_id, "count": 1})
		return
		return


# ---------------------------------------------------------------------------
# 5. Route Optimization
# ---------------------------------------------------------------------------

func _consider_route_modifications(
	intent: TurnPipeline.CarrierIntent,
	carrier: CarrierData,
	game_state: GameState,
) -> void:
	var financials: Dictionary = game_state.last_turn_financials.get(carrier.id, {})
	var route_summaries: Array = financials.get("routes", [])
	if route_summaries.is_empty():
		return

	var active_routes := carrier.get_active_routes()

	# Check if there are unserved pairs that need ships — don't hoard ships on existing routes
	var has_unserved_pairs := _get_shortest_unserved_pair_distance(carrier, game_state) > 0.0

	for summary: Dictionary in route_summaries:
		var route_id: String = summary.get("route_id", "")
		var route := _find_route(carrier, route_id)
		if route == null or not route.active:
			continue

		# Skip routes that were just created (need time to build demand)
		var created_turn: int = _route_created_turn.get(route_id, 0)
		if game_state.current_turn - created_turn < 4:
			continue

		var revenue: Dictionary = summary.get("revenue", {})
		var total_rev: float = revenue.get("total_revenue", 0.0)
		var op_cost: float = summary.get("operating_cost", 0.0)

		# Track loss streaks for cancellation
		if total_rev < op_cost:
			_route_loss_streak[route_id] = _route_loss_streak.get(route_id, 0) + 1
		else:
			_route_loss_streak[route_id] = 0

		# Cancel after 3 consecutive loss turns, but never cancel the last route
		if _route_loss_streak.get(route_id, 0) >= 3 and active_routes.size() > 1:
			intent.route_cancellations.append(route_id)
			_route_loss_streak.erase(route_id)
			continue

		# Adjust pricing based on load factor
		var pax_served: int = summary.get("passengers_served", 0)
		var pax_cap: int = summary.get("passenger_capacity", 1)
		var cargo_served: int = summary.get("cargo_served", 0)
		var cargo_cap: int = summary.get("cargo_capacity", 1)

		var pax_load := float(pax_served) / maxf(float(pax_cap), 1.0)
		var cargo_load := float(cargo_served) / maxf(float(cargo_cap), 1.0)
		var avg_load := (pax_load + cargo_load) / 2.0

		var new_pax_price := route.passenger_price
		var new_cargo_price := route.cargo_price
		var new_ship_ids: Array = route.ship_ids.duplicate()
		var new_frequency := route.frequency
		var modified := false

		if avg_load > 0.85:
			if has_unserved_pairs:
				# Don't absorb ships — save them for new routes; raise prices instead
				new_pax_price *= 1.10
				new_cargo_price *= 1.10
				modified = true
			else:
				# No unserved pairs — safe to add ships to expand capacity
				var available_ships: Array = carrier.get_available_ships()
				var distance := game_state.galaxy.calculate_distance(route.origin_id, route.dest_id)
				for ship: ShipCatalog.ShipInstance in available_ships:
					var ship_type := game_state.catalog.get_type(ship.type_id)
					if ship_type != null and ship_type.range >= distance:
						new_ship_ids.append(ship.id)
						new_frequency = _choose_frequency(new_ship_ids, carrier, game_state, distance)
						modified = true
						break
				if not modified:
					new_pax_price *= 1.10
					new_cargo_price *= 1.10
					modified = true
			# Also try increasing frequency if ships support it
			var max_freq := RouteValidator.calculate_max_frequency(
				new_ship_ids, carrier, game_state.catalog,
				game_state.galaxy.calculate_distance(route.origin_id, route.dest_id)
			)
			if max_freq > new_frequency:
				new_frequency = mini(new_frequency + 1, max_freq)
				modified = true
		elif avg_load < 0.4:
			if total_rev < op_cost:
				new_pax_price *= 1.08
				new_cargo_price *= 1.08
			else:
				new_pax_price *= 0.92
				new_cargo_price *= 0.92
			modified = true
			if new_frequency > 1:
				new_frequency -= 1
				modified = true

		# Only add idle ships when no unserved pairs need them
		if not modified and not has_unserved_pairs and avg_load > 0.6 and total_rev > op_cost * 1.2:
			var idle_ships: Array = carrier.get_available_ships()
			if not idle_ships.is_empty():
				var distance := game_state.galaxy.calculate_distance(route.origin_id, route.dest_id)
				for ship: ShipCatalog.ShipInstance in idle_ships:
					var ship_type := game_state.catalog.get_type(ship.type_id)
					if ship_type != null and ship_type.range >= distance:
						new_ship_ids.append(ship.id)
						modified = true
						break
				if modified:
					new_frequency = _choose_frequency(new_ship_ids, carrier, game_state, distance)

		if modified:
			intent.route_modifications.append({
				"route_id": route_id,
				"ship_ids": new_ship_ids,
				"passenger_price": new_pax_price,
				"cargo_price": new_cargo_price,
				"frequency": new_frequency,
			})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _has_route_on_lane(carrier: CarrierData, lane_id: String) -> bool:
	for route: CarrierData.Route in carrier.get_active_routes():
		if route.lane_id == lane_id:
			return true
	return false


func _count_competitors_on_lane(lane_id: String, own_carrier_id: String, game_state: GameState) -> int:
	var count := 0
	for carrier: CarrierData in game_state.carriers:
		if carrier.id == own_carrier_id:
			continue
		for route: CarrierData.Route in carrier.get_active_routes():
			if route.lane_id == lane_id:
				count += 1
				break
	return count


func _has_route_potential(planet_id: String, carrier: CarrierData, game_state: GameState) -> bool:
	## Returns true if this planet could pair with another slot-planet to form a route
	## using any owned ship OR any purchasable ship type from the catalog.
	var slot_planets: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_slot_count(pid) > 0 and pid != planet_id
	)
	var available_types := game_state.catalog.get_available_types(game_state.current_turn)
	for other_pid: String in slot_planets:
		var lane_id := GalaxyData.derive_lane_id(planet_id, other_pid)
		if not _has_route_on_lane(carrier, lane_id):
			var distance := game_state.galaxy.calculate_distance(planet_id, other_pid)
			if distance > 0.0:
				# Check owned ships
				for ship: ShipCatalog.ShipInstance in carrier.ships:
					var ship_type := game_state.catalog.get_type(ship.type_id)
					if ship_type != null and ship_type.range >= distance:
						return true
				# Check catalog ships (could buy one that reaches)
				for st: ShipCatalog.ShipType in available_types:
					if st.range >= distance:
						return true
	return false


func _get_shortest_unserved_pair_distance(carrier: CarrierData, game_state: GameState) -> float:
	var slot_planets: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_available_slots_at(pid) > 0
	)
	var best_distance := -1.0
	for i in range(slot_planets.size()):
		for j in range(i + 1, slot_planets.size()):
			var origin_id: String = slot_planets[i]
			var dest_id: String = slot_planets[j]
			var lane_id := GalaxyData.derive_lane_id(origin_id, dest_id)
			if _has_route_on_lane(carrier, lane_id):
				continue
			var distance := game_state.galaxy.calculate_distance(origin_id, dest_id)
			if distance <= 0.0:
				continue
			if best_distance < 0.0 or distance < best_distance:
				best_distance = distance
	return best_distance


func _estimate_demand_ratio(carrier: CarrierData, game_state: GameState) -> float:
	## Returns the passenger fraction (0.0-1.0) based on existing route performance.
	var financials: Dictionary = game_state.last_turn_financials.get(carrier.id, {})
	var route_summaries: Array = financials.get("routes", [])
	if route_summaries.is_empty():
		return 0.5  # Default 50/50

	var total_pax := 0
	var total_cargo := 0
	for summary: Dictionary in route_summaries:
		total_pax += summary.get("passengers_served", 0)
		total_cargo += summary.get("cargo_served", 0)

	var total := total_pax + total_cargo
	if total == 0:
		return 0.5
	return clampf(float(total_pax) / float(total), 0.3, 0.7)


func _find_route(carrier: CarrierData, route_id: String) -> CarrierData.Route:
	for route: CarrierData.Route in carrier.routes:
		if route.id == route_id:
			return route
	return null


func _choose_frequency(ship_ids: Array, carrier: CarrierData, game_state: GameState, lane_distance: float) -> int:
	var max_freq := RouteValidator.calculate_max_frequency(
		ship_ids, carrier, game_state.catalog, lane_distance
	)
	return maxi(1, int(max_freq * route_preference))
