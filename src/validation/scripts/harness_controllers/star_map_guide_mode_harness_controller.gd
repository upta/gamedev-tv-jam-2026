extends Control

## Validation harness for star map guide mode lifecycle.
## Tests: guide activation, line following, route_requested emission.

const StarMapScene := preload("res://game/ui/star_map/star_map.tscn")

var star_map: Node  # StarMap instance
var game_state_data: GameState
var _step: int = 0
var _last_route_requested_origin: String = ""
var _last_route_requested_dest: String = ""
var _route_request_count: int = 0


func reset_harness() -> void:
	_step = 0
	_last_route_requested_origin = ""
	_last_route_requested_dest = ""
	_route_request_count = 0

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

	star_map.route_requested.connect(_on_route_requested)


func _physics_process(_delta: float) -> void:
	_step += 1

	if star_map == null:
		return

	match _step:
		40:
			# Click planet earth to enter guide mode
			star_map._on_planet_clicked("earth")
		60:
			# Click planet mars to request route
			star_map._on_planet_clicked("mars")


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = _build_metrics()
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _on_route_requested(origin_id: String, dest_id: String) -> void:
	_last_route_requested_origin = origin_id
	_last_route_requested_dest = dest_id
	_route_request_count += 1


func _build_harness_state() -> Dictionary:
	return {
		"step": _step,
		"guide_origin_id": star_map._guide_origin_id if star_map else "",
		"guide_snap_planet_id": star_map._guide_snap_planet_id if star_map else "",
		"guide_active": star_map._is_guide_active() if star_map else false,
		"last_route_requested_origin": _last_route_requested_origin,
		"last_route_requested_dest": _last_route_requested_dest,
		"route_request_count": _route_request_count,
	}


func _build_metrics() -> Dictionary:
	return {
		"step": _step,
		"route_request_count": _route_request_count,
	}
