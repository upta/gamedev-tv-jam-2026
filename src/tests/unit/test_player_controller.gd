extends GutTest

## Tests for PlayerController intent accumulation

var controller: PlayerController
var game_state: GameState
var carrier: CarrierData
var catalog: ShipCatalog


func before_each() -> void:
	controller = PlayerController.new()
	game_state = GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	catalog = ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state.initialize(galaxy, catalog, carriers)
	carrier = game_state.get_carrier("player")
	controller.bind_carrier(carrier, catalog)


# ---------------------------------------------------------------------------
# Basic state
# ---------------------------------------------------------------------------

func test_initial_intent_is_empty() -> void:
	assert_not_null(controller.pending_intent)
	assert_eq(controller.pending_intent.slot_bids.size(), 0)
	assert_eq(controller.pending_intent.route_creates.size(), 0)
	assert_eq(controller.pending_intent.route_modifications.size(), 0)
	assert_eq(controller.pending_intent.route_cancellations.size(), 0)
	assert_eq(controller.pending_intent.ship_orders.size(), 0)
	assert_eq(controller.pending_intent.slot_sales.size(), 0)


# ---------------------------------------------------------------------------
# Add methods
# ---------------------------------------------------------------------------

func test_add_slot_bid() -> void:
	controller.add_slot_bid("planet_a", 2, 50.0)
	assert_eq(controller.pending_intent.slot_bids.size(), 1)
	var bid: Dictionary = controller.pending_intent.slot_bids[0]
	assert_eq(bid["planet_id"], "planet_a")
	assert_eq(bid["quantity"], 2)
	assert_eq(bid["price_per_slot"], 50.0)


func test_add_route_create() -> void:
	controller.add_route_create("origin_a", "dest_b", ["ship_1"], 10.0, 5.0, 2)
	assert_eq(controller.pending_intent.route_creates.size(), 1)
	var rc: Dictionary = controller.pending_intent.route_creates[0]
	assert_eq(rc["origin_id"], "origin_a")
	assert_eq(rc["dest_id"], "dest_b")
	assert_eq(rc["ship_ids"], ["ship_1"])
	assert_eq(rc["passenger_price"], 10.0)
	assert_eq(rc["cargo_price"], 5.0)
	assert_eq(rc["frequency"], 2)


func test_modify_route() -> void:
	controller.modify_route("route_42", ["ship_2"], 20.0, 10.0, 3)
	assert_eq(controller.pending_intent.route_modifications.size(), 1)
	var mod: Dictionary = controller.pending_intent.route_modifications[0]
	assert_eq(mod["route_id"], "route_42")
	assert_eq(mod["ship_ids"], ["ship_2"])
	assert_eq(mod["passenger_price"], 20.0)
	assert_eq(mod["cargo_price"], 10.0)
	assert_eq(mod["frequency"], 3)


func test_cancel_route() -> void:
	controller.cancel_route("route_99")
	assert_eq(controller.pending_intent.route_cancellations.size(), 1)
	assert_eq(controller.pending_intent.route_cancellations[0], "route_99")


func test_add_ship_order() -> void:
	controller.add_ship_order("sd-100", 20, 20)
	assert_eq(controller.pending_intent.ship_orders.size(), 1)
	var order: Dictionary = controller.pending_intent.ship_orders[0]
	assert_eq(order["type_id"], "sd-100")
	assert_eq(order["passenger_capacity"], 20)
	assert_eq(order["cargo_capacity"], 20)


func test_add_slot_sale() -> void:
	controller.add_slot_sale("planet_b", 3)
	assert_eq(controller.pending_intent.slot_sales.size(), 1)
	var sale: Dictionary = controller.pending_intent.slot_sales[0]
	assert_eq(sale["planet_id"], "planet_b")
	assert_eq(sale["count"], 3)


# ---------------------------------------------------------------------------
# Clear
# ---------------------------------------------------------------------------

