extends Control

## Validation harness for UI layout measurement.
## Measures actual pixel dimensions and positions of key UI elements,
## then exposes them via get_observed_state() for assertion in scenarios.
## Each checkpoint also captures a screenshot for visual verification.

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
			game_scene._on_toolbar_pressed("ships")
		60:
			game_scene._on_toolbar_pressed("ships")
		65:
			game_scene._on_toolbar_pressed("routes")


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = { "step": _step }
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _build_harness_state() -> Dictionary:
	var result := {
		"step": _step,
		"active_modal": _get_active_modal(),
		"ui_visible": game_scene != null and game_scene.is_inside_tree(),
	}

	# Top bar layout metrics
	var top_bar: Node = _find_node_safe("TopBar")
	if top_bar:
		result["top_bar_height"] = int(top_bar.size.y)
		result["top_bar_width"] = int(top_bar.size.x)

		var margin_node: Node = top_bar.get_node_or_null("Margin")
		if margin_node:
			result["top_bar_margin_top"] = margin_node.get_theme_constant("margin_top")
			result["top_bar_margin_bottom"] = margin_node.get_theme_constant("margin_bottom")
			result["top_bar_margin_left"] = margin_node.get_theme_constant("margin_left")
			result["top_bar_margin_right"] = margin_node.get_theme_constant("margin_right")

		var hbox: Node = top_bar.get_node_or_null("Margin/HBoxContainer")
		if hbox:
			result["top_bar_hbox_separation"] = hbox.get_theme_constant("separation")

		var first_label: Node = top_bar.get_node_or_null("Margin/HBoxContainer/TurnLabel")
		if first_label:
			var label_global_y: float = first_label.global_position.y
			var bar_global_y: float = top_bar.global_position.y
			result["first_label_offset_y"] = int(label_global_y - bar_global_y)

		# Measure actual gap between first label and first separator
		var vsep: Node = top_bar.get_node_or_null("Margin/HBoxContainer/VSeparator")
		if first_label and vsep:
			var label_right: float = first_label.global_position.x + first_label.size.x
			var sep_left: float = vsep.global_position.x
			result["label_to_vsep_gap"] = int(sep_left - label_right)

	# Ships modal layout metrics (when open)
	var ships_modal: Node = _find_node_safe("ShipsModal")
	if ships_modal and ships_modal.visible:
		var content_vbox: Node = ships_modal.get_node_or_null(
			"Panel/VBoxContainer/ContentContainer/ScrollContainer/ContentVBox")
		if content_vbox:
			result["ships_vbox_separation"] = content_vbox.get_theme_constant("separation")

	# Routes modal layout metrics (when open)
	var routes_modal: Node = _find_node_safe("RoutesModal")
	if routes_modal and routes_modal.visible:
		var content_container: Node = routes_modal.get_node_or_null(
			"Panel/VBoxContainer/ContentContainer")
		if content_container:
			result["modal_content_margin_top"] = content_container.get_theme_constant("margin_top")
			result["modal_content_margin_left"] = content_container.get_theme_constant("margin_left")
			result["modal_content_margin_bottom"] = content_container.get_theme_constant("margin_bottom")
			result["modal_content_margin_right"] = content_container.get_theme_constant("margin_right")

		var vbox: Node = routes_modal.get_node_or_null("Panel/VBoxContainer")
		if vbox:
			result["modal_vbox_separation"] = vbox.get_theme_constant("separation")

	return result


func _get_active_modal() -> String:
	if game_scene == null:
		return ""
	return game_scene._active_modal


func _find_node_safe(node_name: String) -> Node:
	if game_scene == null:
		return null
	return game_scene.find_child(node_name, true, false)
