class_name CarrierData
extends Resource

## Carrier state resource — owns routes, ships, slots, and cash.
## Symmetric: player and NPCs use identical CarrierData (D002).


class Route:
	var id: String
	var lane_id: String
	var origin_id: String
	var dest_id: String
	var ship_ids: Array[String]
	var passenger_price: float
	var cargo_price: float
	var frequency: int
	var active: bool

	func _init(
		p_id: String = "",
		p_lane_id: String = "",
		p_origin_id: String = "",
		p_dest_id: String = "",
		p_ship_ids: Array[String] = [],
		p_passenger_price: float = 0.0,
		p_cargo_price: float = 0.0,
		p_frequency: int = 1,
		p_active: bool = true
	) -> void:
		id = p_id
		lane_id = p_lane_id
		origin_id = p_origin_id
		dest_id = p_dest_id
		ship_ids = p_ship_ids
		passenger_price = p_passenger_price
		cargo_price = p_cargo_price
		frequency = p_frequency
		active = p_active


## Lightweight ship reference — mirrors ship_catalog.gd's ShipInstance fields.
## P1.4 (GameState) will unify types; until then this avoids a hard dependency.
class ShipRef:
	var id: String
	var type_id: String
	var name: String
	var available_turn: int  # 0 = already delivered

	func _init(
		p_id: String = "",
		p_type_id: String = "",
		p_name: String = "",
		p_available_turn: int = 0
	) -> void:
		id = p_id
		type_id = p_type_id
		name = p_name
		available_turn = p_available_turn


@export var id: String
@export var carrier_name: String  # "name" shadows Object.name
@export var cash: float

var slots: Dictionary = {}        # { planet_id: String -> count: int }
var ships: Array = []             # Array of ShipRef
var routes: Array = []            # Array of Route
var pending_orders: Array = []    # ShipRefs with available_turn > current turn


func get_slot_count(planet_id: String) -> int:
	if slots.has(planet_id):
		return slots[planet_id]
	return 0


func has_slots_at(planet_id: String) -> bool:
	return get_slot_count(planet_id) > 0


func get_routes() -> Array:
	return routes


func get_active_routes() -> Array:
	var result: Array = []
	for route: Route in routes:
		if route.active:
			result.append(route)
	return result


func get_available_ships() -> Array:
	var assigned_ids: Dictionary = {}
	for route: Route in routes:
		if route.active:
			for ship_id: String in route.ship_ids:
				assigned_ids[ship_id] = true

	var available: Array = []
	for ship: ShipRef in ships:
		if not assigned_ids.has(ship.id):
			available.append(ship)
	return available


func total_ship_count() -> int:
	return ships.size() + pending_orders.size()


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

static func create_default_carriers() -> Array:
	var carriers: Array = []

	var defs: Array = [
		{ "id": "player", "name": "Player Corp",
		  "planets": ["earth", "mars"], "ship_name": "PC-001" },
		{ "id": "npc_1", "name": "Nova Transit",
		  "planets": ["proxima_b", "haven"], "ship_name": "NT-001" },
		{ "id": "npc_2", "name": "Stellar Lines",
		  "planets": ["titan", "europa"], "ship_name": "SL-001" },
		{ "id": "npc_3", "name": "Frontier Express",
		  "planets": ["wolf_station", "forge"], "ship_name": "FE-001" },
	]

	for def_data: Dictionary in defs:
		var carrier := CarrierData.new()
		carrier.id = def_data["id"]
		carrier.carrier_name = def_data["name"]
		carrier.cash = 3000.0

		# 2 slots on different planets
		for planet_id: String in def_data["planets"]:
			carrier.slots[planet_id] = 1

		# 1 starting ship (already delivered)
		var ship := ShipRef.new(
			def_data["id"] + "_ship_1",
			"basic",
			def_data["ship_name"],
			0
		)
		carrier.ships.append(ship)

		carriers.append(carrier)

	return carriers
