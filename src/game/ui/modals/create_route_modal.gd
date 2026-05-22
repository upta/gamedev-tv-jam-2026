class_name CreateRouteModal
extends ModalDialog

## Modal for creating a new route or editing an existing one.
## In create mode: opened from Routes Overview via "Create Route" button.
## In edit mode: opened from Routes Overview via "Edit" button on an active route.

signal route_created
signal route_modified

var _player_controller: PlayerController
var _game_state: GameState
var _content: VBoxContainer

# Edit mode
var _edit_mode: bool = false
var _editing_route: CarrierData.Route = null
var _editing_route_overrides: Dictionary = {}

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
var _create_status_label: Label
var _details_section: VBoxContainer

# Sub-dialog
var _selection_popup: PanelContainer
var _selection_overlay: ColorRect
var _selection_callback: Callable
var _selection_popup_items: Array[Dictionary] = []


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
	_edit_mode = false
	_editing_route = null
	_reset_form()
	set_title("New Route")
	super.open()
	_rebuild_form()


func open_with_planets(origin_id: String, dest_id: String) -> void:
	_edit_mode = false
	_editing_route = null
	_reset_form()
	_origin_id = origin_id
	_dest_id = dest_id
	set_title("New Route")
	super.open()
	_rebuild_form()


func open_for_edit(route: CarrierData.Route) -> void:
	_edit_mode = true
	_editing_route = route
	_origin_id = route.origin_id
	_dest_id = route.dest_id
	_selected_ship_ids = route.ship_ids.duplicate()

	# If a pending modification exists, use those values instead of committed state
	var pending_mod := _find_pending_modification(route.id)
	if pending_mod.size() > 0:
		_selected_ship_ids = pending_mod["ship_ids"].duplicate() if pending_mod.has("ship_ids") else _selected_ship_ids
		_editing_route_overrides = pending_mod

	set_title("Edit Route")
	super.open()
	_rebuild_form()


