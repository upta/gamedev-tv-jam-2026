class_name PlanetNode
extends Area2D

## Interactive planet marker on the star map.

const SYSTEM_COLORS := {
	"sol": Color(0.3, 0.5, 1.0),
	"alpha_centauri": Color(0.3, 0.9, 0.4),
	"wolf_359": Color(0.9, 0.3, 0.3),
	"tau_ceti": Color(0.9, 0.9, 0.3),
}
const CARRIER_COLORS := {
	"player": Color(0.2, 0.6, 1.0),
	"npc_1": Color(0.9, 0.3, 0.3),
	"npc_2": Color(0.3, 0.9, 0.3),
	"npc_3": Color(0.9, 0.7, 0.2),
}
const SLOT_DOT_RADIUS := 3.0

var planet_id: String
var planet_name: String
var system: String
var total_slots: int
var _selected: bool = false
var _slot_indicators: Array = []  # Array of { color: Color, angle: float }

@onready var _label: Label = $NameLabel


func setup(planet: GalaxyData.Planet) -> void:
	planet_id = planet.id
	planet_name = planet.name
	system = planet.system
	total_slots = planet.total_slots

	# Configure collision shape
	var shape := CircleShape2D.new()
	shape.radius = _get_radius()
	$CollisionShape2D.shape = shape

	_label.text = planet_name
	_label.position = Vector2(-_label.size.x * 0.5, _get_radius() + 2.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	input_pickable = false
	queue_redraw()


func update_slots(slot_owners: Dictionary) -> void:
	_slot_indicators.clear()
	var idx: int = 0
	for carrier_id: String in slot_owners:
		var count: int = slot_owners[carrier_id]
		var color: Color = CARRIER_COLORS.get(carrier_id, Color.WHITE)
		for _i: int in range(count):
			_slot_indicators.append({ "color": color, "index": idx })
			idx += 1
	queue_redraw()


func set_selected(selected: bool) -> void:
	_selected = selected
	modulate = Color(1.3, 1.3, 1.3) if _selected else Color.WHITE
	queue_redraw()


func _draw() -> void:
	var radius: float = _get_radius()
	var color: Color = SYSTEM_COLORS.get(system, Color.WHITE)

	# Selection ring
	if _selected:
		draw_circle(Vector2.ZERO, radius + 3.0, Color(1.0, 1.0, 1.0, 0.4))

	# Planet body
	draw_circle(Vector2.ZERO, radius, color)

	# Slot indicator dots arranged in a ring around the planet
	if _slot_indicators.size() > 0:
		var ring_radius: float = radius + SLOT_DOT_RADIUS + 3.0
		var angle_step: float = TAU / maxi(_slot_indicators.size(), 1)
		for i: int in range(_slot_indicators.size()):
			var angle: float = -PI / 2.0 + angle_step * i
			var dot_pos := Vector2(cos(angle), sin(angle)) * ring_radius
			draw_circle(dot_pos, SLOT_DOT_RADIUS, _slot_indicators[i]["color"])


func get_radius() -> float:
	return _get_radius()


func _get_radius() -> float:
	return 8.0 + total_slots * 1.2
