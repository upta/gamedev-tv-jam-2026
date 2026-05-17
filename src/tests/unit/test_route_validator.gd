extends GutTest

## Unit tests for RouteValidator — route creation, modification, capacity, and frequency.

var galaxy: GalaxyData
var catalog: ShipCatalog


func before_each() -> void:
	galaxy = GalaxyData.new()
	galaxy.planets.append(GalaxyData.Planet.new("earth", "Earth", "sol", 10, Vector2(0.0, 0.0)))
	galaxy.planets.append(GalaxyData.Planet.new("mars", "Mars", "sol", 8, Vector2(1.2, -0.8)))
	galaxy.planets.append(GalaxyData.Planet.new("proxima_b", "Proxima b", "alpha_centauri", 6, Vector2(7.0, 2.5)))
	galaxy._build_indices()

	catalog = ShipCatalog.create_default_catalog()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_carrier(id: String = "test") -> CarrierData:
	var c := CarrierData.new()
	c.id = id
	c.carrier_name = id.capitalize()
	c.cash = 5000.0
	c.slots["earth"] = 2
	c.slots["mars"] = 1
	return c


func _add_ship(carrier: CarrierData, type_id: String = "sd-100", pax: int = 20, cargo: int = 20, avail_turn: int = -2) -> ShipCatalog.ShipInstance:
	var ship := catalog.create_ship_instance(type_id, pax, cargo, carrier.id, avail_turn)
	carrier.ships.append(ship)
	return ship


func _add_active_route(carrier: CarrierData, ship_ids: Array[String], origin: String = "earth", dest: String = "mars") -> CarrierData.Route:
	var route := CarrierData.Route.new(
		"route_%d" % carrier.routes.size(),
		origin,
		dest,
		ship_ids,
		10.0,
		5.0,
		1,
		true,
	)
	carrier.routes.append(route)
	return route


# ---------------------------------------------------------------------------
# validate_route_creation — happy path
# ---------------------------------------------------------------------------

func test_valid_creation() -> void:
	var carrier := _make_carrier()
	var ship := _add_ship(carrier)

	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "mars",
		[ship.id], 1, 1,
	)
	assert_true(result["valid"], "valid route creation")
	assert_eq(result["clamped_frequency"], 1, "frequency preserved")


# ---------------------------------------------------------------------------
# validate_route_creation — failure cases
# ---------------------------------------------------------------------------

func test_creation_fails_no_slots_at_origin() -> void:
	var carrier := _make_carrier()
	carrier.slots.erase("earth")
	var ship := _add_ship(carrier)

	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "mars",
		[ship.id], 1, 1,
	)
	assert_false(result["valid"], "no origin slots")
	assert_true(result["reason"].contains("origin"), "reason mentions origin")


func test_creation_fails_no_slots_at_dest() -> void:
	var carrier := _make_carrier()
	carrier.slots.erase("mars")
	var ship := _add_ship(carrier)

	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "mars",
		[ship.id], 1, 1,
	)
	assert_false(result["valid"], "no dest slots")
	assert_true(result["reason"].contains("destination"), "reason mentions destination")


func test_creation_fails_no_lane() -> void:
	var carrier := _make_carrier()
	carrier.slots["nonexistent"] = 1
	var ship := _add_ship(carrier)

	# nonexistent planet has no position in the galaxy
	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"mars", "nonexistent",
		[ship.id], 1, 1,
	)
	assert_false(result["valid"], "no lane")
	assert_true(result["reason"].contains("lane"), "reason mentions lane")


func test_creation_fails_insufficient_range() -> void:
	var carrier := _make_carrier()
	carrier.slots["proxima_b"] = 1
	# SD-100 range = 5.0, earth-proxima_b distance = 8.0
	var ship := _add_ship(carrier, "sd-100")

	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "proxima_b",
		[ship.id], 1, 1,
	)
	assert_false(result["valid"], "range too short")
	assert_true(result["reason"].contains("range"), "reason mentions range")


func test_creation_fails_ship_already_assigned() -> void:
	var carrier := _make_carrier()
	var ship := _add_ship(carrier)

	# Assign ship to existing route first
	var ship_ids: Array[String] = [ship.id]
	_add_active_route(carrier, ship_ids)

	# Try to use same ship on a new route
	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "mars",
		[ship.id], 1, 1,
	)
	assert_false(result["valid"], "ship already assigned")
	assert_true(result["reason"].contains("assigned"), "reason mentions assigned")


func test_creation_fails_ship_not_delivered() -> void:
	var carrier := _make_carrier()
	# Ship available at turn 10, current turn = 1
	var ship := _add_ship(carrier, "sd-100", 20, 20, 8)  # build_turns=2 → available at 10

	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "mars",
		[ship.id], 1, 1,
	)
	assert_false(result["valid"], "ship not yet delivered")
	assert_true(result["reason"].contains("delivered"), "reason mentions delivery")


func test_creation_fails_ship_not_owned() -> void:
	var carrier := _make_carrier()
	# Don't add any ship — just reference a non-existent ID

	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "mars",
		["phantom_ship"], 1, 1,
	)
	assert_false(result["valid"], "ship not found")
	assert_true(result["reason"].contains("not found"), "reason mentions not found")


# ---------------------------------------------------------------------------
# validate_route_creation — frequency clamping
# ---------------------------------------------------------------------------

