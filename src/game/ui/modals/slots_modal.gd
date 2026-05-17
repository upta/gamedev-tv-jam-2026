class_name SlotsModal
extends ModalDialog

var _player_controller: PlayerController
var _game_state: GameState
var _selected_planet_id: String = ""

var _content_vbox: VBoxContainer
var _planet_selector: OptionButton
var _bid_section: VBoxContainer
var _sell_section: VBoxContainer
var _qty_spin: SpinBox
var _price_spin: SpinBox
var _sell_spin: SpinBox


func _ready() -> void:
	super()
	set_title("🪐 Planet Slots")


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state
	_player_controller.intent_changed.connect(_on_intent_changed)


func open() -> void:
	super.open()
	refresh()


func refresh() -> void:
	var scroll: ScrollContainer = get_content_container().get_child(0) as ScrollContainer
	# Clear existing content
	for child in scroll.get_children():
		child.queue_free()

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_vbox)

	_build_holdings_section()
	_build_pending_section()
	_build_planet_selector()
	_build_bid_section()
	_build_sell_section()
	_update_action_sections()


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

func _build_holdings_section() -> void:
	_add_section_header("Your Slot Holdings")

	var carrier := _game_state.get_player_carrier()
	if carrier.slots.is_empty():
		var lbl := Label.new()
		lbl.text = "No slots owned."
		_content_vbox.add_child(lbl)
		return

	for planet_id: String in carrier.slots:
		var count: int = carrier.slots[planet_id]
		if count <= 0:
			continue
		var planet: GalaxyData.Planet = _game_state.galaxy.get_planet(planet_id)
		var planet_name := planet.name if planet else planet_id
		var lbl := Label.new()
		lbl.text = "%s: %d slots" % [planet_name, count]
		_content_vbox.add_child(lbl)


func _build_pending_section() -> void:
	_add_section_header("Pending Slot Actions")

	var intent := _player_controller.pending_intent
	var has_actions := false

	for i in intent.slot_bids.size():
		has_actions = true
		var bid: Dictionary = intent.slot_bids[i]
		var planet: GalaxyData.Planet = _game_state.galaxy.get_planet(bid["planet_id"])
		var planet_name: String = planet.name if planet else str(bid["planet_id"])
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "Bid: %s × %d @ $%.0f/slot" % [planet_name, bid["quantity"], bid["price_per_slot"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		var idx := i
		cancel_btn.pressed.connect(func() -> void: _player_controller.remove_slot_bid(idx))
		row.add_child(cancel_btn)
		_content_vbox.add_child(row)

	for i in intent.slot_sales.size():
		has_actions = true
		var sale: Dictionary = intent.slot_sales[i]
		var planet: GalaxyData.Planet = _game_state.galaxy.get_planet(sale["planet_id"])
		var planet_name: String = planet.name if planet else str(sale["planet_id"])
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "Sell: %s × %d" % [planet_name, sale["count"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		var idx := i
		cancel_btn.pressed.connect(func() -> void: _player_controller.remove_slot_sale(idx))
		row.add_child(cancel_btn)
		_content_vbox.add_child(row)

	if not has_actions:
		var lbl := Label.new()
		lbl.text = "No pending actions."
		_content_vbox.add_child(lbl)


func _build_planet_selector() -> void:
	_add_section_header("Planet Selector")

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
	_content_vbox.add_child(_planet_selector)

	# Restore selection if possible
	if _selected_planet_id != "":
		for i in _planet_selector.item_count:
			if _planet_selector.get_item_metadata(i) == _selected_planet_id:
				_planet_selector.select(i)
				break


func _build_bid_section() -> void:
	_bid_section = VBoxContainer.new()
	_content_vbox.add_child(_bid_section)


func _build_sell_section() -> void:
	_sell_section = VBoxContainer.new()
	_content_vbox.add_child(_sell_section)


func _update_action_sections() -> void:
	# Clear existing
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

	# --- Bid section ---
	var bid_header := Label.new()
	bid_header.text = "— Bid for Slots —"
	_bid_section.add_child(bid_header)

	var avail_label := Label.new()
	avail_label.text = "Available: %d slots" % available
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
		own_label.text = "You own: %d slots" % owned
		_sell_section.add_child(own_label)

		var sell_row := _create_label_spinbox("Count:", 1, owned, 1, 1)
		_sell_spin = sell_row.get_child(1) as SpinBox
		_sell_section.add_child(sell_row)

		var sell_btn := Button.new()
		sell_btn.text = "Sell Slots"
		sell_btn.pressed.connect(_on_sell_slots)
		_sell_section.add_child(sell_btn)


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


func _add_section_header(text: String) -> void:
	var sep := HSeparator.new()
	_content_vbox.add_child(sep)
	var lbl := Label.new()
	lbl.text = text
	_content_vbox.add_child(lbl)


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_planet_selected(index: int) -> void:
	_selected_planet_id = _planet_selector.get_item_metadata(index)
	_update_action_sections()


func _on_submit_bid() -> void:
	if _selected_planet_id == "" or not _qty_spin or not _price_spin:
		return
	_player_controller.add_slot_bid(_selected_planet_id, int(_qty_spin.value), _price_spin.value)


func _on_sell_slots() -> void:
	if _selected_planet_id == "" or not _sell_spin:
		return
	_player_controller.add_slot_sale(_selected_planet_id, int(_sell_spin.value))


func _on_intent_changed(_intent: TurnPipeline.CarrierIntent) -> void:
	if visible:
		refresh()
