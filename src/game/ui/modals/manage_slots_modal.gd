class_name ManageSlotsModal
extends ModalDialog

## Modal showing a flat table of all planets with inline Buy/Sell buttons.
## Opened from SlotsModal via "Buy/Sell Slots" button.

signal slot_action_submitted

var _player_controller: PlayerController
var _game_state: GameState
var _outer_vbox: VBoxContainer
var _scroll_content: VBoxContainer
var _selected_planet_id: String = ""

# Popup controls
var _popup_overlay: PanelContainer
var _popup_title: Label
var _popup_qty_spin: SpinBox
var _popup_price_row: HBoxContainer
var _popup_price_spin: SpinBox
var _popup_mode: String = ""  # "buy" or "sell"
var _popup_planet_id: String = ""


func _ready() -> void:
	super._ready()
	set_title("Buy / Sell Slots")

	var scroll: ScrollContainer = _content_container.get_child(0)
	_content_container.remove_child(scroll)

	_outer_vbox = VBoxContainer.new()
	_outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(_outer_vbox)

	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outer_vbox.add_child(scroll)

	_scroll_content = VBoxContainer.new()
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_scroll_content)


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state


func open() -> void:
	_selected_planet_id = ""
	_popup_mode = ""
	_popup_planet_id = ""
	super.open()
	_rebuild_table()


func open_with_buy(planet_id: String) -> void:
	_selected_planet_id = planet_id
	_popup_mode = ""
	_popup_planet_id = ""
	super.open()
	_rebuild_table()
	_show_buy_popup(planet_id)


# ---------------------------------------------------------------------------
# Table Building
# ---------------------------------------------------------------------------

func _rebuild_table() -> void:
	if _scroll_content == null or _game_state == null:
		return
	for child: Node in _scroll_content.get_children():
		child.queue_free()
	# Remove popup and close button from outer_vbox (keep scroll at index 0)
	for i in range(_outer_vbox.get_child_count() - 1, 0, -1):
		_outer_vbox.get_child(i).queue_free()

	_build_header()
	_build_planet_rows()
	_build_popup()
	_build_close_button()


func _build_header() -> void:
	var header := HBoxContainer.new()

	var h_planet := Label.new()
	h_planet.text = "Planet"
	h_planet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_planet.custom_minimum_size.x = 180
	header.add_child(h_planet)

	var h_avail := Label.new()
	h_avail.text = "Available / Total"
	h_avail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_avail.custom_minimum_size.x = 130
	header.add_child(h_avail)

	var h_owned := Label.new()
	h_owned.text = "You Own"
	h_owned.custom_minimum_size.x = 70
	header.add_child(h_owned)

	var h_actions := Label.new()
	h_actions.text = "Actions"
	h_actions.custom_minimum_size.x = 120
	header.add_child(h_actions)

	_scroll_content.add_child(header)
	_scroll_content.add_child(HSeparator.new())


func _build_planet_rows() -> void:
	var carrier := _game_state.get_player_carrier()
	for planet: GalaxyData.Planet in _game_state.galaxy.planets:
		var available := _calc_available_slots(planet.id)
		var owned := carrier.get_slot_count(planet.id)

		var row := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = "%s (%s)" % [planet.name, planet.system]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size.x = 180
		row.add_child(name_label)

		var avail_label := Label.new()
		avail_label.text = "%d available / %d total" % [available, planet.total_slots]
		avail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		avail_label.custom_minimum_size.x = 130
		row.add_child(avail_label)

		var owned_label := Label.new()
		owned_label.text = str(owned)
		owned_label.custom_minimum_size.x = 70
		row.add_child(owned_label)

		var btn_box := HBoxContainer.new()
		btn_box.custom_minimum_size.x = 120

		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_buy_pressed.bind(planet.id))
		btn_box.add_child(buy_btn)

		var sell_btn := Button.new()
		sell_btn.text = "Sell"
		sell_btn.disabled = owned <= 0
		sell_btn.pressed.connect(_on_sell_pressed.bind(planet.id))
		btn_box.add_child(sell_btn)

		row.add_child(btn_box)
		_scroll_content.add_child(row)


