extends GutTest


# ===========================================================================
# Helpers
# ===========================================================================

func _make_galaxy_with_lane(distance: float = 6.0) -> GalaxyData:
	var g := GalaxyData.new()
	# Position planets so their Euclidean distance equals the desired distance
	g.planets.append(GalaxyData.Planet.new("planet_a", "Planet A", "sys", 4, Vector2(0.0, 0.0)))
	g.planets.append(GalaxyData.Planet.new("planet_b", "Planet B", "sys", 4, Vector2(distance, 0.0)))
	g._build_indices()
	return g


func _make_catalog() -> ShipCatalog:
	var c := ShipCatalog.new()
	# efficiency 0.8
	c.add_type(ShipCatalog.ShipType.new(
		"test_type", "Test Ship", "TestCo", 20.0, 40, 0.8, 500, 2, 0))
	# efficiency 0.5
	c.add_type(ShipCatalog.ShipType.new(
		"slow_type", "Slow Ship", "TestCo", 20.0, 60, 0.5, 800, 3, 0))
	return c


func _make_ship(id: String, type_id: String = "test_type", pax: int = 20, cargo: int = 20) -> ShipCatalog.ShipInstance:
	return ShipCatalog.ShipInstance.new(id, type_id, pax, cargo, "", 0)


func _make_carrier(id: String, ships: Array = [], slots: Dictionary = {}) -> CarrierData:
	var c := CarrierData.new()
	c.id = id
	c.cash = 1000.0
	c.ships = ships
	c.slots = slots
	return c


func _make_route(
	id: String, ship_ids: Array[String],
	pax_price: float = 10.0, cargo_price: float = 8.0,
	origin: String = "planet_a", dest: String = "planet_b",
	active: bool = true,
) -> CarrierData.Route:
	return CarrierData.Route.new(
		id, origin, dest, ship_ids,
		pax_price, cargo_price, 1, active)


# ===========================================================================
# deliver_pending_ships
# ===========================================================================

func test_deliver_ships_when_turn_matches():
	var ship := ShipCatalog.ShipInstance.new("s1", "test_type", 20, 20, "c1", 3)
	var carrier := _make_carrier("c1")
	carrier.pending_orders = [ship]

	var deliveries := FinancialCalculator.deliver_pending_ships([carrier], 3)

	assert_eq(deliveries.size(), 1, "one ship delivered")
	assert_eq(deliveries[0]["ship_id"], "s1")
	assert_eq(carrier.ships.size(), 1, "ship moved to ships array")
	assert_eq(carrier.pending_orders.size(), 0, "pending cleared")


func test_deliver_ships_when_turn_past():
	var ship := ShipCatalog.ShipInstance.new("s1", "test_type", 20, 20, "c1", 2)
	var carrier := _make_carrier("c1")
	carrier.pending_orders = [ship]

	var deliveries := FinancialCalculator.deliver_pending_ships([carrier], 5)

	assert_eq(deliveries.size(), 1, "past-due ship delivered")
	assert_eq(carrier.ships.size(), 1)
	assert_eq(carrier.pending_orders.size(), 0)


func test_deliver_ships_not_ready_stays_pending():
	var ship := ShipCatalog.ShipInstance.new("s1", "test_type", 20, 20, "c1", 5)
	var carrier := _make_carrier("c1")
	carrier.pending_orders = [ship]

	var deliveries := FinancialCalculator.deliver_pending_ships([carrier], 3)

	assert_eq(deliveries.size(), 0, "no deliveries yet")
	assert_eq(carrier.ships.size(), 0, "ships still empty")
	assert_eq(carrier.pending_orders.size(), 1, "still pending")


