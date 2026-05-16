class_name RouteValidator
extends RefCounted

## Static utility for validating route creation/modification and calculating frequency.
## No state — all methods are static.


static func validate_route_creation(
	carrier: CarrierData,
	galaxy: GalaxyData,
	catalog: ShipCatalog,
	lane_id: String,
	origin_id: String,
	dest_id: String,
	ship_ids: Array,
	frequency: int,
	current_turn: int,
) -> Dictionary:
	if not carrier.has_slots_at(origin_id):
		return _fail("Carrier has no slots at origin planet '%s'" % origin_id)

	if not carrier.has_slots_at(dest_id):
		return _fail("Carrier has no slots at destination planet '%s'" % dest_id)

	var lane := galaxy.get_lane(origin_id, dest_id)
	if lane == null:
		return _fail("No lane exists between '%s' and '%s'" % [origin_id, dest_id])

	var assigned_ids := _get_assigned_ship_ids(carrier, "")
	var ship_error := _validate_ships(carrier, catalog, ship_ids, lane.distance, assigned_ids, current_turn)
	if ship_error != "":
		return _fail(ship_error)

	var max_freq := calculate_max_frequency(ship_ids)
	var clamped := mini(frequency, max_freq)

	return { "valid": true, "reason": "", "clamped_frequency": clamped }


static func validate_route_modification(
	carrier: CarrierData,
	galaxy: GalaxyData,
	catalog: ShipCatalog,
	route: CarrierData.Route,
	new_ship_ids: Array,
	new_frequency: int,
	_new_passenger_price: float,
	_new_cargo_price: float,
	current_turn: int,
) -> Dictionary:
	if not carrier.has_slots_at(route.origin_id):
		return _fail("Carrier has no slots at origin planet '%s'" % route.origin_id)

	if not carrier.has_slots_at(route.dest_id):
		return _fail("Carrier has no slots at destination planet '%s'" % route.dest_id)

	var lane := galaxy.get_lane(route.origin_id, route.dest_id)
	if lane == null:
		return _fail("No lane exists between '%s' and '%s'" % [route.origin_id, route.dest_id])

	# Ships on THIS route are considered available (they'd be freed on reassignment)
	var assigned_ids := _get_assigned_ship_ids(carrier, route.id)
	var ship_error := _validate_ships(carrier, catalog, new_ship_ids, lane.distance, assigned_ids, current_turn)
	if ship_error != "":
		return _fail(ship_error)

	var max_freq := calculate_max_frequency(new_ship_ids)
	var clamped := mini(new_frequency, max_freq)

	return { "valid": true, "reason": "", "clamped_frequency": clamped }


static func calculate_max_frequency(ship_ids: Array) -> int:
	return ship_ids.size()


static func get_route_capacity(
	route: CarrierData.Route,
	carrier: CarrierData,
	catalog: ShipCatalog,
) -> Dictionary:
	var total_passenger := 0
	var total_cargo := 0

	for ship_id: String in route.ship_ids:
		var ship := _find_ship(carrier, ship_id)
		if ship == null:
			continue
		total_passenger += ship.passenger_capacity
		total_cargo += ship.cargo_capacity

	return {
		"passenger": total_passenger * route.frequency,
		"cargo": total_cargo * route.frequency,
	}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _fail(reason: String) -> Dictionary:
	return { "valid": false, "reason": reason, "clamped_frequency": 0 }


static func _find_ship(carrier: CarrierData, ship_id: String) -> ShipCatalog.ShipInstance:
	for ship: ShipCatalog.ShipInstance in carrier.ships:
		if ship.id == ship_id:
			return ship
	return null


static func _get_assigned_ship_ids(carrier: CarrierData, exclude_route_id: String) -> Dictionary:
	var assigned: Dictionary = {}
	for route: CarrierData.Route in carrier.routes:
		if not route.active:
			continue
		if route.id == exclude_route_id:
			continue
		for ship_id: String in route.ship_ids:
			assigned[ship_id] = true
	return assigned


static func _validate_ships(
	carrier: CarrierData,
	catalog: ShipCatalog,
	ship_ids: Array,
	lane_distance: float,
	assigned_ids: Dictionary,
	current_turn: int,
) -> String:
	for ship_id: String in ship_ids:
		var ship := _find_ship(carrier, ship_id)
		if ship == null:
			return "Ship '%s' not found in carrier's fleet" % ship_id

		var ship_type := catalog.get_type(ship.type_id)
		if ship_type == null:
			return "Unknown ship type '%s' for ship '%s'" % [ship.type_id, ship_id]

		if ship_type.range < lane_distance:
			return "Ship '%s' range (%.1f) insufficient for lane distance (%.1f)" % [ship_id, ship_type.range, lane_distance]

		if assigned_ids.has(ship_id):
			return "Ship '%s' is already assigned to another active route" % ship_id

		if ship.available_turn > current_turn:
			return "Ship '%s' not yet delivered (available turn %d, current turn %d)" % [ship_id, ship.available_turn, current_turn]

	return ""
