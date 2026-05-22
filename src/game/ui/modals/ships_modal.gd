class_name ShipsModal
extends ModalDialog

## Modal for viewing fleet status and pending ship orders.
## Ship ordering is handled by OrderShipModal, opened via the "Order Ship" button.

signal order_ship_requested

var _player_controller: PlayerController
var _game_state: GameState

var _content_vbox: VBoxContainer


func _ready() -> void:
	super._ready()
	set_title("Ships")
	_content_vbox = $Panel/VBoxContainer/ContentContainer/ScrollContainer/ContentVBox


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state
	_player_controller.intent_changed.connect(_on_intent_changed)


func open() -> void:
	super.open()
	refresh()


func refresh() -> void:
	if not _game_state or not _player_controller:
		return

	# Clear existing content
	for child in _content_vbox.get_children():
		child.queue_free()

	var carrier := _game_state.get_player_carrier()

	_build_fleet_section(carrier)
	_build_pending_orders_section()
	_build_order_button()


# ---------------------------------------------------------------------------
# Section 1: Fleet Overview
# ---------------------------------------------------------------------------

func _build_fleet_section(carrier: CarrierData) -> void:
	var header := ThemeBuilder.make_section_header("Your Fleet")
	_content_vbox.add_child(header)

	# Build ship-to-route map
	var ship_route_map: Dictionary = {}
	for route: CarrierData.Route in carrier.routes:
		if route.active:
			for ship_id: String in route.ship_ids:
				ship_route_map[ship_id] = route.lane_id

	if carrier.ships.is_empty() and carrier.pending_orders.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No ships in fleet."
		_content_vbox.add_child(empty_label)
	else:
		for ship: ShipCatalog.ShipInstance in carrier.ships:
			var ship_type := _game_state.catalog.get_type(ship.type_id)
			var type_name := ship_type.name if ship_type else ship.type_id
			var assignment: String = ship_route_map.get(ship.id, "Idle")
			var label := Label.new()
			label.text = "%s - Pax:%d Cargo:%d - %s" % [type_name, ship.passenger_capacity, ship.cargo_capacity, assignment]
			_content_vbox.add_child(label)

		for ship: ShipCatalog.ShipInstance in carrier.pending_orders:
			var label := Label.new()
			label.text = "(Building) %s - Ready turn %d" % [ship.type_id, ship.available_turn]
			_content_vbox.add_child(label)

	_content_vbox.add_child(HSeparator.new())


# ---------------------------------------------------------------------------
# Section 2: Pending Ship Orders (from intent)
# ---------------------------------------------------------------------------

func _build_pending_orders_section() -> void:
	var header := ThemeBuilder.make_section_header("Pending Ship Orders")
	_content_vbox.add_child(header)

	var orders: Array = _player_controller.pending_intent.ship_orders
	if orders.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No pending orders."
		_content_vbox.add_child(empty_label)
	else:
		for i in range(orders.size()):
			var order: Dictionary = orders[i]
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = "%s - Pax:%d Cargo:%d" % [order["type_id"], order["passenger_capacity"], order["cargo_capacity"]]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)

			var cancel_btn := Button.new()
			cancel_btn.text = "Cancel"
			cancel_btn.pressed.connect(_on_cancel_order.bind(i))
			row.add_child(cancel_btn)

			_content_vbox.add_child(row)

	_content_vbox.add_child(HSeparator.new())


# ---------------------------------------------------------------------------
# Section 3: Order Ship Button
# ---------------------------------------------------------------------------

func _build_order_button() -> void:
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var order_btn := Button.new()
	order_btn.text = "Order Ship"
	order_btn.pressed.connect(func() -> void: order_ship_requested.emit())
	btn_row.add_child(order_btn)
	_content_vbox.add_child(btn_row)


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------


func _on_cancel_order(index: int) -> void:
	_player_controller.remove_ship_order(index)
	refresh()


func _on_intent_changed(_intent: TurnPipeline.CarrierIntent) -> void:
	if visible:
		refresh()
