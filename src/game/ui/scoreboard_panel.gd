class_name ScoreboardPanel
extends PanelContainer

var _game_state: GameState
var _carrier_id: String
var _rows_container: VBoxContainer


func _ready() -> void:
	_apply_style()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "STANDINGS"
	title.add_theme_color_override("font_color", ThemeBuilder.MUTED)
	title.add_theme_font_size_override("font_size", 11)
	var font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_bold:
		title.add_theme_font_override("font", font_bold)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	_rows_container = VBoxContainer.new()
	_rows_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_container.add_theme_constant_override("separation", 1)
	vbox.add_child(_rows_container)


func bind(game_state: GameState, carrier_id: String) -> void:
	_game_state = game_state
	_carrier_id = carrier_id
	refresh()


func refresh() -> void:
	if _game_state == null or _rows_container == null:
		return

	for child in _rows_container.get_children():
		child.queue_free()

	var rankings: Array = ScoreCalculator.get_rankings(
		_game_state.carriers, _game_state.catalog, _game_state.galaxy
	)

	for entry: Dictionary in rankings:
		var is_player: bool = entry["carrier_id"] == _carrier_id
		var row := _create_row(entry["rank"], entry["carrier_name"], is_player, entry["carrier_id"])
		_rows_container.add_child(row)


func _create_row(rank: int, carrier_name: String, is_player: bool, carrier_id: String) -> HBoxContainer:
	var carrier_color: Color = ThemeBuilder.CARRIER_COLORS.get(carrier_id, ThemeBuilder.MUTED)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)

	var indicator := Label.new()
	indicator.text = "●"
	indicator.add_theme_color_override("font_color", carrier_color)
	indicator.add_theme_font_size_override("font_size", 10)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(indicator)

	var name_label := Label.new()
	name_label.text = "#%d  %s" % [rank, carrier_name]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", carrier_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	return row


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	var bg := ThemeBuilder.SURFACE
	bg.a = 0.85
	style.bg_color = bg
	style.border_color = ThemeBuilder.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
