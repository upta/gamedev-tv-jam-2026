extends Control

## Validation harness for the manage-slots modal flow.
## Opens slots modal, clicks "Buy/Sell Slots", interacts with the form,
## places a bid, and returns to slots modal.

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
		20:
			# Open slots modal
			game_scene._on_toolbar_pressed("slots")
		30:
			# Click "Buy/Sell Slots" — opens manage slots modal
			game_scene._on_manage_slots_requested()
		40:
			# Select first planet
			var modal = game_scene._manage_slots_modal
			if modal and modal.visible:
				modal.select_planet(0)
		60:
			# Submit a bid
			var modal = game_scene._manage_slots_modal
			if modal and modal.visible:
				modal.confirm_bid()


func get_observed_state() -> Dictionary:
	var manage_modal_open := false
	var slots_modal_open := false
	var pending_slot_bids := 0
	var form_state := {}

	if game_scene != null:
		var manage_modal = game_scene.get("_manage_slots_modal")
		if manage_modal != null:
			manage_modal_open = manage_modal.visible
			if manage_modal.visible and manage_modal.has_method("get_form_state"):
				form_state = manage_modal.get_form_state()

		var slots_modal = game_scene.get("_slots_modal")
		if slots_modal != null:
			slots_modal_open = slots_modal.visible

		if game_scene.get("_player_controller") != null:
			pending_slot_bids = game_scene._player_controller.pending_intent.slot_bids.size()

	return {
		"step": _step,
		"manage_slots_modal_open": manage_modal_open,
		"slots_modal_open": slots_modal_open,
		"pending_slot_bids": pending_slot_bids,
		"form_state": form_state,
		"active_modal": _get_active_modal(),
		"metrics": { "step": _step },
		"nodes": {},
		"signals": {},
	}


func _get_active_modal() -> String:
	if game_scene == null:
		return ""
	return game_scene._active_modal
