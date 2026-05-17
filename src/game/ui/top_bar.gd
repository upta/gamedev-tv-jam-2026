class_name TopBar
extends PanelContainer

signal next_turn_pressed()
signal toolbar_button_pressed(modal_name: String)

const TOOLBAR_BUTTONS: Array[Array] = [
	["📊 Dashboard", "dashboard"],
	["🚀 Routes", "routes"],
	["🛸 Ships", "ships"],
	["🏷️ Slots", "slots"],
	["📜 Turn Log", "turn_log"],
]

@onready var _turn_label: Label = %TurnLabel
@onready var _cash_label: Label = %CashLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _rank_label: Label = %RankLabel
@onready var _events_label: Label = %EventsLabel
@onready var _next_turn_button: Button = %NextTurnButton
@onready var _toolbar_container: HBoxContainer = %ToolbarContainer

var _game_state: GameState
var _carrier_id: String
var _toolbar_buttons: Dictionary = {}


func _ready() -> void:
	_next_turn_button.pressed.connect(_on_next_turn_pressed)
	_create_toolbar_buttons()


func _create_toolbar_buttons() -> void:
	for entry: Array in TOOLBAR_BUTTONS:
		var label: String = entry[0]
		var modal_name: String = entry[1]
		var button := Button.new()
		button.text = label
		button.flat = true
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

	var score_data: Dictionary = ScoreCalculator.calculate_score(carrier, _game_state.catalog)
	_score_label.text = "Score: %d" % int(score_data["total"])

	var rankings: Array = ScoreCalculator.get_rankings(_game_state.carriers, _game_state.catalog)
	var rank := 1
	var total_carriers := rankings.size()
	for entry: Dictionary in rankings:
		if entry["carrier_id"] == _carrier_id:
			rank = entry["rank"]
			break
	_rank_label.text = "Rank: %d/%d" % [rank, total_carriers]

	_events_label.text = "Events: %d" % _game_state.events.size()


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
