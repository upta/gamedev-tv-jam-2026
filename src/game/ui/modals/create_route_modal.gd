class_name CreateRouteModal
extends ModalDialog

## Dedicated modal for creating a new route.
## Opened from the Routes Overview modal via the "Create Route" button.

signal route_created

var _player_controller: PlayerController
var _game_state: GameState
var _content: VBoxContainer

# Form state
var _origin_id: String = ""
var _dest_id: String = ""
var _selected_ship_ids: Array = []

# Form controls
var _origin_display: Label
var _dest_display: Label
var _ship_select_btn: Button
var _ship_display: Label
var _info_label: Label
var _freq_spin: SpinBox
var _pax_spin: SpinBox
var _cargo_spin: SpinBox
var _create_btn: Button
var _details_section: VBoxContainer

# Sub-dialog
var _selection_popup: PanelContainer
var _selection_overlay: ColorRect
var _selection_callback: Callable


func _ready() -> void:
	super._ready()
	set_title("New Route")
	var scroll: ScrollContainer = _content_container.get_child(0)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state


func open() -> void:
	_reset_form()
	super.open()
	_rebuild_form()


func close() -> void:
	_close_selection_popup()
	super.close()


func _exit_tree() -> void:
	_close_selection_popup()


# ---------------------------------------------------------------------------
# Form Building
# ---------------------------------------------------------------------------

func _rebuild_form() -> void:
	if _content == null or _game_state == null:
		return
	for child: Node in _content.get_children():
		child.queue_free()

	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return

	# Origin row
	var origin_row := HBoxContainer.new()
	var origin_label := Label.new()
	origin_label.text = "Origin System"
	origin_label.custom_minimum_size.x = 160
	origin_row.add_child(origin_label)
	_origin_display = Label.new()
	_origin_display.text = _get_planet_display_name(_origin_id)
	_origin_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	origin_row.add_child(_origin_display)
	var origin_btn := Button.new()
	origin_btn.text = "Select"
	origin_btn.pressed.connect(_open_planet_selector.bind("origin"))
	origin_row.add_child(origin_btn)
	_content.add_child(origin_row)

	# Destination row
	var dest_row := HBoxContainer.new()
	var dest_label := Label.new()
	dest_label.text = "Destination System"
	dest_label.custom_minimum_size.x = 160
	dest_row.add_child(dest_label)
	_dest_display = Label.new()
	_dest_display.text = _get_planet_display_name(_dest_id)
	_dest_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dest_row.add_child(_dest_display)
	var dest_btn := Button.new()
	dest_btn.text = "Select"
	dest_btn.pressed.connect(_open_planet_selector.bind("dest"))
	dest_row.add_child(dest_btn)
	_content.add_child(dest_row)

	# Ship row
	var ship_row := HBoxContainer.new()
	var ship_label := Label.new()
	ship_label.text = "Ships"
	ship_label.custom_minimum_size.x = 160
	ship_row.add_child(ship_label)
	_ship_display = Label.new()
	_ship_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_ship_display()
	ship_row.add_child(_ship_display)
	_ship_select_btn = Button.new()
	_ship_select_btn.text = "Select"
	_ship_select_btn.pressed.connect(_open_ship_selector)
	_ship_select_btn.disabled = _origin_id.is_empty() or _dest_id.is_empty() or _origin_id == _dest_id
	ship_row.add_child(_ship_select_btn)
	_content.add_child(ship_row)

	_content.add_child(HSeparator.new())

	# Dynamic details section (shown after origin+dest selected)
	_details_section = VBoxContainer.new()
	_content.add_child(_details_section)

	_rebuild_route_details(carrier)


