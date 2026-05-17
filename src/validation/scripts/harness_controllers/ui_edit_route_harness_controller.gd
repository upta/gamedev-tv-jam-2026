extends Control

## Validation harness for the edit route flow.
## Creates a route, advances a turn so it becomes active, then opens the
## edit modal and verifies pre-fill and modification.

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
		# Build up the player: bid for slots, order ships, advance turns
		40:
			game_scene._player_controller.add_slot_bid("earth", 1, 100.0)
		50:
			game_scene._on_next_turn()
		60:
			game_scene._player_controller.add_ship_order("sd-100", 20, 20)
		70:
			game_scene._on_next_turn()
		80:
			# Wait for ship delivery
			game_scene._on_next_turn()
		90:
			# Create a route programmatically
			var carrier: CarrierData = game_scene._session.game_state.get_carrier("player")
			if carrier:
				var available: Array = carrier.get_available_ships()
				if not available.is_empty():
					game_scene._player_controller.add_route_create(
						"earth", "mars", [available[0].id],
						15.0, 12.0, 1,
					)
		100:
			# Advance turn to make the route active
			game_scene._on_next_turn()
		120:
			# Open routes modal
			game_scene._on_toolbar_pressed("routes")
		130:
			# Find the active route and open edit modal
			var carrier: CarrierData = game_scene._session.game_state.get_carrier("player")
			if carrier:
				var active_routes := carrier.get_active_routes()
				if not active_routes.is_empty():
					game_scene._on_edit_route_requested(active_routes[0])
		150:
			# Change the passenger price
			game_scene._create_route_modal.set_passenger_price(25.0)
		160:
			# Save changes
			game_scene._create_route_modal.confirm_save()


func get_observed_state() -> Dictionary:
	var edit_modal_open := false
	var edit_mode := false
	var editing_route_id := ""
	var form_state: Dictionary = {}
	var pending_modifications := 0
	var pending_cancellations := 0
	var active_route_count := 0

	if game_scene != null:
		var modal = game_scene.get("_create_route_modal")
		if modal != null:
			edit_modal_open = modal.visible
			edit_mode = modal.get_edit_mode()
			editing_route_id = modal.get_editing_route_id()
			if modal.visible:
				form_state = modal.get_form_state()

		var pc = game_scene.get("_player_controller")
		if pc != null:
			var summary: Dictionary = pc.get_pending_summary()
			pending_modifications = summary.get("route_modifications", 0)
			pending_cancellations = summary.get("route_cancellations", 0)

		if game_scene.get("_session") != null:
			var carrier: CarrierData = game_scene._session.game_state.get_carrier("player")
			if carrier:
				active_route_count = carrier.get_active_routes().size()

	return {
		"step": _step,
		"edit_modal_open": edit_modal_open,
		"edit_mode": edit_mode,
		"editing_route_id": editing_route_id,
		"form_origin_id": form_state.get("origin_id", ""),
		"form_dest_id": form_state.get("dest_id", ""),
		"form_ship_count": form_state.get("ship_count", 0),
		"form_frequency": form_state.get("frequency", 0),
		"form_passenger_price": form_state.get("passenger_price", 0.0),
		"form_cargo_price": form_state.get("cargo_price", 0.0),
		"pending_modifications": pending_modifications,
		"pending_cancellations": pending_cancellations,
		"active_route_count": active_route_count,
		"metrics": { "step": _step },
		"nodes": {},
		"signals": {},
	}
