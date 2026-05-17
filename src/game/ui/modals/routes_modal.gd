class_name RoutesModal
extends ModalDialog

## Modal for creating and cancelling routes with lane selection.

var _player_controller: PlayerController
var _game_state: GameState
var _content: VBoxContainer

# Create-route form state
var _lane_option: OptionButton
var _info_label: Label
var _ship_checks: Array = []
var _pax_spin: SpinBox
var _cargo_spin: SpinBox
var _create_btn: Button
var _create_section: VBoxContainer


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

	_ship_checks.clear()

	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return

	_build_active_routes(carrier)
	_content.add_child(HSeparator.new())
	_build_pending_actions()
	_content.add_child(HSeparator.new())
	_build_create_route(carrier)


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
# Section 3: Create New Route
# ---------------------------------------------------------------------------

func _build_create_route(carrier: CarrierData) -> void:
	var header := Label.new()
	header.text = "— Create New Route —"
	_content.add_child(header)

	# Lane selector
	var lane_row := HBoxContainer.new()
	var lane_label := Label.new()
	lane_label.text = "Lane:"
	lane_row.add_child(lane_label)
	_lane_option = OptionButton.new()
	_lane_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lane_option.add_item("Select a lane...")

	for lane: GalaxyData.Lane in _game_state.galaxy.lanes:
		var planet_a := _game_state.galaxy.get_planet(lane.origin_id)
		var planet_b := _game_state.galaxy.get_planet(lane.dest_id)
		var name_a: String = planet_a.name if planet_a else lane.origin_id
		var name_b: String = planet_b.name if planet_b else lane.dest_id
		_lane_option.add_item("%s ↔ %s (%.1f ly)" % [name_a, name_b, lane.distance])
		_lane_option.set_item_metadata(_lane_option.item_count - 1, lane.id)

	lane_row.add_child(_lane_option)
	_content.add_child(lane_row)

	# Container for the rest of the create form (populated on lane selection)
	_create_section = VBoxContainer.new()
	_content.add_child(_create_section)

	_lane_option.item_selected.connect(_on_lane_selected)


func _on_lane_selected(index: int) -> void:
	for child: Node in _create_section.get_children():
		child.queue_free()
	_ship_checks.clear()

	if index == 0:
		return

	var lane_id: String = _lane_option.get_item_metadata(index)
	var lane: GalaxyData.Lane = null
	for l: GalaxyData.Lane in _game_state.galaxy.lanes:
		if l.id == lane_id:
			lane = l
			break
	if lane == null:
		return

	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return

	var planet_a := _game_state.galaxy.get_planet(lane.origin_id)
	var planet_b := _game_state.galaxy.get_planet(lane.dest_id)
	var name_a: String = planet_a.name if planet_a else lane.origin_id
	var name_b: String = planet_b.name if planet_b else lane.dest_id

	# Slot info
	var origin_slots: int = carrier.get_slot_count(lane.origin_id)
	var dest_slots: int = carrier.get_slot_count(lane.dest_id)
	_info_label = Label.new()
	_info_label.text = "Distance: %.1f ly | Slots: %d at %s, %d at %s" % [
		lane.distance, origin_slots, name_a, dest_slots, name_b,
	]
	_create_section.add_child(_info_label)

	# Suggested prices
	var suggested_pax := DemandCalculator.calculate_suggested_price(lane, "passenger")
	var suggested_cargo := DemandCalculator.calculate_suggested_price(lane, "cargo")
	var suggested_label := Label.new()
	suggested_label.text = "Suggested prices — Passenger: §%.2f  Cargo: §%.2f" % [suggested_pax, suggested_cargo]
	_create_section.add_child(suggested_label)

	# Eligible ships
	var eligible_ships := _get_eligible_ships(lane.distance)
	if eligible_ships.is_empty():
		var no_ships := Label.new()
		no_ships.text = "No eligible ships (need range ≥ %.1f ly)." % lane.distance
		_create_section.add_child(no_ships)
		return

	var ships_label := Label.new()
	ships_label.text = "Select ships:"
	_create_section.add_child(ships_label)

	for ship: ShipCatalog.ShipInstance in eligible_ships:
		var ship_type := _game_state.catalog.get_type(ship.type_id)
		var type_name: String = ship_type.name if ship_type else ship.type_id
		var cb := CheckBox.new()
		cb.text = "%s (Pax:%d Cargo:%d)" % [type_name, ship.passenger_capacity, ship.cargo_capacity]
		cb.set_meta("ship_id", ship.id)
		cb.toggled.connect(_on_ship_check_toggled)
		_create_section.add_child(cb)
		_ship_checks.append(cb)

	# Pricing
	var pax_default := int(roundf(suggested_pax))
	var pax_max := int(10 * ceilf(suggested_pax))
	var cargo_default := int(roundf(suggested_cargo))
	var cargo_max := int(10 * ceilf(suggested_cargo))

	var pax_row := _create_label_spinbox("Passenger price:", 1, pax_max, 1, pax_default)
	_create_section.add_child(pax_row)
	_pax_spin = pax_row.get_child(1)

	var cargo_row := _create_label_spinbox("Cargo price:", 1, cargo_max, 1, cargo_default)
	_create_section.add_child(cargo_row)
	_cargo_spin = cargo_row.get_child(1)

	# Create button
	_create_btn = Button.new()
	_create_btn.text = "Create Route"
	_create_btn.pressed.connect(_on_create_route.bind(lane_id))
	_create_section.add_child(_create_btn)

	_update_create_button_state()