func test_clear_intent() -> void:
	controller.add_slot_bid("planet_a", 1, 10.0)
	controller.add_ship_order("sd-100", 20, 20)
	controller.cancel_route("route_1")
	controller.clear_intent()
	assert_eq(controller.pending_intent.slot_bids.size(), 0)
	assert_eq(controller.pending_intent.route_creates.size(), 0)
	assert_eq(controller.pending_intent.route_modifications.size(), 0)
	assert_eq(controller.pending_intent.route_cancellations.size(), 0)
	assert_eq(controller.pending_intent.ship_orders.size(), 0)
	assert_eq(controller.pending_intent.slot_sales.size(), 0)


# ---------------------------------------------------------------------------
# Remove methods
# ---------------------------------------------------------------------------

func test_remove_slot_bid() -> void:
	controller.add_slot_bid("planet_a", 1, 10.0)
	controller.add_slot_bid("planet_b", 2, 20.0)
	controller.remove_slot_bid(0)
	assert_eq(controller.pending_intent.slot_bids.size(), 1)
	assert_eq(controller.pending_intent.slot_bids[0]["planet_id"], "planet_b")


func test_remove_out_of_bounds_does_not_crash() -> void:
	controller.remove_slot_bid(99)
	controller.remove_route_create(-1)
	controller.remove_route_modification(0)
	controller.remove_route_cancellation(5)
	controller.remove_ship_order(10)
	controller.remove_slot_sale(100)
	# If we reach here without error the test passes
	assert_true(true)


# ---------------------------------------------------------------------------
# generate_intent
# ---------------------------------------------------------------------------

func test_generate_intent_returns_accumulated() -> void:
	controller.add_slot_bid("planet_a", 1, 10.0)
	controller.add_ship_order("sd-100", 20, 20)
	var intent: TurnPipeline.CarrierIntent = controller.generate_intent(game_state, "player")
	assert_eq(intent.slot_bids.size(), 1)
	assert_eq(intent.ship_orders.size(), 1)


func test_generate_intent_resets() -> void:
	controller.add_slot_bid("planet_a", 1, 10.0)
	controller.generate_intent(game_state, "player")
	assert_eq(controller.pending_intent.slot_bids.size(), 0)
	assert_eq(controller.pending_intent.route_creates.size(), 0)
	assert_eq(controller.pending_intent.ship_orders.size(), 0)


func test_generate_intent_sets_carrier_id() -> void:
	var intent: TurnPipeline.CarrierIntent = controller.generate_intent(game_state, "player")
	assert_eq(intent.carrier_id, "player")


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

func test_get_pending_summary() -> void:
	controller.add_slot_bid("p", 1, 1.0)
	controller.add_slot_bid("q", 1, 1.0)
	controller.add_route_create("o", "d", [], 1.0, 1.0)
	controller.cancel_route("r1")
	var summary: Dictionary = controller.get_pending_summary()
	assert_eq(summary["slot_bids"], 2)
	assert_eq(summary["route_creates"], 1)
	assert_eq(summary["route_modifications"], 0)
	assert_eq(summary["route_cancellations"], 1)
	assert_eq(summary["ship_orders"], 0)
	assert_eq(summary["slot_sales"], 0)


# ---------------------------------------------------------------------------
# Signal
# ---------------------------------------------------------------------------

func test_intent_changed_signal_emitted() -> void:
	watch_signals(controller)
	controller.add_slot_bid("planet_a", 1, 10.0)
	assert_signal_emitted(controller, "intent_changed")


# ---------------------------------------------------------------------------
# Multiple accumulation
# ---------------------------------------------------------------------------

