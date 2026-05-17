extends GutTest

## Tests for IdleController

var controller: IdleController
var game_state: GameState


func before_each() -> void:
	controller = IdleController.new()
	game_state = GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state.initialize(galaxy, catalog, carriers)


func test_is_carrier_controller() -> void:
	assert_is(controller, CarrierController)


func test_is_refcounted() -> void:
	assert_is(controller, RefCounted)


func test_returns_empty_intent() -> void:
	var intent := controller.generate_intent(game_state, "player")
	assert_eq(intent.carrier_id, "player")
	assert_eq(intent.slot_bids.size(), 0)
	assert_eq(intent.route_creates.size(), 0)
	assert_eq(intent.ship_orders.size(), 0)
	assert_eq(intent.route_cancellations.size(), 0)
	assert_eq(intent.route_modifications.size(), 0)
	assert_eq(intent.slot_sales.size(), 0)


func test_works_for_any_carrier_id() -> void:
	for id in ["player", "npc_1", "npc_2", "npc_3"]:
		var intent := controller.generate_intent(game_state, id)
		assert_eq(intent.carrier_id, id)
