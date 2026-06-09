extends Control

## Screenshot harness controller for promotional images.
## Drives the game through ~11 turns with player actions, then captures:
##   1. "gameplay" — star map with routes visible (no modals)
##   2. "ships" — ships modal showing ship list
##   3. "turn_summary" — turn presentation overlay with player summary

var game_scene: Node
var _step: int = 0
var _phase: String = "setup"


func reset_harness() -> void:
	_step = 0
	_phase = "setup"

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
		# --- Phase 1: Build up game state (turns 1-11) ---
		40:
			game_scene._on_next_turn()  # Turn 2
		60:
			game_scene._on_next_turn()  # Turn 3
		80:
			game_scene._player_controller.add_slot_bid("earth", 1, 100.0)
		100:
			game_scene._on_next_turn()  # Turn 4 (processes slot bid)
		120:
			game_scene._player_controller.add_ship_order("sd-100", 20, 20)
		140:
			game_scene._on_next_turn()  # Turn 5 (ship ordered)
		160:
			game_scene._on_next_turn()  # Turn 6
		205:
			game_scene._on_toolbar_pressed("routes")
		213:
			game_scene._on_create_route_requested()
		225:
			game_scene._create_route_modal.set_origin("earth")
			game_scene._create_route_modal.set_destination("mars")
		235:
			var carrier: CarrierData = game_scene._session.game_state.get_carrier("player")
			if carrier:
				var available: Array = carrier.get_available_ships()
				if not available.is_empty():
					game_scene._create_route_modal.select_ships([available[0].id])
		245:
			game_scene._create_route_modal.confirm_create()
		250:
			# Close routes modal that re-opened after route creation
			if game_scene._active_modal == "routes":
				game_scene._on_toolbar_pressed("routes")

		# --- Phase 2: Screenshots (no more auto-turns after 260) ---
		270:
			_phase = "gameplay"
		280:
			game_scene._on_toolbar_pressed("ships")
		285:
			# Open the "Order Ship" sub-modal from ships modal
			game_scene._on_order_ship_requested()
			_phase = "ships"
		300:
			game_scene._order_ship_modal.close()
			game_scene._on_toolbar_pressed("ships")  # Close ships modal
		305:
			_show_turn_summary()
			_phase = "turn_summary"

	# Auto-advance turns 7-11 (steps 180-260, every 20 frames)
	if _step >= 180 and _step <= 260 and (_step - 180) % 20 == 0 and not game_scene._session.is_complete:
		game_scene._on_next_turn()


func _show_turn_summary() -> void:
	var session: GameSession = game_scene._session
	var gs: GameState = session.game_state

	# Capture pre-turn state for summary deltas
	var cash_before := {}
	for carrier: CarrierData in gs.carriers:
		cash_before[carrier.id] = carrier.cash
	var prev_financials: Dictionary = gs.last_turn_financials.duplicate(true)

	# Run turn 12
	var result: TurnPipeline.TurnResult = session.run_next_turn()

	# Build summaries
	var summaries: Dictionary = TurnSummaryBuilder.build_summaries(
		result, gs, cash_before, prev_financials
	)

	# Refresh UI behind overlay
	game_scene._star_map.refresh(game_scene._session.game_state)
	game_scene._top_bar.refresh()
	game_scene._scoreboard.refresh()
	game_scene._pending_actions.refresh()

	# Show turn presentation overlay, skip to player summary
	game_scene._turn_presentation.present_turn(
		summaries, game_scene._carrier_id,
		game_scene._session.game_state, prev_financials
	)
	game_scene._turn_presentation._show_player_summary()


func get_observed_state() -> Dictionary:
	return {
		"step": _step,
		"phase": _phase,
		"current_turn": _get_current_turn(),
		"active_modal": _get_active_modal(),
		"turn_summary_visible": _is_turn_summary_visible(),
		"player_routes": _get_player_route_count(),
		"player_ships": _get_player_ship_count(),
		"metrics": { "step": _step },
		"nodes": {},
		"signals": {},
	}


func _get_current_turn() -> int:
	if game_scene == null or game_scene.get("_session") == null:
		return 0
	return game_scene._session.game_state.current_turn


func _get_active_modal() -> String:
	if game_scene == null:
		return ""
	return game_scene._active_modal


func _is_turn_summary_visible() -> bool:
	if game_scene == null:
		return false
	return game_scene._turn_presentation._overlay.visible


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


func _get_player_carrier() -> CarrierData:
	if game_scene == null or game_scene.get("_session") == null:
		return null
	return game_scene._session.game_state.get_carrier(game_scene._carrier_id)