func _rebuild_route_details(carrier: CarrierData) -> void:
	for child: Node in _details_section.get_children():
		child.queue_free()
	_create_btn = null

	if _origin_id.is_empty() or _dest_id.is_empty() or _origin_id == _dest_id:
		return

	var lane := _game_state.galaxy.get_lane(_origin_id, _dest_id)
	if lane == null:
		var no_lane := Label.new()
		no_lane.text = "No lane between these planets."
		_details_section.add_child(no_lane)
		return

	# Distance and slot info
	var origin_slots: int = carrier.get_slot_count(_origin_id)
	var dest_slots: int = carrier.get_slot_count(_dest_id)
	_info_label = Label.new()
	_info_label.text = "Distance: %.1f ly | Slots: %d at %s, %d at %s" % [
		lane.distance, origin_slots, _get_planet_display_name(_origin_id),
		dest_slots, _get_planet_display_name(_dest_id),
	]
	_details_section.add_child(_info_label)

	# Suggested prices
	var suggested_pax := DemandCalculator.calculate_suggested_price(lane, "passenger")
	var suggested_cargo := DemandCalculator.calculate_suggested_price(lane, "cargo")

	# Flights per month — max depends on selected ships
	var max_freq := _compute_max_frequency()
	var freq_row := _create_label_spinbox("Flights per Month:", 1, maxi(max_freq, 1), 1, 1)
	_details_section.add_child(freq_row)
	_freq_spin = freq_row.get_child(1)
	_freq_spin.editable = max_freq > 0

	# Max frequency label
	var freq_max_label := Label.new()
	freq_max_label.name = "FreqMaxLabel"
	freq_max_label.text = "/ %d" % max_freq if max_freq > 0 else "/ —"
	freq_row.add_child(freq_max_label)

	# Pricing
	var pax_default := int(roundf(suggested_pax))
	var pax_max := int(10 * ceilf(suggested_pax))
	var cargo_default := int(roundf(suggested_cargo))
	var cargo_max := int(10 * ceilf(suggested_cargo))

	var pax_row := _create_label_spinbox("Passenger Price:", 1, pax_max, 1, pax_default)
	_details_section.add_child(pax_row)
	_pax_spin = pax_row.get_child(1)

	var cargo_row := _create_label_spinbox("Cargo Price:", 1, cargo_max, 1, cargo_default)
	_details_section.add_child(cargo_row)
	_cargo_spin = cargo_row.get_child(1)

	# Bottom buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(close)
	btn_row.add_child(cancel_btn)
	_create_btn = Button.new()
	_create_btn.text = "Create"
	_create_btn.pressed.connect(_on_create_route)
	btn_row.add_child(_create_btn)
	_details_section.add_child(btn_row)

	_update_create_button_state()


# ---------------------------------------------------------------------------
# Planet Selection Sub-Dialog
# ---------------------------------------------------------------------------

func _open_planet_selector(target: String) -> void:
	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return

	var items_with_slots: Array[Dictionary] = []
	var items_no_slots: Array[Dictionary] = []

	for planet: GalaxyData.Planet in _game_state.galaxy.planets:
		# Exclude the already-selected counterpart
		if target == "origin" and planet.id == _dest_id:
			continue
		if target == "dest" and planet.id == _origin_id:
			continue
		var slot_count: int = carrier.get_slot_count(planet.id)
		if slot_count > 0:
			items_with_slots.append({
				"id": planet.id,
				"label": "%s — %d slot(s)" % [planet.name, slot_count],
				"selectable": true,
			})
		else:
			items_no_slots.append({
				"id": planet.id,
				"label": "%s — No slots" % planet.name,
				"selectable": false,
			})

	items_with_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["label"] < b["label"])
	items_no_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["label"] < b["label"])

	var callback := func(selected_id: String) -> void:
		if target == "origin":
			_origin_id = selected_id
		else:
			_dest_id = selected_id
		_selected_ship_ids.clear()
		_rebuild_form()

	_show_selection_popup("Select Planet", items_with_slots, items_no_slots, callback)


# ---------------------------------------------------------------------------
# Ship Selection Sub-Dialog
# ---------------------------------------------------------------------------