func _on_ship_check_toggled(_pressed: bool) -> void:
	_update_create_button_state()


func _update_create_button_state() -> void:
	if _create_btn == null:
		return
	var any_selected := false
	for cb: CheckBox in _ship_checks:
		if cb.button_pressed:
			any_selected = true
			break

	# Check slots at lane endpoints
	var has_slots := true
	var lane_id: String = _lane_option.get_item_metadata(_lane_option.selected) if _lane_option.selected > 0 else ""
	if not lane_id.is_empty():
		var lane: GalaxyData.Lane = null
		for l: GalaxyData.Lane in _game_state.galaxy.lanes:
			if l.id == lane_id:
				lane = l
				break
		if lane:
			var carrier := _game_state.get_player_carrier()
			if carrier:
				has_slots = carrier.has_slots_at(lane.origin_id) and carrier.has_slots_at(lane.dest_id)

	_create_btn.disabled = not any_selected or not has_slots


func _on_create_route(lane_id: String) -> void:
	var lane: GalaxyData.Lane = null
	for l: GalaxyData.Lane in _game_state.galaxy.lanes:
		if l.id == lane_id:
			lane = l
			break
	if lane == null:
		return

	var selected_ids: Array = []
	for cb: CheckBox in _ship_checks:
		if cb.button_pressed:
			selected_ids.append(cb.get_meta("ship_id"))
	if selected_ids.is_empty():
		return

	_player_controller.add_route_create(
		lane_id, lane.origin_id, lane.dest_id, selected_ids,
		_pax_spin.value, _cargo_spin.value,
	)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_eligible_ships(min_range: float) -> Array:
	var player := _game_state.get_player_carrier()
	if player == null:
		return []
	var idle_ships := player.get_available_ships()

	# Exclude ships already committed in pending route creates
	var pending_ship_ids: Dictionary = {}
	for rc: Dictionary in _player_controller.pending_intent.route_creates:
		for ship_id: String in rc["ship_ids"]:
			pending_ship_ids[ship_id] = true

	var eligible: Array = []
	for ship: ShipCatalog.ShipInstance in idle_ships:
		if pending_ship_ids.has(ship.id):
			continue
		var ship_type := _game_state.catalog.get_type(ship.type_id)
		if ship_type and ship_type.range >= min_range:
			eligible.append(ship)
	return eligible


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
