extends GutTest


# ===========================================================================
# Helpers
# ===========================================================================

func _make_galaxy() -> GalaxyData:
	var g := GalaxyData.new()
	g.planets.append(GalaxyData.Planet.new("earth", "Earth", "Sol", 4, Vector2(0.0, 0.0)))
	g.planets.append(GalaxyData.Planet.new("mars", "Mars", "Sol", 4, Vector2(3.0, 0.0)))
	g._build_indices()
	return g


func _make_catalog() -> ShipCatalog:
	var c := ShipCatalog.new()
	c.add_type(ShipCatalog.ShipType.new(
		"sd-100", "SD-100", "Sol Dynamics", 20.0, 40, 0.8, 500, 2, 0))
	return c


func _make_ship(id: String) -> ShipCatalog.ShipInstance:
	return ShipCatalog.ShipInstance.new(id, "sd-100", 20, 20, "", 0)


func _make_carrier(id: String, cname: String, cash: float = 3000.0) -> CarrierData:
	var c := CarrierData.new()
	c.id = id
	c.carrier_name = cname
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


func _make_intents() -> Array:
	var intent_player := TurnPipeline.CarrierIntent.new()
	intent_player.carrier_id = "player"
	intent_player.slot_bids = [{"planet_id": "mars", "quantity": 1, "price_per_slot": 100.0}]

	var intent_npc := TurnPipeline.CarrierIntent.new()
	intent_npc.carrier_id = "npc_1"

	return [intent_player, intent_npc]


# ===========================================================================
# Tests
# ===========================================================================

func test_record_turn_increments_count() -> void:
	var telemetry := GameTelemetry.new()
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	var intents := _make_intents()

	telemetry.record_turn(1, intents, result, gs)

	assert_eq(telemetry.get_turn_count(), 1, "Should have 1 turn recorded")


func test_clear_resets() -> void:
	var telemetry := GameTelemetry.new()
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	var intents := _make_intents()

	telemetry.record_turn(1, intents, result, gs)
	assert_eq(telemetry.get_turn_count(), 1)

	telemetry.clear()
	assert_eq(telemetry.get_turn_count(), 0, "Should be 0 after clear")


func test_save_produces_valid_json() -> void:
	var telemetry := GameTelemetry.new()
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	var intents := _make_intents()

	telemetry.record_turn(1, intents, result, gs)
	telemetry.save_to_file()

	# Read back and parse
	var file := FileAccess.open(GameTelemetry.SAVE_PATH, FileAccess.READ)
	assert_not_null(file, "File should exist after save")
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	assert_eq(err, OK, "JSON should be valid")

	var data: Dictionary = json.data
	assert_true(data.has("_meta"), "Should have _meta key")
	assert_true(data.has("turns"), "Should have turns key")
	assert_eq(data["_meta"]["turns_recorded"], 1)
	assert_eq(data["turns"].size(), 1)
	assert_eq(data["turns"][0]["turn"], 1)


func test_intents_are_serialized() -> void:
	var telemetry := GameTelemetry.new()
	var gs := _make_game_state()
	var result := _make_empty_turn_result()
	var intents := _make_intents()

	telemetry.record_turn(1, intents, result, gs)
	telemetry.save_to_file()

	var file := FileAccess.open(GameTelemetry.SAVE_PATH, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var turn_data: Dictionary = json.data["turns"][0]
	var intents_data: Dictionary = turn_data["intents"]

	assert_true(intents_data.has("player"), "Intents should have player key")
	assert_true(intents_data.has("npc_1"), "Intents should have npc_1 key")
	assert_eq(intents_data["player"]["slot_bids"].size(), 1, "Player should have 1 slot bid")
	assert_eq(intents_data["npc_1"]["slot_bids"].size(), 0, "NPC should have 0 slot bids")


func test_state_after_captures_carrier_data() -> void:
	var telemetry := GameTelemetry.new()
	var gs := _make_game_state()

	# Add a route to player
	var ship_ids: Array[String] = ["player-ship-0001"]
	var route := CarrierData.Route.new("player-route-0", "earth", "mars", ship_ids, 10.0, 8.0, 1, true)
	gs.get_carrier("player").routes.append(route)

	var result := _make_empty_turn_result()
	var intents := _make_intents()

	telemetry.record_turn(1, intents, result, gs)
	telemetry.save_to_file()

	var file := FileAccess.open(GameTelemetry.SAVE_PATH, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var state_after: Dictionary = json.data["turns"][0]["state_after"]

	# Verify player state
	assert_true(state_after.has("player"), "Should have player state")
	var player_state: Dictionary = state_after["player"]
	assert_eq(player_state["cash"], 3000.0)
	assert_true(player_state.has("slots"), "Should have slots")
	assert_true(player_state.has("routes"), "Should have routes")
	assert_true(player_state.has("ships"), "Should have ships")
	assert_true(player_state.has("pending_orders"), "Should have pending_orders")
	assert_true(player_state.has("score"), "Should have score")

	# Verify route data
	assert_eq(player_state["routes"].size(), 1)
	assert_eq(player_state["routes"][0]["origin_id"], "earth")
	assert_eq(player_state["routes"][0]["dest_id"], "mars")

	# Verify ship data
	assert_eq(player_state["ships"].size(), 1)
	assert_eq(player_state["ships"][0]["id"], "player-ship-0001")

	# Verify NPC state exists too
	assert_true(state_after.has("npc_1"), "Should have npc_1 state")
	assert_eq(state_after["npc_1"]["cash"], 3000.0)
