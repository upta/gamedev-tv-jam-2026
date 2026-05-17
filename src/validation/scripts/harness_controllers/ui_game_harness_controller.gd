extends Control

## Validation harness for the full GameScene.
## Instantiates the game and drives a sequence of player actions at specific
## physics frames so scenarios can checkpoint and assert UI wiring end-to-end.
## Uses runtime load() instead of preload() to avoid script-reload ordering issues.

var game_scene: Node
var _step: int = 0


func reset_harness() -> void:
	_step = 0

	if game_scene and is_instance_valid(game_scene):
		game_scene.queue_free()
		game_scene = null

	var scene: PackedScene = load("res://game/main.tscn")
	game_scene = scene.instantiate()
	add_child(game_scene)


func _physics_process(_delta: float) -> void:
	_step += 1

	if game_scene == null or game_scene.get("_session") == null:
		return

	match _step:
		40:
			game_scene._on_next_turn()
		60:
			game_scene._on_next_turn()
		80:
			game_scene._player_controller.add_slot_bid("earth", 1, 100.0)
		100:
			game_scene._on_next_turn()
		120:
			game_scene._player_controller.add_ship_order("sd-100", 20, 20)
		140:
			game_scene._on_next_turn()
		160:
			game_scene._on_next_turn()

	if _step >= 180 and (_step - 180) % 20 == 0 and not game_scene._session.is_complete:
		game_scene._on_next_turn()


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = { "step": _step }
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _build_harness_state() -> Dictionary:
	return {
		"step": _step,
		"session_status": _get_session_status(),
		"current_turn": _get_current_turn(),
		"player_cash": _get_player_cash(),
		"player_score": _get_player_score(),
		"player_routes": _get_player_route_count(),
		"player_ships": _get_player_ship_count(),
		"player_slots": _get_player_slot_count(),
		"ui_visible": game_scene != null and game_scene.is_inside_tree(),
		"game_over_visible": _is_game_over_visible(),
		"top_bar_turn_text": _get_top_bar_turn_text(),
		"pending_actions": _get_pending_action_count(),
	}


func _get_session_status() -> String:
	if game_scene == null or game_scene.get("_session") == null:
		return "not_started"
	if game_scene._session.is_complete:
		return "completed"
	return "running"


func _get_current_turn() -> int:
	if game_scene == null or game_scene.get("_session") == null:
		return 0
	return game_scene._session.game_state.current_turn


func _get_player_cash() -> float:
	var carrier := _get_player_carrier()
	if carrier == null:
		return 0.0
	return carrier.cash


func _get_player_score() -> float:
	var carrier := _get_player_carrier()
	if carrier == null:
		return 0.0
	var score := ScoreCalculator.calculate_score(carrier, game_scene._session.game_state.catalog)
	return score["total"]


func _get_player_route_count() -> int:
	var carrier := _get_player_carrier()
	if carrier == null:
		return 0
	return carrier.get_active_routes().size()


func _get_player_ship_count() -> int:
	var carrier := _get_player_carrier()
	if carrier == null:
		return 0
	return carrier.ships.size()


func _get_player_slot_count() -> int:
	var carrier := _get_player_carrier()
	if carrier == null:
		return 0
	var total := 0
	for count: int in carrier.slots.values():
		total += count
	return total


func _is_game_over_visible() -> bool:
	if game_scene == null:
		return false
	return game_scene._game_over_screen.visible


func _get_top_bar_turn_text() -> String:
	if game_scene == null:
		return ""
	return game_scene._top_bar._turn_label.text


func _get_pending_action_count() -> int:
	if game_scene == null or game_scene.get("_player_controller") == null:
		return 0
	var summary: Dictionary = game_scene._player_controller.get_pending_summary()
	var total := 0
	for count: int in summary.values():
		total += count
	return total


func _get_player_carrier() -> CarrierData:
	if game_scene == null or game_scene.get("_session") == null:
		return null
	return game_scene._session.game_state.get_carrier(game_scene._carrier_id)
