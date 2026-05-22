class_name StarMap
extends Control

## Visual galaxy map showing planets and active carrier routes.

signal planet_selected(planet_id: String)

const CARRIER_COLORS := {
	"player": Color(0.24, 0.92, 0.67),
	"npc_1": Color(0.9, 0.3, 0.3),
	"npc_2": Color(0.3, 0.7, 0.9),
	"npc_3": Color(0.9, 0.7, 0.2),
}
const PLAYER_ROUTE_WIDTH := 4.0
const NPC_ROUTE_WIDTH := 2.0

const MAP_PADDING := 100.0
const MAP_DEFAULT_SIZE := Vector2(1200, 700)

const _PlanetNodeScene := preload("res://game/ui/star_map/planet_node.tscn")

var _game_state: GameState
var _planet_nodes: Dictionary = {}   # { planet_id: Area2D (PlanetNode) }
var _route_lines: Array = []         # drawn route overlay Line2Ds
var _selected_planet_id: String = ""
var _planet_positions: Dictionary = {}  # { planet_id: Vector2 } in pixel space
var _planet_radii: Dictionary = {}     # { planet_id: float } for hit detection
var _hover_panel: PanelContainer = null
var _hover_label: RichTextLabel = null
var _hovered_planet_id: String = ""

@onready var _map_content: Node2D = $MapContent


func bind(game_state: GameState) -> void:
	_game_state = game_state
	_build_map()
	_build_hover_panel()


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

	# Separation pass: push overlapping planets apart within each system
	_resolve_planet_overlap(galaxy, viewport_size)

	# Planets
	for planet: GalaxyData.Planet in galaxy.planets:
		var planet_node: Area2D = _PlanetNodeScene.instantiate()
		var pos: Vector2 = _planet_positions.get(planet.id, Vector2.ZERO)
		planet_node.position = pos
		_map_content.add_child(planet_node)
		planet_node.setup(planet)
		_planet_radii[planet.id] = planet_node.get_radius()
		_planet_nodes[planet.id] = planet_node

	# Initial data pass
	_update_slot_indicators()
	_update_route_overlays()


func _resolve_planet_overlap(galaxy: GalaxyData, viewport_size: Vector2) -> void:
	# Group planets by system
	var systems: Dictionary = {}
	for planet: GalaxyData.Planet in galaxy.planets:
		if not systems.has(planet.system):
			systems[planet.system] = []
		systems[planet.system].append(planet.id)

	var min_separation_h := 70.0  # Horizontal minimum (planet circles + some label width)
	var min_separation_v := 90.0  # Vertical minimum (radius + label height + gap)

	# Iterative repulsion within each system
	for _iteration: int in range(12):
		for system_id: String in systems:
			var planet_ids: Array = systems[system_id]
			for i: int in range(planet_ids.size()):
				for j: int in range(i + 1, planet_ids.size()):
					var id_a: String = planet_ids[i]
					var id_b: String = planet_ids[j]
					var pos_a: Vector2 = _planet_positions[id_a]
					var pos_b: Vector2 = _planet_positions[id_b]
					var delta: Vector2 = pos_b - pos_a
					# Use elliptical separation (more vertical clearance for labels)
					var overlap_x: float = min_separation_h - absf(delta.x)
					var overlap_y: float = min_separation_v - absf(delta.y)
					if overlap_x > 0 and overlap_y > 0:
						# Push apart along the axis with less overlap
						var direction: Vector2
						if overlap_x < overlap_y:
							direction = Vector2(signf(delta.x) if delta.x != 0 else 1.0, 0)
							var push: float = overlap_x * 0.5
							_planet_positions[id_a] = pos_a - direction * push
							_planet_positions[id_b] = pos_b + direction * push
						else:
							direction = Vector2(0, signf(delta.y) if delta.y != 0 else 1.0)
							var push: float = overlap_y * 0.5
							_planet_positions[id_a] = pos_a - direction * push
							_planet_positions[id_b] = pos_b + direction * push

	# Clamp all positions within viewport bounds
	for planet_id: String in _planet_positions:
		var pos: Vector2 = _planet_positions[planet_id]
		pos.x = clampf(pos.x, MAP_PADDING * 0.5, viewport_size.x - MAP_PADDING * 0.5)
		pos.y = clampf(pos.y, MAP_PADDING * 0.5, viewport_size.y - MAP_PADDING * 0.5)
		_planet_positions[planet_id] = pos


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var planet_id := _get_planet_at(mb.position)
			if planet_id != "":
				_on_planet_clicked(planet_id)
				accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var planet_id := _get_planet_at(motion.position)
		_update_hover(planet_id, motion.position)


func _get_planet_at(pos: Vector2) -> String:
	# Check which planet circle contains the position (closest if overlapping)
	var best_id := ""
	var best_dist := INF
	for planet_id: String in _planet_positions:
		var planet_pos: Vector2 = _planet_positions[planet_id]
		var radius: float = _planet_radii.get(planet_id, 12.0)
		var dist: float = pos.distance_to(planet_pos)
		if dist <= radius + 4.0 and dist < best_dist:  # small tolerance for easier targeting
			best_dist = dist
			best_id = planet_id
	return best_id


