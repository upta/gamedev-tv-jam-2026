class_name GameScene
extends Control

var _player_controller: PlayerController
var _session: GameSession
var _carrier_id: String = "player"

var _modals: Dictionary = {}
var _active_modal: String = ""
var _skip_presentation: bool = false
var _route_modal_from_map: bool = false
var _slots_modal_from_map: bool = false

@onready var _top_bar: TopBar = %TopBar
@onready var _star_map = %StarMap
@onready var _scoreboard = %ScoreboardPanel
@onready var _pending_actions: PendingActionsPanel = %PendingActionsPanel
@onready var _toast_manager = %ToastManager
@onready var _game_over_screen = %GameOverScreen
@onready var _dashboard_modal: DashboardModal = %DashboardModal
@onready var _turn_log_modal: TurnLogModal = %TurnLogModal
@onready var _ships_modal: ShipsModal = %ShipsModal
@onready var _slots_modal: SlotsModal = %SlotsModal
@onready var _routes_modal: RoutesModal = %RoutesModal
@onready var _create_route_modal: CreateRouteModal = %CreateRouteModal
@onready var _order_ship_modal: OrderShipModal = %OrderShipModal
@onready var _manage_slots_modal: ManageSlotsModal = %ManageSlotsModal
@onready var _turn_presentation: TurnPresentationOverlay = %TurnPresentationOverlay
@onready var _welcome_overlay: WelcomeOverlay = %WelcomeOverlay
@onready var _settings_menu: SettingsMenu = %SettingsMenu


func _ready() -> void:
	theme = ThemeBuilder.build_theme()
	_player_controller = PlayerController.new()
	_session = GameSetup.create_player_session(_player_controller)
	_player_controller.bind_carrier(
		_session.game_state.get_carrier(_carrier_id),
		_session.game_state.catalog
	)
	_modals = {
		"dashboard": _dashboard_modal,
		"routes": _routes_modal,
		"ships": _ships_modal,
		"slots": _slots_modal,
		"turn_log": _turn_log_modal,
	}
	_bind_all()
	_connect_signals()
	_show_welcome()
	_start_music()


func _show_welcome() -> void:
	if _skip_presentation or OS.has_feature("headless") or OS.get_cmdline_user_args().has("--test-mode"):
		return
	_welcome_overlay.show_tutorial()


func _start_music() -> void:
	if OS.has_feature("headless") or OS.get_cmdline_user_args().has("--test-mode"):
		return
	var am := _get_audio_manager()
	if am:
		am.play_music(am.MUSIC_MENU)


func _get_audio_manager() -> Node:
	return get_node_or_null("/root/AudioManager")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_settings_menu.toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F12:
			_save_debug_state()


func _bind_all() -> void:
	_top_bar.bind(_session.game_state, _carrier_id)
	_star_map.bind(_session.game_state)
	_scoreboard.bind(_session.game_state, _carrier_id)
	_pending_actions.bind(_player_controller, _session.game_state, _carrier_id)
	_dashboard_modal.bind(_session.game_state, _carrier_id)
	_ships_modal.bind(_player_controller, _session.game_state)
	_slots_modal.bind(_player_controller, _session.game_state)
	_routes_modal.bind(_player_controller, _session.game_state)
	_create_route_modal.bind(_player_controller, _session.game_state)
	_order_ship_modal.bind(_player_controller, _session.game_state)
	_manage_slots_modal.bind(_player_controller, _session.game_state)
	_turn_log_modal.set_game_state(_session.game_state)


func _connect_signals() -> void:
	_top_bar.next_turn_pressed.connect(_on_next_turn)
	_top_bar.toolbar_button_pressed.connect(_on_toolbar_pressed)
	_top_bar.debug_save_pressed.connect(_save_debug_state)
	_game_over_screen.play_again_requested.connect(_on_play_again)
	_player_controller.intent_changed.connect(_on_intent_changed_refresh_top_bar)
	for modal_name: String in _modals:
		_modals[modal_name].closed.connect(_on_modal_closed)
	_routes_modal.create_route_requested.connect(_on_create_route_requested)
	_routes_modal.edit_route_requested.connect(_on_edit_route_requested)
	_create_route_modal.closed.connect(_on_create_route_modal_closed)
	_create_route_modal.route_created.connect(_on_route_created)
	_create_route_modal.route_modified.connect(_on_route_modified)
	_ships_modal.order_ship_requested.connect(_on_order_ship_requested)
	_order_ship_modal.closed.connect(_on_order_ship_modal_closed)
	_order_ship_modal.ship_ordered.connect(_on_ship_ordered)
	_slots_modal.manage_slots_requested.connect(_on_manage_slots_requested)
	_manage_slots_modal.closed.connect(_on_manage_slots_modal_closed)
	_manage_slots_modal.slot_action_submitted.connect(_on_slot_action_submitted)
	_star_map.route_requested.connect(_on_star_map_route_requested)
	_star_map.slot_purchase_requested.connect(_on_star_map_slot_purchase_requested)