func _find_pending_modification(route_id: String) -> Dictionary:
	if _player_controller == null:
		return {}
	for mod: Dictionary in _player_controller.pending_intent.route_modifications:
		if mod.get("route_id", "") == route_id:
			return mod
	return {}


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
	if not _edit_mode:
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
	if not _edit_mode:
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
	_create_status_label = null

	if _origin_id.is_empty() or _dest_id.is_empty() or _origin_id == _dest_id:
		return

	var lane := _game_state.galaxy.get_lane(_origin_id, _dest_id)
	if lane == null:
		var no_lane := Label.new()
		no_lane.text = "No lane between these planets."
		_details_section.add_child(no_lane)
		return

	# Show distance immediately after planets selected
	var distance_label := Label.new()
	distance_label.text = "Distance: %.1f ly" % lane.distance
	_details_section.add_child(distance_label)

	# Show which ships in fleet can reach this distance
	var ships_in_range: Array = []
	for ship in carrier.ships:
		var ship_type := _game_state.catalog.get_type(ship.type_id)
		if ship_type and ship_type.range >= lane.distance:
			ships_in_range.append(ship)

	var ships_by_type: Dictionary = {}
	for ship in ships_in_range:
		var type_id: String = ship.type_id
		if not ships_by_type.has(type_id):
			ships_by_type[type_id] = 0
		ships_by_type[type_id] += 1

	var range_label := Label.new()
	if ships_in_range.is_empty():
		range_label.text = "No ships in range — order ships with range >= %.1f ly" % lane.distance
		range_label.modulate = Color(0.8, 0.4, 0.4)
	else:
		var ship_list: Array = []
		for type_id in ships_by_type.keys():
			var count: int = ships_by_type[type_id]
			ship_list.append("%s (x%d)" % [type_id, count])
		range_label.text = "Ships in range: " + ", ".join(ship_list)
		range_label.modulate = Color(0.6, 0.8, 0.6)
	_details_section.add_child(range_label)

	if _selected_ship_ids.is_empty():
		var hint := Label.new()
		hint.text = "Select ships to configure route"
		hint.modulate = Color(0.6, 0.6, 0.6)
		_details_section.add_child(hint)
		return

	# Distance and slot info (detailed view after ships selected)
	var origin_slots: int = carrier.get_slot_count(_origin_id)
	var dest_slots: int = carrier.get_slot_count(_dest_id)
	var origin_avail: int = _get_adjusted_available_slots(carrier, _origin_id)
	var dest_avail: int = _get_adjusted_available_slots(carrier, _dest_id)
	_info_label = Label.new()
	_info_label.text = "%s: %d/%d avail | %s: %d/%d avail" % [
		_get_planet_display_name(_origin_id), maxi(origin_avail, 0), origin_slots,
		_get_planet_display_name(_dest_id), maxi(dest_avail, 0), dest_slots,
	]
	_details_section.add_child(_info_label)

	# Suggested prices
	var suggested_pax := DemandCalculator.calculate_suggested_price(lane, "passenger")
	var suggested_cargo := DemandCalculator.calculate_suggested_price(lane, "cargo")

	# Flights per month — max depends on selected ships
	var max_freq := _compute_max_frequency()
	var freq_default: int = 1
	if _edit_mode:
		if _editing_route_overrides.has("frequency"):
			freq_default = _editing_route_overrides["frequency"]
		elif _editing_route:
			freq_default = _editing_route.frequency
	var freq_row := _create_label_spinbox("Flights per Month:", 1, maxi(max_freq, 1), 1, mini(freq_default, maxi(max_freq, 1)))
	_details_section.add_child(freq_row)
	_freq_spin = freq_row.get_child(1)
	_freq_spin.editable = max_freq > 0

	# Max frequency label
	var freq_max_label := Label.new()
	freq_max_label.name = "FreqMaxLabel"
	freq_max_label.text = "/ %d" % max_freq if max_freq > 0 else "/ -"
	freq_row.add_child(freq_max_label)

	# Pricing
	var pax_default: int
	if _edit_mode and _editing_route_overrides.has("passenger_price"):
		pax_default = int(roundf(_editing_route_overrides["passenger_price"]))
	elif _edit_mode and _editing_route:
		pax_default = int(roundf(_editing_route.passenger_price))
	else:
		pax_default = int(roundf(suggested_pax))
	var pax_max := int(10 * ceilf(suggested_pax))
	var cargo_default: int
	if _edit_mode and _editing_route_overrides.has("cargo_price"):
		cargo_default = int(roundf(_editing_route_overrides["cargo_price"]))
	elif _edit_mode and _editing_route:
		cargo_default = int(roundf(_editing_route.cargo_price))
	else:
		cargo_default = int(roundf(suggested_cargo))
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
	if _edit_mode:
		_create_btn.text = "Save Changes"
		_create_btn.pressed.connect(_on_save_route)
	else:
		_create_btn.text = "Create"
		_create_btn.pressed.connect(_on_create_route)
	btn_row.add_child(_create_btn)
	_details_section.add_child(btn_row)

	_create_status_label = Label.new()
	_create_status_label.modulate = Color(0.95, 0.75, 0.35)
	_create_status_label.visible = false
	_details_section.add_child(_create_status_label)

	# Cancel Route button (edit mode only, at bottom, styled as destructive)
	if _edit_mode:
		var cancel_route_row := HBoxContainer.new()
		cancel_route_row.alignment = BoxContainer.ALIGNMENT_CENTER
		var cancel_route_btn := Button.new()
		cancel_route_btn.text = "Cancel Route"
		cancel_route_btn.add_theme_color_override("font_color", ThemeBuilder.NEGATIVE)
		cancel_route_btn.pressed.connect(_on_cancel_route_from_edit)
		cancel_route_row.add_child(cancel_route_btn)
		_details_section.add_child(cancel_route_row)

	_update_create_button_state()


# ---------------------------------------------------------------------------
# Planet Selection Sub-Dialog
# ---------------------------------------------------------------------------

