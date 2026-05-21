extends Control

## Validation harness for route planning in the create-route modal.
## Verifies that no-slot planets stay selectable for estimation while create
## remains blocked with a clear reason until slots are acquired.

const ORIGIN_ID := "earth"
const NO_SLOT_DEST_ID := "titan"

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
			game_scene._on_toolbar_pressed("routes")
		50:
			game_scene._on_create_route_requested()
		60:
			game_scene._create_route_modal.set_origin(ORIGIN_ID)
		70:
			game_scene._create_route_modal.open_planet_selector("dest")
		80:
			game_scene._create_route_modal.select_selection_popup_item(NO_SLOT_DEST_ID)
		90:
			var carrier: CarrierData = game_scene._session.game_state.get_carrier("player")
			if carrier:
				var available: Array = carrier.get_available_ships()
				if not available.is_empty():
					game_scene._create_route_modal.select_ships([available[0].id])


func get_observed_state() -> Dictionary:
	var popup_visible := false
	var modal_open := false
	var origin_id := ""
	var dest_id := ""
	var no_slot_planet_present := false
	var no_slot_planet_selectable := false
	var no_slot_planet_label := ""
	var distance_text := ""
	var range_text := ""
	var create_button_disabled := true
	var create_block_reason := ""

	if game_scene != null:
		var modal = game_scene.get("_create_route_modal")
		if modal != null:
			modal_open = modal.visible
			popup_visible = modal.is_selection_popup_visible()
			var form_state: Dictionary = modal.get_form_state()
			origin_id = form_state.get("origin_id", "")
			dest_id = form_state.get("dest_id", "")
			for item: Dictionary in modal.get_selection_popup_items():
				if item.get("id", "") == NO_SLOT_DEST_ID:
					no_slot_planet_present = true
					no_slot_planet_selectable = item.get("selectable", false)
					no_slot_planet_label = item.get("label", "")
			for line: String in modal.get_detail_lines():
				if line.begins_with("Distance:"):
					distance_text = line
				elif line.begins_with("Ships in range:") or line.begins_with("No ships in range"):
					range_text = line
			create_button_disabled = modal.is_create_action_disabled()
			create_block_reason = modal.get_create_status_text()

	return {
		"step": _step,
		"create_route_modal_open": modal_open,
		"selection_popup_visible": popup_visible,
		"origin_id": origin_id,
		"dest_id": dest_id,
		"no_slot_planet_present": no_slot_planet_present,
		"no_slot_planet_selectable": no_slot_planet_selectable,
		"no_slot_planet_label": no_slot_planet_label,
		"distance_text": distance_text,
		"range_text": range_text,
		"create_button_disabled": create_button_disabled,
		"create_block_reason": create_block_reason,
		"metrics": { "step": _step },
		"nodes": {},
		"signals": {},
	}