func test_multiple_actions_accumulate() -> void:
	controller.add_slot_bid("planet_a", 1, 10.0)
	controller.add_route_create("o", "d", ["s1"], 5.0, 3.0)
	controller.modify_route("route_1", ["s2"], 8.0, 4.0)
	controller.cancel_route("route_2")
	controller.add_ship_order("sd-100", 20, 20)
	controller.add_slot_sale("planet_b", 2)
	assert_eq(controller.pending_intent.slot_bids.size(), 1)
	assert_eq(controller.pending_intent.route_creates.size(), 1)
	assert_eq(controller.pending_intent.route_modifications.size(), 1)
	assert_eq(controller.pending_intent.route_cancellations.size(), 1)
	assert_eq(controller.pending_intent.ship_orders.size(), 1)
	assert_eq(controller.pending_intent.slot_sales.size(), 1)


# ---------------------------------------------------------------------------
# Escrow
# ---------------------------------------------------------------------------

func test_slot_bid_escrows_cash() -> void:
	var initial_cash := carrier.cash
	controller.add_slot_bid("sol_a", 2, 50.0)
	assert_almost_eq(carrier.cash, initial_cash - 100.0, 0.01)


func test_remove_slot_bid_refunds_cash() -> void:
	var initial_cash := carrier.cash
	controller.add_slot_bid("sol_a", 2, 50.0)
	controller.remove_slot_bid(0)
	assert_almost_eq(carrier.cash, initial_cash, 0.01)


func test_replace_slot_bid_swaps_escrow() -> void:
	var initial_cash := carrier.cash
	controller.add_slot_bid("sol_a", 2, 50.0)  # cost 100
	controller.add_slot_bid("sol_a", 3, 40.0)  # cost 120, replaces old
	assert_almost_eq(carrier.cash, initial_cash - 120.0, 0.01)


func test_ship_order_escrows_cash() -> void:
	var initial_cash := carrier.cash
	var ship_type := catalog.get_type("sd-100")
	controller.add_ship_order("sd-100", 20, 20)
	assert_almost_eq(carrier.cash, initial_cash - float(ship_type.cost), 0.01)


func test_remove_ship_order_refunds_cash() -> void:
	var initial_cash := carrier.cash
	controller.add_ship_order("sd-100", 20, 20)
	controller.remove_ship_order(0)
	assert_almost_eq(carrier.cash, initial_cash, 0.01)


func test_generate_intent_refunds_all_escrow() -> void:
	var initial_cash := carrier.cash
	controller.add_slot_bid("sol_a", 2, 50.0)
	controller.add_ship_order("sd-100", 20, 20)
	controller.generate_intent(game_state, "player")
	assert_almost_eq(carrier.cash, initial_cash, 0.01)


func test_clear_intent_refunds_all_escrow() -> void:
	var initial_cash := carrier.cash
	controller.add_slot_bid("sol_a", 2, 50.0)
	controller.add_ship_order("sd-100", 20, 20)
	controller.clear_intent()
	assert_almost_eq(carrier.cash, initial_cash, 0.01)


func test_multiple_bids_and_orders_accumulate_escrow() -> void:
	var initial_cash := carrier.cash
	var ship_cost := float(catalog.get_type("sd-100").cost)
	controller.add_slot_bid("sol_a", 2, 50.0)  # 100
	controller.add_slot_bid("sol_b", 1, 75.0)  # 75
	controller.add_ship_order("sd-100", 20, 20)  # ship_cost
	var expected := initial_cash - 100.0 - 75.0 - ship_cost
	assert_almost_eq(carrier.cash, expected, 0.01)
	assert_almost_eq(controller._escrowed, 100.0 + 75.0 + ship_cost, 0.01)


func test_escrow_without_carrier_bound_does_not_crash() -> void:
	var unbound_ctrl := PlayerController.new()
	unbound_ctrl.add_slot_bid("sol_a", 2, 50.0)
	unbound_ctrl.add_ship_order("sd-100", 20, 20)
	unbound_ctrl.remove_slot_bid(0)
	unbound_ctrl.remove_ship_order(0)
	unbound_ctrl.clear_intent()
	# If we reach here without error the test passes
	assert_true(true)