func test_frequency_clamped_to_ship_count() -> void:
	var carrier := _make_carrier()
	var ship := _add_ship(carrier)

	# Request frequency 5 with only 1 ship
	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "mars",
		[ship.id], 5, 1,
	)
	assert_true(result["valid"], "valid but clamped")
	assert_eq(result["clamped_frequency"], 1, "clamped to 1 ship")


func test_frequency_not_clamped_when_enough_ships() -> void:
	var carrier := _make_carrier()
	var ship1 := _add_ship(carrier)
	var ship2 := _add_ship(carrier)
	var ship3 := _add_ship(carrier)

	var result := RouteValidator.validate_route_creation(
		carrier, galaxy, catalog,
		"earth", "mars",
		[ship1.id, ship2.id, ship3.id], 2, 1,
	)
	assert_true(result["valid"], "valid")
	assert_eq(result["clamped_frequency"], 2, "freq 2 ≤ 3 ships, no clamp")


# ---------------------------------------------------------------------------
# validate_route_modification
# ---------------------------------------------------------------------------

func test_modification_valid() -> void:
	var carrier := _make_carrier()
	var ship := _add_ship(carrier)
	var ship_ids: Array[String] = [ship.id]
	var route := _add_active_route(carrier, ship_ids)

	# Modify with same ship — should be valid because ship on THIS route is available
	var result := RouteValidator.validate_route_modification(
		carrier, galaxy, catalog,
		route, [ship.id], 1, 10.0, 5.0, 1,
	)
	assert_true(result["valid"], "ship on this route is available for reassignment")


func test_modification_ships_on_other_routes_blocked() -> void:
	var carrier := _make_carrier()
	var ship1 := _add_ship(carrier)
	var ship2 := _add_ship(carrier)

	# ship1 on route A
	var ids1: Array[String] = [ship1.id]
	_add_active_route(carrier, ids1)

	# ship2 on route B
	var ids2: Array[String] = [ship2.id]
	var route_b := _add_active_route(carrier, ids2)

	# Try to modify route B to use ship1 (which is on route A)
	var result := RouteValidator.validate_route_modification(
		carrier, galaxy, catalog,
		route_b, [ship1.id], 1, 10.0, 5.0, 1,
	)
	assert_false(result["valid"], "ship on another route blocked")


func test_modification_clamps_frequency() -> void:
	var carrier := _make_carrier()
	var ship := _add_ship(carrier)
	var ship_ids: Array[String] = [ship.id]
	var route := _add_active_route(carrier, ship_ids)

	var result := RouteValidator.validate_route_modification(
		carrier, galaxy, catalog,
		route, [ship.id], 5, 10.0, 5.0, 1,
	)
	assert_true(result["valid"], "valid but clamped")
	assert_eq(result["clamped_frequency"], 1, "clamped to 1 ship")


# ---------------------------------------------------------------------------
# calculate_max_frequency
# ---------------------------------------------------------------------------

func test_max_frequency_equals_ship_count() -> void:
	assert_eq(RouteValidator.calculate_max_frequency(["a", "b", "c"]), 3, "3 ships → freq 3")


func test_max_frequency_single_ship() -> void:
	assert_eq(RouteValidator.calculate_max_frequency(["a"]), 1, "1 ship → freq 1")


func test_max_frequency_empty() -> void:
	assert_eq(RouteValidator.calculate_max_frequency([]), 0, "no ships → freq 0")


# ---------------------------------------------------------------------------
# get_route_capacity
# ---------------------------------------------------------------------------

func test_route_capacity_single_ship() -> void:
	var carrier := _make_carrier()
	var ship := _add_ship(carrier, "sd-100", 25, 15)  # pax=25, cargo=15
	var ship_ids: Array[String] = [ship.id]
	var route := _add_active_route(carrier, ship_ids)
	route.frequency = 1

	var cap := RouteValidator.get_route_capacity(route, carrier, catalog)
	assert_eq(cap["passenger"], 25, "25 pax × freq 1")
	assert_eq(cap["cargo"], 15, "15 cargo × freq 1")


func test_route_capacity_multiple_ships() -> void:
	var carrier := _make_carrier()
	var ship1 := _add_ship(carrier, "sd-100", 20, 20)
	var ship2 := _add_ship(carrier, "sd-100", 30, 10)
	var ship_ids: Array[String] = [ship1.id, ship2.id]
	var route := _add_active_route(carrier, ship_ids)
	route.frequency = 1

	var cap := RouteValidator.get_route_capacity(route, carrier, catalog)
	assert_eq(cap["passenger"], 50, "20 + 30 = 50 pax")
	assert_eq(cap["cargo"], 30, "20 + 10 = 30 cargo")


func test_route_capacity_with_frequency() -> void:
	var carrier := _make_carrier()
	var ship := _add_ship(carrier, "sd-100", 20, 20)
	var ship_ids: Array[String] = [ship.id]
	var route := _add_active_route(carrier, ship_ids)
	route.frequency = 3

	var cap := RouteValidator.get_route_capacity(route, carrier, catalog)
	assert_eq(cap["passenger"], 60, "20 pax × freq 3 = 60")
	assert_eq(cap["cargo"], 60, "20 cargo × freq 3 = 60")


func test_route_capacity_empty_ships() -> void:
	var carrier := _make_carrier()
	var empty_ids: Array[String] = []
	var route := _add_active_route(carrier, empty_ids)
	route.frequency = 1

	var cap := RouteValidator.get_route_capacity(route, carrier, catalog)
	assert_eq(cap["passenger"], 0, "no ships → 0 pax")
	assert_eq(cap["cargo"], 0, "no ships → 0 cargo")
