extends GutTest

## Unit tests for ScoreCalculator — composite company value scoring.

var catalog: ShipCatalog


func before_each() -> void:
	catalog = ShipCatalog.create_default_catalog()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_carrier(id: String = "test", cash: float = 1000.0) -> CarrierData:
	var c := CarrierData.new()
	c.id = id
	c.carrier_name = id.capitalize()
	c.cash = cash
	return c


func _add_ship(carrier: CarrierData, type_id: String = "sd-100", pax: int = 20, cargo: int = 20) -> ShipCatalog.ShipInstance:
	var ship := catalog.create_ship_instance(type_id, pax, cargo, carrier.id, -2)
	carrier.ships.append(ship)
	return ship


func _add_pending_order(carrier: CarrierData, type_id: String = "sd-100", pax: int = 20, cargo: int = 20) -> ShipCatalog.ShipInstance:
	var ship := catalog.create_ship_instance(type_id, pax, cargo, carrier.id, 99)
	carrier.pending_orders.append(ship)
	return ship


func _add_route(carrier: CarrierData, ship_ids: Array[String], freq: int = 1, pax_price: float = 10.0, cargo_price: float = 5.0, active: bool = true) -> CarrierData.Route:
	var route := CarrierData.Route.new(
		"route_%d" % carrier.routes.size(),
		"earth",
		"mars",
		ship_ids,
		pax_price,
		cargo_price,
		freq,
		active,
	)
	carrier.routes.append(route)
	return route


# ---------------------------------------------------------------------------
# calculate_score
# ---------------------------------------------------------------------------

func test_cash_only_carrier() -> void:
	var carrier := _make_carrier("cash_only", 5000.0)
	var score := ScoreCalculator.calculate_score(carrier, catalog)

	assert_almost_eq(score["cash"], 5000.0, 0.01, "cash component")
	assert_almost_eq(score["ship_assets"], 0.0, 0.01, "no ships → zero assets")
	assert_almost_eq(score["slot_value"], 0.0, 0.01, "no slots → zero slot value")
	assert_almost_eq(score["route_value"], 0.0, 0.01, "no routes → zero route value")
	assert_almost_eq(score["total"], 5000.0, 0.01, "total equals cash")


func test_ship_assets_from_fleet() -> void:
	var carrier := _make_carrier("fleet", 0.0)
	_add_ship(carrier, "sd-100")  # cost = 500
	_add_ship(carrier, "sd-300", 40, 40)  # cost = 1200

	var score := ScoreCalculator.calculate_score(carrier, catalog)
	assert_almost_eq(score["ship_assets"], 1700.0, 0.01, "500 + 1200")


func test_ship_assets_includes_pending_orders() -> void:
	var carrier := _make_carrier("pending", 0.0)
	_add_ship(carrier, "sd-100")        # cost = 500
	_add_pending_order(carrier, "sd-300", 40, 40)  # cost = 1200

	var score := ScoreCalculator.calculate_score(carrier, catalog)
	assert_almost_eq(score["ship_assets"], 1700.0, 0.01, "fleet + pending")


func test_slot_value() -> void:
	var carrier := _make_carrier("slots", 0.0)
	carrier.slots["earth"] = 3
	carrier.slots["mars"] = 2

	var score := ScoreCalculator.calculate_score(carrier, catalog)
	# 5 slots × 200 = 1000
	assert_almost_eq(score["slot_value"], 1000.0, 0.01, "5 slots × 200")


func test_route_value_single_active_route() -> void:
	var carrier := _make_carrier("route", 0.0)
	var ship := _add_ship(carrier, "sd-100")  # pax=20, cargo=20
	var ship_ids: Array[String] = [ship.id]
	# freq=1, pax_price=10, cargo_price=5
	_add_route(carrier, ship_ids, 1, 10.0, 5.0)

	var score := ScoreCalculator.calculate_score(carrier, catalog)
	# revenue = freq * (pax_cap * pax_price * 0.5 + cargo_cap * cargo_price * 0.5)
	# = 1 * (20*10*0.5 + 20*5*0.5) = 1 * (100 + 50) = 150
	# route_value = 150 * 5.0 = 750
	assert_almost_eq(score["route_value"], 750.0, 0.01, "single route value")


func test_inactive_routes_excluded() -> void:
	var carrier := _make_carrier("inactive", 0.0)
	var ship := _add_ship(carrier, "sd-100")
	var ship_ids: Array[String] = [ship.id]
	_add_route(carrier, ship_ids, 1, 10.0, 5.0, false)

	var score := ScoreCalculator.calculate_score(carrier, catalog)
	assert_almost_eq(score["route_value"], 0.0, 0.01, "inactive route ignored")


func test_route_value_with_frequency() -> void:
	var carrier := _make_carrier("freq", 0.0)
	var ship1 := _add_ship(carrier, "sd-100")
	var ship2 := _add_ship(carrier, "sd-100")
	var ship_ids: Array[String] = [ship1.id, ship2.id]
	_add_route(carrier, ship_ids, 2, 10.0, 5.0)

	var score := ScoreCalculator.calculate_score(carrier, catalog)
	# total_pax = 40, total_cargo = 40
	# revenue = 2 * (40*10*0.5 + 40*5*0.5) = 2 * (200+100) = 600
	# route_value = 600 * 5.0 = 3000
	assert_almost_eq(score["route_value"], 3000.0, 0.01, "frequency multiplied")


