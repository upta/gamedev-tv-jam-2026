class_name DashboardPanel
extends PanelContainer

## Carrier dashboard showing fleet, slots, routes, and score at a glance.

@onready var _header: Label = $MarginContainer/ScrollContainer/Content/DashboardHeader
@onready var _fleet_header: Label = $MarginContainer/ScrollContainer/Content/FleetHeader
@onready var _fleet_list: VBoxContainer = $MarginContainer/ScrollContainer/Content/FleetList
@onready var _slots_header: Label = $MarginContainer/ScrollContainer/Content/SlotsHeader
@onready var _slots_list: VBoxContainer = $MarginContainer/ScrollContainer/Content/SlotsList
@onready var _routes_header: Label = $MarginContainer/ScrollContainer/Content/RoutesHeader
@onready var _routes_list: VBoxContainer = $MarginContainer/ScrollContainer/Content/RoutesList

var _game_state: GameState
var _carrier_id: String


func bind(game_state: GameState, carrier_id: String) -> void:
	_game_state = game_state
	_carrier_id = carrier_id
	_style_section_headers()
	refresh()


func refresh() -> void:
	if _game_state == null or _carrier_id.is_empty():
		return
	_refresh_header()
	_refresh_fleet()
	_refresh_slots()
	_refresh_routes()


func _refresh_header() -> void:
	var carrier := _game_state.get_carrier(_carrier_id)
	if carrier == null:
		return
	_header.text = "%s | %s" % [carrier.carrier_name, FormatHelpers.format_cash(carrier.cash)]


func _refresh_fleet() -> void:
	_clear_children(_fleet_list)
	var carrier := _game_state.get_carrier(_carrier_id)
	if carrier == null:
		return

	# Build ship -> route assignment lookup
	var ship_route_map: Dictionary = {}
	for route: CarrierData.Route in carrier.routes:
		if route.active:
			for ship_id: String in route.ship_ids:
				var origin := _game_state.galaxy.get_planet(route.origin_id)
				var dest := _game_state.galaxy.get_planet(route.dest_id)
				var origin_name: String = origin.name if origin else route.origin_id
				var dest_name: String = dest.name if dest else route.dest_id
				ship_route_map[ship_id] = "%s → %s" % [origin_name, dest_name]

	for ship: ShipCatalog.ShipInstance in carrier.ships:
		var type_name := ship.type_id
		var ship_type := _game_state.catalog.get_type(ship.type_id)
		if ship_type != null:
			type_name = ship_type.name
		var assignment: String = ship_route_map.get(ship.id, "Idle")
		var rtl := ThemeBuilder.make_icon_label()
		rtl.text = "%s - %s%d %s%d - %s" % [
			type_name,
			ThemeBuilder.pax_bb(), ship.passenger_capacity,
			ThemeBuilder.cargo_bb(), ship.cargo_capacity,
			assignment,
		]
		_fleet_list.add_child(rtl)

	for order: ShipCatalog.ShipInstance in carrier.pending_orders:
		var order_type := _game_state.catalog.get_type(order.type_id)
		var order_name: String = order_type.name if order_type else order.type_id
		var label := Label.new()
		label.text = "(Building) %s - Available turn %d" % [order_name, order.available_turn + 1]
		_fleet_list.add_child(label)


func _refresh_slots() -> void:
	_clear_children(_slots_list)
	var carrier := _game_state.get_carrier(_carrier_id)
	if carrier == null:
		return

	for planet_id: String in carrier.slots:
		var count: int = carrier.slots[planet_id]
		var planet_name := planet_id
		var planet := _game_state.galaxy.get_planet(planet_id)
		if planet != null:
			planet_name = planet.name
		var label := Label.new()
		label.text = "%s: %d slots" % [planet_name, count]
		_slots_list.add_child(label)


func _refresh_routes() -> void:
	_clear_children(_routes_list)
	var carrier := _game_state.get_carrier(_carrier_id)
	if carrier == null:
		return

	for route: CarrierData.Route in carrier.routes:
		if not route.active:
			continue
		var origin_name := route.origin_id
		var dest_name := route.dest_id
		var origin := _game_state.galaxy.get_planet(route.origin_id)
		var dest := _game_state.galaxy.get_planet(route.dest_id)
		if origin != null:
			origin_name = origin.name
		if dest != null:
			dest_name = dest.name
		var rtl := ThemeBuilder.make_icon_label()
		rtl.text = "%s -> %s | %s §%d %s §%d | Ships: %d | Freq: %d" % [
			origin_name, dest_name,
			ThemeBuilder.pax_bb(), int(route.passenger_price),
			ThemeBuilder.cargo_bb(), int(route.cargo_price),
			route.ship_ids.size(), route.frequency,
		]
		_routes_list.add_child(rtl)


func _clear_children(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _style_section_headers() -> void:
	var font_heading = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	for lbl: Label in [_fleet_header, _slots_header, _routes_header]:
		lbl.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.uppercase = true
		if font_heading:
			lbl.add_theme_font_override("font", font_heading)
	_header.add_theme_color_override("font_color", ThemeBuilder.TEXT)
	if font_heading:
		_header.add_theme_font_override("font", font_heading)
