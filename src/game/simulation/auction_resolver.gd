class_name AuctionResolver
extends RefCounted

## Static utility for resolving blind slot auctions and processing slot sales.
## Returns results only — never mutates CarrierData directly (D001).


static func resolve_auctions(
	bids: Array,
	galaxy: GalaxyData,
	carriers: Array,
	carrier_order: Array
) -> Dictionary:
	var awards: Array = []
	var rejections: Array = []

	var bids_by_planet: Dictionary = {}
	for bid: Dictionary in bids:
		var pid: String = bid["planet_id"]
		if not bids_by_planet.has(pid):
			bids_by_planet[pid] = []
		bids_by_planet[pid].append(bid)

	for planet_id: String in bids_by_planet:
		var planet_bids: Array = bids_by_planet[planet_id]
		var available: int = get_available_slots(planet_id, galaxy, carriers)

		planet_bids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["price_per_slot"] != b["price_per_slot"]:
				return a["price_per_slot"] > b["price_per_slot"]
			var idx_a: int = carrier_order.find(a["carrier_id"])
			var idx_b: int = carrier_order.find(b["carrier_id"])
			return idx_a < idx_b
		)

		var remaining: int = available
		for bid: Dictionary in planet_bids:
			if remaining <= 0:
				rejections.append({
					"carrier_id": bid["carrier_id"],
					"planet_id": planet_id,
					"reason": "No slots available"
				})
				continue

			var slots_to_award: int = mini(bid["quantity"], remaining)
			var cost: float = slots_to_award * bid["price_per_slot"]

			var carrier: CarrierData = _find_carrier(bid["carrier_id"], carriers)
			if carrier == null:
				rejections.append({
					"carrier_id": bid["carrier_id"],
					"planet_id": planet_id,
					"reason": "Carrier not found"
				})
				continue

			if carrier.cash < cost:
				rejections.append({
					"carrier_id": bid["carrier_id"],
					"planet_id": planet_id,
					"reason": "Insufficient funds"
				})
				continue

			awards.append({
				"carrier_id": bid["carrier_id"],
				"planet_id": planet_id,
				"slots_won": slots_to_award,
				"cost": cost
			})
			remaining -= slots_to_award

	return { "awards": awards, "rejections": rejections }


static func process_slot_sale(
	carrier: CarrierData,
	planet_id: String,
	quantity: int
) -> Dictionary:
	var owned: int = carrier.get_slot_count(planet_id)
	if owned < quantity:
		return {
			"success": false,
			"reason": "Carrier owns %d slots at %s but tried to sell %d" % [owned, planet_id, quantity],
			"slots_freed": 0
		}

	var routes_needing_slots: Array[String] = []
	var slots_used_by_routes: int = 0
	for route: CarrierData.Route in carrier.get_active_routes():
		if route.origin_id == planet_id or route.dest_id == planet_id:
			slots_used_by_routes += 1
			routes_needing_slots.append(route.id)

	var slots_after_sale: int = owned - quantity
	if slots_after_sale < slots_used_by_routes:
		return {
			"success": false,
			"reason": "Cannot sell — %d active route(s) require slots at %s: %s. Cancel these routes first." % [
				routes_needing_slots.size(), planet_id, ", ".join(routes_needing_slots)
			],
			"slots_freed": 0
		}

	return { "success": true, "reason": "", "slots_freed": quantity }


static func get_available_slots(
	planet_id: String,
	galaxy: GalaxyData,
	carriers: Array
) -> int:
	var planet: GalaxyData.Planet = galaxy.get_planet(planet_id)
	if planet == null:
		return 0

	var occupied: int = 0
	for carrier: CarrierData in carriers:
		occupied += carrier.get_slot_count(planet_id)

	return planet.total_slots - occupied


static func _find_carrier(carrier_id: String, carriers: Array) -> CarrierData:
	for carrier: CarrierData in carriers:
		if carrier.id == carrier_id:
			return carrier
	return null
