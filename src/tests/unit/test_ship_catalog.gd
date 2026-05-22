extends GutTest

# ---------------------------------------------------------------------------
# Factory tests — create_default_catalog()
# ---------------------------------------------------------------------------

func test_default_catalog_has_7_types() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var all_types := catalog.get_available_types(9999)
	assert_eq(all_types.size(), 7, "Default catalog should have 7 ship types")


func test_default_catalog_contains_expected_ids() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var expected_ids := ["sd-100", "sd-300", "sd-500", "sd-900", "fw-10", "fw-50", "fw-70"]
	for type_id in expected_ids:
		assert_not_null(catalog.get_type(type_id), "Catalog should contain type '%s'" % type_id)


# ---------------------------------------------------------------------------
# get_type()
# ---------------------------------------------------------------------------

func test_get_type_returns_correct_type() -> void:
	var catalog := _make_mini_catalog()
	var t := catalog.get_type("test-ship")
	assert_not_null(t, "Should find test-ship type")
	assert_eq(t.name, "Test Ship")
	assert_eq(t.manufacturer, "TestCo")
	assert_almost_eq(t.range, 10.0, 0.001)
	assert_eq(t.max_capacity, 50)
	assert_eq(t.cost, 1000)


func test_get_type_returns_null_for_unknown() -> void:
	var catalog := _make_mini_catalog()
	var t := catalog.get_type("nonexistent")
	assert_null(t, "Unknown type should return null")
	assert_push_error("unknown ship type")


# ---------------------------------------------------------------------------
# get_available_types()
# ---------------------------------------------------------------------------

func test_available_types_at_turn_0() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var available := catalog.get_available_types(0)
	assert_eq(available.size(), 3, "Turn 0 should unlock 3 types (sd-100, sd-300, fw-10)")
	var ids: Array[String] = []
	for t in available:
		ids.append(t.id)
	assert_true(ids.has("sd-100"), "sd-100 should be available at turn 0")
	assert_true(ids.has("sd-300"), "sd-300 should be available at turn 0")
	assert_true(ids.has("fw-10"), "fw-10 should be available at turn 0")


func test_available_types_at_turn_8() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var available := catalog.get_available_types(8)
	assert_eq(available.size(), 4, "Turn 8 should unlock sd-500 in addition to the initial 3")
	var ids: Array[String] = []
	for t in available:
		ids.append(t.id)
	assert_true(ids.has("sd-500"), "sd-500 unlocks at turn 8")


func test_available_types_at_high_turn_returns_all() -> void:
	var catalog := ShipCatalog.create_default_catalog()
	var available := catalog.get_available_types(100)
	assert_eq(available.size(), 7, "All types should be available at a high turn")


func test_available_types_with_custom_catalog() -> void:
	var catalog := _make_mini_catalog()
	assert_eq(catalog.get_available_types(0).size(), 1, "Only unlock_turn=0 type available at turn 0")
	assert_eq(catalog.get_available_types(5).size(), 2, "Both types available at turn 5")


# ---------------------------------------------------------------------------
# create_ship_instance() — valid
# ---------------------------------------------------------------------------

func test_create_ship_instance_returns_valid_instance() -> void:
	var catalog := _make_mini_catalog()
	var ship := catalog.create_ship_instance("test-ship", 30, 20, "owner1", 0)
	assert_not_null(ship, "Valid capacity split should succeed")
	assert_eq(ship.type_id, "test-ship")
	assert_eq(ship.passenger_capacity, 30)
	assert_eq(ship.cargo_capacity, 20)
	assert_eq(ship.owner_id, "owner1")


func test_create_ship_instance_available_turn() -> void:
	var catalog := _make_mini_catalog()
	var ship := catalog.create_ship_instance("test-ship", 25, 25, "owner1", 3)
	assert_not_null(ship)
	# build_turns = 2, current_turn = 3, so available_turn = 4 (delivered during turn 4 resolution)
	assert_eq(ship.available_turn, 4, "available_turn should be current_turn + build_turns - 1")


func test_create_ship_instance_all_passengers() -> void:
	var catalog := _make_mini_catalog()
	var ship := catalog.create_ship_instance("test-ship", 50, 0, "owner1", 0)
	assert_not_null(ship, "All-passenger split should work if it equals max_capacity")
	assert_eq(ship.passenger_capacity, 50)
	assert_eq(ship.cargo_capacity, 0)


func test_create_ship_instance_all_cargo() -> void:
	var catalog := _make_mini_catalog()
	var ship := catalog.create_ship_instance("test-ship", 0, 50, "owner1", 0)
	assert_not_null(ship, "All-cargo split should work if it equals max_capacity")


# ---------------------------------------------------------------------------
# create_ship_instance() — invalid
# ---------------------------------------------------------------------------

func test_create_ship_instance_capacity_mismatch_returns_null() -> void:
	var catalog := _make_mini_catalog()
	var ship := catalog.create_ship_instance("test-ship", 10, 10, "owner1", 0)
	assert_null(ship, "Capacity 10+10=20 != max_capacity 50 should fail")
	assert_push_error("capacity split")


func test_create_ship_instance_over_capacity_returns_null() -> void:
	var catalog := _make_mini_catalog()
	var ship := catalog.create_ship_instance("test-ship", 30, 30, "owner1", 0)
	assert_null(ship, "Capacity 30+30=60 > max_capacity 50 should fail")
	assert_push_error("capacity split")


func test_create_ship_instance_unknown_type_returns_null() -> void:
	var catalog := _make_mini_catalog()
	var ship := catalog.create_ship_instance("no-such-type", 25, 25, "owner1", 0)
	assert_null(ship, "Unknown type should return null")
	assert_push_error("unknown ship type")


# ---------------------------------------------------------------------------
# Instance ID pattern
# ---------------------------------------------------------------------------

func test_instance_id_format() -> void:
	var catalog := _make_mini_catalog()
	var ship := catalog.create_ship_instance("test-ship", 25, 25, "owner1", 0)
	assert_not_null(ship)
	assert_true(
		ship.id.begins_with("test-ship-"),
		"Instance id should start with type_id prefix"
	)
	# Pattern: {type_id}-{4-digit zero-padded counter}
	var suffix := ship.id.substr(len("test-ship-"))
	assert_eq(suffix.length(), 4, "Counter suffix should be 4 digits")
	assert_eq(suffix, "0001", "First instance should be 0001")


func test_instance_ids_increment() -> void:
	var catalog := _make_mini_catalog()
	var ship1 := catalog.create_ship_instance("test-ship", 25, 25, "owner1", 0)
	var ship2 := catalog.create_ship_instance("test-ship", 50, 0, "owner1", 0)
	assert_not_null(ship1)
	assert_not_null(ship2)
	assert_ne(ship1.id, ship2.id, "Each instance should have a unique id")
	assert_true(ship2.id.ends_with("0002"), "Second instance should end with 0002")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_mini_catalog() -> ShipCatalog:
	var catalog := ShipCatalog.new()
	catalog.add_type(ShipCatalog.ShipType.new(
		"test-ship", "Test Ship", "TestCo", 10.0, 50, 0.7, 1000, 2, 0
	))
	catalog.add_type(ShipCatalog.ShipType.new(
		"late-ship", "Late Ship", "TestCo", 8.0, 30, 0.5, 800, 3, 5
	))
	return catalog