func _build_popup() -> void:
	_popup_overlay = PanelContainer.new()
	_popup_overlay.visible = false
	_popup_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	_popup_title = Label.new()
	vbox.add_child(_popup_title)
	vbox.add_child(HSeparator.new())

	# Quantity
	var qty_row := HBoxContainer.new()
	var qty_label := Label.new()
	qty_label.text = "Quantity:"
	qty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_row.add_child(qty_label)
	_popup_qty_spin = SpinBox.new()
	_popup_qty_spin.min_value = 1
	_popup_qty_spin.max_value = 1
	_popup_qty_spin.step = 1
	_popup_qty_spin.value = 1
	_popup_qty_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_row.add_child(_popup_qty_spin)
	vbox.add_child(qty_row)

	# Price (buy only)
	_popup_price_row = HBoxContainer.new()
	var price_label := Label.new()
	price_label.text = "Price per slot:"
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_price_row.add_child(price_label)
	_popup_price_spin = SpinBox.new()
	_popup_price_spin.min_value = 500
	_popup_price_spin.max_value = 100000
	_popup_price_spin.step = 1
	_popup_price_spin.value = 500
	_popup_price_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_price_row.add_child(_popup_price_spin)
	vbox.add_child(_popup_price_row)

	# Confirm / Cancel
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	ThemeBuilder.style_primary_button(confirm_btn)
	confirm_btn.pressed.connect(_on_popup_confirm)
	btn_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_popup_cancel)
	btn_row.add_child(cancel_btn)
	vbox.add_child(btn_row)

	_popup_overlay.add_child(vbox)
	_outer_vbox.add_child(_popup_overlay)


func _build_close_button() -> void:
	_outer_vbox.add_child(HSeparator.new())
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	btn_row.add_child(close_btn)
	_outer_vbox.add_child(btn_row)


# ---------------------------------------------------------------------------
# Popup Logic
# ---------------------------------------------------------------------------

func _show_buy_popup(planet_id: String) -> void:
	var planet := _game_state.galaxy.get_planet(planet_id)
	if not planet:
		return
	_popup_mode = "buy"
	_popup_planet_id = planet_id
	var available := _calc_available_slots(planet_id)

	_popup_title.text = "Buy Slots - %s" % planet.name
	_popup_qty_spin.max_value = maxi(available, 1)
	_popup_qty_spin.value = 1
	_popup_price_row.visible = true
	_popup_price_spin.value = 500
	_popup_overlay.visible = true


func _show_sell_popup(planet_id: String) -> void:
	var carrier := _game_state.get_player_carrier()
	var owned := carrier.get_slot_count(planet_id)
	if owned <= 0:
		return
	var planet := _game_state.galaxy.get_planet(planet_id)
	if not planet:
		return
	_popup_mode = "sell"
	_popup_planet_id = planet_id

	_popup_title.text = "Sell Slots - %s" % planet.name
	_popup_qty_spin.max_value = owned
	_popup_qty_spin.value = 1
	_popup_price_row.visible = false
	_popup_overlay.visible = true


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _calc_available_slots(planet_id: String) -> int:
	var planet: GalaxyData.Planet = _game_state.galaxy.get_planet(planet_id)
	if not planet:
		return 0
	var used := 0
	for carrier: CarrierData in _game_state.carriers:
		used += carrier.get_slot_count(planet_id)
	return planet.total_slots - used


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_buy_pressed(planet_id: String) -> void:
	_selected_planet_id = planet_id
	_show_buy_popup(planet_id)


func _on_sell_pressed(planet_id: String) -> void:
	_selected_planet_id = planet_id
	_show_sell_popup(planet_id)


func _on_popup_confirm() -> void:
	if _popup_mode == "buy":
		_player_controller.add_slot_bid(
			_popup_planet_id, int(_popup_qty_spin.value), _popup_price_spin.value
		)
	elif _popup_mode == "sell":
		_player_controller.add_slot_sale(_popup_planet_id, int(_popup_qty_spin.value))
	_popup_overlay.visible = false
	_popup_mode = ""
	slot_action_submitted.emit()
	close()


func _on_popup_cancel() -> void:
	_popup_overlay.visible = false
	_popup_mode = ""


# ---------------------------------------------------------------------------
# Programmatic API (for validation harness)
# ---------------------------------------------------------------------------

func get_form_state() -> Dictionary:
	var planet_count := _game_state.galaxy.planets.size() if _game_state else 0
	return {
		"selected_planet_id": _selected_planet_id,
		"popup_mode": _popup_mode,
		"popup_planet_id": _popup_planet_id,
		"bid_quantity": int(_popup_qty_spin.value) if _popup_qty_spin and _popup_mode == "buy" else 0,
		"bid_price": _popup_price_spin.value if _popup_price_spin and _popup_mode == "buy" else 0.0,
		"sell_count": int(_popup_qty_spin.value) if _popup_qty_spin and _popup_mode == "sell" else 0,
		"planet_count": planet_count,
	}


func select_planet(index: int) -> void:
	if _game_state == null:
		return
	var planets := _game_state.galaxy.planets
	if index >= 0 and index < planets.size():
		_selected_planet_id = planets[index].id


func confirm_bid() -> void:
	if _selected_planet_id == "":
		return
	_show_buy_popup(_selected_planet_id)
	_on_popup_confirm()


func confirm_sell() -> void:
	if _selected_planet_id == "":
		return
	_show_sell_popup(_selected_planet_id)
	_on_popup_confirm()
