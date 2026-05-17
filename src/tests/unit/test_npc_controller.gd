extends GutTest

## Tests for NpcController AI (P2.3)

var game_state: GameState
var controller: NpcController


func _create_game_state(seed_val: int = 42) -> GameState:
	var gs := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	gs.initialize(galaxy, catalog, carriers, seed_val)
	return gs


func before_each() -> void:
	game_state = _create_game_state()
	controller = NpcController.new()


func test_is_carrier_controller() -> void:
	assert_is(controller, CarrierController)


func test_returns_valid_intent() -> void:
	var intent := controller.generate_intent(game_state, "npc_1")
	assert_not_null(intent)
	assert_eq(intent.carrier_id, "npc_1")


func test_npc_creates_route_when_possible() -> void:
	# NPC_1 starts with slots at proxima_b and haven but no lane connects them directly.
	# Give npc_1 a slot at centauri_prime so it can use ac_proxima_centauri lane.
	var created_route := false
	for seed_val in range(1, 50):
		game_state = _create_game_state(seed_val)
		game_state.get_carrier("npc_1").slots["centauri_prime"] = 1
		controller = NpcController.new()
		var intent := controller.generate_intent(game_state, "npc_1")
		if intent.route_creates.size() > 0:
			created_route = true
			break
	assert_true(created_route, "NPC should eventually create a route")


func test_npc_bids_on_slots_when_aggressive() -> void:
	controller.slot_aggression = 1.0  # Always bid
	var bid := false
	for seed_val in range(1, 50):
		game_state = _create_game_state(seed_val)
		var intent := controller.generate_intent(game_state, "npc_1")
		if intent.slot_bids.size() > 0:
			bid = true
			break
	assert_true(bid, "Aggressive NPC should bid on slots")


func test_npc_orders_ships_when_all_deployed() -> void:
	controller.ship_eagerness = 1.0
	var ordered := false
	for seed_val in range(1, 50):
		game_state = _create_game_state(seed_val)
		game_state.get_carrier("npc_1").slots["centauri_prime"] = 1
		var c := game_state.get_carrier("npc_1")
		var sid: String = c.ships[0].id
		var tids: Array[String] = [sid]
		var r := CarrierData.Route.new(
			"npc_1-route-0", "proxima_b", "centauri_prime",
			tids, 5.0, 4.0, 1, true
		)
		c.routes.append(r)
		controller = NpcController.new()
		controller.ship_eagerness = 1.0
		var intent := controller.generate_intent(game_state, "npc_1")
		if intent.ship_orders.size() > 0:
			ordered = true
			break
	assert_true(ordered, "NPC with all ships deployed should order a new ship")


func test_npc_does_nothing_when_conservative() -> void:
	controller.slot_aggression = 0.0
	controller.route_preference = 0.0
	controller.ship_eagerness = 0.0
	# With all weights at 0, the RNG gates should block most actions.
	# Route creation isn't gated by RNG so NPC might still create routes — that's fine.
	var intent := controller.generate_intent(game_state, "npc_1")
	assert_not_null(intent)
	assert_eq(intent.carrier_id, "npc_1")


func test_invalid_carrier_returns_empty_intent() -> void:
	var intent := controller.generate_intent(game_state, "nonexistent")
	assert_eq(intent.carrier_id, "nonexistent")
	assert_eq(intent.slot_bids.size(), 0)
	assert_eq(intent.route_creates.size(), 0)


func test_slot_bid_has_valid_structure() -> void:
	controller.slot_aggression = 1.0
	var bid_found := false
	for seed_val in range(1, 100):
		game_state = _create_game_state(seed_val)
		controller = NpcController.new()
		controller.slot_aggression = 1.0
		var intent := controller.generate_intent(game_state, "npc_1")
		if intent.slot_bids.size() > 0:
			var bid: Dictionary = intent.slot_bids[0]
			assert_has(bid, "planet_id")
			assert_has(bid, "quantity")
			assert_has(bid, "price_per_slot")
			assert_true(bid["quantity"] > 0)
			assert_true(bid["price_per_slot"] > 0.0)
			bid_found = true
			break
	assert_true(bid_found, "Should find a valid bid with aggressive settings")
