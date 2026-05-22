extends GutTest


# ===========================================================================
# Helpers
# ===========================================================================

func _make_galaxy() -> GalaxyData:
	var g := GalaxyData.new()
	g.planets.append(GalaxyData.Planet.new("earth", "Earth", "Sol", 4, Vector2(0.0, 0.0)))
	g.planets.append(GalaxyData.Planet.new("mars", "Mars", "Sol", 4, Vector2(3.0, 0.0)))
	g.planets.append(GalaxyData.Planet.new("jupiter", "Jupiter", "Sol", 4, Vector2(8.0, 0.0)))
	g._build_indices()
	return g


func _make_catalog() -> ShipCatalog:
	var c := ShipCatalog.new()
	c.add_type(ShipCatalog.ShipType.new(
		"sd-100", "SD-100", "Sol Dynamics", 20.0, 40, 0.8, 5000, 2, 0))
	return c


func _make_ship(id: String, type_id: String = "sd-100") -> ShipCatalog.ShipInstance:
	return ShipCatalog.ShipInstance.new(id, type_id, 20, 20, "", 0)


func _make_carrier(id: String, name: String, cash: float = 30000.0) -> CarrierData:
	var c := CarrierData.new()
	c.id = id
	c.carrier_name = name
	c.cash = cash
	c.slots = {"earth": 2, "mars": 2}
	c.ships = [_make_ship(id + "-ship-0001")]
	return c


func _make_game_state() -> GameState:
	var gs := GameState.new()
	var galaxy := _make_galaxy()
	var catalog := _make_catalog()
	var carriers: Array = [
		_make_carrier("player", "Player Corp"),
		_make_carrier("npc_1", "Nova Transit"),
	]
	gs.initialize(galaxy, catalog, carriers, 42)
	return gs


func _make_empty_turn_result(turn: int = 1) -> TurnPipeline.TurnResult:
	var result := TurnPipeline.TurnResult.new()
	result.turn_number = turn
	result.auction_results = {}
	result.financials = {}
	return result


# ===========================================================================
# Tests
# ===========================================================================

func test_build_summaries_returns_all_carriers() -> void:
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})

	assert_true(summaries.has("player"), "Should have player summary")
	assert_true(summaries.has("npc_1"), "Should have NPC summary")


func test_cash_before_after_captured() -> void:
	var gs := _make_game_state()
	# Modify carrier cash to simulate post-turn state
	gs.get_carrier("player").cash = 30200.0
	var result := _make_empty_turn_result()
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_eq(player_summary.cash_before, 30000.0)
	assert_eq(player_summary.cash_after, 30200.0)


func test_carrier_with_no_actions_has_empty_actions_array() -> void:
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var npc_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["npc_1"]

	assert_eq(npc_summary.actions.size(), 0, "Carrier with no actions should have empty actions array")


func test_slot_wins_appear_in_summary() -> void:
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	result.auction_results = {
		"awards": [{"carrier_id": "player", "planet_id": "mars", "slots_won": 2, "cost": 100.0}],
		"rejections": [],
	}
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_eq(player_summary.slots_won.size(), 1)
	assert_eq(player_summary.slots_won[0]["planet_id"], "mars")
	assert_eq(player_summary.slots_won[0]["count"], 2)
	assert_true(player_summary.actions.size() > 0, "Should have action text for slot win")
	assert_string_contains(player_summary.actions[0], "Won 2 slots at Mars")


func test_route_creation_appears_in_summary() -> void:
	var gs := _make_game_state()
	# Add a route to the carrier (simulating it was just created this turn)
	var ship_ids: Array[String] = ["player-ship-0001"]
	var route := CarrierData.Route.new("player-route-0", "earth", "mars", ship_ids, 10.0, 8.0, 1, true)
	gs.get_carrier("player").routes.append(route)

	var result := _make_empty_turn_result()
	result.route_changes = [{"type": "created", "carrier_id": "player", "route_id": "player-route-0"}]
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_eq(player_summary.routes_created.size(), 1)
	assert_eq(player_summary.routes_created[0]["origin_id"], "earth")
	assert_eq(player_summary.routes_created[0]["dest_id"], "mars")
	assert_true(player_summary.actions.size() > 0)
	assert_string_contains(player_summary.actions[0], "Opened route Earth")


func test_ship_orders_appear_in_summary() -> void:
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	result.ship_orders = [{"carrier_id": "npc_1", "ship_id": "npc_1-sd-100-0002", "type_id": "sd-100", "cost": 5000.0}]
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var npc_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["npc_1"]

	assert_eq(npc_summary.ships_ordered.size(), 1)
	assert_eq(npc_summary.ships_ordered[0]["type_id"], "sd-100")
	assert_string_contains(npc_summary.actions[0], "Ordered 1 sd-100")


func test_ship_deliveries_appear_in_summary() -> void:
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	result.deliveries = [{"carrier_id": "player", "ship_id": "player-sd-100-0002", "type_id": "sd-100"}]
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_eq(player_summary.ships_delivered.size(), 1)
	assert_eq(player_summary.ships_delivered[0]["type_id"], "sd-100")
	assert_string_contains(player_summary.actions[0], "Ship delivered")


