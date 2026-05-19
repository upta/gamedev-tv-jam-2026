class_name OrderShipModal
extends ModalDialog

## Modal for ordering a new ship.
## Opened from ShipsModal via "Order Ship" button.

signal ship_ordered

var _player_controller: PlayerController
var _game_state: GameState
var _content: VBoxContainer

# Form controls
var _type_option: OptionButton
var _pax_spin: SpinBox
var _cargo_spin: SpinBox
var _qty_spin: SpinBox
var _stats_label: Label
var _order_button: Button
var _cancel_button: Button

var _available_types: Array = []
var _updating_spinboxes: bool = false


func _ready() -> void:
	super._ready()
	set_title("Order Ship")
	var scroll: ScrollContainer = _content_container.get_child(0)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state


func open() -> void:
	super.open()
	_rebuild_form()


func _rebuild_form() -> void:
	if not _game_state or not _player_controller:
		return

	for child in _content.get_children():
		child.queue_free()

	var carrier := _game_state.get_player_carrier()

	# Ship type dropdown
	var type_label := Label.new()
	type_label.text = "Ship Type:"
	_content.add_child(type_label)

	_type_option = OptionButton.new()
	_available_types = _game_state.catalog.get_available_types(_game_state.current_turn)
	for idx in range(_available_types.size()):
		var st: ShipCatalog.ShipType = _available_types[idx]
		_type_option.add_item(st.name, idx)
	_type_option.item_selected.connect(_on_type_selected)
	_content.add_child(_type_option)

	# Stats display
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_stats_label)

	# Capacity spinboxes
	var max_cap := 0
	if _available_types.size() > 0:
		max_cap = _available_types[0].max_capacity

	var pax_row := _create_label_spinbox("Passengers:", 0, max_cap, 1, max_cap / 2)
	_pax_spin = pax_row.get_child(1) as SpinBox
	_content.add_child(pax_row)

	var cargo_row := _create_label_spinbox("Cargo:", 0, max_cap, 1, max_cap - max_cap / 2)
	_cargo_spin = cargo_row.get_child(1) as SpinBox
	_content.add_child(cargo_row)

	_pax_spin.value_changed.connect(_on_pax_changed)
	_cargo_spin.value_changed.connect(_on_cargo_changed)

	_content.add_child(HSeparator.new())

	# Quantity
	var qty_row := _create_label_spinbox("Quantity:", 1, 10, 1, 1)
	_qty_spin = qty_row.get_child(1) as SpinBox
	_qty_spin.value_changed.connect(_on_qty_changed)
	_content.add_child(qty_row)

	_content.add_child(HSeparator.new())

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.pressed.connect(close)
	btn_row.add_child(_cancel_button)

	_order_button = Button.new()
	_order_button.text = "Order Ship"
	_order_button.pressed.connect(_on_order_pressed)
	btn_row.add_child(_order_button)

	_content.add_child(btn_row)

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
	var qty := int(_qty_spin.value) if _qty_spin else 1
	var total_cost := st.cost * qty
	_stats_label.text = "Cost: §%d x %d = §%d | Cap: %d | Range: %.1f ly | Build: %d turns" % [st.cost, qty, total_cost, st.max_capacity, st.range, st.build_turns]
	_order_button.disabled = carrier.cash < total_cost


# ---------------------------------------------------------------------------
# Programmatic API for validation harness
# ---------------------------------------------------------------------------

func get_form_state() -> Dictionary:
	var st := _get_selected_type()
	return {
		"type_id": st.id if st else "",
		"type_name": st.name if st else "",
		"passenger_capacity": int(_pax_spin.value) if _pax_spin else 0,
		"cargo_capacity": int(_cargo_spin.value) if _cargo_spin else 0,
		"quantity": int(_qty_spin.value) if _qty_spin else 1,
		"can_order": not _order_button.disabled if _order_button else false,
	}


func select_type(index: int) -> void:
	if _type_option and index >= 0 and index < _available_types.size():
		_type_option.select(index)
		_on_type_selected(index)


func set_passenger_capacity(value: int) -> void:
	if _pax_spin:
		_pax_spin.value = value


func confirm_order() -> void:
	_on_order_pressed()


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


func _on_qty_changed(_value: float) -> void:
	if _game_state:
		_update_stats_and_button(_game_state.get_player_carrier())


func _on_order_pressed() -> void:
	var st := _get_selected_type()
	if st == null:
		return
	var qty := int(_qty_spin.value) if _qty_spin else 1
	for i in range(qty):
		_player_controller.add_ship_order(st.id, int(_pax_spin.value), int(_cargo_spin.value))
	ship_ordered.emit()
	close()
