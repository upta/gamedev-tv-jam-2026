class_name ShipCatalog
extends Resource

## Ship type definitions and ship instance factory.
## Ship types define blueprints; ship instances are concrete ships owned by carriers.

var _types: Dictionary = {} # id -> ShipType
var _next_instance_id: int = 0


class ShipType:
	var id: String
	var name: String
	var manufacturer: String
	var range: float
	var max_capacity: int
	var efficiency: float
	var cost: int
	var build_turns: int
	var unlock_turn: int

	func get_efficiency_rating() -> String:
		if efficiency >= 1.0: return "A"
		if efficiency >= 0.7: return "B"
		if efficiency >= 0.5: return "C"
		if efficiency >= 0.35: return "D"
		return "E"

	func _init(
		p_id: String = "",
		p_name: String = "",
		p_manufacturer: String = "",
		p_range: float = 0.0,
		p_max_capacity: int = 0,
		p_efficiency: float = 0.0,
		p_cost: int = 0,
		p_build_turns: int = 0,
		p_unlock_turn: int = 0,
	) -> void:
		id = p_id
		name = p_name
		manufacturer = p_manufacturer
		range = p_range
		max_capacity = p_max_capacity
		efficiency = p_efficiency
		cost = p_cost
		build_turns = p_build_turns
		unlock_turn = p_unlock_turn


class ShipInstance:
	var id: String
	var type_id: String
	var passenger_capacity: int
	var cargo_capacity: int
	var owner_id: String
	var available_turn: int

	func _init(
		p_id: String = "",
		p_type_id: String = "",
		p_passenger_capacity: int = 0,
		p_cargo_capacity: int = 0,
		p_owner_id: String = "",
		p_available_turn: int = 0,
	) -> void:
		id = p_id
		type_id = p_type_id
		passenger_capacity = p_passenger_capacity
		cargo_capacity = p_cargo_capacity
		owner_id = p_owner_id
		available_turn = p_available_turn


func add_type(ship_type: ShipType) -> void:
	_types[ship_type.id] = ship_type


func get_type(id: String) -> ShipType:
	if not _types.has(id):
		push_error("ShipCatalog: unknown ship type '%s'" % id)
		return null
	return _types[id]


func get_available_types(turn: int) -> Array[ShipType]:
	var result: Array[ShipType] = []
	for ship_type: ShipType in _types.values():
		if ship_type.unlock_turn <= turn:
			result.append(ship_type)
	return result


func create_ship_instance(
	type_id: String,
	passenger_capacity: int,
	cargo_capacity: int,
	owner_id: String,
	current_turn: int,
) -> ShipInstance:
	var ship_type := get_type(type_id)
	if ship_type == null:
		return null

	var total := passenger_capacity + cargo_capacity
	if total != ship_type.max_capacity:
		push_error(
			"ShipCatalog: capacity split (%d + %d = %d) must equal max_capacity (%d) for type '%s'"
			% [passenger_capacity, cargo_capacity, total, ship_type.max_capacity, type_id]
		)
		return null

	var instance := ShipInstance.new(
		_generate_instance_id(type_id),
		type_id,
		passenger_capacity,
		cargo_capacity,
		owner_id,
		current_turn + ship_type.build_turns - 1,
	)
	return instance


func _generate_instance_id(type_id: String) -> String:
	_next_instance_id += 1
	return "%s-%04d" % [type_id, _next_instance_id]


static func create_default_catalog() -> ShipCatalog:
	var catalog := ShipCatalog.new()

	# Sol Dynamics — reliable, balanced
	catalog.add_type(ShipType.new("sd-100", "Shuttle SD-100", "Sol Dynamics", 5.0, 40, 0.8, 500, 2, 0))
	catalog.add_type(ShipType.new("sd-300", "Freighter SD-300", "Sol Dynamics", 8.0, 80, 0.5, 1200, 3, 0))
	catalog.add_type(ShipType.new("sd-500", "Cruiser SD-500", "Sol Dynamics", 12.0, 120, 0.6, 2000, 4, 8))
	catalog.add_type(ShipType.new("sd-900", "Titan SD-900", "Sol Dynamics", 15.0, 200, 0.4, 4000, 5, 20))

	# Frontier Works — specialized, extreme stats
	catalog.add_type(ShipType.new("fw-10", "Scout FW-10", "Frontier Works", 10.0, 20, 0.6, 250, 2, 0))
	catalog.add_type(ShipType.new("fw-50", "Hauler FW-50", "Frontier Works", 6.0, 150, 0.3, 1800, 4, 12))
	catalog.add_type(ShipType.new("fw-70", "Express FW-70", "Frontier Works", 10.0, 60, 1.2, 1500, 3, 16))

	return catalog
