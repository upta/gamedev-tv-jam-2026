extends GutTest


# ===========================================================================
# calculate_suggested_price
# ===========================================================================

func test_suggested_price_passenger_basic():
	var lane := GalaxyData.Lane.new("l", "a", "b", 6.0)
	# (6.0 / 0.6) * 1.5 = 15.0
	assert_almost_eq(
		DemandCalculator.calculate_suggested_price(lane, "passenger"),
		15.0, 0.001, "passenger price for distance 6.0")


func test_suggested_price_cargo_basic():
	var lane := GalaxyData.Lane.new("l", "a", "b", 6.0)
	# 15.0 * 0.8 = 12.0
	assert_almost_eq(
		DemandCalculator.calculate_suggested_price(lane, "cargo"),
		12.0, 0.001, "cargo price for distance 6.0")


func test_suggested_price_zero_distance():
	var lane := GalaxyData.Lane.new("l", "a", "b", 0.0)
	assert_almost_eq(
		DemandCalculator.calculate_suggested_price(lane, "passenger"),
		0.0, 0.001, "zero distance → zero price")


func test_suggested_price_small_distance():
	var lane := GalaxyData.Lane.new("l", "a", "b", 0.6)
	# (0.6 / 0.6) * 1.5 = 1.5
	assert_almost_eq(
		DemandCalculator.calculate_suggested_price(lane, "passenger"),
		1.5, 0.001, "distance 0.6 → 1.5")


func test_suggested_price_cargo_always_cheaper_than_passenger():
	var lane := GalaxyData.Lane.new("l", "a", "b", 10.0)
	var pax := DemandCalculator.calculate_suggested_price(lane, "passenger")
	var cargo := DemandCalculator.calculate_suggested_price(lane, "cargo")
	assert_lt(cargo, pax, "cargo price should be less than passenger price")


# ===========================================================================
# calculate_price_factor
# ===========================================================================

func test_price_factor_at_suggested():
	assert_almost_eq(
		DemandCalculator.calculate_price_factor(10.0, 10.0),
		1.0, 0.001, "at suggested → 1.0")


func test_price_factor_below_suggested():
	# 1.0 - (5.0 - 10.0) / 10.0 = 1.5
	assert_almost_eq(
		DemandCalculator.calculate_price_factor(5.0, 10.0),
		1.5, 0.001, "half suggested → 1.5 (capped)")


func test_price_factor_above_suggested():
	# 1.0 - (15.0 - 10.0) / 10.0 = 0.5
	assert_almost_eq(
		DemandCalculator.calculate_price_factor(15.0, 10.0),
		0.5, 0.001, "50% above → 0.5")


func test_price_factor_way_above_clamped_to_min():
	# 1.0 - (30.0 - 10.0) / 10.0 = -1.0 → clamped 0.2
	assert_almost_eq(
		DemandCalculator.calculate_price_factor(30.0, 10.0),
		0.2, 0.001, "extreme overpricing → floor 0.2")


func test_price_factor_way_below_clamped_to_max():
	# 1.0 - (0.0 - 10.0) / 10.0 = 2.0 → clamped 1.5
	assert_almost_eq(
		DemandCalculator.calculate_price_factor(0.0, 10.0),
		1.5, 0.001, "free ticket → cap 1.5")


func test_price_factor_zero_suggested_returns_one():
	assert_almost_eq(
		DemandCalculator.calculate_price_factor(10.0, 0.0),
		1.0, 0.001, "zero suggested → 1.0")


func test_price_factor_negative_suggested_returns_one():
	assert_almost_eq(
		DemandCalculator.calculate_price_factor(10.0, -5.0),
		1.0, 0.001, "negative suggested → 1.0")


# ===========================================================================
# get_demand_tier
# ===========================================================================

func test_demand_tier_low_zero():
	assert_eq(DemandCalculator.get_demand_tier(0), "Low")


