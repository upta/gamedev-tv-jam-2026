extends GutTest

## Tests for CarrierController base class

var controller: CarrierController
var game_state: GameState


func before_each() -> void:
	controller = CarrierController.new()
	game_state = GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state.initialize(galaxy, catalog, carriers)


func test_generate_intent_returns_carrier_intent() -> void:
	var intent := controller.generate_intent(game_state, "player")
	assert_not_null(intent)
	assert_is(intent, TurnPipeline.CarrierIntent)


func test_generate_intent_sets_carrier_id() -> void:
	var intent := controller.generate_intent(game_state, "npc_1")
	assert_eq(intent.carrier_id, "npc_1")


func test_default_intent_is_empty() -> void:
	var intent := controller.generate_intent(game_state, "player")
	assert_eq(intent.slot_bids.size(), 0)
	assert_eq(intent.route_creates.size(), 0)
	assert_eq(intent.route_modifications.size(), 0)
	assert_eq(intent.route_cancellations.size(), 0)
	assert_eq(intent.ship_orders.size(), 0)
	assert_eq(intent.slot_sales.size(), 0)


func test_controller_is_refcounted() -> void:
	assert_is(controller, RefCounted)
