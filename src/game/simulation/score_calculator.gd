class_name ScoreCalculator
extends RefCounted

## Static utility for computing composite company value.
## Score = cash + ship_assets + slot_value + route_value (D002: symmetric across all carriers).

const BASE_SLOT_VALUE := 2000.0
const ROUTE_MULTIPLIER := 5.0
const ESTIMATED_FILL_RATE := 0.5


static func calculate_score(carrier: CarrierData, catalog: ShipCatalog, galaxy: GalaxyData = null) -> Dictionary:
	var cash_value := carrier.cash

	var ship_assets := _calculate_ship_assets(carrier, catalog)
	var slot_value := _calculate_slot_value(carrier)
	var route_value := _calculate_route_value(carrier, catalog, galaxy)

	return {
		"total": cash_value + ship_assets + slot_value + route_value,
		"cash": cash_value,
		"ship_assets": ship_assets,
		"slot_value": slot_value,
		"route_value": route_value,
	}


static func determine_winner(carriers: Array, catalog: ShipCatalog, galaxy: GalaxyData = null) -> CarrierData:
	var best_carrier: CarrierData = null
	var best_score := -1.0

	for carrier: CarrierData in carriers:
		var score := calculate_score(carrier, catalog, galaxy)["total"] as float
		if score > best_score:
			best_score = score
			best_carrier = carrier

	return best_carrier


static func get_rankings(carriers: Array, catalog: ShipCatalog, galaxy: GalaxyData = null) -> Array:
	var entries: Array = []

	for carrier: CarrierData in carriers:
		var breakdown := calculate_score(carrier, catalog, galaxy)
		entries.append({
			"carrier_id": carrier.id,
			"carrier_name": carrier.carrier_name,
			"score": breakdown["total"],
			"cash_score": breakdown["cash"],
			"ship_score": breakdown["ship_assets"],
			"slot_score": breakdown["slot_value"],
			"route_score": breakdown["route_value"],
			"rank": 0,
		})

	# Sort descending by score; stable sort preserves insertion order for ties (D004)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)

	for i: int in entries.size():
		entries[i]["rank"] = i + 1

	return entries


# ---------------------------------------------------------------------------
# Component calculators
# ---------------------------------------------------------------------------

static func _calculate_ship_assets(carrier: CarrierData, catalog: ShipCatalog) -> float:
	var total := 0.0
	for ship: ShipCatalog.ShipInstance in carrier.ships:
		var ship_type := catalog.get_type(ship.type_id)
		if ship_type != null:
			total += ship_type.cost
	for ship: ShipCatalog.ShipInstance in carrier.pending_orders:
		var ship_type := catalog.get_type(ship.type_id)
		if ship_type != null:
			total += ship_type.cost
	return total


static func _calculate_slot_value(carrier: CarrierData) -> float:
	var total_slots := 0
	for count: int in carrier.slots.values():
		total_slots += count
	return total_slots * BASE_SLOT_VALUE


static func _calculate_route_value(carrier: CarrierData, catalog: ShipCatalog, galaxy: GalaxyData = null) -> float:
	var total := 0.0
	var ship_index := _build_ship_index(carrier)

	for route: CarrierData.Route in carrier.routes:
		if not route.active:
			continue
		total += _estimate_route_revenue(route, ship_index, galaxy) * ROUTE_MULTIPLIER

	return total


static func _estimate_route_revenue(route: CarrierData.Route, ship_index: Dictionary, galaxy: GalaxyData = null) -> float:
	var total_passenger_cap := 0
	var total_cargo_cap := 0

	for ship_id: String in route.ship_ids:
		var ship: ShipCatalog.ShipInstance = ship_index.get(ship_id)
		if ship == null:
			continue
		total_passenger_cap += ship.passenger_capacity
		total_cargo_cap += ship.cargo_capacity

	# Use price-adjusted fill rate when galaxy data is available
	var pax_fill := ESTIMATED_FILL_RATE
	var cargo_fill := ESTIMATED_FILL_RATE
	if galaxy != null:
		var lane := galaxy.get_lane(route.origin_id, route.dest_id)
		if lane:
			var suggested_pax := DemandCalculator.calculate_suggested_price(lane, "passenger")
			var suggested_cargo := DemandCalculator.calculate_suggested_price(lane, "cargo")
			pax_fill = DemandCalculator.calculate_price_factor(route.passenger_price, suggested_pax)
			cargo_fill = DemandCalculator.calculate_price_factor(route.cargo_price, suggested_cargo)

	var passenger_revenue := total_passenger_cap * route.passenger_price * pax_fill
	var cargo_revenue := total_cargo_cap * route.cargo_price * cargo_fill
	return route.frequency * (passenger_revenue + cargo_revenue)


static func _build_ship_index(carrier: CarrierData) -> Dictionary:
	var index: Dictionary = {}
	for ship: ShipCatalog.ShipInstance in carrier.ships:
		index[ship.id] = ship
	return index
