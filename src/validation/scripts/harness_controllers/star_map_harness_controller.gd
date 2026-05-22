extends Control

## Validation harness for the star map UI component.
## On reset: instantiates StarMap, binds it to a fresh GameState.
## Exposes planet/route/slot data through get_observed_state().

const StarMapScene := preload("res://game/ui/star_map/star_map.tscn")

var star_map: Node  # StarMap instance (avoid class_name reference for load-order safety)
var game_state_data: GameState
var _last_planet_selected: String = ""
var _planet_select_count: int = 0
var _last_route_requested_origin: String = ""
var _last_route_requested_dest: String = ""
var _route_request_count: int = 0
var _last_slot_purchase_planet_id: String = ""
var _slot_purchase_request_count: int = 0


func reset_harness() -> void:
	_last_planet_selected = ""
	_planet_select_count = 0
	_last_route_requested_origin = ""
	_last_route_requested_dest = ""
	_route_request_count = 0
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

	# Instantiate star map
	star_map = StarMapScene.instantiate()
	add_child(star_map)
	star_map.bind(game_state_data)

	star_map.planet_selected.connect(_on_planet_selected)
	star_map.route_requested.connect(_on_route_requested)
	star_map.slot_purchase_requested.connect(_on_slot_purchase_requested)


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = _build_metrics()
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _on_planet_selected(planet_id: String) -> void:
	_last_planet_selected = planet_id
	_planet_select_count += 1


func _on_route_requested(origin_id: String, dest_id: String) -> void:
	_last_route_requested_origin = origin_id
	_last_route_requested_dest = dest_id
	_route_request_count += 1


func _on_slot_purchase_requested(planet_id: String) -> void:
	_last_slot_purchase_planet_id = planet_id
	_slot_purchase_request_count += 1


## Programmatically trigger a right-click on a planet (simulated input)
func trigger_planet_right_click(planet_id: String) -> void:
	if star_map:
		star_map._on_planet_right_clicked(planet_id)


## Programmatically dismiss the context menu (simulated left-click on empty space)
func dismiss_context_menu() -> void:
	if star_map:
		star_map._dismiss_context_menu()


func _build_harness_state() -> Dictionary:
	var planet_count: int = star_map._planet_nodes.size() if star_map else 0
	var route_line_count: int = star_map._route_lines.size() if star_map else 0

	# Count planets that have slot indicators
	var planets_with_slots: int = 0
	if star_map:
		for planet_id: String in star_map._planet_nodes:
			var node: Node = star_map._planet_nodes[planet_id]
			if node._slot_indicators.size() > 0:
				planets_with_slots += 1

	# Gather per-carrier slot data
	var carrier_slot_counts: Dictionary = {}
	if game_state_data:
		for carrier: CarrierData in game_state_data.get_all_carriers():
			var total: int = 0
			for count: int in carrier.slots.values():
				total += count
			carrier_slot_counts[carrier.id] = total

	# Context menu state
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
		"planet_node_count": planet_count,
		"route_line_count": route_line_count,
		"planets_with_slots": planets_with_slots,
		"selected_planet_id": star_map._selected_planet_id if star_map else "",
		"last_planet_selected": _last_planet_selected,
		"planet_select_count": _planet_select_count,
		"carrier_slot_counts": carrier_slot_counts,
		"guide_origin_id": star_map._guide_origin_id if star_map else "",
		"guide_snap_planet_id": star_map._guide_snap_planet_id if star_map else "",
		"guide_active": star_map._is_guide_active() if star_map else false,
		"last_route_requested_origin": _last_route_requested_origin,
		"last_route_requested_dest": _last_route_requested_dest,
		"route_request_count": _route_request_count,
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
		"planet_nodes": star_map._planet_nodes.size() if star_map else 0,
		"route_overlays": star_map._route_lines.size() if star_map else 0,
	}
