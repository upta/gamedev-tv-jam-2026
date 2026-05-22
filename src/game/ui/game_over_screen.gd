class_name GameOverScreen
extends ColorRect

signal play_again_requested()

const GOLD_COLOR := Color(1, 0.85, 0)
const PLAYER_HIGHLIGHT_COLOR := Color(0.24, 0.92, 0.67) # matches ThemeBuilder.ACCENT
const HEADER_LABELS: Array[String] = ["Rank", "Name", "Score", "Cash", "Ship Value", "Slot Value", "Route Value"]

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

	# Style "GAME OVER" label
	var game_over_label: Label = $CenterContainer/VBoxContainer/GameOverLabel
	if font_heading:
		game_over_label.add_theme_font_override("font", font_heading)
	game_over_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT)

	# Style turn label
	_turn_label.add_theme_color_override("font_color", ThemeBuilder.MUTED)

	# Style winner label
	if font_heading:
		_winner_label.add_theme_font_override("font", font_heading)


func show_results(rankings: Array, turns_played: int, player_carrier_id: String) -> void:
	_turn_label.text = "Turn %d / 30" % turns_played

	if rankings.size() > 0:
		var winner: Dictionary = rankings[0]
		var player_won: bool = (winner["carrier_id"] == player_carrier_id)
		_winner_label.add_theme_color_override("font_color", GOLD_COLOR)
		if player_won:
			_winner_label.text = "%s wins with score %d!" % [winner["carrier_name"], int(winner["score"])]
		else:
			var player_rank := _find_player_rank(rankings, player_carrier_id)
			_winner_label.text = "%s wins with score %d! (You placed #%d)" % [
				winner["carrier_name"], int(winner["score"]), player_rank
			]

	_clear_grid()
	_add_header_row()
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
	for header_text: String in HEADER_LABELS:
		var label := Label.new()
		label.text = header_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", ThemeBuilder.MUTED)
		_rankings_grid.add_child(label)


func _add_ranking_row(entry: Dictionary, is_player: bool) -> void:
	var values: Array[String] = [
		str(entry["rank"]),
		entry["carrier_name"],
		str(int(entry["score"])),
		str(int(entry["cash_score"])),
		str(int(entry["ship_score"])),
		str(int(entry["slot_score"])),
		str(int(entry["route_score"])),
	]

	for value: String in values:
		var label := Label.new()
		label.text = value
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_player:
			label.add_theme_color_override("font_color", PLAYER_HIGHLIGHT_COLOR)
		_rankings_grid.add_child(label)