func test_deliver_ships_mixed_readiness():
	var ready := ShipCatalog.ShipInstance.new("s1", "test_type", 20, 20, "c1", 3)
	var not_ready := ShipCatalog.ShipInstance.new("s2", "test_type", 10, 10, "c1", 7)
	var carrier := _make_carrier("c1")
	carrier.pending_orders = [ready, not_ready]

	var deliveries := FinancialCalculator.deliver_pending_ships([carrier], 3)

	assert_eq(deliveries.size(), 1, "only ready ship delivered")
	assert_eq(deliveries[0]["ship_id"], "s1")
	assert_eq(carrier.ships.size(), 1)
	assert_eq(carrier.pending_orders.size(), 1, "one still pending")
	assert_eq(carrier.pending_orders[0].id, "s2")


func test_deliver_ships_multiple_carriers():
	var ship_a := ShipCatalog.ShipInstance.new("sa", "test_type", 20, 20, "ca", 1)
	var ship_b := ShipCatalog.ShipInstance.new("sb", "test_type", 20, 20, "cb", 10)

	var carrier_a := _make_carrier("ca")
	carrier_a.pending_orders = [ship_a]
	var carrier_b := _make_carrier("cb")
	carrier_b.pending_orders = [ship_b]

	var deliveries := FinancialCalculator.deliver_pending_ships([carrier_a, carrier_b], 5)

	assert_eq(deliveries.size(), 1, "only carrier_a ship ready")
	assert_eq(deliveries[0]["carrier_id"], "ca")
	assert_eq(carrier_a.ships.size(), 1)
	assert_eq(carrier_b.pending_orders.size(), 1, "carrier_b ship still pending")


func test_deliver_ships_empty_carriers():
	var deliveries := FinancialCalculator.deliver_pending_ships([], 5)
	assert_eq(deliveries.size(), 0, "empty carriers → no deliveries")


# ===========================================================================
# calculate_route_revenue
# ===========================================================================

func test_route_revenue_basic():
	var route := _make_route("r1", ["s1"] as Array[String], 10.0, 8.0)
	var carrier := _make_carrier("c1")
	var catalog := _make_catalog()
	var demand_split := { "c1": { "passengers_served": 20, "cargo_served": 15 } }

	var rev := FinancialCalculator.calculate_route_revenue(route, carrier, catalog, demand_split)

	assert_almost_eq(rev["passenger_revenue"], 200.0, 0.001, "20 × 10.0")
	assert_almost_eq(rev["cargo_revenue"], 120.0, 0.001, "15 × 8.0")
	assert_almost_eq(rev["total_revenue"], 320.0, 0.001, "200 + 120")


func test_route_revenue_zero_demand():
	var route := _make_route("r1", ["s1"] as Array[String], 10.0, 8.0)
	var carrier := _make_carrier("c1")
	var catalog := _make_catalog()
	var demand_split := { "c1": { "passengers_served": 0, "cargo_served": 0 } }

	var rev := FinancialCalculator.calculate_route_revenue(route, carrier, catalog, demand_split)

	assert_almost_eq(rev["total_revenue"], 0.0, 0.001, "no demand → zero revenue")


func test_route_revenue_carrier_not_in_split():
	var route := _make_route("r1", ["s1"] as Array[String], 10.0, 8.0)
	var carrier := _make_carrier("c1")
	var catalog := _make_catalog()
	var demand_split: Dictionary = {}

	var rev := FinancialCalculator.calculate_route_revenue(route, carrier, catalog, demand_split)

	assert_almost_eq(rev["total_revenue"], 0.0, 0.001, "carrier absent from split → zero")


func test_route_revenue_passengers_only():
	var route := _make_route("r1", ["s1"] as Array[String], 25.0, 0.0)
	var carrier := _make_carrier("c1")
	var catalog := _make_catalog()
	var demand_split := { "c1": { "passengers_served": 10, "cargo_served": 5 } }

	var rev := FinancialCalculator.calculate_route_revenue(route, carrier, catalog, demand_split)

	assert_almost_eq(rev["passenger_revenue"], 250.0, 0.001, "10 × 25")
	assert_almost_eq(rev["cargo_revenue"], 0.0, 0.001, "cargo price 0 → no revenue")


