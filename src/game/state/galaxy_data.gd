class_name GalaxyData
extends Resource

## Static topology of the galaxy — planets with 2D positions.
## Any planet can connect to any other; distances are Euclidean.
## Immutable after creation. Use create_default_galaxy() for the prototype map.


class Planet:
	var id: String
	var name: String
	var system: String
	var total_slots: int
	var position: Vector2

	func _init(p_id: String = "", p_name: String = "", p_system: String = "", p_total_slots: int = 4, p_position: Vector2 = Vector2.ZERO) -> void:
		id = p_id
		name = p_name
		system = p_system
		total_slots = p_total_slots
		position = p_position


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

var _planet_index: Dictionary = {}


func _build_indices() -> void:
	_planet_index.clear()
	for planet: Planet in planets:
		_planet_index[planet.id] = planet


func get_planet(id: String) -> Planet:
	return _planet_index.get(id, null)


func get_lane(origin_id: String, dest_id: String) -> Lane:
	var planet_a := get_planet(origin_id)
	var planet_b := get_planet(dest_id)
	if planet_a == null or planet_b == null:
		return null
	var distance := planet_a.position.distance_to(planet_b.position)
	var lane_id := derive_lane_id(origin_id, dest_id)
	return Lane.new(lane_id, origin_id, dest_id, distance)


func calculate_distance(planet_a_id: String, planet_b_id: String) -> float:
	var planet_a := get_planet(planet_a_id)
	var planet_b := get_planet(planet_b_id)
	if planet_a == null or planet_b == null:
		return -1.0
	return planet_a.position.distance_to(planet_b.position)


func get_distance(origin_id: String, dest_id: String) -> float:
	return calculate_distance(origin_id, dest_id)


static func derive_lane_id(planet_a_id: String, planet_b_id: String) -> String:
	var first: String
	var second: String
	if planet_a_id < planet_b_id:
		first = planet_a_id
		second = planet_b_id
	else:
		first = planet_b_id
		second = planet_a_id
	return first + "::" + second


static func create_default_galaxy() -> GalaxyData:
	var galaxy := GalaxyData.new()

	# --- Sol System (center ~0,0) ---
	galaxy.planets.append(Planet.new("earth", "Earth", "sol", 10, Vector2(0.0, 0.0)))
	galaxy.planets.append(Planet.new("mars", "Mars", "sol", 8, Vector2(1.2, -0.8)))
	galaxy.planets.append(Planet.new("titan", "Titan", "sol", 5, Vector2(-1.5, 1.5)))
	galaxy.planets.append(Planet.new("europa", "Europa", "sol", 4, Vector2(-0.5, -1.8)))

	# --- Alpha Centauri System (center ~8,3) ---
	galaxy.planets.append(Planet.new("proxima_b", "Proxima b", "alpha_centauri", 6, Vector2(7.0, 2.5)))
	galaxy.planets.append(Planet.new("centauri_prime", "Centauri Prime", "alpha_centauri", 9, Vector2(9.0, 3.5)))
	galaxy.planets.append(Planet.new("haven", "Haven", "alpha_centauri", 4, Vector2(8.0, 4.5)))

	# --- Wolf 359 System (center ~5,11) ---
	galaxy.planets.append(Planet.new("wolf_station", "Wolf Station", "wolf_359", 7, Vector2(4.5, 10.5)))
	galaxy.planets.append(Planet.new("forge", "Forge", "wolf_359", 5, Vector2(5.5, 11.5)))
	galaxy.planets.append(Planet.new("outpost", "Outpost", "wolf_359", 3, Vector2(5.0, 12.8)))

	# --- Tau Ceti System (center ~13,7) ---
	galaxy.planets.append(Planet.new("tau_haven", "Tau Haven", "tau_ceti", 6, Vector2(12.5, 6.5)))
	galaxy.planets.append(Planet.new("frosthold", "Frosthold", "tau_ceti", 3, Vector2(13.5, 7.5)))

	galaxy._build_indices()
	return galaxy
