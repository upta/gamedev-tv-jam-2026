class_name GameScene
extends Control

var _player_controller: PlayerController
var _session: GameSession
var _carrier_id: String = "player"

var _modals: Dictionary = {}
var _active_modal: String = ""

@onready var _top_bar: TopBar = %TopBar
@onready var _star_map = %StarMap
@onready var _toast_manager = %ToastManager
@onready var _game_over_screen = %GameOverScreen
@onready var _dashboard_modal: DashboardModal = %DashboardModal
@onready var _turn_log_modal: TurnLogModal = %TurnLogModal
@onready var _ships_modal: ShipsModal = %ShipsModal
@onready var _slots_modal: SlotsModal = %SlotsModal
@onready var _routes_modal: RoutesModal = %RoutesModal


func _ready() -> void:
	_player_controller = PlayerController.new()
	_session = GameSetup.create_player_session(_player_controller)
	_modals = {
		"dashboard": _dashboard_modal,
		"routes": _routes_modal,
		"ships": _ships_modal,
		"slots": _slots_modal,
		"turn_log": _turn_log_modal,
	}
	_bind_all()
	_connect_signals()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_save_debug_state()


func _bind_all() -> void:
	_top_bar.bind(_session.game_state, _carrier_id)
	_star_map.bind(_session.game_state)
	_dashboard_modal.bind(_session.game_state, _carrier_id)
	_ships_modal.bind(_player_controller, _session.game_state)
	_slots_modal.bind(_player_controller, _session.game_state)
	_routes_modal.bind(_player_controller, _session.game_state)


func _connect_signals() -> void:
	_top_bar.next_turn_pressed.connect(_on_next_turn)
	_top_bar.toolbar_button_pressed.connect(_on_toolbar_pressed)
	_top_bar.debug_save_pressed.connect(_save_debug_state)
	_game_over_screen.play_again_requested.connect(_on_play_again)
	for modal_name: String in _modals:
		_modals[modal_name].closed.connect(_on_modal_closed)


func _on_next_turn() -> void:
	_top_bar.set_turn_in_progress(true)
	var result := _session.run_next_turn()
	_star_map.refresh(_session.game_state)
	_top_bar.refresh()
	_show_turn_notifications(result)
	_top_bar.set_turn_in_progress(false)
	_turn_log_modal.add_turn_result(result.turn_number, result, _carrier_id)
	if not _active_modal.is_empty():
		var modal = _modals[_active_modal]
		if modal.has_method("refresh"):
			modal.refresh()
	if result.game_over or _session.is_complete:
		_top_bar.set_game_over()
		var rankings := ScoreCalculator.get_rankings(
			_session.game_state.carriers, _session.game_state.catalog, _session.game_state.galaxy
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


func _on_toolbar_pressed(modal_name: String) -> void:
	if _active_modal == modal_name:
		_modals[modal_name].close()
		_active_modal = ""
		_top_bar.set_active_toolbar("")
	else:
		if not _active_modal.is_empty():
			_modals[_active_modal].close()
		_modals[modal_name].open()
		_active_modal = modal_name
		_top_bar.set_active_toolbar(modal_name)


func _on_modal_closed() -> void:
	_active_modal = ""
	_top_bar.set_active_toolbar("")


func _on_play_again() -> void:
	if not _active_modal.is_empty():
		_modals[_active_modal].close()
		_active_modal = ""
		_top_bar.set_active_toolbar("")
	_turn_log_modal.clear_log()
	_game_over_screen.hide_screen()
	_toast_manager.clear_all()
	_player_controller = PlayerController.new()
	_session = GameSetup.create_player_session(_player_controller)
	_bind_all()
	_top_bar.set_turn_in_progress(false)


func _save_debug_state() -> void:
	var path := DebugStateSaver.save(_session.game_state, _player_controller)
	_toast_manager.show_toast("Debug state saved: %s" % path, "success")
