class_name DashboardPanel
extends PanelContainer

## Carrier dashboard showing fleet, slots, routes, and score at a glance.

@onready var _header: Label = $MarginContainer/ScrollContainer/Content/DashboardHeader
@onready var _fleet_list: VBoxContainer = $MarginContainer/ScrollContainer/Content/FleetList
@onready var _slots_list: VBoxContainer = $MarginContainer/ScrollContainer/Content/SlotsList
@onready var _routes_list: VBoxContainer = $MarginContainer/ScrollContainer/Content/RoutesList

var _game_state: GameState
var _carrier_id: String


func bind(game_state: GameState, carrier_id: String) -> void:
	_game_state = game_state
	_carrier_id = carrier_id
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
	var score_data := ScoreCalculator.calculate_score(carrier, _game_state.catalog, _game_state.galaxy)
	var score: int = int(score_data["total"])
	_header.text = "%s | §%d | Score: %d" % [carrier.carrier_name, int(carrier.cash), score]


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
				ship_route_map[ship_id] = route.lane_id

	for ship: ShipCatalog.ShipInstance in carrier.ships:
		var type_name := ship.type_id
		var ship_type := _game_state.catalog.get_type(ship.type_id)
		if ship_type != null:
			type_name = ship_type.name
		var assignment: String = ship_route_map.get(ship.id, "Idle")
		var label := Label.new()
		label.text = "%s (%s) - Pax:%d Cargo:%d - %s" % [
			type_name, ship.type_id,
			ship.passenger_capacity, ship.cargo_capacity,
			assignment,
		]
		_fleet_list.add_child(label)

	for order: ShipCatalog.ShipInstance in carrier.pending_orders:
		var label := Label.new()
		label.text = "(Building) %s - Ready turn %d" % [order.type_id, order.available_turn]
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
		var label := Label.new()
		label.text = "%s → %s | Pax: §%d Cargo: §%d | Ships: %d | Freq: %d" % [
			origin_name, dest_name,
			int(route.passenger_price), int(route.cargo_price),
			route.ship_ids.size(), route.frequency,
		]
		_routes_list.add_child(label)


func _clear_children(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()