func _open_ship_selector() -> void:
	if _origin_id.is_empty() or _dest_id.is_empty() or _origin_id == _dest_id:
		return

	var lane := _game_state.galaxy.get_lane(_origin_id, _dest_id)
	if lane == null:
		return

	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return

	var idle_ships := carrier.get_available_ships()

	# Exclude ships already committed in other pending route creates
	var pending_ship_ids: Dictionary = {}
	for rc: Dictionary in _player_controller.pending_intent.route_creates:
		for ship_id: String in rc["ship_ids"]:
			pending_ship_ids[ship_id] = true

	var in_range: Array[Dictionary] = []
	var out_range: Array[Dictionary] = []

	for ship: ShipCatalog.ShipInstance in idle_ships:
		if pending_ship_ids.has(ship.id):
			continue
		var ship_type := _game_state.catalog.get_type(ship.type_id)
		if ship_type == null:
			continue
		var type_name: String = ship_type.name
		var already_selected := _selected_ship_ids.has(ship.id)
		if ship_type.range >= lane.distance:
			in_range.append({
				"id": ship.id,
				"label": "%s (Pax:%d Cargo:%d)%s" % [
					type_name, ship.passenger_capacity, ship.cargo_capacity,
					" ✓" if already_selected else "",
				],
				"selectable": true,
			})
		else:
			out_range.append({
				"id": ship.id,
				"label": "%s — Out of range" % type_name,
				"selectable": false,
			})

	in_range.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["label"] < b["label"])
	out_range.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["label"] < b["label"])

	var callback := func(selected_id: String) -> void:
		if _selected_ship_ids.has(selected_id):
			_selected_ship_ids.erase(selected_id)
		else:
			_selected_ship_ids.append(selected_id)
		_update_ship_display()
		_update_frequency_max()
		_update_create_button_state()

	_show_selection_popup("Select Ship", in_range, out_range, callback, false)


# ---------------------------------------------------------------------------
# Generic Selection Popup
# ---------------------------------------------------------------------------

