class_name LaneLine
extends Line2D

## Visual representation of a galaxy lane on the star map.

const DEFAULT_COLOR := Color(0.4, 0.4, 0.4)
const SELECTED_COLOR := Color(1.0, 1.0, 1.0)
const DEFAULT_WIDTH := 1.5

var lane_id: String
var origin_id: String
var dest_id: String
var _selected: bool = false


func setup(lane: GalaxyData.Lane, from_pos: Vector2, to_pos: Vector2) -> void:
	lane_id = lane.id
	origin_id = lane.origin_id
	dest_id = lane.dest_id
	clear_points()
	add_point(from_pos)
	add_point(to_pos)
	default_color = DEFAULT_COLOR
	width = DEFAULT_WIDTH
	antialiased = true


func set_selected(selected: bool) -> void:
	_selected = selected
	default_color = SELECTED_COLOR if _selected else DEFAULT_COLOR
	width = 2.5 if _selected else DEFAULT_WIDTH
