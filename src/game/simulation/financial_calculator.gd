class_name FinancialCalculator
extends RefCounted

## Static utility for route revenue, operating costs, and carrier financials.
## No state — all methods are static.

const SLOT_UPKEEP_COST: float = 100.0  # per slot per turn
const FUEL_COST_PER_UNIT: float = 3.0


static func deliver_pending_ships(carriers: Array, current_turn: int) -> Array:
	var deliveries: Array = []

	for carrier: CarrierData in carriers:
		var still_pending: Array = []
		for ship: ShipCatalog.ShipInstance in carrier.pending_orders:
			if ship.available_turn <= current_turn:
				carrier.ships.append(ship)
				deliveries.append({
					"carrier_id": carrier.id,
					"ship_id": ship.id,
					"type_id": ship.type_id,
				})
			else:
				still_pending.append(ship)
		carrier.pending_orders = still_pending

	return deliveries


static func calculate_route_revenue(
	route: CarrierData.Route,
	_carrier: CarrierData,
	_catalog: ShipCatalog,
	demand_split_result: Dictionary,
) -> Dictionary:
	var carrier_id: String = _carrier.id
	var passengers_served := 0
	var cargo_served := 0

	if demand_split_result.has(carrier_id):
		var split: Dictionary = demand_split_result[carrier_id]
		passengers_served = split.get("passengers_served", 0)
		cargo_served = split.get("cargo_served", 0)

	var passenger_revenue: float = passengers_served * route.passenger_price
	var cargo_revenue: float = cargo_served * route.cargo_price

	return {
		"passenger_revenue": passenger_revenue,
		"cargo_revenue": cargo_revenue,
		"total_revenue": passenger_revenue + cargo_revenue,
	}


static func calculate_route_operating_cost(
	route: CarrierData.Route,
	carrier: CarrierData,
	catalog: ShipCatalog,
	galaxy: GalaxyData,
) -> float:
	var lane := galaxy.get_lane(route.origin_id, route.dest_id)
	if lane == null:
		return 0.0

	var total_cost := 0.0
	for ship_id: String in route.ship_ids:
		var ship := _find_ship(carrier, ship_id)
		if ship == null:
			continue
		var ship_type := catalog.get_type(ship.type_id)
		if ship_type == null:
			continue
		total_cost += (
			pow(lane.distance, 1.2)
			* ship_type.max_capacity
			* FUEL_COST_PER_UNIT
			/ ship_type.efficiency
		) * route.frequency

	return total_cost


static func calculate_slot_upkeep(carrier: CarrierData) -> float:
	var total_slots := 0
	for count: int in carrier.slots.values():
		total_slots += count
	return total_slots * SLOT_UPKEEP_COST


static func process_financials(
	carriers: Array,
	catalog: ShipCatalog,
	galaxy: GalaxyData,
	demand_data: DemandData,
) -> Dictionary:
	# Group all active routes across all carriers by (lane_id, direction)
	var lane_dir_routes: Dictionary = {}  # "lane_id::direction" -> Array[{ carrier, route }]

	for carrier: CarrierData in carriers:
		for route: CarrierData.Route in carrier.get_active_routes():
			var lane := galaxy.get_lane(route.origin_id, route.dest_id)
			if lane == null:
				continue

			# Direction is relative to canonical lane_id ordering (alphabetical)
			var canonical_lane_id := GalaxyData.derive_lane_id(route.origin_id, route.dest_id)
			var parts := canonical_lane_id.split("::")
			var direction := "forward" if route.origin_id == parts[0] else "reverse"
			var key := canonical_lane_id + "::" + direction

			if not lane_dir_routes.has(key):
				lane_dir_routes[key] = { "lane": lane, "direction": direction, "entries": [] }
			lane_dir_routes[key]["entries"].append({ "carrier": carrier, "route": route })

	# Calculate demand split once per (lane, direction)
	var demand_splits: Dictionary = {}  # "lane_id::direction" -> split result

	for key: String in lane_dir_routes:
		var group: Dictionary = lane_dir_routes[key]
		var lane: GalaxyData.Lane = group["lane"]
		var direction: String = group["direction"]
		var group_entries: Array = group["entries"]

		var routes_on_lane: Array = []
		for entry: Dictionary in group_entries:
			routes_on_lane.append(entry["route"])

		var demand_entry := demand_data.get_entry(lane.id, direction)
		if demand_entry == null:
			continue

		var suggested_pax := DemandCalculator.calculate_suggested_price(lane, "passenger")
		var suggested_cargo := DemandCalculator.calculate_suggested_price(lane, "cargo")

		# Use canonical origin (alphabetically first planet) for direction matching
		var canonical_origin: String = lane.id.split("::")[0]

		demand_splits[key] = DemandCalculator.calculate_demand_split(
			routes_on_lane,
			direction,
			demand_entry,
			carriers,
			catalog,
			suggested_pax,
			suggested_cargo,
			canonical_origin,
		)

	# Build per-carrier financial summaries
	var result: Dictionary = {}

	for carrier: CarrierData in carriers:
		var route_summaries: Array = []
		var total_revenue := 0.0
		var total_costs := 0.0

		for route: CarrierData.Route in carrier.get_active_routes():
			var lane := galaxy.get_lane(route.origin_id, route.dest_id)
			if lane == null:
				continue

			# Must use canonical direction (alphabetical) to match the grouping key
			var canonical_lane_id := GalaxyData.derive_lane_id(route.origin_id, route.dest_id)
			var parts := canonical_lane_id.split("::")
			var direction := "forward" if route.origin_id == parts[0] else "reverse"
			var key := canonical_lane_id + "::" + direction

			var split: Dictionary = demand_splits.get(key, {})
			var revenue := calculate_route_revenue(route, carrier, catalog, split)
			var op_cost := calculate_route_operating_cost(route, carrier, catalog, galaxy)

			# Per-route demand served (from carrier-level split)
			var pax_served := 0
			var cargo_served := 0
			if split.has(carrier.id):
				pax_served = split[carrier.id].get("passengers_served", 0)
				cargo_served = split[carrier.id].get("cargo_served", 0)

			var capacity := RouteValidator.get_route_capacity(route, carrier, catalog)

			route_summaries.append({
				"route_id": route.id,
				"revenue": revenue,
				"operating_cost": op_cost,
				"passengers_served": pax_served,
				"cargo_served": cargo_served,
				"passenger_capacity": capacity["passenger"],
				"cargo_capacity": capacity["cargo"],
			})

			total_revenue += revenue["total_revenue"]
			total_costs += op_cost

		var slot_upkeep := calculate_slot_upkeep(carrier)
		var net := total_revenue - total_costs - slot_upkeep
		carrier.cash += net

		result[carrier.id] = {
			"routes": route_summaries,
			"total_revenue": total_revenue,
			"total_costs": total_costs,
			"slot_upkeep": slot_upkeep,
			"net": net,
			"cash_after": carrier.cash,
			"bankrupt": carrier.cash <= 0.0,
		}

	return result


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _find_ship(carrier: CarrierData, ship_id: String) -> ShipCatalog.ShipInstance:
	for ship: ShipCatalog.ShipInstance in carrier.ships:
		if ship.id == ship_id:
			return ship
	return null
