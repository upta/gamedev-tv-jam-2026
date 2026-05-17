class_name StarMap
extends Control

## Visual galaxy map showing planets and active carrier routes.

signal planet_selected(planet_id: String)
signal lane_selected(lane_id: String, origin_id: String, dest_id: String)

const CARRIER_COLORS := {
	"player": Color(0.2, 0.6, 1.0),
	"npc_1": Color(0.9, 0.3, 0.3),
	"npc_2": Color(0.3, 0.9, 0.3),
	"npc_3": Color(0.9, 0.7, 0.2),
}
const PLAYER_ROUTE_WIDTH := 4.0
const NPC_ROUTE_WIDTH := 2.0

const MAP_PADDING := 60.0
const MAP_DEFAULT_SIZE := Vector2(1200, 700)

const _PlanetNodeScene := preload("res://game/ui/star_map/planet_node.tscn")

var _game_state: GameState
var _planet_nodes: Dictionary = {}   # { planet_id: Area2D (PlanetNode) }
var _route_lines: Array = []         # drawn route overlay Line2Ds
var _selected_planet_id: String = ""
var _planet_positions: Dictionary = {}  # { planet_id: Vector2 } in pixel space

@onready var _map_content: Node2D = $MapContent


func bind(game_state: GameState) -> void:
	_game_state = game_state
	_build_map()


func refresh(game_state: GameState) -> void:
	_game_state = game_state
	_update_slot_indicators()
	_update_route_overlays()


func deselect_all() -> void:
	if _selected_planet_id != "":
		var prev_node: Node = _planet_nodes.get(_selected_planet_id, null)
		if prev_node:
			prev_node.set_selected(false)
		_selected_planet_id = ""


func _build_map() -> void:
	# Clear existing content
	for child: Node in _map_content.get_children():
		child.queue_free()
	_planet_nodes.clear()
	_planet_positions.clear()
	_route_lines.clear()

	var galaxy: GalaxyData = _game_state.galaxy

	# Compute bounding box of all planet positions in light-year space
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for planet: GalaxyData.Planet in galaxy.planets:
		min_pos.x = minf(min_pos.x, planet.position.x)
		min_pos.y = minf(min_pos.y, planet.position.y)
		max_pos.x = maxf(max_pos.x, planet.position.x)
		max_pos.y = maxf(max_pos.y, planet.position.y)

	# Calculate scale and offset to fit all planets within the viewport
	var viewport_size: Vector2 = size if size.x > 0 and size.y > 0 else MAP_DEFAULT_SIZE
	var available := viewport_size - Vector2(MAP_PADDING * 2, MAP_PADDING * 2)
	var extent := max_pos - min_pos
	if extent.x < 0.001:
		extent.x = 1.0
	if extent.y < 0.001:
		extent.y = 1.0
	var map_scale: float = minf(available.x / extent.x, available.y / extent.y)
	var content_size := extent * map_scale
	var map_offset := (viewport_size - content_size) * 0.5 - min_pos * map_scale

	# Derive pixel positions from galaxy planet coordinates
	for planet: GalaxyData.Planet in galaxy.planets:
		_planet_positions[planet.id] = planet.position * map_scale + map_offset

	# Planets
	for planet: GalaxyData.Planet in galaxy.planets:
		var planet_node: Area2D = _PlanetNodeScene.instantiate()
		var pos: Vector2 = _planet_positions.get(planet.id, Vector2.ZERO)
		planet_node.position = pos
		_map_content.add_child(planet_node)
		planet_node.setup(planet)
		planet_node.clicked.connect(_on_planet_clicked)
		_planet_nodes[planet.id] = planet_node

	# Initial data pass
	_update_slot_indicators()
	_update_route_overlays()


func _update_route_overlays() -> void:
	# Clear old route lines
	for line: Line2D in _route_lines:
		line.queue_free()
	_route_lines.clear()

	if _game_state == null:
		return

	# Count routes per lane for offset calculation
	var lane_route_counts: Dictionary = {}  # lane_id -> current count

	for carrier: CarrierData in _game_state.get_all_carriers():
		for route: CarrierData.Route in carrier.get_active_routes():
			var from_pos: Vector2 = _planet_positions.get(route.origin_id, Vector2.ZERO)
			var to_pos: Vector2 = _planet_positions.get(route.dest_id, Vector2.ZERO)

			# Calculate perpendicular offset for parallel routes
			var lane_id := GalaxyData.derive_lane_id(route.origin_id, route.dest_id)
			var count: int = lane_route_counts.get(lane_id, 0)
			lane_route_counts[lane_id] = count + 1

			var direction: Vector2 = (to_pos - from_pos).normalized()
			var perpendicular := Vector2(-direction.y, direction.x)
			var offset: float = (count - 1.0) * 4.0  # center around midpoint
			var offset_vec: Vector2 = perpendicular * offset

			var line := Line2D.new()
			line.add_point(from_pos + offset_vec)
			line.add_point(to_pos + offset_vec)
			line.default_color = CARRIER_COLORS.get(carrier.id, Color.WHITE)
			line.width = PLAYER_ROUTE_WIDTH if carrier.id == "player" else NPC_ROUTE_WIDTH
			line.antialiased = true

			# Insert route lines behind planet nodes
			_map_content.add_child(line)
			var planet_start_idx: int = _map_content.get_child_count() - 1 - _planet_nodes.size()
			if planet_start_idx > 0:
				_map_content.move_child(line, planet_start_idx)
			_route_lines.append(line)


func _update_slot_indicators() -> void:
	if _game_state == null:
		return

	for planet_id: String in _planet_nodes:
		var planet_node: Area2D = _planet_nodes[planet_id]
		var slot_owners: Dictionary = {}

		for carrier: CarrierData in _game_state.get_all_carriers():
			var count: int = carrier.get_slot_count(planet_id)
			if count > 0:
				slot_owners[carrier.id] = count

		planet_node.update_slots(slot_owners)


func _on_planet_clicked(planet_id: String) -> void:
	# Deselect previous planet
	if _selected_planet_id != "" and _selected_planet_id != planet_id:
		var prev_node: Node = _planet_nodes.get(_selected_planet_id, null)
		if prev_node:
			prev_node.set_selected(false)

	# Select new planet (or toggle off if same)
	if _selected_planet_id == planet_id:
		var node: Node = _planet_nodes.get(planet_id, null)
		if node:
			node.set_selected(false)
		_selected_planet_id = ""
	else:
		_selected_planet_id = planet_id
		var node: Node = _planet_nodes.get(planet_id, null)
		if node:
			node.set_selected(true)
		planet_selected.emit(planet_id)
