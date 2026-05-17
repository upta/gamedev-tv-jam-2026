class_name GameScene
extends Control

var _player_controller: PlayerController
var _session: GameSession
var _carrier_id: String = "player"

@onready var _top_bar: TopBar = %TopBar
@onready var _star_map = %StarMap
@onready var _toast_manager = %ToastManager
@onready var _game_over_screen = %GameOverScreen


func _ready() -> void:
	_player_controller = PlayerController.new()
	_session = GameSetup.create_player_session(_player_controller)
	_bind_all()
	_connect_signals()


func _bind_all() -> void:
	_top_bar.bind(_session.game_state, _carrier_id)
	_star_map.bind(_session.game_state)


func _connect_signals() -> void:
	_top_bar.next_turn_pressed.connect(_on_next_turn)
	_game_over_screen.play_again_requested.connect(_on_play_again)


func _on_next_turn() -> void:
	_top_bar.set_turn_in_progress(true)
	var result := _session.run_next_turn()
	_star_map.refresh(_session.game_state)
	_top_bar.refresh()
	_show_turn_notifications(result)
	_top_bar.set_turn_in_progress(false)
	if result.game_over or _session.is_complete:
		_top_bar.set_game_over()
		var rankings := ScoreCalculator.get_rankings(
			_session.game_state.carriers, _session.game_state.catalog
		)
		_game_over_screen.show_results(rankings, result.turn_number, _carrier_id)


func _show_turn_notifications(result: TurnPipeline.TurnResult) -> void:
	for delivery: Dictionary in result.deliveries:
		if delivery.get("carrier_id", "") == _carrier_id:
			_toast_manager.show_toast("Ship delivered!", "success")

	for award: Dictionary in result.auction_results.get("awards", []):
		if award.get("carrier_id", "") == _carrier_id:
			var slots: int = award.get("slots_won", 0)
			var planet: String = award.get("planet_id", "")
			_toast_manager.show_toast("Won %d slots at %s" % [slots, planet], "success")
	for rejection: Dictionary in result.auction_results.get("rejections", []):
		if rejection.get("carrier_id", "") == _carrier_id:
			var planet: String = rejection.get("planet_id", "")
			_toast_manager.show_toast("Lost bid at %s" % planet, "danger")

	for desc: String in result.event_descriptions:
		_toast_manager.show_toast(desc, "warning")

	for carrier_id: String in result.bankruptcies:
		_toast_manager.show_toast("%s went bankrupt!" % carrier_id, "danger")


func _on_play_again() -> void:
	_game_over_screen.hide_screen()
	_toast_manager.clear_all()
	_player_controller = PlayerController.new()
	_session = GameSetup.create_player_session(_player_controller)
	_bind_all()
	_top_bar.set_turn_in_progress(false)
