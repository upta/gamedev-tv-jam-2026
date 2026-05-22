extends GutTest

# ---------------------------------------------------------------------------
# Factory tests — create_default_carriers()
# ---------------------------------------------------------------------------

func test_default_carriers_count() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	assert_eq(carriers.size(), 4, "Should create 4 carriers")


func test_default_carrier_ids() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	var ids: Array[String] = []
	for c in carriers:
		ids.append(c.id)
	assert_true(ids.has("player"), "Should have player carrier")
	assert_true(ids.has("npc_1"), "Should have npc_1 carrier")
	assert_true(ids.has("npc_2"), "Should have npc_2 carrier")
	assert_true(ids.has("npc_3"), "Should have npc_3 carrier")


func test_default_carriers_each_have_30000_cash() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	for carrier: CarrierData in carriers:
		assert_almost_eq(carrier.cash, 30000.0, 0.01, "%s should have 30000 cash" % carrier.id)


func test_default_carriers_each_have_2_slots() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	for carrier: CarrierData in carriers:
		var slot_total := 0
		for planet_id in carrier.slots:
			slot_total += carrier.slots[planet_id]
		assert_eq(slot_total, 2, "%s should have 2 total slots" % carrier.id)


func test_default_carriers_each_have_1_ship() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	for carrier: CarrierData in carriers:
		assert_eq(carrier.ships.size(), 1, "%s should have 1 ship" % carrier.id)


func test_default_player_carrier_slots_at_earth_and_mars() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	var player: CarrierData = null
	for c in carriers:
		if c.id == "player":
			player = c
			break
	assert_not_null(player)
	assert_true(player.has_slots_at("earth"), "Player should have a slot at Earth")
	assert_true(player.has_slots_at("mars"), "Player should have a slot at Mars")


func test_default_npcs_share_earth_and_unique_home_slots() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	var expected_slots := {
		"npc_1": ["earth", "europa"],
		"npc_2": ["earth", "titan"],
		"npc_3": ["earth", "mars"],
	}
	for carrier: CarrierData in carriers:
		if not expected_slots.has(carrier.id):
			continue
		for planet_id: String in expected_slots[carrier.id]:
			assert_true(carrier.has_slots_at(planet_id), "%s should have a slot at %s" % [carrier.id, planet_id])


# ---------------------------------------------------------------------------
# get_slot_count() / has_slots_at()
# ---------------------------------------------------------------------------

func test_get_slot_count_returns_count() -> void:
	var carrier := _make_carrier()
	assert_eq(carrier.get_slot_count("planet_a"), 2)


func test_get_slot_count_returns_0_for_unknown() -> void:
	var carrier := _make_carrier()
	assert_eq(carrier.get_slot_count("unknown_planet"), 0, "Unknown planet should return 0")


func test_has_slots_at_true_when_slots_exist() -> void:
	var carrier := _make_carrier()
	assert_true(carrier.has_slots_at("planet_a"))


func test_has_slots_at_false_when_no_slots() -> void:
	var carrier := _make_carrier()
	assert_false(carrier.has_slots_at("unknown_planet"))


# ---------------------------------------------------------------------------
# get_routes() / get_active_routes()
# ---------------------------------------------------------------------------

func test_get_routes_returns_all() -> void:
	var carrier := _make_carrier_with_routes()
	assert_eq(carrier.get_routes().size(), 3, "Should return all 3 routes")


func test_get_active_routes_excludes_inactive() -> void:
	var carrier := _make_carrier_with_routes()
	var active := carrier.get_active_routes()
	assert_eq(active.size(), 2, "Should return only 2 active routes")
	for route: CarrierData.Route in active:
		assert_true(route.active, "All returned routes should be active")


func test_get_active_routes_empty_when_none_active() -> void:
	var carrier := _make_carrier()
	var route := CarrierData.Route.new("r1", "a", "b", [], 10.0, 5.0, 1, false)
	carrier.routes.append(route)
	assert_eq(carrier.get_active_routes().size(), 0, "No active routes when all inactive")


