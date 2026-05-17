class_name ActionPanel
extends PanelContainer

## Context-sensitive action panel that changes content based on star map selection.
## Calls PlayerController.add_*() methods when the player submits a form.

@onready var _context_label: Label = $MarginContainer/ScrollContainer/Content/ContextLabel
@onready var _form_container: VBoxContainer = $MarginContainer/ScrollContainer/Content/FormContainer
@onready var _pending_summary: VBoxContainer = $MarginContainer/ScrollContainer/Content/PendingSummary

var _player_controller: PlayerController
var _game_state: GameState
var _current_context: String = "none"
var _selected_planet_id: String = ""
var _selected_lane_id: String = ""
var _selected_origin_id: String = ""
var _selected_dest_id: String = ""
var _updating_capacity: bool = false


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state
	_player_controller.intent_changed.connect(_on_intent_changed)
	show_default()


func show_planet_actions(planet_id: String) -> void:
	_current_context = "planet"
	_selected_planet_id = planet_id
	var planet := _game_state.galaxy.get_planet(planet_id)
	var planet_name: String = planet.name if planet else planet_id
	_context_label.text = "Planet: %s" % planet_name
	_clear_forms()
	_build_planet_forms(planet_id)
	_build_pending_summary()


func show_lane_actions(lane_id: String, origin_id: String, dest_id: String) -> void:
	_current_context = "lane"
	_selected_lane_id = lane_id
	_selected_origin_id = origin_id
	_selected_dest_id = dest_id
	var origin := _game_state.galaxy.get_planet(origin_id)
	var dest := _game_state.galaxy.get_planet(dest_id)
	var origin_name: String = origin.name if origin else origin_id
	var dest_name: String = dest.name if dest else dest_id
	_context_label.text = "Lane: %s \u2194 %s" % [origin_name, dest_name]
	_clear_forms()
	_build_lane_forms(lane_id, origin_id, dest_id)
	_build_pending_summary()


func show_default() -> void:
	_current_context = "none"
	_selected_planet_id = ""
	_selected_lane_id = ""
	_selected_origin_id = ""
	_selected_dest_id = ""
	_context_label.text = "General Actions"
	_clear_forms()
	_build_ship_order_form()
	_build_pending_summary()


func refresh_pending_summary() -> void:
	_build_pending_summary()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_intent_changed(_intent: TurnPipeline.CarrierIntent) -> void:
	refresh_pending_summary()


# ---------------------------------------------------------------------------
# Form management
# ---------------------------------------------------------------------------

func _clear_forms() -> void:
	for child: Node in _form_container.get_children():
		child.queue_free()


func _build_planet_forms(planet_id: String) -> void:
	var planet := _game_state.galaxy.get_planet(planet_id)
	if planet == null:
		return

	var occupied: int = 0
	for carrier: CarrierData in _game_state.carriers:
		occupied += carrier.get_slot_count(planet_id)
	var available: int = planet.total_slots - occupied

	var info_label := Label.new()
	info_label.text = "Total slots: %d | Occupied: %d | Available: %d" % [
		planet.total_slots, occupied, available,
	]
	_form_container.add_child(info_label)

	# -- Slot Bid form --
	var bid_header := Label.new()
	bid_header.text = "\u2014 Bid for Slots \u2014"
	_form_container.add_child(bid_header)

	if available > 0:
		var qty_row := _create_label_spinbox("Quantity:", 1, available, 1, 1)
		_form_container.add_child(qty_row)
		var qty_spin: SpinBox = qty_row.get_child(1)

		var price_row := _create_label_spinbox("Price per slot:", 50, 10000, 1, 50)
		_form_container.add_child(price_row)
		var price_spin: SpinBox = price_row.get_child(1)

		var bid_btn := Button.new()
		bid_btn.text = "Submit Bid"
		bid_btn.pressed.connect(_on_slot_bid_submit.bind(planet_id, qty_spin, price_spin))
		_form_container.add_child(bid_btn)
	else:
		var no_slots_label := Label.new()
		no_slots_label.text = "No slots available for bidding."
		_form_container.add_child(no_slots_label)

	# -- Slot Sell form (only if player owns slots here) --
	var player := _game_state.get_player_carrier()
	if player and player.has_slots_at(planet_id):
		var sell_sep := HSeparator.new()
		_form_container.add_child(sell_sep)

		var sell_header := Label.new()
		sell_header.text = "\u2014 Sell Slots \u2014"
		_form_container.add_child(sell_header)

		var owned: int = player.get_slot_count(planet_id)
		var count_row := _create_label_spinbox("Count:", 1, owned, 1, 1)
		_form_container.add_child(count_row)
		var count_spin: SpinBox = count_row.get_child(1)

		var sell_btn := Button.new()
		sell_btn.text = "Sell Slots"
		sell_btn.pressed.connect(_on_slot_sell_submit.bind(planet_id, count_spin))
		_form_container.add_child(sell_btn)


