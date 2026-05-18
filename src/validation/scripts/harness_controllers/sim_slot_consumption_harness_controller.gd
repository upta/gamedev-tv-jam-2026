extends Node

## Validation harness for slot consumption by routes.
## Creates routes that consume slots, then verifies slots are properly consumed
## and further route creation is blocked when all slots are used.

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
	if game_state_data.current_turn > 5:
		return

	var intents := _get_intents_for_turn(game_state_data.current_turn)
	last_turn_result = game_state_data.advance_turn(intents)
	turns_resolved += 1


func get_observed_state() -> Dictionary:
	var player := game_state_data.get_player_carrier()
	var earth_owned := player.get_slot_count("earth") if player else 0
	var mars_owned := player.get_slot_count("mars") if player else 0
	var earth_used := player.get_slots_used_by_routes("earth") if player else 0
	var mars_used := player.get_slots_used_by_routes("mars") if player else 0
	var earth_available := player.get_available_slots_at("earth") if player else 0
	var mars_available := player.get_available_slots_at("mars") if player else 0
	var active_routes := player.get_active_routes().size() if player else 0

	var route_changes: Array = []
	if last_turn_result != null:
		route_changes = last_turn_result.route_changes

	var route_creates_count := 0
	var route_rejections := 0
	for change: Dictionary in route_changes:
		if change.get("type", "") == "created":
			route_creates_count += 1

	return {
		"current_turn": game_state_data.current_turn,
		"turns_resolved": turns_resolved,
		"earth_owned": earth_owned,
		"mars_owned": mars_owned,
		"earth_used": earth_used,
		"mars_used": mars_used,
		"earth_available": earth_available,
		"mars_available": mars_available,
		"active_routes": active_routes,
		"route_creates_this_turn": route_creates_count,
		"route_changes": route_changes,
		"metrics": {
			"active_routes": active_routes,
			"earth_available": earth_available,
			"mars_available": mars_available,
		},
		"nodes": {},
		"signals": {},
	}


func _setup_scripted_intents() -> void:
	var player := game_state_data.get_player_carrier()
	if player == null or player.ships.size() == 0:
		return

	var ship_id: String = player.ships[0].id

	# Turn 1: Create route earth→mars — should succeed, consuming 1 slot at each
	var intent_t1 := TurnPipeline.CarrierIntent.new()
	intent_t1.carrier_id = "player"
	intent_t1.route_creates.append({
		"origin_id": "earth",
		"dest_id": "mars",
		"ship_ids": [ship_id],
		"passenger_price": 5.0,
		"cargo_price": 4.0,
		"frequency": 1,
	})
	scripted_intents[1] = [intent_t1]

	# Turn 2: Order a new ship (so we have a ship for turn 4)
	var intent_t2 := TurnPipeline.CarrierIntent.new()
	intent_t2.carrier_id = "player"
	intent_t2.ship_orders.append({
		"type_id": "sd-100",
		"passenger_capacity": 20,
		"cargo_capacity": 20,
	})
	scripted_intents[2] = [intent_t2]

	# Turn 4: Try to create another route earth→mars — should FAIL because mars has 0 available slots
	# (The new ship arrives at turn 4 since build_turns=2)
	var intent_t4 := TurnPipeline.CarrierIntent.new()
	intent_t4.carrier_id = "player"
	# We need to reference the ship that will be delivered. It will be the second ship.
	# Since we can't know the exact ID, we'll try with a placeholder — actually the pipeline
	# validates with actual ships, so we need to wait until the ship is delivered.
	# Instead, let's just attempt a second route — it will fail on no available mars slots
	# regardless of ship availability. Use the same ship id — it'll fail on slots first.
	intent_t4.route_creates.append({
		"origin_id": "earth",
		"dest_id": "mars",
		"ship_ids": [ship_id],
		"passenger_price": 5.0,
		"cargo_price": 4.0,
		"frequency": 1,
	})
	scripted_intents[4] = [intent_t4]


func _get_intents_for_turn(turn: int) -> Array:
	if scripted_intents.has(turn):
		return scripted_intents[turn]
	return []
