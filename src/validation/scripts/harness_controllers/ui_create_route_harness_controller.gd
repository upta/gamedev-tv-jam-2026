extends Control

## Validation harness for the create-route selection popup.
## Exercises the planet selector UI and exposes popup visibility/item count
## for scenario assertions. Does NOT run turns — purely UI-focused.

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
			# Open routes modal
			game_scene._on_toolbar_pressed("routes")
		50:
			# Open create route modal
			game_scene._on_create_route_requested()
		60:
			# Set origin to earth programmatically (for same-planet exclusion tests)
			game_scene._create_route_modal.set_origin("earth")
		70:
			# Open the planet selection popup for dest (earth should be excluded)
			game_scene._create_route_modal.open_planet_selector("dest")


func get_observed_state() -> Dictionary:
	var popup_visible := false
	var popup_items := 0
	var modal_open := false
	var origin_id := ""

	if game_scene != null:
		var modal = game_scene.get("_create_route_modal")
		if modal != null:
			modal_open = modal.visible
			popup_visible = modal.is_selection_popup_visible()
			popup_items = modal.get_selection_popup_item_count()
			origin_id = modal._origin_id

	return {
		"step": _step,
		"create_route_modal_open": modal_open,
		"selection_popup_visible": popup_visible,
		"selection_popup_item_count": popup_items,
		"origin_id": origin_id,
		"metrics": { "step": _step },
		"nodes": {},
		"signals": {},
	}