func test_route_financials_extraction() -> void:
	var gs := _make_game_state()
	var ship_ids: Array[String] = ["player-ship-0001"]
	var route := CarrierData.Route.new("player-route-0", "earth", "mars", ship_ids, 10.0, 8.0, 1, true)
	gs.get_carrier("player").routes.append(route)

	var result := _make_empty_turn_result()
	result.financials = {
		"player": {
			"routes": [{
				"route_id": "player-route-0",
				"revenue": {"passenger_revenue": 200.0, "cargo_revenue": 100.0, "total_revenue": 300.0},
				"operating_cost": 50.0,
				"passengers_served": 20,
				"cargo_served": 12,
				"passenger_capacity": 30,
				"cargo_capacity": 20,
			}],
			"total_revenue": 300.0,
			"total_costs": 50.0,
			"slot_upkeep": 40.0,
			"net": 210.0,
			"cash_after": 30210.0,
			"bankrupt": false,
		},
		"npc_1": {
			"routes": [],
			"total_revenue": 0.0,
			"total_costs": 0.0,
			"slot_upkeep": 40.0,
			"net": -40.0,
			"cash_after": 29960.0,
			"bankrupt": false,
		},
	}
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_eq(player_summary.route_financials.size(), 1)
	var rf: Dictionary = player_summary.route_financials[0]
	assert_eq(rf["route_id"], "player-route-0")
	assert_eq(rf["origin_id"], "earth")
	assert_eq(rf["dest_id"], "mars")
	assert_eq(rf["pax_served"], 20)
	assert_eq(rf["pax_capacity"], 30)
	assert_eq(rf["cargo_served"], 12)
	assert_eq(rf["cargo_capacity"], 20)
	assert_eq(rf["revenue"], 300.0)
	assert_eq(rf["costs"], 50.0)
	assert_eq(rf["profit"], 250.0)

	assert_eq(player_summary.total_revenue, 300.0)
	assert_eq(player_summary.total_costs, 50.0)
	assert_eq(player_summary.slot_upkeep, 40.0)
	assert_eq(player_summary.net, 210.0)


func test_carrier_name_set_correctly() -> void:
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})

	assert_eq(summaries["player"].carrier_name, "Player Corp")
	assert_eq(summaries["npc_1"].carrier_name, "Nova Transit")


func test_slot_sales_appear_in_summary() -> void:
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	result.slot_sales = [{"carrier_id": "player", "planet_id": "earth", "count": 1}]
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_eq(player_summary.slots_sold.size(), 1)
	assert_eq(player_summary.slots_sold[0]["planet_id"], "earth")
	assert_string_contains(player_summary.actions[0], "Sold 1 slot at Earth")


func test_route_cancelled_shows_planet_names() -> void:
	var gs := _make_game_state()
	var ship_ids: Array[String] = ["player-ship-0001"]
	var route := CarrierData.Route.new("player-route-0", "earth", "mars", ship_ids, 10.0, 8.0, 1, false)
	gs.get_carrier("player").routes.append(route)

	var result := _make_empty_turn_result()
	result.route_changes = [{
		"type": "cancelled",
		"carrier_id": "player",
		"route_id": "player-route-0",
		"origin_id": "earth",
		"dest_id": "mars",
	}]
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_eq(player_summary.routes_cancelled.size(), 1)
	assert_string_contains(player_summary.actions[0], "Cancelled route Earth")
	assert_string_contains(player_summary.actions[0], "Mars")


func test_route_modified_shows_price_changes() -> void:
	var gs := _make_game_state()
	var ship_ids: Array[String] = ["player-ship-0001"]
	var route := CarrierData.Route.new("player-route-0", "earth", "mars", ship_ids, 9.2, 7.4, 1, true)
	gs.get_carrier("player").routes.append(route)

	var result := _make_empty_turn_result()
	result.route_changes = [{
		"type": "modified",
		"carrier_id": "player",
		"route_id": "player-route-0",
		"origin_id": "earth",
		"dest_id": "mars",
		"old_passenger_price": 10.0,
		"new_passenger_price": 9.2,
		"old_cargo_price": 8.0,
		"new_cargo_price": 7.4,
		"old_ship_count": 1,
		"new_ship_count": 1,
		"old_frequency": 1,
		"new_frequency": 1,
	}]
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_eq(player_summary.routes_modified.size(), 1)
	assert_string_contains(player_summary.actions[0], "Modified Earth")
	assert_string_contains(player_summary.actions[0], "Mars")
	assert_string_contains(player_summary.actions[0], "lowered prices")


func test_route_modified_shows_ship_and_frequency_changes() -> void:
	var gs := _make_game_state()
	var ship_ids: Array[String] = ["player-ship-0001"]
	var route := CarrierData.Route.new("player-route-0", "earth", "mars", ship_ids, 10.0, 8.0, 2, true)
	gs.get_carrier("player").routes.append(route)

	var result := _make_empty_turn_result()
	result.route_changes = [{
		"type": "modified",
		"carrier_id": "player",
		"route_id": "player-route-0",
		"origin_id": "earth",
		"dest_id": "mars",
		"old_passenger_price": 10.0,
		"new_passenger_price": 11.0,
		"old_cargo_price": 8.0,
		"new_cargo_price": 8.8,
		"old_ship_count": 1,
		"new_ship_count": 2,
		"old_frequency": 1,
		"new_frequency": 2,
	}]
	var cash_before := {"player": 30000.0, "npc_1": 30000.0}

	var summaries := TurnSummaryBuilder.build_summaries(result, gs, cash_before, {})
	var player_summary: TurnSummaryBuilder.CarrierTurnSummary = summaries["player"]

	assert_string_contains(player_summary.actions[0], "raised prices")
	assert_string_contains(player_summary.actions[0], "added 1 ship")
	assert_string_contains(player_summary.actions[0], "increased frequency")
