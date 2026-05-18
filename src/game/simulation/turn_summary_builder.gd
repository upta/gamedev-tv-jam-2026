class_name TurnSummaryBuilder
extends RefCounted

## Pure data utility that extracts per-carrier turn summaries from a TurnResult.
## No UI, no scene references — fully unit-testable.


class CarrierTurnSummary:
	var carrier_id: String
	var carrier_name: String
	var cash_before: float
	var cash_after: float
	var actions: Array[String]
	var slots_won: Array  # [{planet_id, count}]
	var slots_lost: Array  # [{planet_id}]
	var slots_sold: Array  # [{planet_id, count}]
	var routes_created: Array  # [{origin_id, dest_id}]
	var routes_cancelled: Array  # [{route_id}]
	var routes_modified: Array  # [{route_id}]
	var ships_ordered: Array  # [{type_id, cost}]
	var ships_delivered: Array  # [{type_id, ship_id}]
	var route_financials: Array  # [{route_id, origin_id, dest_id, pax_served, pax_capacity, cargo_served, cargo_capacity, revenue, costs, profit}]
	var total_revenue: float
	var total_costs: float
	var slot_upkeep: float
	var net: float


static func build_summaries(
	result: TurnPipeline.TurnResult,
	game_state: GameState,
	cash_before: Dictionary,
	prev_financials: Dictionary,
) -> Dictionary:
	var summaries: Dictionary = {}

	for carrier: CarrierData in game_state.carriers:
		var summary := CarrierTurnSummary.new()
		summary.carrier_id = carrier.id
		summary.carrier_name = carrier.carrier_name
		summary.cash_before = cash_before.get(carrier.id, 0.0)
		summary.cash_after = carrier.cash
		summary.slots_won = []
		summary.slots_lost = []
		summary.slots_sold = []
		summary.routes_created = []
		summary.routes_cancelled = []
		summary.routes_modified = []
		summary.ships_ordered = []
		summary.ships_delivered = []
		summary.route_financials = []
		summary.actions = []

		# Slot wins
		for award: Dictionary in result.auction_results.get("awards", []):
			if award.get("carrier_id", "") == carrier.id:
				summary.slots_won.append({
					"planet_id": award.get("planet_id", ""),
					"count": award.get("slots_won", 0),
				})

		# Slot losses (rejections)
		for rejection: Dictionary in result.auction_results.get("rejections", []):
			if rejection.get("carrier_id", "") == carrier.id:
				summary.slots_lost.append({
					"planet_id": rejection.get("planet_id", ""),
				})

		# Slot sales
		for sale: Dictionary in result.slot_sales:
			if sale.get("carrier_id", "") == carrier.id:
				summary.slots_sold.append({
					"planet_id": sale.get("planet_id", ""),
					"count": sale.get("count", 0),
				})

		# Route changes
		for change: Dictionary in result.route_changes:
			if change.get("carrier_id", "") != carrier.id:
				continue
			match change.get("type", ""):
				"created":
					var route := _find_route_by_id(carrier, change.get("route_id", ""))
					if route:
						summary.routes_created.append({
							"origin_id": route.origin_id,
							"dest_id": route.dest_id,
							"ship_count": route.ship_ids.size(),
						})
				"cancelled":
					summary.routes_cancelled.append({
						"route_id": change.get("route_id", ""),
					})
				"modified":
					summary.routes_modified.append({
						"route_id": change.get("route_id", ""),
					})

		# Ship orders
		for order: Dictionary in result.ship_orders:
			if order.get("carrier_id", "") == carrier.id:
				summary.ships_ordered.append({
					"type_id": order.get("type_id", ""),
					"cost": order.get("cost", 0.0),
				})

		# Ship deliveries
		for delivery: Dictionary in result.deliveries:
			if delivery.get("carrier_id", "") == carrier.id:
				summary.ships_delivered.append({
					"type_id": delivery.get("type_id", ""),
					"ship_id": delivery.get("ship_id", ""),
				})

		# Route financials
		var fin: Dictionary = result.financials.get(carrier.id, {})
		var route_summaries: Array = fin.get("routes", [])
		for rs: Dictionary in route_summaries:
			var route := _find_route_by_id(carrier, rs.get("route_id", ""))
			if route == null:
				continue
			var rev_dict: Dictionary = rs.get("revenue", {})
			var revenue: float = rev_dict.get("total_revenue", 0.0)
			var costs: float = rs.get("operating_cost", 0.0)
			summary.route_financials.append({
				"route_id": route.id,
				"origin_id": route.origin_id,
				"dest_id": route.dest_id,
				"pax_served": rs.get("passengers_served", 0),
				"pax_capacity": rs.get("passenger_capacity", 0),
				"cargo_served": rs.get("cargo_served", 0),
				"cargo_capacity": rs.get("cargo_capacity", 0),
				"revenue": revenue,
				"costs": costs,
				"profit": revenue - costs,
			})

		summary.total_revenue = fin.get("total_revenue", 0.0)
		summary.total_costs = fin.get("total_costs", 0.0)
		summary.slot_upkeep = fin.get("slot_upkeep", 0.0)
		summary.net = fin.get("net", 0.0)

		# Build human-readable actions
		summary.actions = _build_actions(summary, game_state)

		summaries[carrier.id] = summary

	return summaries


static func _build_actions(summary: CarrierTurnSummary, game_state: GameState) -> Array[String]:
	var actions: Array[String] = []

	for slot: Dictionary in summary.slots_won:
		var planet_name := _get_planet_name(game_state, slot.get("planet_id", ""))
		actions.append("Won %d slot%s at %s" % [
			slot.get("count", 0),
			"s" if slot.get("count", 0) != 1 else "",
			planet_name,
		])

	for slot: Dictionary in summary.slots_lost:
		var planet_name := _get_planet_name(game_state, slot.get("planet_id", ""))
		actions.append("Lost bid at %s" % planet_name)

	for slot: Dictionary in summary.slots_sold:
		var planet_name := _get_planet_name(game_state, slot.get("planet_id", ""))
		actions.append("Sold %d slot%s at %s" % [
			slot.get("count", 0),
			"s" if slot.get("count", 0) != 1 else "",
			planet_name,
		])

	for route: Dictionary in summary.routes_created:
		var origin_name := _get_planet_name(game_state, route.get("origin_id", ""))
		var dest_name := _get_planet_name(game_state, route.get("dest_id", ""))
		var ship_count: int = route.get("ship_count", 0)
		actions.append("Created route %s → %s (%d ship%s)" % [
			origin_name, dest_name, ship_count,
			"s" if ship_count != 1 else "",
		])

	for route: Dictionary in summary.routes_cancelled:
		actions.append("Cancelled a route")

	for route: Dictionary in summary.routes_modified:
		actions.append("Modified a route")

	for order: Dictionary in summary.ships_ordered:
		actions.append("Ordered 1 %s" % order.get("type_id", "ship"))

	for delivery: Dictionary in summary.ships_delivered:
		actions.append("Ship delivered: %s" % delivery.get("type_id", ""))

	return actions


static func _get_planet_name(game_state: GameState, planet_id: String) -> String:
	var planet := game_state.galaxy.get_planet(planet_id)
	if planet:
		return planet.name
	return planet_id


static func _find_route_by_id(carrier: CarrierData, route_id: String) -> CarrierData.Route:
	for route: CarrierData.Route in carrier.routes:
		if route.id == route_id:
			return route
	return null