func test_total_is_sum_of_components() -> void:
	var carrier := _make_carrier("total", 2000.0)
	carrier.slots["earth"] = 2  # 400
	_add_ship(carrier, "sd-100")  # 500
	# total = 2000 + 500 + 400 + 0(no routes) = 2900
	var score := ScoreCalculator.calculate_score(carrier, catalog)
	var expected_total: float = score["cash"] + score["ship_assets"] + score["slot_value"] + score["route_value"]
	assert_almost_eq(score["total"], expected_total, 0.01, "total = sum of components")


func test_empty_carrier() -> void:
	var carrier := _make_carrier("empty", 0.0)
	var score := ScoreCalculator.calculate_score(carrier, catalog)
	assert_almost_eq(score["total"], 0.0, 0.01, "empty carrier scores zero")


# ---------------------------------------------------------------------------
# determine_winner
# ---------------------------------------------------------------------------

func test_determine_winner_single() -> void:
	var c := _make_carrier("solo", 100.0)
	var winner := ScoreCalculator.determine_winner([c], catalog)
	assert_eq(winner.id, "solo", "only carrier wins")


func test_determine_winner_higher_cash_wins() -> void:
	var c1 := _make_carrier("poor", 100.0)
	var c2 := _make_carrier("rich", 9000.0)

	var winner := ScoreCalculator.determine_winner([c1, c2], catalog)
	assert_eq(winner.id, "rich", "higher score wins")


func test_determine_winner_considers_all_components() -> void:
	var c1 := _make_carrier("cash_heavy", 3000.0)
	var c2 := _make_carrier("asset_heavy", 0.0)
	_add_ship(c2, "sd-900", 100, 100)  # cost = 4000
	# c1 total = 3000, c2 total = 4000 (ship assets)
	var winner := ScoreCalculator.determine_winner([c1, c2], catalog)
	assert_eq(winner.id, "asset_heavy", "ship assets counted")


# ---------------------------------------------------------------------------
# get_rankings
# ---------------------------------------------------------------------------

func test_rankings_sorted_descending() -> void:
	var c1 := _make_carrier("low", 100.0)
	var c2 := _make_carrier("mid", 500.0)
	var c3 := _make_carrier("high", 2000.0)

	var rankings := ScoreCalculator.get_rankings([c1, c2, c3], catalog)

	assert_eq(rankings.size(), 3, "all carriers ranked")
	assert_eq(rankings[0]["carrier_id"], "high", "highest first")
	assert_eq(rankings[1]["carrier_id"], "mid", "middle second")
	assert_eq(rankings[2]["carrier_id"], "low", "lowest last")


func test_rankings_assign_correct_ranks() -> void:
	var c1 := _make_carrier("a", 100.0)
	var c2 := _make_carrier("b", 200.0)

	var rankings := ScoreCalculator.get_rankings([c1, c2], catalog)
	assert_eq(rankings[0]["rank"], 1, "first place = rank 1")
	assert_eq(rankings[1]["rank"], 2, "second place = rank 2")


func test_rankings_include_carrier_name() -> void:
	var c := _make_carrier("test_carrier", 100.0)
	c.carrier_name = "Astro Corp"

	var rankings := ScoreCalculator.get_rankings([c], catalog)
	assert_eq(rankings[0]["carrier_name"], "Astro Corp", "name preserved")


func test_rankings_empty_array() -> void:
	var rankings := ScoreCalculator.get_rankings([], catalog)
	assert_eq(rankings.size(), 0, "no carriers → empty rankings")


# ---------------------------------------------------------------------------
# price-adjusted route value
# ---------------------------------------------------------------------------

func test_route_value_uses_price_factor() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	var lane := galaxy.get_lane("earth", "mars")
	assert_not_null(lane, "earth-mars lane exists")

	var suggested_pax := DemandCalculator.calculate_suggested_price(lane, "passenger")
	var suggested_cargo := DemandCalculator.calculate_suggested_price(lane, "cargo")

	# Fairly priced carrier
	var c_fair := _make_carrier("fair", 0.0)
	var ship_fair := _add_ship(c_fair, "sd-100")
	var fair_ids: Array[String] = [ship_fair.id]
	_add_route(c_fair, fair_ids, 1, suggested_pax, suggested_cargo)

	# Overpriced carrier (10x suggested)
	var c_over := _make_carrier("overpriced", 0.0)
	var ship_over := _add_ship(c_over, "sd-100")
	var over_ids: Array[String] = [ship_over.id]
	_add_route(c_over, over_ids, 1, suggested_pax * 10.0, suggested_cargo * 10.0)

	var score_fair := ScoreCalculator.calculate_score(c_fair, catalog, galaxy)
	var score_over := ScoreCalculator.calculate_score(c_over, catalog, galaxy)

	assert_true(
		score_fair["route_value"] > score_over["route_value"],
		"fairly priced route should score higher than overpriced route"
	)


func test_route_value_no_galaxy_fallback() -> void:
	var carrier := _make_carrier("fallback", 0.0)
	var ship := _add_ship(carrier, "sd-100")  # pax=20, cargo=20
	var ship_ids: Array[String] = [ship.id]
	_add_route(carrier, ship_ids, 1, 10.0, 5.0)

	# Without galaxy — uses flat 0.5 fill rate
	var score := ScoreCalculator.calculate_score(carrier, catalog)
	# revenue = 1 * (20*10*0.5 + 20*5*0.5) = 150, route_value = 150 * 5.0 = 750
	assert_almost_eq(score["route_value"], 750.0, 0.01, "null galaxy uses flat 0.5 fill rate")