func test_demand_tier_low_boundary():
	assert_eq(DemandCalculator.get_demand_tier(29), "Low")


func test_demand_tier_medium_lower_boundary():
	assert_eq(DemandCalculator.get_demand_tier(30), "Medium")


func test_demand_tier_medium_upper_boundary():
	assert_eq(DemandCalculator.get_demand_tier(70), "Medium")


func test_demand_tier_high_boundary():
	assert_eq(DemandCalculator.get_demand_tier(71), "High")


func test_demand_tier_high_large_value():
	assert_eq(DemandCalculator.get_demand_tier(999), "High")


# ===========================================================================
# calculate_demand_split
# ===========================================================================

func _make_lane(distance: float = 6.0) -> GalaxyData.Lane:
	return GalaxyData.Lane.new("test_lane", "planet_a", "planet_b", distance)


func _make_carrier(id: String, ships: Array, routes: Array) -> CarrierData:
	var c := CarrierData.new()
	c.id = id
	c.ships = ships
	c.routes = routes
	return c


func _make_ship(id: String, pax: int, cargo: int) -> ShipCatalog.ShipInstance:
	return ShipCatalog.ShipInstance.new(id, "sd-100", pax, cargo, "", 0)


func _make_route(
	id: String, origin: String, dest: String,
	ship_ids: Array[String], pax_price: float, cargo_price: float,
	freq: int = 1, active: bool = true,
) -> CarrierData.Route:
	return CarrierData.Route.new(
		id, "test_lane", origin, dest, ship_ids,
		pax_price, cargo_price, freq, active)


func _make_demand(pax: int, cargo: int, mod_pax: float = 1.0, mod_cargo: float = 1.0) -> DemandData.DemandEntry:
	return DemandData.DemandEntry.new("test_lane", "forward", pax, cargo, mod_pax, mod_cargo)


func _suggested_pax(distance: float = 6.0) -> float:
	return (distance / 0.6) * 1.5


func _suggested_cargo(distance: float = 6.0) -> float:
	return _suggested_pax(distance) * 0.8


func test_demand_split_no_routes_returns_empty():
	var demand := _make_demand(100, 50)
	var catalog := ShipCatalog.create_default_catalog()
	var result := DemandCalculator.calculate_demand_split(
		[], "forward", demand, [], catalog,
		_suggested_pax(), _suggested_cargo(), "planet_a")
	assert_eq(result.size(), 0, "no routes → empty result")


func test_demand_split_single_carrier_monopoly():
	var ship := _make_ship("s1", 30, 10)
	var route := _make_route("r1", "planet_a", "planet_b", ["s1"] as Array[String], _suggested_pax(), _suggested_cargo())
	var carrier := _make_carrier("c1", [ship], [route])
	var demand := _make_demand(100, 50)
	var catalog := ShipCatalog.create_default_catalog()

	var result := DemandCalculator.calculate_demand_split(
		[route], "forward", demand, [carrier], catalog,
		_suggested_pax(), _suggested_cargo(), "planet_a")

	assert_true(result.has("c1"), "carrier present in result")
	# Capacity-constrained: 30 pax, 10 cargo
	assert_eq(result["c1"]["passengers_served"], 30, "capped at pax capacity")
	assert_eq(result["c1"]["cargo_served"], 10, "capped at cargo capacity")


func test_demand_split_single_carrier_demand_below_capacity():
	var ship := _make_ship("s1", 30, 20)
	var route := _make_route("r1", "planet_a", "planet_b", ["s1"] as Array[String], _suggested_pax(), _suggested_cargo())
	var carrier := _make_carrier("c1", [ship], [route])
	var demand := _make_demand(10, 5)
	var catalog := ShipCatalog.create_default_catalog()

	var result := DemandCalculator.calculate_demand_split(
		[route], "forward", demand, [carrier], catalog,
		_suggested_pax(), _suggested_cargo(), "planet_a")

	assert_eq(result["c1"]["passengers_served"], 10, "serves all demand when under capacity")
	assert_eq(result["c1"]["cargo_served"], 5, "serves all cargo demand")


