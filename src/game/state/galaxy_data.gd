class_name GalaxyData
extends Resource

## Static topology of the galaxy — planets and the lanes connecting them.
## Immutable after creation. Use create_default_galaxy() for the prototype map.


class Planet:
	var id: String
	var name: String
	var system: String
	var total_slots: int

	func _init(p_id: String = "", p_name: String = "", p_system: String = "", p_total_slots: int = 4) -> void:
		id = p_id
		name = p_name
		system = p_system
		total_slots = p_total_slots


class Lane:
	var id: String
	var origin_id: String
	var dest_id: String
	var distance: float

	func _init(p_id: String = "", p_origin_id: String = "", p_dest_id: String = "", p_distance: float = 1.0) -> void:
		id = p_id
		origin_id = p_origin_id
		dest_id = p_dest_id
		distance = p_distance


var planets: Array = []
var lanes: Array = []

var _planet_index: Dictionary = {}
var _lane_index: Dictionary = {}
var _lanes_from_index: Dictionary = {}


func _build_indices() -> void:
	_planet_index.clear()
	_lane_index.clear()
	_lanes_from_index.clear()

	for planet: Planet in planets:
		_planet_index[planet.id] = planet

	for lane: Lane in lanes:
		var key_fwd := _lane_key(lane.origin_id, lane.dest_id)
		var key_rev := _lane_key(lane.dest_id, lane.origin_id)
		_lane_index[key_fwd] = lane
		_lane_index[key_rev] = lane

		if not _lanes_from_index.has(lane.origin_id):
			_lanes_from_index[lane.origin_id] = []
		_lanes_from_index[lane.origin_id].append(lane)

		if not _lanes_from_index.has(lane.dest_id):
			_lanes_from_index[lane.dest_id] = []
		_lanes_from_index[lane.dest_id].append(lane)


func _lane_key(a: String, b: String) -> String:
	return a + "::" + b


func get_planet(id: String) -> Planet:
	return _planet_index.get(id, null)


func get_lane(origin_id: String, dest_id: String) -> Lane:
	return _lane_index.get(_lane_key(origin_id, dest_id), null)


func get_lanes_from(planet_id: String) -> Array:
	return _lanes_from_index.get(planet_id, [])


func get_distance(origin_id: String, dest_id: String) -> float:
	var lane := get_lane(origin_id, dest_id)
	if lane == null:
		return -1.0
	return lane.distance


static func create_default_galaxy() -> GalaxyData:
	var galaxy := GalaxyData.new()

	# --- Sol System (4 planets) ---
	galaxy.planets.append(Planet.new("earth", "Earth", "sol", 10))
	galaxy.planets.append(Planet.new("mars", "Mars", "sol", 8))
	galaxy.planets.append(Planet.new("titan", "Titan", "sol", 5))
	galaxy.planets.append(Planet.new("europa", "Europa", "sol", 4))

	# --- Alpha Centauri System (3 planets) ---
	galaxy.planets.append(Planet.new("proxima_b", "Proxima b", "alpha_centauri", 6))
	galaxy.planets.append(Planet.new("centauri_prime", "Centauri Prime", "alpha_centauri", 9))
	galaxy.planets.append(Planet.new("haven", "Haven", "alpha_centauri", 4))

	# --- Wolf 359 System (3 planets) ---
	galaxy.planets.append(Planet.new("wolf_station", "Wolf Station", "wolf_359", 7))
	galaxy.planets.append(Planet.new("forge", "Forge", "wolf_359", 5))
	galaxy.planets.append(Planet.new("outpost", "Outpost", "wolf_359", 3))

	# --- Tau Ceti System (2 planets) ---
	galaxy.planets.append(Planet.new("tau_haven", "Tau Haven", "tau_ceti", 6))
	galaxy.planets.append(Planet.new("frosthold", "Frosthold", "tau_ceti", 3))

	# --- Intra-system lanes (short, 1-3 distance) ---
	# Sol
	galaxy.lanes.append(Lane.new("sol_earth_mars", "earth", "mars", 1.5))
	galaxy.lanes.append(Lane.new("sol_earth_titan", "earth", "titan", 2.5))
	galaxy.lanes.append(Lane.new("sol_mars_europa", "mars", "europa", 2.0))
	galaxy.lanes.append(Lane.new("sol_titan_europa", "titan", "europa", 1.0))

	# Alpha Centauri
	galaxy.lanes.append(Lane.new("ac_proxima_centauri", "proxima_b", "centauri_prime", 2.0))
	galaxy.lanes.append(Lane.new("ac_centauri_haven", "centauri_prime", "haven", 1.5))

	# Wolf 359
	galaxy.lanes.append(Lane.new("w359_station_forge", "wolf_station", "forge", 1.0))
	galaxy.lanes.append(Lane.new("w359_forge_outpost", "forge", "outpost", 2.0))

	# Tau Ceti
	galaxy.lanes.append(Lane.new("tc_haven_frost", "tau_haven", "frosthold", 1.5))

	# --- Inter-system lanes (long, 5-15 distance) ---
	# Sol <-> Alpha Centauri (the closest real star systems)
	galaxy.lanes.append(Lane.new("inter_earth_proxima", "earth", "proxima_b", 8.0))
	galaxy.lanes.append(Lane.new("inter_mars_centauri", "mars", "centauri_prime", 9.0))

	# Sol <-> Wolf 359
	galaxy.lanes.append(Lane.new("inter_titan_wolf", "titan", "wolf_station", 12.0))

	# Alpha Centauri <-> Wolf 359
	galaxy.lanes.append(Lane.new("inter_haven_forge", "haven", "forge", 10.0))

	# Alpha Centauri <-> Tau Ceti
	galaxy.lanes.append(Lane.new("inter_centauri_tau", "centauri_prime", "tau_haven", 7.0))

	# Wolf 359 <-> Tau Ceti (long remote route)
	galaxy.lanes.append(Lane.new("inter_outpost_frost", "outpost", "frosthold", 14.0))

	galaxy._build_indices()
	return galaxy