func test_get_active_routes_empty_carrier() -> void:
	var carrier := CarrierData.new()
	assert_eq(carrier.get_active_routes().size(), 0, "Empty carrier has no active routes")


# ---------------------------------------------------------------------------
# get_available_ships()
# ---------------------------------------------------------------------------

func test_get_available_ships_all_available_when_no_routes() -> void:
	var carrier := _make_carrier()
	var available := carrier.get_available_ships()
	assert_eq(available.size(), carrier.ships.size(), "All ships available when no routes")


func test_get_available_ships_excludes_assigned() -> void:
	var carrier := _make_carrier_with_routes()
	var available := carrier.get_available_ships()
	# ship_a assigned to active route r1, ship_b assigned to active route r2
	# ship_c is not assigned to any active route (r3 is inactive)
	assert_eq(available.size(), 1, "Only ship_c should be available")
	assert_eq(available[0].id, "ship_c")


func test_get_available_ships_inactive_route_does_not_reserve() -> void:
	var carrier := _make_carrier()
	var ship := _make_ship("ship_x", "type_x", "owner")
	carrier.ships.append(ship)
	var route := CarrierData.Route.new("r1", "a", "b", ["ship_x"], 10.0, 5.0, 1, false)
	carrier.routes.append(route)
	var available := carrier.get_available_ships()
	var ids: Array[String] = []
	for s in available:
		ids.append(s.id)
	assert_true(ids.has("ship_x"), "Ship on inactive route should be available")


# ---------------------------------------------------------------------------
# total_ship_count()
# ---------------------------------------------------------------------------

func test_total_ship_count_ships_only() -> void:
	var carrier := _make_carrier()
	assert_eq(carrier.total_ship_count(), 2, "2 ships, 0 pending")


func test_total_ship_count_includes_pending() -> void:
	var carrier := _make_carrier()
	carrier.pending_orders.append(_make_ship("pending_1", "type", "owner"))
	assert_eq(carrier.total_ship_count(), 3, "2 ships + 1 pending = 3")


func test_total_ship_count_empty_carrier() -> void:
	var carrier := CarrierData.new()
	assert_eq(carrier.total_ship_count(), 0, "Empty carrier has 0 ships")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_fresh_carrier_has_no_ships() -> void:
	var carrier := CarrierData.new()
	assert_eq(carrier.ships.size(), 0)
	assert_eq(carrier.pending_orders.size(), 0)
	assert_eq(carrier.routes.size(), 0)


func test_fresh_carrier_slots_empty() -> void:
	var carrier := CarrierData.new()
	assert_eq(carrier.slots.size(), 0)
	assert_false(carrier.has_slots_at("anywhere"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_ship(p_id: String, p_type_id: String, p_owner_id: String) -> ShipCatalog.ShipInstance:
	return ShipCatalog.ShipInstance.new(p_id, p_type_id, 25, 25, p_owner_id, 0)


func _make_carrier() -> CarrierData:
	var carrier := CarrierData.new()
	carrier.id = "test_carrier"
	carrier.carrier_name = "Test Carrier"
	carrier.cash = 5000.0
	carrier.slots["planet_a"] = 2
	carrier.slots["planet_b"] = 1
	carrier.ships.append(_make_ship("ship_a", "type_a", "test_carrier"))
	carrier.ships.append(_make_ship("ship_b", "type_b", "test_carrier"))
	return carrier


func _make_carrier_with_routes() -> CarrierData:
	var carrier := _make_carrier()
	carrier.ships.append(_make_ship("ship_c", "type_c", "test_carrier"))

	# Two active routes, one inactive
	var r1 := CarrierData.Route.new("r1", "a", "b", ["ship_a"], 10.0, 5.0, 1, true)
	var r2 := CarrierData.Route.new("r2", "b", "c", ["ship_b"], 8.0, 4.0, 2, true)
	var r3 := CarrierData.Route.new("r3", "c", "d", ["ship_c"], 6.0, 3.0, 1, false)
	carrier.routes.append(r1)
	carrier.routes.append(r2)
	carrier.routes.append(r3)
	return carrier