func test_demand_split_two_carriers_proportional():
	var ship_a := _make_ship("sa", 30, 10)
	var ship_b := _make_ship("sb", 20, 20)

	var route_a := _make_route("ra", "planet_a", "planet_b", ["sa"] as Array[String], _suggested_pax(), _suggested_cargo())
	var route_b := _make_route("rb", "planet_a", "planet_b", ["sb"] as Array[String], _suggested_pax(), _suggested_cargo())

	var carrier_a := _make_carrier("ca", [ship_a], [route_a])
	var carrier_b := _make_carrier("cb", [ship_b], [route_b])

	# Demand fits exactly within total capacity (50 pax, 30 cargo)
	var demand := _make_demand(50, 30)
	var catalog := ShipCatalog.create_default_catalog()

	var result := DemandCalculator.calculate_demand_split(
		[route_a, route_b], "forward", demand,
		[carrier_a, carrier_b], catalog,
		_suggested_pax(), _suggested_cargo(), "planet_a")

	# At suggested prices, factors=1.0. Weights = capacity.
	# pax: a=30/50*50=30, b=20/50*50=20. cargo: a=10/30*30=10, b=20/30*30=20.
	assert_eq(result["ca"]["passengers_served"], 30)
	assert_eq(result["cb"]["passengers_served"], 20)
	assert_eq(result["ca"]["cargo_served"], 10)
	assert_eq(result["cb"]["cargo_served"], 20)


func test_demand_split_inactive_route_ignored():
	var ship := _make_ship("s1", 30, 10)
	var route := _make_route("r1", "planet_a", "planet_b", ["s1"] as Array[String], _suggested_pax(), _suggested_cargo(), 1, false)
	var carrier := _make_carrier("c1", [ship], [route])
	var demand := _make_demand(100, 50)
	var catalog := ShipCatalog.create_default_catalog()

	var result := DemandCalculator.calculate_demand_split(
		[route], "forward", demand, [carrier], catalog,
		_suggested_pax(), _suggested_cargo(), "planet_a")

	assert_eq(result.size(), 0, "inactive route → empty result")


func test_demand_split_wrong_direction_ignored():
	var ship := _make_ship("s1", 30, 10)
	# Route origin is planet_b, but lane_origin_id is planet_a → forward doesn't match
	var route := _make_route("r1", "planet_b", "planet_a", ["s1"] as Array[String], _suggested_pax(), _suggested_cargo())
	var carrier := _make_carrier("c1", [ship], [route])
	var demand := _make_demand(100, 50)
	var catalog := ShipCatalog.create_default_catalog()

	var result := DemandCalculator.calculate_demand_split(
		[route], "forward", demand, [carrier], catalog,
		_suggested_pax(), _suggested_cargo(), "planet_a")

	assert_eq(result.size(), 0, "wrong direction → empty result")


func test_demand_split_demand_modifier_scales_demand():
	var ship := _make_ship("s1", 50, 50)
	var route := _make_route("r1", "planet_a", "planet_b", ["s1"] as Array[String], _suggested_pax(), _suggested_cargo())
	var carrier := _make_carrier("c1", [ship], [route])
	# base 20 pax * modifier 2.0 = effective 40; base 10 cargo * modifier 3.0 = effective 30
	var demand := _make_demand(20, 10, 2.0, 3.0)
	var catalog := ShipCatalog.create_default_catalog()

	var result := DemandCalculator.calculate_demand_split(
		[route], "forward", demand, [carrier], catalog,
		_suggested_pax(), _suggested_cargo(), "planet_a")

	assert_eq(result["c1"]["passengers_served"], 40, "modifier doubles effective pax demand")
	assert_eq(result["c1"]["cargo_served"], 30, "modifier triples effective cargo demand")
