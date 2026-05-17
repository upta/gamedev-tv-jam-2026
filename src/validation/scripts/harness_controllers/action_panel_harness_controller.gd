extends Control

## Validation harness for the ActionPanel.
## Drives a sequence of context switches and intent submissions at specific
## physics frames so scenarios can checkpoint and assert at the right moments.

const ActionPanelScene := preload("res://game/ui/panels/action_panel.tscn")

var action_panel: Node
var game_state_data: GameState
var player_controller_inst: PlayerController
var _step: int = 0


func reset_harness() -> void:
	_step = 0

	if action_panel and is_instance_valid(action_panel):
		action_panel.queue_free()
		action_panel = null

	game_state_data = GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state_data.initialize(galaxy, catalog, carriers)

	player_controller_inst = PlayerController.new()
	player_controller_inst.pending_intent.carrier_id = "player"

	action_panel = ActionPanelScene.instantiate()
	add_child(action_panel)
	action_panel.bind(player_controller_inst, game_state_data)


func _physics_process(_delta: float) -> void:
	_step += 1
	# Steps are spaced generously (20-frame windows) so checkpoints can land
	# reliably between actions, regardless of load-harness frame overhead.
	match _step:
		30:
			action_panel.show_planet_actions("earth")
		50:
			player_controller_inst.add_slot_bid("earth", 2, 100.0)
		70:
			action_panel.show_lane_actions("sol_earth_mars", "earth", "mars")
		90:
			action_panel.show_default()
		110:
			player_controller_inst.add_ship_order("sd-100", 20, 20)
		130:
			player_controller_inst.clear_intent()


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = _build_metrics()
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _build_harness_state() -> Dictionary:
	return {
		"step": _step,
		"current_context": action_panel._current_context if action_panel else "",
		"context_label_text": action_panel._context_label.text if action_panel else "",
		"selected_planet_id": action_panel._selected_planet_id if action_panel else "",
		"selected_lane_id": action_panel._selected_lane_id if action_panel else "",
		"form_child_count": action_panel._form_container.get_child_count() if action_panel else 0,
		"pending_summary": player_controller_inst.get_pending_summary() if player_controller_inst else {},
	}


func _build_metrics() -> Dictionary:
	return {
		"step": _step,
	}