func _update_hover(planet_id: String, mouse_pos: Vector2) -> void:
	if planet_id == _hovered_planet_id:
		# Same planet — just reposition panel
		if planet_id != "" and _hover_panel and _hover_panel.visible:
			_position_hover_panel(mouse_pos)
		return
	# Changed planets
	if _hovered_planet_id != "":
		_on_planet_unhovered()
	_hovered_planet_id = planet_id
	if planet_id != "":
		_on_planet_hovered(planet_id, mouse_pos)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _hovered_planet_id != "":
			_hovered_planet_id = ""
			_on_planet_unhovered()


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


# ---------------------------------------------------------------------------
# Hover Info Panel
# ---------------------------------------------------------------------------

func _build_hover_panel() -> void:
	_hover_panel = PanelContainer.new()
	_hover_panel.visible = false
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = ThemeBuilder.SURFACE
	style.border_color = ThemeBuilder.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	_hover_panel.add_theme_stylebox_override("panel", style)

	_hover_label = RichTextLabel.new()
	_hover_label.bbcode_enabled = true
	_hover_label.fit_content = true
	_hover_label.scroll_active = false
	_hover_label.custom_minimum_size = Vector2(220, 0)
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_child(_hover_label)

	add_child(_hover_panel)


func _on_planet_hovered(planet_id: String, mouse_pos: Vector2) -> void:
	if _hover_panel == null or _game_state == null:
		return

	var planet := _game_state.galaxy.get_planet(planet_id)
	if planet == null:
		return

	# Gather ownership data
	var player_owned := 0
	var other_owned := 0
	var carriers := _game_state.get_all_carriers()
	for carrier: CarrierData in carriers:
		var count: int = carrier.get_slot_count(planet_id)
		if carrier.id == "player":
			player_owned += count
		else:
			other_owned += count
	var available: int = planet.total_slots - player_owned - other_owned

	# Count routes touching this planet
	var total_routes := 0
	var player_routes := 0
	for carrier: CarrierData in carriers:
		for route: CarrierData.Route in carrier.get_active_routes():
			if route.origin_id == planet_id or route.dest_id == planet_id:
				total_routes += 1
				if carrier.id == "player":
					player_routes += 1

	# Aggregate demand for lanes touching this planet
	var pax_demands: Array = []
	var cargo_demands: Array = []
	for other_planet: GalaxyData.Planet in _game_state.galaxy.planets:
		if other_planet.id == planet_id:
			continue
		var lane_id := GalaxyData.derive_lane_id(planet_id, other_planet.id)
		var fwd := _game_state.demand_table.get_entry(lane_id, "forward")
		var rev := _game_state.demand_table.get_entry(lane_id, "reverse")
		if fwd:
			pax_demands.append(fwd.base_demand_passenger)
			cargo_demands.append(fwd.base_demand_cargo)
		if rev:
			pax_demands.append(rev.base_demand_passenger)
			cargo_demands.append(rev.base_demand_cargo)

	var avg_pax := 0
	var avg_cargo := 0
	if pax_demands.size() > 0:
		var total := 0
		for d: int in pax_demands:
			total += d
		avg_pax = total / pax_demands.size()
	if cargo_demands.size() > 0:
		var total := 0
		for d: int in cargo_demands:
			total += d
		avg_cargo = total / cargo_demands.size()

	var pax_tier := DemandCalculator.get_demand_tier(avg_pax)
	var cargo_tier := DemandCalculator.get_demand_tier(avg_cargo)

	# Format system name
	var system_display := planet.system.replace("_", " ").capitalize()

	# Build panel text
	var text := "[b]%s[/b] (%s)\n" % [planet.name, system_display]
	text += "Slots: %d total (%d yours, %d NPC, %d available)\n" % [planet.total_slots, player_owned, other_owned, available]
	text += "Routes: %d active (%d yours)\n" % [total_routes, player_routes]
	text += "Demand: %s pax / %s cargo" % [pax_tier, cargo_tier]

	_hover_label.text = text
	_hover_panel.visible = true
	_hover_panel.size = Vector2.ZERO  # Force panel to resize to content
	_position_hover_panel(mouse_pos)


func _position_hover_panel(anchor_pos: Vector2) -> void:
	if _hover_panel == null or not _hover_panel.visible:
		return
	var panel_size: Vector2 = _hover_panel.size
	var viewport_size: Vector2 = size if size.x > 0 and size.y > 0 else MAP_DEFAULT_SIZE

	# Default: offset to the right and slightly above the mouse
	var pos := anchor_pos + Vector2(16, -panel_size.y - 8)

	# Clamp right edge
	if pos.x + panel_size.x > viewport_size.x:
		pos.x = anchor_pos.x - panel_size.x - 16
	# Clamp left edge
	if pos.x < 0:
		pos.x = 0
	# Clamp top edge
	if pos.y < 0:
		pos.y = anchor_pos.y + 16
	# Clamp bottom edge
	if pos.y + panel_size.y > viewport_size.y:
		pos.y = viewport_size.y - panel_size.y

	_hover_panel.position = pos


func _on_planet_unhovered() -> void:
	if _hover_panel:
		_hover_panel.visible = false
