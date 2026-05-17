extends Control

## Validation harness for the order-ship modal flow.
## Opens ships modal, clicks "Order Ship", interacts with the order form,
## places an order, and returns to ships modal.

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
			# Click "Order Ship" — opens order ship modal
			game_scene._on_order_ship_requested()
		40:
			# Select first ship type and confirm order
			var modal = game_scene._order_ship_modal
			if modal and modal.visible:
				modal.select_type(0)
		50:
			# Place the order
			var modal = game_scene._order_ship_modal
			if modal and modal.visible:
				modal.confirm_order()


func get_observed_state() -> Dictionary:
	var order_modal_open := false
	var ships_modal_open := false
	var pending_ship_orders := 0
	var form_state := {}

	if game_scene != null:
		var order_modal = game_scene.get("_order_ship_modal")
		if order_modal != null:
			order_modal_open = order_modal.visible
			if order_modal.visible and order_modal.has_method("get_form_state"):
				form_state = order_modal.get_form_state()

		var ships_modal = game_scene.get("_ships_modal")
		if ships_modal != null:
			ships_modal_open = ships_modal.visible

		if game_scene.get("_player_controller") != null:
			pending_ship_orders = game_scene._player_controller.pending_intent.ship_orders.size()

	return {
		"step": _step,
		"order_ship_modal_open": order_modal_open,
		"ships_modal_open": ships_modal_open,
		"pending_ship_orders": pending_ship_orders,
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
