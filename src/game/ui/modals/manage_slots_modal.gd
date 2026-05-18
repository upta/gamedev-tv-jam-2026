class_name ManageSlotsModal
extends ModalDialog

## Modal for bidding on or selling planet slots.
## Opened from SlotsModal via "Buy/Sell Slots" button.

signal slot_action_submitted

var _player_controller: PlayerController
var _game_state: GameState
var _content: VBoxContainer
var _selected_planet_id: String = ""

# Form controls
var _planet_selector: OptionButton
var _bid_section: VBoxContainer
var _sell_section: VBoxContainer
var _qty_spin: SpinBox
var _price_spin: SpinBox
var _sell_spin: SpinBox


func _ready() -> void:
	super._ready()
	set_title("Buy / Sell Slots")
	var scroll: ScrollContainer = _content_container.get_child(0)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state


func open() -> void:
	_selected_planet_id = ""
	super.open()
	_rebuild_form()


# ---------------------------------------------------------------------------
# Form Building
# ---------------------------------------------------------------------------

func _rebuild_form() -> void:
	if _content == null or _game_state == null:
		return
	for child: Node in _content.get_children():
		child.queue_free()

	_build_planet_selector()
	_bid_section = VBoxContainer.new()
	_content.add_child(_bid_section)
	_sell_section = VBoxContainer.new()
	_content.add_child(_sell_section)
	_update_action_sections()


func _build_planet_selector() -> void:
	var header := Label.new()
	header.text = "Select Planet"
	_content.add_child(header)
	_content.add_child(HSeparator.new())

	_planet_selector = OptionButton.new()
	_planet_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_planet_selector.add_item("— Select a planet —", 0)
	_planet_selector.set_item_metadata(0, "")

	var idx := 1
	for planet: GalaxyData.Planet in _game_state.galaxy.planets:
		var available := _calc_available_slots(planet.id)
		var text := "%s (%s) — %d/%d slots" % [planet.name, planet.system, available, planet.total_slots]
		_planet_selector.add_item(text, idx)
		_planet_selector.set_item_metadata(idx, planet.id)
		idx += 1

	_planet_selector.item_selected.connect(_on_planet_selected)
	_content.add_child(_planet_selector)

	if _selected_planet_id != "":
		for i in _planet_selector.item_count:
			if _planet_selector.get_item_metadata(i) == _selected_planet_id:
				_planet_selector.select(i)
				break


func _update_action_sections() -> void:
	for child in _bid_section.get_children():
		child.queue_free()
	for child in _sell_section.get_children():
		child.queue_free()

	if _selected_planet_id == "":
		return

	var planet: GalaxyData.Planet = _game_state.galaxy.get_planet(_selected_planet_id)
	if not planet:
		return

	var available := _calc_available_slots(_selected_planet_id)
	var carrier := _game_state.get_player_carrier()
	var owned := carrier.get_slot_count(_selected_planet_id)
	var used := carrier.get_slots_used_by_routes(_selected_planet_id)

	# --- Bid section ---
	var bid_header := Label.new()
	bid_header.text = "— Bid for Slots —"
	_bid_section.add_child(bid_header)

	var avail_label := Label.new()
	avail_label.text = "Available on planet: %d slots" % available
	_bid_section.add_child(avail_label)

	var max_bid := planet.total_slots if available <= 0 else maxi(available, 1)
	var qty_row := _create_label_spinbox("Quantity:", 1, max_bid, 1, 1)
	_qty_spin = qty_row.get_child(1) as SpinBox
	_bid_section.add_child(qty_row)

	var price_row := _create_label_spinbox("Price per slot:", 50, 10000, 1, 50)
	_price_spin = price_row.get_child(1) as SpinBox
	_bid_section.add_child(price_row)

	var bid_btn := Button.new()
	bid_btn.text = "Submit Bid"
	bid_btn.pressed.connect(_on_submit_bid)
	_bid_section.add_child(bid_btn)

	# --- Sell section ---
	if owned > 0:
		var sell_header := Label.new()
		sell_header.text = "— Sell Slots —"
		_sell_section.add_child(sell_header)

		var own_label := Label.new()
		own_label.text = "You own: %d slots (%d used by routes)" % [owned, used]
		_sell_section.add_child(own_label)

		var sell_row := _create_label_spinbox("Count:", 1, owned, 1, 1)
		_sell_spin = sell_row.get_child(1) as SpinBox
		_sell_section.add_child(sell_row)

		var sell_btn := Button.new()
		sell_btn.text = "Sell Slots"
		sell_btn.pressed.connect(_on_sell_slots)
		_sell_section.add_child(sell_btn)

	# --- Bottom buttons ---
	_content.add_child(HSeparator.new())
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	var cancel_btn := Button.new()
	cancel_btn.text = "Close"
	cancel_btn.pressed.connect(close)
	btn_row.add_child(cancel_btn)
	_content.add_child(btn_row)


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


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_planet_selected(index: int) -> void:
	_selected_planet_id = _planet_selector.get_item_metadata(index)
	_rebuild_form()


func _on_submit_bid() -> void:
	if _selected_planet_id == "" or not _qty_spin or not _price_spin:
		return
	_player_controller.add_slot_bid(_selected_planet_id, int(_qty_spin.value), _price_spin.value)
	slot_action_submitted.emit()
	close()


func _on_sell_slots() -> void:
	if _selected_planet_id == "" or not _sell_spin:
		return
	_player_controller.add_slot_sale(_selected_planet_id, int(_sell_spin.value))
	slot_action_submitted.emit()
	close()


# ---------------------------------------------------------------------------
# Programmatic API (for validation harness)
# ---------------------------------------------------------------------------

func get_form_state() -> Dictionary:
	return {
		"selected_planet_id": _selected_planet_id,
		"bid_quantity": int(_qty_spin.value) if _qty_spin else 0,
		"bid_price": _price_spin.value if _price_spin else 0.0,
		"sell_count": int(_sell_spin.value) if _sell_spin else 0,
		"planet_count": _planet_selector.item_count - 1 if _planet_selector else 0,
	}


func select_planet(index: int) -> void:
	if _planet_selector and index >= 0 and index < _planet_selector.item_count - 1:
		_planet_selector.select(index + 1)  # +1 because index 0 is placeholder
		_on_planet_selected(index + 1)


func confirm_bid() -> void:
	_on_submit_bid()


func confirm_sell() -> void:
	_on_sell_slots()
