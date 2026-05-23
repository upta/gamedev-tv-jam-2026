class_name StarFieldBackground
extends Control

## Decorative star field background drawn via _draw().
## Deterministic seed so the pattern is stable across frames/sessions.

const STAR_COUNT := 200
const SEED := 42

var _positions: Array[Vector2] = []
var _alphas: Array[float] = []


func _ready() -> void:
	resized.connect(_regenerate)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_regenerate()


func _regenerate() -> void:
	_positions.clear()
	_alphas.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var area := size
	if area.x <= 0 or area.y <= 0:
		return
	for _i: int in range(STAR_COUNT):
		_positions.append(Vector2(rng.randf() * area.x, rng.randf() * area.y))
		_alphas.append(rng.randf_range(0.12, 0.45))
	queue_redraw()


func _draw() -> void:
	# Dark background fill
	draw_rect(Rect2(Vector2.ZERO, size), ThemeBuilder.CLEAR_COLOR)
	# Stars
	var dim_color := ThemeBuilder.TEXT
	for i: int in range(_positions.size()):
		var star_color := Color(dim_color.r, dim_color.g, dim_color.b, _alphas[i])
		var radius: float = 0.5 + _alphas[i] * 1.5
		draw_circle(_positions[i], radius, star_color)