# ===========================================================================
# calculate_route_operating_cost
# ===========================================================================

func test_operating_cost_single_ship():
	var ship := _make_ship("s1", "test_type")
	var carrier := _make_carrier("c1", [ship])
	var route := _make_route("r1", ["s1"] as Array[String])
	var catalog := _make_catalog()
	var galaxy := _make_galaxy_with_lane(6.0)

	# distance=6.0, efficiency=0.8 → 6.0/0.8 = 7.5
	var cost := FinancialCalculator.calculate_route_operating_cost(route, carrier, catalog, galaxy)
	assert_almost_eq(cost, 7.5, 0.001, "6.0 / 0.8 = 7.5")


func test_operating_cost_multiple_ships():
	var ship_a := _make_ship("s1", "test_type")   # eff 0.8
	var ship_b := _make_ship("s2", "slow_type")   # eff 0.5
	var carrier := _make_carrier("c1", [ship_a, ship_b])
	var route := _make_route("r1", ["s1", "s2"] as Array[String])
	var catalog := _make_catalog()
	var galaxy := _make_galaxy_with_lane(6.0)

	# 6.0/0.8 + 6.0/0.5 = 7.5 + 12.0 = 19.5
	var cost := FinancialCalculator.calculate_route_operating_cost(route, carrier, catalog, galaxy)
	assert_almost_eq(cost, 19.5, 0.001, "sum of per-ship costs")


func test_operating_cost_no_lane_returns_zero():
	var ship := _make_ship("s1", "test_type")
	var carrier := _make_carrier("c1", [ship])
	# Route refers to planets not in galaxy
	var route := _make_route("r1", ["s1"] as Array[String], 10.0, 8.0, "unknown_a", "unknown_b")
	var catalog := _make_catalog()
	var galaxy := _make_galaxy_with_lane(6.0)

	var cost := FinancialCalculator.calculate_route_operating_cost(route, carrier, catalog, galaxy)
	assert_almost_eq(cost, 0.0, 0.001, "no lane → zero cost")


func test_operating_cost_missing_ship_skipped():
	var carrier := _make_carrier("c1", [])  # no ships
	var route := _make_route("r1", ["ghost_ship"] as Array[String])
	var catalog := _make_catalog()
	var galaxy := _make_galaxy_with_lane(6.0)

	var cost := FinancialCalculator.calculate_route_operating_cost(route, carrier, catalog, galaxy)
	assert_almost_eq(cost, 0.0, 0.001, "missing ship → zero cost")


# ===========================================================================
# calculate_slot_upkeep
# ===========================================================================

func test_slot_upkeep_single_planet():
	var carrier := _make_carrier("c1", [], { "earth": 2 })
	assert_almost_eq(
		FinancialCalculator.calculate_slot_upkeep(carrier),
		20.0, 0.001, "2 slots × 10.0")


func test_slot_upkeep_multiple_planets():
	var carrier := _make_carrier("c1", [], { "earth": 2, "mars": 3, "titan": 1 })
	# (2 + 3 + 1) × 10.0 = 60.0
	assert_almost_eq(
		FinancialCalculator.calculate_slot_upkeep(carrier),
		60.0, 0.001, "6 total slots × 10.0")


func test_slot_upkeep_no_slots():
	var carrier := _make_carrier("c1", [], {})
	assert_almost_eq(
		FinancialCalculator.calculate_slot_upkeep(carrier),
		0.0, 0.001, "no slots → zero upkeep")


func test_slot_upkeep_matches_constant():
	var carrier := _make_carrier("c1", [], { "earth": 1 })
	assert_almost_eq(
		FinancialCalculator.calculate_slot_upkeep(carrier),
		FinancialCalculator.SLOT_UPKEEP_COST, 0.001,
		"single slot cost equals SLOT_UPKEEP_COST constant")
