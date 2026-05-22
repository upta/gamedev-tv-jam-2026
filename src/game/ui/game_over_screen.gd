class_name GameOverScreen
extends ColorRect

signal play_again_requested()

const GOLD_COLOR := Color(1, 0.85, 0)
const PLAYER_HIGHLIGHT_COLOR := Color(0.24, 0.92, 0.67) # matches ThemeBuilder.ACCENT
const HEADER_LABELS: Array[String] = ["Rank", "Name", "Score", "Cash", "Ship Value", "Slot Value", "Route Value"]
const COLUMN_WIDTHS: Array[int] = [40, 140, 80, 80, 80, 80, 90]
const RIGHT_ALIGNED_COLUMNS: Array[int] = [2, 3, 4, 5, 6]

@onready var _turn_label: Label = $CenterContainer/VBoxContainer/TurnLabel
@onready var _winner_label: Label = $CenterContainer/VBoxContainer/WinnerLabel
@onready var _rankings_grid: GridContainer = $CenterContainer/VBoxContainer/RankingsGrid
@onready var _play_again_button: Button = $CenterContainer/VBoxContainer/PlayAgainButton


func _ready() -> void:
	visible = false
	_play_again_button.pressed.connect(func() -> void: play_again_requested.emit())
	_apply_style()


func _apply_style() -> void:
	color = Color(0.04, 0.055, 0.055, 0.85)
	var font_heading = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font

	var game_over_label: Label = $CenterContainer/VBoxContainer/GameOverLabel
	if font_heading:
		game_over_label.add_theme_font_override("font", font_heading)
	game_over_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT)

	_turn_label.add_theme_color_override("font_color", ThemeBuilder.MUTED)

	if font_heading:
		_winner_label.add_theme_font_override("font", font_heading)

	_rankings_grid.add_theme_constant_override("h_separation", 12)
	_rankings_grid.add_theme_constant_override("v_separation", 4)

	ThemeBuilder.style_primary_button(_play_again_button)


func show_results(rankings: Array, turns_played: int, player_carrier_id: String) -> void:
	_turn_label.text = "Turn %d / 30" % turns_played

	if rankings.size() > 0:
		var winner: Dictionary = rankings[0]
		var player_won: bool = (winner["carrier_id"] == player_carrier_id)
		_winner_label.add_theme_color_override("font_color", GOLD_COLOR)
		if player_won:
			_winner_label.text = "You win!"
		else:
			_winner_label.text = "%s wins!" % [winner["carrier_name"]]

	_clear_grid()
	_add_header_row()
	_add_spacer_row()
	for entry: Dictionary in rankings:
		_add_ranking_row(entry, entry["carrier_id"] == player_carrier_id)

	visible = true


func hide_screen() -> void:
	visible = false
	_clear_grid()
	_winner_label.text = ""
	_turn_label.text = ""


func _find_player_rank(rankings: Array, player_carrier_id: String) -> int:
	for entry: Dictionary in rankings:
		if entry["carrier_id"] == player_carrier_id:
			return entry["rank"] as int
	return 0


func _clear_grid() -> void:
	for child: Node in _rankings_grid.get_children():
		child.queue_free()


func _add_header_row() -> void:
	for i: int in HEADER_LABELS.size():
		var label := Label.new()
		label.text = HEADER_LABELS[i]
		label.custom_minimum_size.x = COLUMN_WIDTHS[i]
		if i in RIGHT_ALIGNED_COLUMNS:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elif i == 1:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", ThemeBuilder.MUTED)
		label.add_theme_font_size_override("font_size", 12)
		_rankings_grid.add_child(label)


func _add_spacer_row() -> void:
	for i: int in HEADER_LABELS.size():
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 4
		_rankings_grid.add_child(spacer)


func _add_ranking_row(entry: Dictionary, is_player: bool) -> void:
	var values: Array[String] = [
		str(entry["rank"]),
		entry["carrier_name"],
		FormatHelpers.format_cash(entry["score"]),
		FormatHelpers.format_cash(entry["cash_score"]),
		FormatHelpers.format_cash(entry["ship_score"]),
		FormatHelpers.format_cash(entry["slot_score"]),
		FormatHelpers.format_cash(entry["route_score"]),
	]

	for i: int in values.size():
		var label := Label.new()
		label.text = values[i]
		label.custom_minimum_size.x = COLUMN_WIDTHS[i]
		if i in RIGHT_ALIGNED_COLUMNS:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elif i == 1:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_player:
			label.add_theme_color_override("font_color", PLAYER_HIGHLIGHT_COLOR)
		_rankings_grid.add_child(label)
