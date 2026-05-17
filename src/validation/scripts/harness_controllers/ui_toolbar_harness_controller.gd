extends Control

## Validation harness for toolbar modal toggling.
## Opens and closes modals at known physics steps so scenarios can
## checkpoint and assert UI clickability.

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
			# Open ships modal
			game_scene._on_toolbar_pressed("ships")
		30:
			# Close ships modal
			game_scene._on_toolbar_pressed("ships")
		40:
			# Open routes modal
			game_scene._on_toolbar_pressed("routes")
		50:
			# Close routes modal
			game_scene._on_toolbar_pressed("routes")


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = { "step": _step }
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _build_harness_state() -> Dictionary:
	return {
		"step": _step,
		"active_modal": _get_active_modal(),
		"ui_visible": game_scene != null and game_scene.is_inside_tree(),
	}


func _get_active_modal() -> String:
	if game_scene == null:
		return ""
	return game_scene._active_modal
