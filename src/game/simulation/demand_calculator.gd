class_name DemandCalculator
extends RefCounted

## Static utility for demand math — pricing anchors, price factors, demand splitting.
## No state. All methods are static.


static func calculate_suggested_price(lane: GalaxyData.Lane, demand_type: String) -> float:
	var base := (lane.distance / 0.6) * 1.5
	if demand_type == "cargo":
		return base * 0.8  # cargo priced slightly below passenger
	return base


static func calculate_price_factor(price: float, suggested_price: float) -> float:
	if suggested_price <= 0.0:
		return 1.0
	return clampf(1.0 - (price - suggested_price) / suggested_price, 0.05, 1.5)


static func calculate_demand_split(
	routes_on_lane: Array,
	direction: String,
	demand_entry: DemandData.DemandEntry,
	carriers: Array,
	catalog: ShipCatalog,
	suggested_passenger_price: float,
	suggested_cargo_price: float,
	lane_origin_id: String = "",
) -> Dictionary:
	# Returns { carrier_id: { "passengers_served": int, "cargo_served": int } }
	var result: Dictionary = {}

	# Collect participating routes and their weighted shares
	var route_data: Array = []  # [{ carrier, route, pax_weight, cargo_weight, pax_cap, cargo_cap }]
	var total_pax_weight := 0.0
	var total_cargo_weight := 0.0

	for carrier: CarrierData in carriers:
		for route: CarrierData.Route in routes_on_lane:
			if not _route_matches_carrier(route, carrier):
				continue
			if not route.active:
				continue
			if not _route_serves_direction(route, direction, lane_origin_id):
				continue

			var capacity := RouteValidator.get_route_capacity(route, carrier, catalog)
			var pax_cap: int = capacity["passenger"]
			var cargo_cap: int = capacity["cargo"]

			var pax_factor := calculate_price_factor(route.passenger_price, suggested_passenger_price)
			var cargo_factor := calculate_price_factor(route.cargo_price, suggested_cargo_price)

			var pax_weight := pax_cap * pax_factor
			var cargo_weight := cargo_cap * cargo_factor

			total_pax_weight += pax_weight
			total_cargo_weight += cargo_weight

			route_data.append({
				"carrier_id": carrier.id,
				"pax_weight": pax_weight,
				"cargo_weight": cargo_weight,
				"pax_cap": pax_cap,
				"cargo_cap": cargo_cap,
				"pax_factor": pax_factor,
				"cargo_factor": cargo_factor,
			})

	if route_data.is_empty():
		return result

	var effective_pax := demand_entry.base_demand_passenger * demand_entry.modifier_passenger
	var effective_cargo := demand_entry.base_demand_cargo * demand_entry.modifier_cargo

	for rd: Dictionary in route_data:
		var cid: String = rd["carrier_id"]
		if not result.has(cid):
			result[cid] = { "passengers_served": 0, "cargo_served": 0 }

		# Proportional split, capped by capacity AND by price-adjusted demand
		var pax_share := 0
		if total_pax_weight > 0.0:
			var raw_share := int(effective_pax * rd["pax_weight"] / total_pax_weight)
			var demand_at_price := int(effective_pax * rd["pax_factor"])
			pax_share = mini(mini(raw_share, rd["pax_cap"]), demand_at_price)

		var cargo_share := 0
		if total_cargo_weight > 0.0:
			var raw_share := int(effective_cargo * rd["cargo_weight"] / total_cargo_weight)
			var demand_at_price := int(effective_cargo * rd["cargo_factor"])
			cargo_share = mini(mini(raw_share, rd["cargo_cap"]), demand_at_price)

		result[cid]["passengers_served"] += pax_share
		result[cid]["cargo_served"] += cargo_share

	return result


static func get_demand_tier(base_demand: int) -> String:
	if base_demand < 30:
		return "Low"
	if base_demand <= 70:
		return "Medium"
	return "High"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _route_matches_carrier(route: CarrierData.Route, carrier: CarrierData) -> bool:
	for r: CarrierData.Route in carrier.routes:
		if r.id == route.id:
			return true
	return false


static func _route_serves_direction(
	route: CarrierData.Route,
	direction: String,
	lane_origin_id: String,
) -> bool:
	# "forward" = route departs from the lane's origin planet.
	# "reverse" = route departs from the lane's dest planet.
	if direction == "forward":
		return route.origin_id == lane_origin_id
	return route.origin_id != lane_origin_id