func _build_lane_forms(lane_id: String, origin_id: String, dest_id: String) -> void:
	var lane := _game_state.galaxy.get_lane(origin_id, dest_id)
	if lane == null:
		return

	var origin := _game_state.galaxy.get_planet(origin_id)
	var dest := _game_state.galaxy.get_planet(dest_id)
	var origin_name: String = origin.name if origin else origin_id
	var dest_name: String = dest.name if dest else dest_id

	var info_label := Label.new()
	info_label.text = "%s \u2194 %s | Distance: %.1f ly" % [origin_name, dest_name, lane.distance]
	_form_container.add_child(info_label)

	# Check if player already has an active route on this lane
	var player := _game_state.get_player_carrier()
	var existing_route: CarrierData.Route = null
	if player:
		for route: CarrierData.Route in player.routes:
			if route.lane_id == lane_id and route.active:
				existing_route = route
				break

	if existing_route == null:
		_build_route_create_section(lane_id, origin_id, dest_id, lane.distance)
	else:
		_build_route_manage_section(existing_route)


func _build_route_create_section(
	lane_id: String,
	origin_id: String,
	dest_id: String,
	distance: float,
) -> void:
	var create_header := Label.new()
	create_header.text = "\u2014 Create Route \u2014"
	_form_container.add_child(create_header)

	var eligible_ships: Array = _get_eligible_ships(distance)
	if eligible_ships.is_empty():
		var no_ships := Label.new()
		no_ships.text = "No eligible ships (need range \u2265 %.1f ly)." % distance
		_form_container.add_child(no_ships)
		return

	var ships_label := Label.new()
	ships_label.text = "Select ships:"
	_form_container.add_child(ships_label)

	var ship_checks: Array = []
	for ship: ShipCatalog.ShipInstance in eligible_ships:
		var ship_type := _game_state.catalog.get_type(ship.type_id)
		var type_name: String = ship_type.name if ship_type else ship.type_id
		var cb := CheckBox.new()
		cb.text = "%s (Pax:%d Cargo:%d)" % [type_name, ship.passenger_capacity, ship.cargo_capacity]
		cb.set_meta("ship_id", ship.id)
		_form_container.add_child(cb)
		ship_checks.append(cb)

	var pax_price_row := _create_label_spinbox("Passenger price:", 1, 1000, 1, 10)
	_form_container.add_child(pax_price_row)
	var pax_spin: SpinBox = pax_price_row.get_child(1)

	var cargo_price_row := _create_label_spinbox("Cargo price:", 1, 1000, 1, 10)
	_form_container.add_child(cargo_price_row)
	var cargo_spin: SpinBox = cargo_price_row.get_child(1)

	var create_btn := Button.new()
	create_btn.text = "Create Route"
	create_btn.pressed.connect(
		_on_route_create_submit.bind(lane_id, origin_id, dest_id, ship_checks, pax_spin, cargo_spin)
	)
	_form_container.add_child(create_btn)


func _build_route_manage_section(route: CarrierData.Route) -> void:
	var route_header := Label.new()
	route_header.text = "\u2014 Active Route \u2014"
	_form_container.add_child(route_header)

	var route_info := Label.new()
	route_info.text = "Ships: %d | Pax: \u00a7%d | Cargo: \u00a7%d | Freq: %d" % [
		route.ship_ids.size(),
		int(route.passenger_price),
		int(route.cargo_price),
		route.frequency,
	]
	_form_container.add_child(route_info)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel Route"
	cancel_btn.pressed.connect(_on_route_cancel_submit.bind(route.id))
	_form_container.add_child(cancel_btn)


