class_name ShipsModal
extends ModalDialog

## Modal for ordering ships and viewing fleet status.

var _player_controller: PlayerController
var _game_state: GameState

var _content_vbox: VBoxContainer
var _pax_spin: SpinBox
var _cargo_spin: SpinBox
var _type_option: OptionButton
var _stats_label: Label
var _order_button: Button

var _available_types: Array = []
var _updating_spinboxes: bool = false


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
	_build_order_section(carrier)


# ---------------------------------------------------------------------------
# Section 1: Fleet Overview
# ---------------------------------------------------------------------------

func _build_fleet_section(carrier: CarrierData) -> void:
	var header := Label.new()
	header.text = "Your Fleet"
	_content_vbox.add_child(header)

	var sep := HSeparator.new()
	_content_vbox.add_child(sep)

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
			label.text = "%s — Pax:%d Cargo:%d — %s" % [type_name, ship.passenger_capacity, ship.cargo_capacity, assignment]
			_content_vbox.add_child(label)

		for ship: ShipCatalog.ShipInstance in carrier.pending_orders:
			var label := Label.new()
			label.text = "(Building) %s — Ready turn %d" % [ship.type_id, ship.available_turn]
			_content_vbox.add_child(label)

	_content_vbox.add_child(HSeparator.new())


# ---------------------------------------------------------------------------
# Section 2: Pending Ship Orders (from intent)
# ---------------------------------------------------------------------------

func _build_pending_orders_section() -> void:
	var header := Label.new()
	header.text = "Pending Ship Orders"
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
			label.text = "%s — Pax:%d Cargo:%d" % [order["type_id"], order["passenger_capacity"], order["cargo_capacity"]]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)

			var cancel_btn := Button.new()
			cancel_btn.text = "Cancel"
			cancel_btn.pressed.connect(_on_cancel_order.bind(i))
			row.add_child(cancel_btn)

			_content_vbox.add_child(row)

	_content_vbox.add_child(HSeparator.new())


# ---------------------------------------------------------------------------
# Section 3: Order New Ship
# ---------------------------------------------------------------------------

func _build_order_section(carrier: CarrierData) -> void:
	var header := Label.new()
	header.text = "Order New Ship"
	_content_vbox.add_child(header)

	# Ship type dropdown
	_type_option = OptionButton.new()
	_available_types = _game_state.catalog.get_available_types(_game_state.current_turn)
	for idx in range(_available_types.size()):
		var st: ShipCatalog.ShipType = _available_types[idx]
		_type_option.add_item(st.name, idx)
	_type_option.item_selected.connect(_on_type_selected)
	_content_vbox.add_child(_type_option)

	# Stats display
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(_stats_label)

	# Capacity spinboxes
	var max_cap := 0
	if _available_types.size() > 0:
		max_cap = _available_types[0].max_capacity

	var pax_row := _create_label_spinbox("Passengers:", 0, max_cap, 1, max_cap / 2)
	_pax_spin = pax_row.get_child(1) as SpinBox
	_content_vbox.add_child(pax_row)

	var cargo_row := _create_label_spinbox("Cargo:", 0, max_cap, 1, max_cap - max_cap / 2)
	_cargo_spin = cargo_row.get_child(1) as SpinBox
	_content_vbox.add_child(cargo_row)

	_pax_spin.value_changed.connect(_on_pax_changed)
	_cargo_spin.value_changed.connect(_on_cargo_changed)

	# Order button
	_order_button = Button.new()
	_order_button.text = "Order Ship"
	_order_button.pressed.connect(_on_order_pressed)
	_content_vbox.add_child(_order_button)

	_update_stats_and_button(carrier)


func _create_label_spinbox(label_text: String, min_val: float, max_val: float, step: float, default_val: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = default_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return row


func _get_selected_type() -> ShipCatalog.ShipType:
	if _available_types.is_empty() or _type_option == null:
		return null
	var idx := _type_option.selected
	if idx < 0 or idx >= _available_types.size():
		return null
	return _available_types[idx]


func _update_stats_and_button(carrier: CarrierData) -> void:
	var st := _get_selected_type()
	if st == null:
		_stats_label.text = "No ships available."
		_order_button.disabled = true
		return
	_stats_label.text = "Cost: §%d | Cap: %d | Range: %.1f ly | Build: %d turns" % [st.cost, st.max_capacity, st.range, st.build_turns]
	_order_button.disabled = carrier.cash < st.cost


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_type_selected(_index: int) -> void:
	var st := _get_selected_type()
	if st == null:
		return
	_updating_spinboxes = true
	_pax_spin.max_value = st.max_capacity
	_cargo_spin.max_value = st.max_capacity
	_pax_spin.value = st.max_capacity / 2
	_cargo_spin.value = st.max_capacity - st.max_capacity / 2
	_updating_spinboxes = false
	_update_stats_and_button(_game_state.get_player_carrier())


func _on_pax_changed(value: float) -> void:
	if _updating_spinboxes:
		return
	var st := _get_selected_type()
	if st == null:
		return
	_updating_spinboxes = true
	_cargo_spin.value = st.max_capacity - int(value)
	_updating_spinboxes = false


func _on_cargo_changed(value: float) -> void:
	if _updating_spinboxes:
		return
	var st := _get_selected_type()
	if st == null:
		return
	_updating_spinboxes = true
	_pax_spin.value = st.max_capacity - int(value)
	_updating_spinboxes = false


func _on_order_pressed() -> void:
	var st := _get_selected_type()
	if st == null:
		return
	_player_controller.add_ship_order(st.id, int(_pax_spin.value), int(_cargo_spin.value))
	refresh()


func _on_cancel_order(index: int) -> void:
	_player_controller.remove_ship_order(index)
	refresh()


func _on_intent_changed(_intent: TurnPipeline.CarrierIntent) -> void:
	if visible:
		refresh()