func _open_planet_selector(target: String) -> void:
	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return

	var items: Array[Dictionary] = []

	for planet: GalaxyData.Planet in _game_state.galaxy.planets:
		# Exclude the already-selected counterpart
		if target == "origin" and planet.id == _dest_id:
			continue
		if target == "dest" and planet.id == _origin_id:
			continue
		var slot_count: int = carrier.get_slot_count(planet.id)
		var available_count: int = _get_adjusted_available_slots(carrier, planet.id)
		var item := {
			"id": planet.id,
			"selectable": true,
		}
		if slot_count > 0:
			item["label"] = "%s - %d available (%d owned)" % [planet.name, maxi(available_count, 0), slot_count]
		else:
			item["label"] = "%s - No slots" % planet.name
			item["label_modulate"] = Color(0.95, 0.75, 0.35)
		items.append(item)

	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["label"] < b["label"])

	var callback := func(selected_id: String) -> void:
		if target == "origin":
			_origin_id = selected_id
		else:
			_dest_id = selected_id
		_selected_ship_ids.clear()
		_rebuild_form()

	_show_selection_popup("Select Planet", items, [], callback)


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

	# In edit mode, also include ships currently assigned to the route being edited
	if _edit_mode and _editing_route:
		var idle_ids: Dictionary = {}
		for ship: ShipCatalog.ShipInstance in idle_ships:
			idle_ids[ship.id] = true
		for ship_id: String in _editing_route.ship_ids:
			if not idle_ids.has(ship_id):
				for ship: ShipCatalog.ShipInstance in carrier.ships:
					if ship.id == ship_id:
						idle_ships.append(ship)
						break

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
				"label": "%s (%s%d %s%d %s%s)%s" % [
					type_name,
					ThemeBuilder.pax_bb(), ship.passenger_capacity,
					ThemeBuilder.cargo_bb(), ship.cargo_capacity,
					ThemeBuilder.fuel_bb(), ship_type.get_efficiency_rating(),
					" *" if already_selected else "",
				],
				"selectable": true,
				"use_bbcode": true,
			})
		else:
			out_range.append({
				"id": ship.id,
				"label": "%s - Out of range" % type_name,
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
		_rebuild_route_details(_game_state.get_player_carrier())
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
	_selection_popup_items = []
	for item: Dictionary in group_a:
		_selection_popup_items.append(item.duplicate(true))
	for item: Dictionary in group_b:
		_selection_popup_items.append(item.duplicate(true))

	_selection_popup = PanelContainer.new()
	_selection_popup.theme = ThemeBuilder.build_theme()
	_selection_popup.custom_minimum_size = Vector2(400, 300)

	# Style popup background with modal surface + border
	var popup_bg := StyleBoxFlat.new()
	popup_bg.bg_color = ThemeBuilder.MODAL_SURFACE
	popup_bg.border_color = ThemeBuilder.BORDER
	popup_bg.set_border_width_all(2)
	popup_bg.set_corner_radius_all(6)
	popup_bg.set_content_margin_all(12)
	_selection_popup.add_theme_stylebox_override("panel", popup_bg)

	var vbox := VBoxContainer.new()
	_selection_popup.add_child(vbox)

	# Title bar
	var title_row := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	title_row.add_child(title_label)
	var close_btn := Button.new()
	close_btn.text = "X"
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
		if item.get("use_bbcode", false):
			var rtl := ThemeBuilder.make_icon_label()
			rtl.text = item["label"]
			rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if item.has("label_modulate"):
				rtl.modulate = item["label_modulate"]
			row.add_child(rtl)
		else:
			var lbl := Label.new()
			lbl.text = item["label"]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if item.has("label_modulate"):
				lbl.modulate = item["label_modulate"]
			row.add_child(lbl)
		var btn := Button.new()
		btn.text = "Select"
		btn.disabled = not item.get("selectable", true)
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
	_selection_popup_items.clear()
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


func _on_save_route() -> void:
	if _editing_route == null or _selected_ship_ids.is_empty():
		return

	var freq: int = int(_freq_spin.value) if _freq_spin else 1
	_player_controller.modify_route(
		_editing_route.id, _selected_ship_ids.duplicate(),
		_pax_spin.value, _cargo_spin.value, freq,
	)
	route_modified.emit()
	close()


func _on_cancel_route_from_edit() -> void:
	if _editing_route == null:
		return
	_player_controller.cancel_route(_editing_route.id)
	close()


func _update_create_button_state() -> void:
	if _create_btn == null:
		return
	var any_ships := not _selected_ship_ids.is_empty()
	var has_slots := true
	var missing_slot_planets: Array[String] = []
	var has_duplicate_route := false

	if not _origin_id.is_empty() and not _dest_id.is_empty():
		var carrier := _game_state.get_player_carrier()
		if carrier:
			missing_slot_planets = _get_missing_slot_planet_names(carrier)
			has_slots = missing_slot_planets.is_empty()

			if not _edit_mode:
				var new_lane_id := GalaxyData.derive_lane_id(_origin_id, _dest_id)
				for route: CarrierData.Route in carrier.routes:
					if route.lane_id == new_lane_id:
						has_duplicate_route = true
						break
				if not has_duplicate_route:
					for rc: Dictionary in _player_controller.pending_intent.route_creates:
						var pending_lane_id := GalaxyData.derive_lane_id(rc["origin_id"], rc["dest_id"])
						if pending_lane_id == new_lane_id:
							has_duplicate_route = true
							break

	_create_btn.disabled = not any_ships or not has_slots or has_duplicate_route

	if _create_status_label:
		if has_duplicate_route:
			_create_status_label.text = "You already have a route on this lane. Edit the existing route instead."
			_create_status_label.visible = true
		elif not has_slots and any_ships:
			_create_status_label.text = "Need slots at %s to create this route." % " and ".join(missing_slot_planets)
			_create_status_label.visible = true
		else:
			_create_status_label.text = ""
			_create_status_label.visible = false


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
	_editing_route_overrides = {}


func _get_planet_display_name(planet_id: String) -> String:
	if planet_id.is_empty():
		return "None"
	var planet := _game_state.galaxy.get_planet(planet_id)
	return planet.name if planet else planet_id


func _count_pending_routes_at(planet_id: String) -> int:
	if _player_controller == null:
		return 0
	var count := 0
	for rc: Dictionary in _player_controller.pending_intent.route_creates:
		if rc["origin_id"] == planet_id or rc["dest_id"] == planet_id:
			count += 1
	return count


func _get_adjusted_available_slots(carrier: CarrierData, planet_id: String) -> int:
	var available := carrier.get_available_slots_at(planet_id) - _count_pending_routes_at(planet_id)
	if _edit_mode and _editing_route and (_editing_route.origin_id == planet_id or _editing_route.dest_id == planet_id):
		available += 1
	return available


func _get_missing_slot_planet_names(carrier: CarrierData) -> Array[String]:
	var missing_planets: Array[String] = []
	if not _origin_id.is_empty() and _get_adjusted_available_slots(carrier, _origin_id) < 1:
		missing_planets.append(_get_planet_display_name(_origin_id))
	if not _dest_id.is_empty() and _get_adjusted_available_slots(carrier, _dest_id) < 1:
		missing_planets.append(_get_planet_display_name(_dest_id))
	return missing_planets


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
			max_label.text = "/ %d" % max_freq if max_freq > 0 else "/ -"


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
	var carrier := _game_state.get_player_carrier()
	if carrier:
		_rebuild_route_details(carrier)
	_update_create_button_state()


func confirm_create() -> void:
	_on_create_route()


func open_for_edit_by_id(route_id: String) -> void:
	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return
	for route: CarrierData.Route in carrier.get_active_routes():
		if route.id == route_id:
			open_for_edit(route)
			return


func get_edit_mode() -> bool:
	return _edit_mode


func get_editing_route_id() -> String:
	if _editing_route:
		return _editing_route.id
	return ""


func get_form_state() -> Dictionary:
	return {
		"origin_id": _origin_id,
		"dest_id": _dest_id,
		"ship_count": _selected_ship_ids.size(),
		"ship_ids": _selected_ship_ids.duplicate(),
		"frequency": int(_freq_spin.value) if _freq_spin else 0,
		"passenger_price": _pax_spin.value if _pax_spin else 0.0,
		"cargo_price": _cargo_spin.value if _cargo_spin else 0.0,
	}


func set_frequency(value: int) -> void:
	if _freq_spin:
		_freq_spin.value = value


func set_passenger_price(value: float) -> void:
	if _pax_spin:
		_pax_spin.value = value


func set_cargo_price(value: float) -> void:
	if _cargo_spin:
		_cargo_spin.value = value


func confirm_save() -> void:
	_on_save_route()


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


func get_selection_popup_items() -> Array[Dictionary]:
	return _selection_popup_items.duplicate(true)


func select_selection_popup_item(item_id: String, close_on_select: bool = true) -> void:
	if not is_selection_popup_visible() or not _selection_callback.is_valid():
		return
	_selection_callback.call(item_id)
	if close_on_select:
		_close_selection_popup()


func is_create_action_disabled() -> bool:
	return _create_btn == null or _create_btn.disabled


func get_create_status_text() -> String:
	return _create_status_label.text if _create_status_label else ""


func get_detail_lines() -> Array[String]:
	var detail_lines: Array[String] = []
	if _details_section == null:
		return detail_lines
	for child: Node in _details_section.get_children():
		if child is Label:
			detail_lines.append(child.text)
	return detail_lines


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
