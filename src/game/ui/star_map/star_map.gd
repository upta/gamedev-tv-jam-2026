class_name StarMap
extends Control

## Visual galaxy map showing planets, lanes, and active carrier routes.

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
const LANE_CLICK_THRESHOLD := 10.0

const PLANET_POSITIONS := {
	"earth": Vector2(200, 300),
	"mars": Vector2(320, 240),
	"titan": Vector2(150, 430),
	"europa": Vector2(280, 460),
	"proxima_b": Vector2(680, 150),
	"centauri_prime": Vector2(830, 200),
	"haven": Vector2(740, 300),
	"wolf_station": Vector2(780, 450),
	"forge": Vector2(900, 400),
	"outpost": Vector2(940, 520),
	"tau_haven": Vector2(1050, 250),
	"frosthold": Vector2(1100, 370),
}

const _LaneLine := preload("res://game/ui/star_map/lane_line.gd")
const _PlanetNodeScene := preload("res://game/ui/star_map/planet_node.tscn")

var _game_state: GameState
var _planet_nodes: Dictionary = {}   # { planet_id: Area2D (PlanetNode) }
var _lane_lines: Dictionary = {}     # { lane_id: Line2D (LaneLine) }
var _route_lines: Array = []         # drawn route overlay Line2Ds
var _selected_planet_id: String = ""
var _selected_lane_id: String = ""

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

	if _selected_lane_id != "":
		var prev_lane: Node = _lane_lines.get(_selected_lane_id, null)
		if prev_lane:
			prev_lane.set_selected(false)
		_selected_lane_id = ""


func _build_map() -> void:
	# Clear existing content
	for child: Node in _map_content.get_children():
		child.queue_free()
	_planet_nodes.clear()
	_lane_lines.clear()
	_route_lines.clear()

	var galaxy: GalaxyData = _game_state.galaxy

	# 1. Lanes (drawn first, behind everything)
	for lane: GalaxyData.Lane in galaxy.lanes:
		var from_pos: Vector2 = PLANET_POSITIONS.get(lane.origin_id, Vector2.ZERO)
		var to_pos: Vector2 = PLANET_POSITIONS.get(lane.dest_id, Vector2.ZERO)
		var lane_line: Line2D = _LaneLine.new()
		lane_line.setup(lane, from_pos, to_pos)
		_map_content.add_child(lane_line)
		_lane_lines[lane.id] = lane_line

	# 2. Planets (on top of lanes)
	for planet: GalaxyData.Planet in galaxy.planets:
		var planet_node: Area2D = _PlanetNodeScene.instantiate()
		var pos: Vector2 = PLANET_POSITIONS.get(planet.id, Vector2.ZERO)
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
			var from_pos: Vector2 = PLANET_POSITIONS.get(route.origin_id, Vector2.ZERO)
			var to_pos: Vector2 = PLANET_POSITIONS.get(route.dest_id, Vector2.ZERO)

			# Calculate perpendicular offset for parallel routes
			var count: int = lane_route_counts.get(route.lane_id, 0)
			lane_route_counts[route.lane_id] = count + 1

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

			# Insert route lines after lane lines but before planet nodes
			var insert_idx: int = _lane_lines.size()
			if insert_idx < _map_content.get_child_count():
				_map_content.add_child(line)
				_map_content.move_child(line, insert_idx + _route_lines.size())
			else:
				_map_content.add_child(line)
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
	# Deselect lane if any
	if _selected_lane_id != "":
		var prev_lane: Node = _lane_lines.get(_selected_lane_id, null)
		if prev_lane:
			prev_lane.set_selected(false)
		_selected_lane_id = ""

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


func _on_lane_clicked(lane_id: String, origin_id: String, dest_id: String) -> void:
	# Deselect planet if any
	if _selected_planet_id != "":
		var prev_node: Node = _planet_nodes.get(_selected_planet_id, null)
		if prev_node:
			prev_node.set_selected(false)
		_selected_planet_id = ""

	# Deselect previous lane
	if _selected_lane_id != "" and _selected_lane_id != lane_id:
		var prev_lane: Node = _lane_lines.get(_selected_lane_id, null)
		if prev_lane:
			prev_lane.set_selected(false)

	# Select new lane (or toggle off if same)
	if _selected_lane_id == lane_id:
		var lane_line: Node = _lane_lines.get(lane_id, null)
		if lane_line:
			lane_line.set_selected(false)
		_selected_lane_id = ""
	else:
		_selected_lane_id = lane_id
		var lane_line: Node = _lane_lines.get(lane_id, null)
		if lane_line:
			lane_line.set_selected(true)
		lane_selected.emit(lane_id, origin_id, dest_id)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Check if click is near any lane line
			var click_pos: Vector2 = mb.position
			var closest_lane_id: String = ""
			var closest_dist: float = LANE_CLICK_THRESHOLD
			var closest_origin: String = ""
			var closest_dest: String = ""

			for lane_id: String in _lane_lines:
				var lane_line: Line2D = _lane_lines[lane_id]
				if lane_line.get_point_count() < 2:
					continue
				var a: Vector2 = lane_line.get_point_position(0)
				var b: Vector2 = lane_line.get_point_position(1)
				var dist: float = _point_to_segment_distance(click_pos, a, b)
				if dist < closest_dist:
					closest_dist = dist
					closest_lane_id = lane_id
					closest_origin = lane_line.origin_id
					closest_dest = lane_line.dest_id

			if closest_lane_id != "":
				_on_lane_clicked(closest_lane_id, closest_origin, closest_dest)
				get_viewport().set_input_as_handled()


static func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = point - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.001:
		return ap.length()
	var t: float = clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)