func _build_ship_order_form() -> void:
	var order_header := Label.new()
	order_header.text = "\u2014 Order Ship \u2014"
	_form_container.add_child(order_header)

	var available_types := _game_state.catalog.get_available_types(_game_state.current_turn)
	if available_types.is_empty():
		var no_types := Label.new()
		no_types.text = "No ship types available."
		_form_container.add_child(no_types)
		return

	# Type selector
	var type_row := HBoxContainer.new()
	var type_label := Label.new()
	type_label.text = "Type:"
	type_row.add_child(type_label)
	var type_option := OptionButton.new()
	type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ship_type: ShipCatalog.ShipType in available_types:
		type_option.add_item(ship_type.name)
		type_option.set_item_metadata(type_option.item_count - 1, ship_type.id)
	type_row.add_child(type_option)
	_form_container.add_child(type_row)

	# Stats display
	var stats_label := Label.new()
	_form_container.add_child(stats_label)

	# Capacity spinboxes
	var pax_row := _create_label_spinbox("Passengers:", 0, 0, 1, 0)
	_form_container.add_child(pax_row)
	var pax_spin: SpinBox = pax_row.get_child(1)

	var cargo_row := _create_label_spinbox("Cargo:", 0, 0, 1, 0)
	_form_container.add_child(cargo_row)
	var cargo_spin: SpinBox = cargo_row.get_child(1)

	# Submit button
	var submit_btn := Button.new()
	submit_btn.text = "Order Ship"
	_form_container.add_child(submit_btn)

	# Wire type selector to update stats and spinbox ranges
	type_option.item_selected.connect(
		_on_ship_type_selected.bind(type_option, stats_label, pax_spin, cargo_spin, submit_btn)
	)

	# Wire capacity spinboxes for auto-adjustment
	pax_spin.value_changed.connect(
		_on_capacity_changed.bind(pax_spin, cargo_spin, type_option, submit_btn)
	)
	cargo_spin.value_changed.connect(
		_on_capacity_changed.bind(cargo_spin, pax_spin, type_option, submit_btn)
	)

	submit_btn.pressed.connect(
		_on_ship_order_submit.bind(type_option, pax_spin, cargo_spin)
	)

	# Initialize with first type
	if type_option.item_count > 0:
		_on_ship_type_selected(0, type_option, stats_label, pax_spin, cargo_spin, submit_btn)


func _build_pending_summary() -> void:
	for child: Node in _pending_summary.get_children():
		child.queue_free()

	if _player_controller == null:
		return

	var header := Label.new()
	header.text = "\u2014 Pending Actions \u2014"
	_pending_summary.add_child(header)

	var summary := _player_controller.get_pending_summary()
	var total: int = 0

	var labels: Dictionary = {
		"slot_bids": "Slot Bids",
		"route_creates": "New Routes",
		"route_modifications": "Route Mods",
		"route_cancellations": "Route Cancels",
		"ship_orders": "Ship Orders",
		"slot_sales": "Slot Sales",
	}

	for key: String in labels:
		var count: int = summary.get(key, 0)
		total += count
		if count > 0:
			var label := Label.new()
			label.text = "%s: %d" % [labels[key], count]
			_pending_summary.add_child(label)

	if total == 0:
		var none_label := Label.new()
		none_label.text = "None"
		_pending_summary.add_child(none_label)
	else:
		var clear_btn := Button.new()
		clear_btn.text = "Clear All"
		clear_btn.pressed.connect(_on_clear_all_pressed)
		_pending_summary.add_child(clear_btn)


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


func _get_eligible_ships(min_range: float) -> Array:
	var player := _game_state.get_player_carrier()
	if player == null:
		return []
	var idle_ships := player.get_available_ships()
	var eligible: Array = []
	for ship: ShipCatalog.ShipInstance in idle_ships:
		var ship_type := _game_state.catalog.get_type(ship.type_id)
		if ship_type and ship_type.range >= min_range:
			eligible.append(ship)
	return eligible


# ---------------------------------------------------------------------------
# Form handlers
# ---------------------------------------------------------------------------

