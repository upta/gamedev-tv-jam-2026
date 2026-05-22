class_name RoutesModal
extends ModalDialog

## Modal showing active routes and pending route actions.
## Route creation is handled by CreateRouteModal, opened via the "Create Route" button.
## Route editing is handled by CreateRouteModal in edit mode, opened via the "Edit" button.

signal create_route_requested
signal edit_route_requested(route: CarrierData.Route)

var _player_controller: PlayerController
var _game_state: GameState
var _content: VBoxContainer


func _ready() -> void:
	super._ready()
	set_title("Routes")
	var scroll: ScrollContainer = _content_container.get_child(0)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
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

	var carrier := _game_state.get_player_carrier()
	if carrier == null:
		return

	_build_active_routes(carrier)
	_content.add_child(HSeparator.new())
	_build_pending_actions()
	_content.add_child(HSeparator.new())
	_build_create_button()


# ---------------------------------------------------------------------------
# Section 1: Active Routes
# ---------------------------------------------------------------------------

func _build_active_routes(carrier: CarrierData) -> void:
	var header := ThemeBuilder.make_section_header("Active Routes")
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

		var route_block := VBoxContainer.new()

		# Line 1: Route config + cancel button
		var row := HBoxContainer.new()
		var rtl := ThemeBuilder.make_icon_label()
		rtl.text = "%s -> %s | Ships: %d | %s §%d %s §%d | Freq: %d" % [
			origin_name, dest_name, route.ship_ids.size(),
			ThemeBuilder.pax_bb(), int(route.passenger_price),
			ThemeBuilder.cargo_bb(), int(route.cargo_price), route.frequency,
		]
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rtl)

		var cancel_btn := Button.new()
		cancel_btn.text = "Edit"
		cancel_btn.pressed.connect(_on_edit_route.bind(route))
		row.add_child(cancel_btn)
		route_block.add_child(row)

		# Line 2: Performance metrics from last turn
		var metrics_rtl := ThemeBuilder.make_icon_label()
		var route_fin := _get_route_financials(carrier.id, route.id)
		if route_fin.is_empty():
			metrics_rtl.text = "    No data yet"
		else:
			var pax_served: int = route_fin.get("passengers_served", 0)
			var pax_cap: int = route_fin.get("passenger_capacity", 0)
			var cargo_served: int = route_fin.get("cargo_served", 0)
			var cargo_cap: int = route_fin.get("cargo_capacity", 0)
			var revenue: float = route_fin.get("revenue", {}).get("total_revenue", 0.0)
			var op_cost: float = route_fin.get("operating_cost", 0.0)
			var profit: float = revenue - op_cost
			var profit_sign := "+" if profit >= 0.0 else ""
			var profit_color := ThemeBuilder.POSITIVE.to_html(false) if profit >= 0.0 else ThemeBuilder.NEGATIVE.to_html(false)
			metrics_rtl.text = "    %s %d/%d | %s %d/%d | Profit: [color=#%s]§%s%d[/color]" % [
				ThemeBuilder.pax_bb(), pax_served, pax_cap,
				ThemeBuilder.cargo_bb(), cargo_served, cargo_cap,
				profit_color, profit_sign, int(profit),
			]
		route_block.add_child(metrics_rtl)

		_content.add_child(route_block)


func _on_edit_route(route: CarrierData.Route) -> void:
	edit_route_requested.emit(route)


func _get_route_financials(carrier_id: String, route_id: String) -> Dictionary:
	if _game_state.last_turn_financials.is_empty():
		return {}
	var carrier_fin: Dictionary = _game_state.last_turn_financials.get(carrier_id, {})
	var routes: Array = carrier_fin.get("routes", [])
	for route_fin: Dictionary in routes:
		if route_fin.get("route_id", "") == route_id:
			return route_fin
	return {}


# ---------------------------------------------------------------------------
# Section 2: Pending Route Actions
# ---------------------------------------------------------------------------

func _build_pending_actions() -> void:
	var header := ThemeBuilder.make_section_header("Pending Actions")
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
		label.text = "Create: %s -> %s (%d ships)" % [
			origin_name, dest_name, rc["ship_ids"].size(),
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.pressed.connect(_on_remove_route_create.bind(i))
		row.add_child(cancel_btn)

		_content.add_child(row)

	# Pending modifications
	for i: int in range(intent.route_modifications.size()):
		has_any = true
		var rm: Dictionary = intent.route_modifications[i]
		var route_id: String = rm.get("route_id", "")
		var route_display := _resolve_route_display(route_id)
		var row := HBoxContainer.new()
		var rtl := ThemeBuilder.make_icon_label()
		rtl.text = "Modify: %s (%s §%d %s §%d Freq: %d)" % [
			route_display,
			ThemeBuilder.pax_bb(), int(rm.get("passenger_price", 0)),
			ThemeBuilder.cargo_bb(), int(rm.get("cargo_price", 0)), rm.get("frequency", 1),
		]
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rtl)

		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.pressed.connect(_on_remove_route_modification.bind(i))
		row.add_child(cancel_btn)

		_content.add_child(row)

	# Pending cancellations
	for i: int in range(intent.route_cancellations.size()):
		has_any = true
		var route_id: String = intent.route_cancellations[i]
		var route_display := _resolve_route_display(route_id)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "Cancel route: %s" % route_display
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


func _on_remove_route_modification(index: int) -> void:
	_player_controller.remove_route_modification(index)


func _resolve_route_display(route_id: String) -> String:
	var carrier := _game_state.get_player_carrier()
	if carrier:
		for route: CarrierData.Route in carrier.routes:
			if route.id == route_id:
				var origin := _game_state.galaxy.get_planet(route.origin_id)
				var dest := _game_state.galaxy.get_planet(route.dest_id)
				var origin_name: String = origin.name if origin else route.origin_id
				var dest_name: String = dest.name if dest else route.dest_id
				return "%s -> %s" % [origin_name, dest_name]
	return route_id


# ---------------------------------------------------------------------------
# Create Route Button
# ---------------------------------------------------------------------------

func _build_create_button() -> void:
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var create_btn := Button.new()
	create_btn.text = "Create Route"
	create_btn.pressed.connect(func() -> void: create_route_requested.emit())
	ThemeBuilder.style_primary_button(create_btn)

	btn_row.add_child(create_btn)
	_content.add_child(btn_row)
