class_name TurnLogModal
extends ModalDialog

@onready var _turn_log_panel: TurnLogPanel = $Panel/VBoxContainer/ContentContainer/ScrollContainer/TurnLogPanel


func _ready() -> void:
	super()
	set_title("Turn Log")


func set_game_state(game_state: GameState) -> void:
	_turn_log_panel.set_game_state(game_state)


func add_turn_result(turn_number: int, result: TurnPipeline.TurnResult, carrier_id: String) -> void:
	_turn_log_panel.add_turn_result(turn_number, result, carrier_id)


func clear_log() -> void:
	_turn_log_panel.clear_log()
