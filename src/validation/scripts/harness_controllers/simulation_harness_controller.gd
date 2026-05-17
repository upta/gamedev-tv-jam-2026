extends Node

## Validation harness for the headless simulation core.
## Advances one turn per physics frame so scenarios can use wait_frames to step.

var game_state_data: GameState
var turns_resolved: int = 0
var last_turn_result: TurnPipeline.TurnResult = null
var scripted_intents: Dictionary = {}


func reset_harness() -> void:
	game_state_data = GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state_data.initialize(galaxy, catalog, carriers)
	turns_resolved = 0
	last_turn_result = null
	_setup_scripted_intents()


func _physics_process(_delta: float) -> void:
	if game_state_data == null:
		return
	if game_state_data.current_turn > 30:
		return

	var intents := _get_intents_for_turn(game_state_data.current_turn)
	last_turn_result = game_state_data.advance_turn(intents)
	turns_resolved += 1


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = _build_metrics()
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _build_harness_state() -> Dictionary:
	var state := {
		"current_turn": game_state_data.current_turn,
		"turns_resolved": turns_resolved,
		"carrier_count": game_state_data.carriers.size(),
		"galaxy": {
			"planet_count": game_state_data.galaxy.planets.size(),
		},
		"demand_table_initialized": game_state_data.demand_table != null,
		"carriers": {},
	}

	for carrier: CarrierData in game_state_data.carriers:
		var active_routes: Array = carrier.get_active_routes()
		var score := ScoreCalculator.calculate_score(carrier, game_state_data.catalog, game_state_data.galaxy)
		var carrier_state := {
			"cash": carrier.cash,
			"ship_count": carrier.ships.size(),
			"route_count": active_routes.size(),
			"slot_count": _total_slots(carrier),
			"score": score["total"],
		}

		# Per-route operating costs for validation
		var route_costs: Array = []
		for route: CarrierData.Route in active_routes:
			var op_cost := FinancialCalculator.calculate_route_operating_cost(
				route, carrier, game_state_data.catalog, game_state_data.galaxy
			)
			route_costs.append({
				"route_id": route.id,
				"frequency": route.frequency,
				"operating_cost": op_cost,
			})
		carrier_state["route_costs"] = route_costs

		state["carriers"][carrier.id] = carrier_state

	if last_turn_result != null:
		state["last_result"] = {
			"bankruptcies": last_turn_result.bankruptcies,
			"game_over": last_turn_result.game_over,
			"rankings": last_turn_result.rankings,
		}

	return state


func _build_metrics() -> Dictionary:
	var player := game_state_data.get_player_carrier()
	var total_ships := 0
	var total_routes := 0
	for carrier: CarrierData in game_state_data.carriers:
		total_ships += carrier.ships.size()
		total_routes += carrier.get_active_routes().size()

	# Economy balance metrics
	var price_factor_at_2x := DemandCalculator.calculate_price_factor(20.0, 10.0)
	var price_factor_at_10x := DemandCalculator.calculate_price_factor(100.0, 10.0)

	return {
		"player_cash": player.cash if player else 0.0,
		"total_carriers": game_state_data.carriers.size(),
		"total_ships_in_play": total_ships,
		"total_active_routes": total_routes,
		"price_factor_at_2x_suggested": price_factor_at_2x,
		"price_factor_at_10x_suggested": price_factor_at_10x,
	}


func _setup_scripted_intents() -> void:
	var player_intent := TurnPipeline.CarrierIntent.new()
	player_intent.carrier_id = "player"

	var player_carrier := game_state_data.get_player_carrier()
	if player_carrier and player_carrier.ships.size() > 0:
		var ship_id: String = player_carrier.ships[0].id
		player_intent.route_creates.append({
			"lane_id": "sol_earth_mars",
			"origin_id": "earth",
			"dest_id": "mars",
			"ship_ids": [ship_id],
			"passenger_price": 5.0,
			"cargo_price": 4.0,
			"frequency": 1,
		})

	scripted_intents[1] = [player_intent]


func _get_intents_for_turn(turn: int) -> Array:
	if scripted_intents.has(turn):
		return scripted_intents[turn]

	var intents: Array = []
	for carrier: CarrierData in game_state_data.carriers:
		var intent := TurnPipeline.CarrierIntent.new()
		intent.carrier_id = carrier.id
		intents.append(intent)
	return intents


func _total_slots(carrier: CarrierData) -> int:
	var total := 0
	for count: int in carrier.slots.values():
		total += count
	return total
