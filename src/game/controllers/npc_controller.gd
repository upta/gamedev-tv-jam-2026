class_name NpcController
extends CarrierController

## Heuristic AI that generates meaningful intents for NPC carriers.
## Jam scope: good enough to be interesting, not optimal.
## One class with tunable weights — no strategy pattern.

# Personality weights (tune these to differentiate NPCs)
var slot_aggression: float = 0.5    # 0.0 = conservative, 1.0 = aggressive slot buying
var route_preference: float = 0.5   # 0.0 = few expensive routes, 1.0 = many cheap routes
var ship_eagerness: float = 0.5     # 0.0 = waits, 1.0 = buys ships immediately


const RESERVE_BUFFER_TURNS: int = 8
const MIN_CASH_RESERVE: float = 1200.0


func generate_intent(game_state: GameState, carrier_id: String) -> TurnPipeline.CarrierIntent:
	var intent := TurnPipeline.CarrierIntent.new()
	intent.carrier_id = carrier_id

	var carrier := game_state.get_carrier(carrier_id)
	if carrier == null:
		return intent

	var reserve := _estimate_cash_reserve(carrier, game_state)

	# Decision priority: Slots → Routes → Ships → Slot Sales
	_consider_slot_bids(intent, carrier, game_state, reserve)
	_consider_route_creation(intent, carrier, game_state, reserve)
	_consider_ship_orders(intent, carrier, game_state, reserve)
	_consider_slot_sales(intent, carrier, game_state)

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
	if game_state.rng.randf() >= slot_aggression:
		return

	var planets_with_slots := carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_slot_count(pid) > 0
	)
	if planets_with_slots.size() >= 4:
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

	var bid_count := mini(candidates.size(), 2)
	var cumulative_cost := 0.0
	for i in range(bid_count):
		var price := 150.0 + game_state.rng.randf_range(-50.0, 50.0)
		if carrier.cash - cumulative_cost - price <= reserve:
			break
		intent.slot_bids.append({
			"planet_id": candidates[i]["planet_id"],
			"quantity": 1,
			"price_per_slot": price,
		})
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

	# Find planet pairs where carrier has slots at both ends and no active route
	var slot_planets: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_slot_count(pid) > 0
	)
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

			# Find a ship with enough range
			var chosen_ship: ShipCatalog.ShipInstance = null
			for ship: ShipCatalog.ShipInstance in available_ships:
				var ship_type := game_state.catalog.get_type(ship.type_id)
				if ship_type != null and ship_type.range >= distance:
					chosen_ship = ship
					break

			if chosen_ship == null:
				continue

			# Check if NPC can sustain the new route's operating costs
			var ship_type := game_state.catalog.get_type(chosen_ship.type_id)
			if ship_type != null:
				var new_route_cost: float = distance / ship_type.efficiency
				var new_reserve := reserve + new_route_cost * RESERVE_BUFFER_TURNS
				if carrier.cash <= new_reserve:
					continue

			# Price based on demand
			var demand_entry := game_state.demand_table.get_entry(lane_id, "forward")
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
				"frequency": 1,
			})
			# At most 1 route per turn
			return


# ---------------------------------------------------------------------------
# 3. Ship Orders
# ---------------------------------------------------------------------------

func _consider_ship_orders(
	intent: TurnPipeline.CarrierIntent,
	carrier: CarrierData,
	game_state: GameState,
	reserve: float,
) -> void:
	if game_state.rng.randf() >= ship_eagerness:
		return

	if not carrier.get_available_ships().is_empty():
		return

	var available_types := game_state.catalog.get_available_types(game_state.current_turn)
	if available_types.is_empty():
		return

	# Find cheapest type
	var cheapest: ShipCatalog.ShipType = null
	for st: ShipCatalog.ShipType in available_types:
		if cheapest == null or st.cost < cheapest.cost:
			cheapest = st

	if cheapest == null or carrier.cash - cheapest.cost <= reserve:
		return

	# 50/50 passenger/cargo split
	var half := cheapest.max_capacity / 2
	var remainder := cheapest.max_capacity - half * 2
	intent.ship_orders.append({
		"type_id": cheapest.id,
		"passenger_capacity": half + remainder,
		"cargo_capacity": half,
	})


# ---------------------------------------------------------------------------
# 4. Slot Sales
# ---------------------------------------------------------------------------

func _consider_slot_sales(
	intent: TurnPipeline.CarrierIntent,
	carrier: CarrierData,
	game_state: GameState,
) -> void:
	var planets_with_slots: Array = carrier.slots.keys().filter(
		func(pid: String) -> bool: return carrier.get_slot_count(pid) > 0
	)

	# Don't sell down to nothing
	if planets_with_slots.size() <= 2:
		return

	var active_routes := carrier.get_active_routes()

	for planet_id: String in planets_with_slots:
		var has_route := false
		for route: CarrierData.Route in active_routes:
			if route.origin_id == planet_id or route.dest_id == planet_id:
				has_route = true
				break
		if not has_route:
			intent.slot_sales.append({
				"planet_id": planet_id,
				"count": 1,
			})
			# Sell at most 1 per turn to be conservative
			return


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _has_route_on_lane(carrier: CarrierData, lane_id: String) -> bool:
	for route: CarrierData.Route in carrier.get_active_routes():
		if route.lane_id == lane_id:
			return true
	return false