func _on_slot_bid_submit(planet_id: String, qty_spin: SpinBox, price_spin: SpinBox) -> void:
	var quantity: int = int(qty_spin.value)
	var price: float = price_spin.value
	if quantity < 1 or price < 50.0:
		return
	_player_controller.add_slot_bid(planet_id, quantity, price)


func _on_slot_sell_submit(planet_id: String, count_spin: SpinBox) -> void:
	var count: int = int(count_spin.value)
	if count < 1:
		return
	var player := _game_state.get_player_carrier()
	if player == null or count > player.get_slot_count(planet_id):
		return
	_player_controller.add_slot_sale(planet_id, count)


func _on_route_create_submit(
	lane_id: String,
	origin_id: String,
	dest_id: String,
	ship_checks: Array,
	pax_spin: SpinBox,
	cargo_spin: SpinBox,
) -> void:
	var selected_ids: Array = []
	for cb: CheckBox in ship_checks:
		if cb.button_pressed:
			selected_ids.append(cb.get_meta("ship_id"))
	if selected_ids.is_empty():
		return
	var pax_price: float = pax_spin.value
	var cargo_price: float = cargo_spin.value
	if pax_price < 1.0 or cargo_price < 1.0:
		return
	_player_controller.add_route_create(
		lane_id, origin_id, dest_id, selected_ids, pax_price, cargo_price
	)


func _on_route_cancel_submit(route_id: String) -> void:
	_player_controller.cancel_route(route_id)


func _on_ship_order_submit(
	type_option: OptionButton,
	pax_spin: SpinBox,
	cargo_spin: SpinBox,
) -> void:
	var idx: int = type_option.selected
	if idx < 0:
		return
	var type_id: String = type_option.get_item_metadata(idx)
	var ship_type := _game_state.catalog.get_type(type_id)
	if ship_type == null:
		return
	var pax: int = int(pax_spin.value)
	var cargo: int = int(cargo_spin.value)
	if pax + cargo != ship_type.max_capacity:
		return
	var player := _game_state.get_player_carrier()
	if player == null or player.cash < ship_type.cost:
		return
	_player_controller.add_ship_order(type_id, pax, cargo)


func _on_ship_type_selected(
	index: int,
	type_option: OptionButton,
	stats_label: Label,
	pax_spin: SpinBox,
	cargo_spin: SpinBox,
	submit_btn: Button,
) -> void:
	var type_id: String = type_option.get_item_metadata(index)
	var ship_type := _game_state.catalog.get_type(type_id)
	if ship_type == null:
		return
	stats_label.text = "Cost: \u00a7%d | Cap: %d | Range: %.1f ly | Build: %d turns" % [
		ship_type.cost, ship_type.max_capacity, ship_type.range, ship_type.build_turns,
	]
	_updating_capacity = true
	pax_spin.max_value = ship_type.max_capacity
	cargo_spin.max_value = ship_type.max_capacity
	var half: int = ship_type.max_capacity / 2
	pax_spin.value = half
	cargo_spin.value = ship_type.max_capacity - half
	_updating_capacity = false
	_update_order_button(type_option, submit_btn)


func _on_capacity_changed(
	_new_value: float,
	changed_spin: SpinBox,
	other_spin: SpinBox,
	type_option: OptionButton,
	submit_btn: Button,
) -> void:
	if _updating_capacity:
		return
	_updating_capacity = true
	var idx: int = type_option.selected
	if idx >= 0:
		var type_id: String = type_option.get_item_metadata(idx)
		var ship_type := _game_state.catalog.get_type(type_id)
		if ship_type:
			other_spin.value = ship_type.max_capacity - changed_spin.value
	_update_order_button(type_option, submit_btn)
	_updating_capacity = false


func _update_order_button(type_option: OptionButton, submit_btn: Button) -> void:
	var idx: int = type_option.selected
	if idx < 0:
		submit_btn.disabled = true
		return
	var type_id: String = type_option.get_item_metadata(idx)
	var ship_type := _game_state.catalog.get_type(type_id)
	if ship_type == null:
		submit_btn.disabled = true
		return
	var player := _game_state.get_player_carrier()
	submit_btn.disabled = player == null or player.cash < ship_type.cost


func _on_clear_all_pressed() -> void:
	_player_controller.clear_intent()
