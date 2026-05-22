extends Control

## Validation harness for star map context menu when no slots are available.
## Tests: button shows "No Slots" and is disabled.

const StarMapScene := preload("res://game/ui/star_map/star_map.tscn")

var star_map: Node  # StarMap instance
var game_state_data: GameState
var _step: int = 0
var _last_slot_purchase_planet_id: String = ""
var _slot_purchase_request_count: int = 0


func reset_harness() -> void:
	_step = 0
	_last_slot_purchase_planet_id = ""
	_slot_purchase_request_count = 0

	if star_map != null and is_instance_valid(star_map):
		star_map.queue_free()
		star_map = null

	# Build game state
	game_state_data = GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state_data.initialize(galaxy, catalog, carriers)

	# Set up earth to have no available slots (all slots owned)
	var earth_planet := game_state_data.galaxy.get_planet("earth")
	if earth_planet:
		var total_slots: int = earth_planet.total_slots
		# Give all slots to player carrier
		var player := game_state_data.get_carrier("player")
		if player:
			player.slots["earth"] = total_slots

	# Instantiate star map
	star_map = StarMapScene.instantiate()
	add_child(star_map)
	star_map.bind(game_state_data)
	star_map.refresh(game_state_data)  # Update slot indicators

	star_map.slot_purchase_requested.connect(_on_slot_purchase_requested)


func _physics_process(_delta: float) -> void:
	_step += 1

	if star_map == null:
		return

	match _step:
		40:
			# Right-click planet earth (which has no available slots)
			star_map._show_context_menu("earth")


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = _build_metrics()
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _on_slot_purchase_requested(planet_id: String) -> void:
	_last_slot_purchase_planet_id = planet_id
	_slot_purchase_request_count += 1


func _build_harness_state() -> Dictionary:
	var context_menu_visible := false
	var context_menu_planet_id := ""
	var context_menu_button_text := ""
	var context_menu_button_disabled := false
	var hover_panel_visible := false
	
	if star_map:
		context_menu_visible = star_map._context_menu != null and star_map._context_menu.visible
		context_menu_planet_id = star_map._context_menu_planet_id if star_map._context_menu_planet_id else ""
		hover_panel_visible = star_map._hover_panel != null and star_map._hover_panel.visible
		
		# Access button directly from star_map._context_buy_btn
		if star_map._context_buy_btn:
			context_menu_button_text = star_map._context_buy_btn.text
			context_menu_button_disabled = star_map._context_buy_btn.disabled

	return {
		"step": _step,
		"context_menu_visible": context_menu_visible,
		"context_menu_planet_id": context_menu_planet_id,
		"context_menu_button_text": context_menu_button_text,
		"context_menu_button_disabled": context_menu_button_disabled,
		"hover_panel_visible": hover_panel_visible,
		"last_slot_purchase_planet_id": _last_slot_purchase_planet_id,
		"slot_purchase_request_count": _slot_purchase_request_count,
	}


func _build_metrics() -> Dictionary:
	return {
		"step": _step,
		"slot_purchase_request_count": _slot_purchase_request_count,
	}
