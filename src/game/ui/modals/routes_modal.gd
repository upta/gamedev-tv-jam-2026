class_name RoutesModal
extends ModalDialog

## Modal showing active routes and pending route actions.
## Route creation is handled by CreateRouteModal, opened via the "Create Route" button.

signal create_route_requested

var _player_controller: PlayerController
var _game_state: GameState
var _content: VBoxContainer


func _ready() -> void:
	super._ready()
	set_title("Routes")
	var scroll: ScrollContainer = _content_container.get_child(0)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state
	_player_controller.intent_changed.connect(_on_intent_changed)


func open() -> void:
	super.open()
	refresh()


func _on_intent_changed(_intent: TurnPipeline.CarrierIntent) -> void:
	refresh()


# ---------------------------------------------------------------------------
# Rebuild
# ---------------------------------------------------------------------------

func refresh() -> void:
	if _content == null or _game_state == null:
		return
	for child: Node in _content.get_children():
		child.queue_free()

	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return

	_build_active_routes(carrier)
	_content.add_child(HSeparator.new())
	_build_pending_actions()
	_content.add_child(HSeparator.new())
	_build_create_button()


# ---------------------------------------------------------------------------
# Section 1: Active Routes
# ---------------------------------------------------------------------------

func _build_active_routes(carrier: CarrierData) -> void:
	var header := Label.new()
	header.text = "— Active Routes —"
	_content.add_child(header)

	var active_routes := carrier.get_active_routes()
	if active_routes.is_empty():
		var none_label := Label.new()
		none_label.text = "No active routes."
		_content.add_child(none_label)
		return

	for route: CarrierData.Route in active_routes:
		var origin := _game_state.galaxy.get_planet(route.origin_id)
		var dest := _game_state.galaxy.get_planet(route.dest_id)
		var origin_name: String = origin.name if origin else route.origin_id
		var dest_name: String = dest.name if dest else route.dest_id

		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s → %s | Ships: %d | Pax: §%d Cargo: §%d | Freq: %d" % [
			origin_name, dest_name, route.ship_ids.size(),
			int(route.passenger_price), int(route.cargo_price), route.frequency,
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel Route"
		cancel_btn.pressed.connect(_on_cancel_route.bind(route.id))
		row.add_child(cancel_btn)

		_content.add_child(row)


func _on_cancel_route(route_id: String) -> void:
	_player_controller.cancel_route(route_id)


# ---------------------------------------------------------------------------
# Section 2: Pending Route Actions
# ---------------------------------------------------------------------------

func _build_pending_actions() -> void:
	var header := Label.new()
	header.text = "— Pending Route Actions —"
	_content.add_child(header)

	var intent := _player_controller.pending_intent
	var has_any := false

	# Pending creates
	for i: int in range(intent.route_creates.size()):
		has_any = true
		var rc: Dictionary = intent.route_creates[i]
		var origin := _game_state.galaxy.get_planet(rc["origin_id"])
		var dest := _game_state.galaxy.get_planet(rc["dest_id"])
		var origin_name: String = origin.name if origin else rc["origin_id"]
		var dest_name: String = dest.name if dest else rc["dest_id"]

		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "Create: %s → %s (%d ships)" % [
			origin_name, dest_name, rc["ship_ids"].size(),
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.pressed.connect(_on_remove_route_create.bind(i))
		row.add_child(cancel_btn)

		_content.add_child(row)

	# Pending cancellations
	for i: int in range(intent.route_cancellations.size()):
		has_any = true
		var route_id: String = intent.route_cancellations[i]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "Cancel route: %s" % route_id
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var undo_btn := Button.new()
		undo_btn.text = "Undo"
		undo_btn.pressed.connect(_on_remove_route_cancellation.bind(i))
		row.add_child(undo_btn)

		_content.add_child(row)

	if not has_any:
		var none_label := Label.new()
		none_label.text = "None"
		_content.add_child(none_label)


func _on_remove_route_create(index: int) -> void:
	_player_controller.remove_route_create(index)


func _on_remove_route_cancellation(index: int) -> void:
	_player_controller.remove_route_cancellation(index)


# ---------------------------------------------------------------------------
# Create Route Button
# ---------------------------------------------------------------------------

func _build_create_button() -> void:
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var create_btn := Button.new()
	create_btn.text = "Create Route"
	create_btn.pressed.connect(func() -> void: create_route_requested.emit())
	btn_row.add_child(create_btn)
	_content.add_child(btn_row)