func _show_selection_popup(
	title: String,
	group_a: Array[Dictionary],
	group_b: Array[Dictionary],
	callback: Callable,
	close_on_select: bool = true,
) -> void:
	_close_selection_popup()
	_selection_callback = callback

	_selection_popup = PanelContainer.new()
	_selection_popup.custom_minimum_size = Vector2(400, 300)

	var vbox := VBoxContainer.new()
	_selection_popup.add_child(vbox)

	# Title bar
	var title_row := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(_close_selection_popup)
	title_row.add_child(close_btn)
	vbox.add_child(title_row)

	vbox.add_child(HSeparator.new())

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 200
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	vbox.add_child(scroll)

	# Group A (selectable)
	for item: Dictionary in group_a:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = item["label"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var btn := Button.new()
		btn.text = "Select"
		var item_id: String = item["id"]
		btn.pressed.connect(_on_selection_item_clicked.bind(item_id, close_on_select))
		row.add_child(btn)
		list.add_child(row)

	# Divider between groups
	if not group_a.is_empty() and not group_b.is_empty():
		list.add_child(HSeparator.new())

	# Group B (non-selectable)
	for item: Dictionary in group_b:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = item["label"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.modulate = Color(0.5, 0.5, 0.5)
		row.add_child(lbl)
		list.add_child(row)

	# Done button for multi-select (ship selector)
	if not close_on_select:
		var done_row := HBoxContainer.new()
		done_row.alignment = BoxContainer.ALIGNMENT_END
		var done_btn := Button.new()
		done_btn.text = "Done"
		done_btn.pressed.connect(_close_selection_popup)
		done_row.add_child(done_btn)
		vbox.add_child(done_row)

	# Add overlay + popup to scene root so it escapes modal layout constraints
	var viewport_size := get_viewport().get_visible_rect().size

	_selection_overlay = ColorRect.new()
	_selection_overlay.color = Color(0, 0, 0, 0.4)
	_selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_overlay.size = viewport_size
	_selection_overlay.gui_input.connect(_on_selection_overlay_input)
	get_tree().root.add_child(_selection_overlay)

	get_tree().root.add_child(_selection_popup)
	_selection_popup.size = Vector2(400, 300)
	_selection_popup.position = (viewport_size - _selection_popup.size) / 2.0


func _on_selection_item_clicked(item_id: String, close_on_select: bool) -> void:
	if _selection_callback.is_valid():
		_selection_callback.call(item_id)
	if close_on_select:
		_close_selection_popup()


func _close_selection_popup() -> void:
	if _selection_overlay and is_instance_valid(_selection_overlay):
		_selection_overlay.queue_free()
		_selection_overlay = null
	if _selection_popup and is_instance_valid(_selection_popup):
		_selection_popup.queue_free()
		_selection_popup = null


func _on_selection_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_selection_popup()


# ---------------------------------------------------------------------------
# Create Route Action
# ---------------------------------------------------------------------------

func _on_create_route() -> void:
	if _origin_id.is_empty() or _dest_id.is_empty() or _origin_id == _dest_id:
		return
	if _selected_ship_ids.is_empty():
		return

	var freq: int = int(_freq_spin.value) if _freq_spin else 1
	_player_controller.add_route_create(
		_origin_id, _dest_id, _selected_ship_ids.duplicate(),
		_pax_spin.value, _cargo_spin.value, freq,
	)
	route_created.emit()
	close()


func _update_create_button_state() -> void:
	if _create_btn == null:
		return
	var any_ships := not _selected_ship_ids.is_empty()

	var has_slots := true
	if not _origin_id.is_empty() and not _dest_id.is_empty():
		var carrier := _game_state.get_player_carrier()
		if carrier:
			has_slots = carrier.has_slots_at(_origin_id) and carrier.has_slots_at(_dest_id)

	_create_btn.disabled = not any_ships or not has_slots


func _update_ship_display() -> void:
	if _ship_display == null:
		return
	if _selected_ship_ids.is_empty():
		_ship_display.text = "None"
	else:
		_ship_display.text = "%d ship(s)" % _selected_ship_ids.size()


func _reset_form() -> void:
	_origin_id = ""
	_dest_id = ""
	_selected_ship_ids.clear()


func _get_planet_display_name(planet_id: String) -> String:
	if planet_id.is_empty():
		return "None"
	var planet := _game_state.galaxy.get_planet(planet_id)
	return planet.name if planet else planet_id


func _compute_max_frequency() -> int:
	if _selected_ship_ids.is_empty() or _origin_id.is_empty() or _dest_id.is_empty():
		return 0
	var lane := _game_state.galaxy.get_lane(_origin_id, _dest_id)
	if lane == null:
		return 0
	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return 0
	return RouteValidator.calculate_max_frequency(
		_selected_ship_ids, carrier, _game_state.catalog, lane.distance
	)


func _update_frequency_max() -> void:
	if _freq_spin == null:
		return
	var max_freq := _compute_max_frequency()
	_freq_spin.max_value = maxi(max_freq, 1)
	_freq_spin.editable = max_freq > 0
	if _freq_spin.value > max_freq and max_freq > 0:
		_freq_spin.value = max_freq

	# Update "/ N" label if it exists
	var freq_row := _freq_spin.get_parent()
	if freq_row:
		var max_label := freq_row.get_node_or_null("FreqMaxLabel")
		if max_label:
			max_label.text = "/ %d" % max_freq if max_freq > 0 else "/ —"


# ---------------------------------------------------------------------------
# Programmatic API (for validation harness)
# ---------------------------------------------------------------------------

func set_origin(planet_id: String) -> void:
	_origin_id = planet_id
	_rebuild_form()


func set_destination(planet_id: String) -> void:
	_dest_id = planet_id
	_rebuild_form()


func select_ships(ship_ids: Array) -> void:
	_selected_ship_ids = ship_ids.duplicate()
	_update_ship_display()
	_update_frequency_max()
	_update_create_button_state()


func confirm_create() -> void:
	_on_create_route()


func open_planet_selector(target: String) -> void:
	_open_planet_selector(target)


func is_selection_popup_visible() -> bool:
	return _selection_popup != null and is_instance_valid(_selection_popup) and _selection_popup.visible


func get_selection_popup_item_count() -> int:
	if not is_selection_popup_visible():
		return 0
	# Count rows with a "Select" button in the popup's scroll list
	var vbox: VBoxContainer = _selection_popup.get_child(0)
	for child: Node in vbox.get_children():
		if child is ScrollContainer:
			var list: VBoxContainer = child.get_child(0)
			var count := 0
			for row: Node in list.get_children():
				if row is HBoxContainer:
					count += 1
			return count
	return 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _create_label_spinbox(
	label_text: String,
	min_val: float,
	max_val: float,
	step: float,
	default_val: float,
) -> HBoxContainer:
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
