class_name NpcController
extends CarrierController

## Heuristic AI that generates meaningful intents for NPC carriers.
## Jam scope: good enough to be interesting, not optimal.
## One class with tunable weights — no strategy pattern.

# Personality weights control intensity, not probability of acting
var slot_aggression: float = 0.5    # 0.0 = 1 conservative bid, 1.0 = 3 aggressive bids
var route_preference: float = 0.5   # 0.0 = few expensive routes, 1.0 = many cheap routes
var ship_eagerness: float = 0.5     # 0.0 = only when all deployed, 1.0 = proactive ordering


const RESERVE_BUFFER_TURNS: int = 8
const MIN_CASH_RESERVE: float = 1200.0
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
	return maxf((route_costs + slot_upkeep) * RESERVE_BUFFER_TURNS, MIN_CASH_RESERVE)


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
	# But count planets with AVAILABLE slots — consumed slots don't count toward the cap
	var max_planets := 3 + int(slot_aggression * 3.0)
	var available_slot_planets := carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_available_slots_at(pid) > 0
	)
	if planets_with_slots.size() >= max_planets and available_slot_planets.size() >= 2:
		return

	# Find reachable planets where we don't already have slots
	var candidates: Array = []
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
				candidates.append({
					"planet_id": planet.id,
					"total_slots": planet.total_slots,
				})

	# Prioritize bigger markets
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["total_slots"] > b["total_slots"]
	)

	# Bid count scales with aggression: 0.3→1, 0.5→1, 0.8→2
	var bid_count := mini(candidates.size(), maxi(1, int(slot_aggression * 3.0)))
	var cumulative_cost := 0.0
	for i in range(bid_count):
		# Price scales with aggression (aggressive NPCs bid higher to win)
		var base_price := 120.0 + slot_aggression * 60.0
		var price := base_price + game_state.rng.randf_range(-30.0, 30.0)
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
			# Per-NPC jitter (±15%) so identical-personality NPCs don't all pick the same route
			score *= 1.0 + game_state.rng.randf_range(-0.15, 0.15)

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

	for candidate: Dictionary in candidates:
		if routes_created >= max_routes:
			break

		var origin_id: String = candidate["origin_id"]
		var dest_id: String = candidate["dest_id"]
		var distance: float = candidate["distance"]

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
		if ship_type != null:
			var npc_freq := _choose_frequency([chosen_ship.id], carrier, game_state, distance)
			var new_route_cost: float = (distance / ship_type.efficiency) * npc_freq
			var new_reserve := reserve + new_route_cost * RESERVE_BUFFER_TURNS
			if carrier.cash <= new_reserve:
				continue

		# Price based on demand — use the direction matching origin->dest
		var lane_parts: PackedStringArray = candidate["lane_id"].split("::")
		var price_direction := "forward" if origin_id == lane_parts[0] else "reverse"
		var demand_entry := game_state.demand_table.get_entry(candidate["lane_id"], price_direction)
		var passenger_price := 5.0
		var cargo_price := 4.0
		if demand_entry != null:
			passenger_price = demand_entry.base_demand_passenger * 0.08
			cargo_price = demand_entry.base_demand_cargo * 0.06
		# ±20% variance
		passenger_price *= 1.0 + game_state.rng.randf_range(-0.2, 0.2)
		cargo_price *= 1.0 + game_state.rng.randf_range(-0.2, 0.2)

		intent.route_creates.append({
			"origin_id": origin_id,
			"dest_id": dest_id,
			"ship_ids": [chosen_ship.id],
			"passenger_price": passenger_price,
			"cargo_price": cargo_price,
			"frequency": _choose_frequency([chosen_ship.id], carrier, game_state, distance),
		})
		# Track creation turn for optimization grace period
		var future_route_id := "%s-route-%d" % [carrier.id, carrier.routes.size() + routes_created]
		_route_created_turn[future_route_id] = game_state.current_turn
		used_ship_ids[chosen_ship.id] = true
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

	# Don't order if we already have 2+ idle ships (use what you have first)
	if available_ships.size() >= 2:
		return

	var available_types := game_state.catalog.get_available_types(game_state.current_turn)
	if available_types.is_empty():
		return

	# Pick ship type based on personality
	var best_type: ShipCatalog.ShipType = null
	if ship_eagerness >= 0.55:
		# Aggressive: prefer higher capacity, but cap spending at 40% of cash
		var max_spend := carrier.cash * 0.4
		for st: ShipCatalog.ShipType in available_types:
			if st.cost > max_spend:
				continue
			if best_type == null or st.max_capacity > best_type.max_capacity:
				best_type = st
		# Fallback: if nothing in budget, pick cheapest
		if best_type == null:
			for st: ShipCatalog.ShipType in available_types:
				if best_type == null or st.cost < best_type.cost:
					best_type = st
	elif ship_eagerness < 0.45:
		# Cautious: stick with cheapest
		for st: ShipCatalog.ShipType in available_types:
			if best_type == null or st.cost < best_type.cost:
				best_type = st
	else:
		# Balanced: pick best value (capacity × efficiency / cost) among
		# ships that can reach current routes
		var max_route_distance := 0.0
		for route: CarrierData.Route in carrier.get_active_routes():
			var d := game_state.galaxy.calculate_distance(route.origin_id, route.dest_id)
			if d > max_route_distance:
				max_route_distance = d
		var best_value := 0.0
		for st: ShipCatalog.ShipType in available_types:
			if st.range < max_route_distance:
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
	# Only sell under financial pressure
	if carrier.cash >= reserve * 0.5:
		return

	var planets_with_slots: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_slot_count(pid) > 0
	)

	# Don't sell down to nothing
	if planets_with_slots.size() <= 2:
		return

	var active_routes := carrier.get_active_routes()

	for planet_id: String in planets_with_slots:
		# Grace period: don't sell recently-bid slots
		if _slot_bid_turns.has(planet_id):
			if game_state.current_turn - _slot_bid_turns[planet_id] < SLOT_GRACE_PERIOD:
				continue

		# Don't sell if a route uses this planet
		var has_route := false
		for route: CarrierData.Route in active_routes:
			if route.origin_id == planet_id or route.dest_id == planet_id:
				has_route = true
				break
		if has_route:
			continue

		# Don't sell if this slot could pair with another planet for a future route
		if _has_route_potential(planet_id, carrier, game_state):
			continue

		intent.slot_sales.append({
			"planet_id": planet_id,
			"count": 1,
		})
		# Sell at most 1 per turn
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

		# Cancel after 5 consecutive loss turns, but never cancel the last route
		if _route_loss_streak.get(route_id, 0) >= 5 and active_routes.size() > 1:
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
			# Overloaded — add ships to expand capacity (any personality)
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
				# No ships available: raise prices
				new_pax_price *= 1.10
				new_cargo_price *= 1.10
				modified = true
			# Also try increasing frequency if ships support it
			var max_freq := RouteValidator.calculate_max_frequency(
				new_ship_ids, carrier, game_state.catalog, distance
			)
			if max_freq > new_frequency:
				new_frequency = mini(new_frequency + 1, max_freq)
				modified = true
		elif avg_load < 0.4:
			# Underloaded — reduce prices
			new_pax_price *= 0.92
			new_cargo_price *= 0.92
			modified = true
			# Also reduce frequency to cut operating costs
			if new_frequency > 1:
				new_frequency -= 1
				modified = true

		# Assign idle ships to routes even at moderate load — sitting idle is wasteful
		if not modified:
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
	## Returns true if this planet could pair with another slot-planet to form a route.
	var slot_planets: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_slot_count(pid) > 0 and pid != planet_id
	)
	for other_pid: String in slot_planets:
		var lane_id := GalaxyData.derive_lane_id(planet_id, other_pid)
		if not _has_route_on_lane(carrier, lane_id):
			# Check if any ship (including pending) could reach
			var distance := game_state.galaxy.calculate_distance(planet_id, other_pid)
			if distance > 0.0:
				for ship: ShipCatalog.ShipInstance in carrier.ships:
					var ship_type := game_state.catalog.get_type(ship.type_id)
					if ship_type != null and ship_type.range >= distance:
						return true
	return false


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
