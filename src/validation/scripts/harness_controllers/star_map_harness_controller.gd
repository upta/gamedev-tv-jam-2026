extends Control

## Validation harness for the star map UI component.
## On reset: instantiates StarMap, binds it to a fresh GameState.
## Exposes planet/route/slot data through get_observed_state().

const StarMapScene := preload("res://game/ui/star_map/star_map.tscn")

var star_map: Node  # StarMap instance (avoid class_name reference for load-order safety)
var game_state_data: GameState
var _last_planet_selected: String = ""
var _planet_select_count: int = 0


func reset_harness() -> void:
	_last_planet_selected = ""
	_planet_select_count = 0

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


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = _build_metrics()
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _on_planet_selected(planet_id: String) -> void:
	_last_planet_selected = planet_id
	_planet_select_count += 1


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

	return {
		"planet_node_count": planet_count,
		"route_line_count": route_line_count,
		"planets_with_slots": planets_with_slots,
		"selected_planet_id": star_map._selected_planet_id if star_map else "",
		"last_planet_selected": _last_planet_selected,
		"planet_select_count": _planet_select_count,
		"carrier_slot_counts": carrier_slot_counts,
	}


func _build_metrics() -> Dictionary:
	return {
		"planet_nodes": star_map._planet_nodes.size() if star_map else 0,
		"route_overlays": star_map._route_lines.size() if star_map else 0,
	}