func _on_next_turn() -> void:
	var am := _get_audio_manager()
	if am:
		am.play_sfx(am.SFX_BEEP_HIGH)

	_top_bar.set_turn_in_progress(true)

	# Capture pre-turn state
	var cash_before: Dictionary = {}
	for carrier: CarrierData in _session.game_state.carriers:
		cash_before[carrier.id] = carrier.cash
	var prev_financials := _session.game_state.last_turn_financials.duplicate(true)

	# Run the turn
	var result := _session.run_next_turn()

	# Build summaries
	var summaries := TurnSummaryBuilder.build_summaries(
		result, _session.game_state, cash_before, prev_financials
	)

	# Start presentation (skip in headless/validation mode)
	if _skip_presentation or OS.has_feature("headless") or OS.get_cmdline_user_args().has("--test-mode"):
		pass  # No presentation — go straight to refresh
	else:
		_turn_presentation.present_turn(summaries, _carrier_id, _session.game_state, prev_financials)
		await _turn_presentation.presentation_complete

	# Refresh UI
	_star_map.refresh(_session.game_state)
	_top_bar.refresh()
	_scoreboard.refresh()
	_pending_actions.refresh()
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
		var carrier_name: String = carrier_id
		for carrier: CarrierData in _session.game_state.carriers:
			if carrier.id == carrier_id:
				carrier_name = carrier.carrier_name
				break
		_toast_manager.show_toast("%s went bankrupt!" % carrier_name, "danger")


func _on_toolbar_pressed(modal_name: String) -> void:
	_star_map.cancel_guide_mode()

	# Close create route modal if open
	if _create_route_modal.visible:
		_create_route_modal.closed.disconnect(_on_create_route_modal_closed)
		_create_route_modal.close()
		_create_route_modal.closed.connect(_on_create_route_modal_closed)

	# Close order ship modal if open
	if _order_ship_modal.visible:
		_order_ship_modal.closed.disconnect(_on_order_ship_modal_closed)
		_order_ship_modal.close()
		_order_ship_modal.closed.connect(_on_order_ship_modal_closed)

	# Close manage slots modal if open
	if _manage_slots_modal.visible:
		_manage_slots_modal.closed.disconnect(_on_manage_slots_modal_closed)
		_manage_slots_modal.close()
		_manage_slots_modal.closed.connect(_on_manage_slots_modal_closed)

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
	_player_controller.intent_changed.disconnect(_on_intent_changed_refresh_top_bar)
	_player_controller = PlayerController.new()
	_session = GameSetup.create_player_session(_player_controller)
	_player_controller.bind_carrier(
		_session.game_state.get_carrier(_carrier_id),
		_session.game_state.catalog
	)
	_player_controller.intent_changed.connect(_on_intent_changed_refresh_top_bar)
	_bind_all()
	_top_bar.set_turn_in_progress(false)


func _save_debug_state() -> void:
	var path := DebugStateSaver.save(_session.game_state, _player_controller)
	var telemetry_path := _session.telemetry.save_to_file()
	_toast_manager.show_toast("Debug state saved: %s" % path, "success")
	_toast_manager.show_toast("Telemetry saved (%d turns): %s" % [_session.telemetry.get_turn_count(), telemetry_path], "success")


func _on_create_route_requested() -> void:
	_routes_modal.close()
	_create_route_modal.open()


func _on_edit_route_requested(route: CarrierData.Route) -> void:
	_routes_modal.close()
	_create_route_modal.open_for_edit(route)


func _on_star_map_route_requested(origin_id: String, dest_id: String) -> void:
	# Close any active modal
	if not _active_modal.is_empty():
		_modals[_active_modal].close()
		_active_modal = ""
		_top_bar.set_active_toolbar("")

	_route_modal_from_map = true

	# Check if player already has a route on this lane
	var lane_id := GalaxyData.derive_lane_id(origin_id, dest_id)
	var player_carrier := _session.game_state.get_player_carrier()
	if player_carrier:
		for route: CarrierData.Route in player_carrier.get_active_routes():
			if route.lane_id == lane_id:
				_create_route_modal.open_for_edit(route)
				return

	_create_route_modal.open_with_planets(origin_id, dest_id)


func _on_create_route_modal_closed() -> void:
	if _route_modal_from_map:
		_route_modal_from_map = false
		return
	# Return to routes modal when create modal is closed/cancelled
	_routes_modal.open()
	_active_modal = "routes"
	_top_bar.set_active_toolbar("routes")


func _on_route_created() -> void:
	# Route was created — routes modal will refresh via intent_changed signal
	pass


func _on_route_modified() -> void:
	# Route was modified — routes modal will refresh via intent_changed signal
	pass


func _on_order_ship_requested() -> void:
	_ships_modal.close()
	_order_ship_modal.open()


func _on_order_ship_modal_closed() -> void:
	_ships_modal.open()
	_active_modal = "ships"
	_top_bar.set_active_toolbar("ships")


func _on_ship_ordered() -> void:
	# Ship was ordered — ships modal will refresh via intent_changed signal
	pass


func _on_manage_slots_requested() -> void:
	_slots_modal.close()
	_manage_slots_modal.open()


func _on_manage_slots_modal_closed() -> void:
	if _slots_modal_from_map:
		_slots_modal_from_map = false
		return
	_slots_modal.open()
	_active_modal = "slots"
	_top_bar.set_active_toolbar("slots")


func _on_star_map_slot_purchase_requested(planet_id: String) -> void:
	_star_map.cancel_guide_mode()
	if not _active_modal.is_empty():
		_modals[_active_modal].close()
		_active_modal = ""
		_top_bar.set_active_toolbar("")
	_slots_modal_from_map = true
	_manage_slots_modal.open_with_buy(planet_id)


func _on_slot_action_submitted() -> void:
	# Slot action submitted — slots modal will refresh via intent_changed signal
	pass


func _on_intent_changed_refresh_top_bar(_intent: TurnPipeline.CarrierIntent) -> void:
	_top_bar.refresh()
	_scoreboard.refresh()
	_pending_actions.refresh()
