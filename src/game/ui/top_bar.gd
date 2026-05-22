class_name TopBar
extends PanelContainer

signal next_turn_pressed()
signal toolbar_button_pressed(modal_name: String)
signal debug_save_pressed()

const TOOLBAR_BUTTONS: Array[Array] = [
	["Dashboard", "dashboard", "res://assets/icons/layout-dashboard.svg"],
	["Routes", "routes", "res://assets/icons/route.svg"],
	["Ships", "ships", "res://assets/icons/rocket.svg"],
	["Slots", "slots", "res://assets/icons/grid-dots.svg"],
	["Turn Log", "turn_log", "res://assets/icons/list.svg"],
]

@onready var _turn_label: Label = %TurnLabel
@onready var _cash_label: Label = %CashLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _next_turn_button: Button = %NextTurnButton
@onready var _toolbar_container: HBoxContainer = %ToolbarContainer

var _game_state: GameState
var _carrier_id: String
var _toolbar_buttons: Dictionary = {}


func _ready() -> void:
	_next_turn_button.pressed.connect(_on_next_turn_pressed)
	_create_toolbar_buttons()
	_apply_top_bar_style()
	if not OS.has_feature("web"):
		_create_debug_button()


func _create_toolbar_buttons() -> void:
	for entry: Array in TOOLBAR_BUTTONS:
		var label: String = entry[0]
		var modal_name: String = entry[1]
		var icon_path: String = entry[2]
		var button := Button.new()
		button.text = label
		button.flat = true
		var icon := load(icon_path) as Texture2D
		if icon:
			button.icon = icon
		button.pressed.connect(_on_toolbar_button_pressed.bind(modal_name))
		_toolbar_container.add_child(button)
		_toolbar_buttons[modal_name] = button


func bind(game_state: GameState, carrier_id: String) -> void:
	_game_state = game_state
	_carrier_id = carrier_id
	refresh()


func refresh() -> void:
	if _game_state == null:
		return

	_turn_label.text = "Turn %d / 30" % _game_state.current_turn

	var carrier: CarrierData = _game_state.get_carrier(_carrier_id)
	if carrier == null:
		return

	_cash_label.text = _format_cash(carrier.cash)

	var score_data: Dictionary = ScoreCalculator.calculate_score(carrier, _game_state.catalog, _game_state.galaxy)
	_score_label.text = "Score: %d" % int(score_data["total"])


func set_turn_in_progress(in_progress: bool) -> void:
	_next_turn_button.disabled = in_progress
	_next_turn_button.text = "Resolving..." if in_progress else "Next Turn"


func set_game_over() -> void:
	_next_turn_button.disabled = true
	_next_turn_button.text = "Game Over"


func set_active_toolbar(modal_name: String) -> void:
	for name: String in _toolbar_buttons:
		var button: Button = _toolbar_buttons[name]
		button.flat = (name != modal_name)


func _on_next_turn_pressed() -> void:
	next_turn_pressed.emit()


func _on_toolbar_button_pressed(modal_name: String) -> void:
	toolbar_button_pressed.emit(modal_name)


func _on_debug_save_pressed() -> void:
	debug_save_pressed.emit()


func _create_debug_button() -> void:
	var button := Button.new()
	button.text = "💾"
	button.tooltip_text = "Save debug state (F12)"
	button.flat = true
	button.pressed.connect(_on_debug_save_pressed)
	_toolbar_container.add_child(button)


func _format_cash(amount: float) -> String:
	var value: int = int(amount)
	var negative: bool = value < 0
	if negative:
		value = -value

	var text: String = str(value)
	var result: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1

	if negative:
		return "§-" + result
	return "§" + result


func _apply_top_bar_style() -> void:
	# Dark top bar panel (margins handled by MarginContainer in .tscn)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = ThemeBuilder.TOP_BAR_BG
	bar_style.border_color = ThemeBuilder.BORDER
	bar_style.border_width_bottom = 2
	add_theme_stylebox_override("panel", bar_style)

	# Stat label colors: turn is muted, cash/score/rank are bright
	_turn_label.add_theme_color_override("font_color", ThemeBuilder.MUTED)
	_cash_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	_score_label.add_theme_color_override("font_color", ThemeBuilder.TEXT)

	# Next Turn button accent styling
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = ThemeBuilder.ACCENT.darkened(0.6)
	btn_style.border_color = ThemeBuilder.ACCENT
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(6)
	btn_style.content_margin_left = 16
	btn_style.content_margin_right = 16
	_next_turn_button.add_theme_stylebox_override("normal", btn_style)
	_next_turn_button.add_theme_color_override("font_color", ThemeBuilder.ACCENT)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = ThemeBuilder.ACCENT.darkened(0.4)
	_next_turn_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := btn_style.duplicate()
	btn_pressed.bg_color = ThemeBuilder.ACCENT.darkened(0.3)
	_next_turn_button.add_theme_stylebox_override("pressed", btn_pressed)
