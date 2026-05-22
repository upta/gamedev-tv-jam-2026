class_name DemandData
extends Resource

## Demand tables for every (lane, direction) pair.
## Base demand varies by planet importance; modifiers default to 1.0 (events alter them later).


class DemandEntry:
	var lane_id: String
	var direction: String  # "forward" (origin→dest) or "reverse" (dest→origin)
	var base_demand_passenger: int
	var base_demand_cargo: int
	var modifier_passenger: float
	var modifier_cargo: float

	func _init(
		p_lane_id: String = "",
		p_direction: String = "forward",
		p_base_demand_passenger: int = 0,
		p_base_demand_cargo: int = 0,
		p_modifier_passenger: float = 1.0,
		p_modifier_cargo: float = 1.0,
	) -> void:
		lane_id = p_lane_id
		direction = p_direction
		base_demand_passenger = p_base_demand_passenger
		base_demand_cargo = p_base_demand_cargo
		modifier_passenger = p_modifier_passenger
		modifier_cargo = p_modifier_cargo


var entries: Array = []

var _entry_index: Dictionary = {}  # "lane_id::direction" -> DemandEntry


func _build_index() -> void:
	_entry_index.clear()
	for entry: DemandEntry in entries:
		_entry_index[_key(entry.lane_id, entry.direction)] = entry


func _key(lane_id: String, direction: String) -> String:
	return lane_id + "::" + direction


func get_entry(lane_id: String, direction: String) -> DemandEntry:
	return _entry_index.get(_key(lane_id, direction), null)


func get_effective_demand_passenger(lane_id: String, direction: String) -> int:
	var entry := get_entry(lane_id, direction)
	if entry == null:
		return 0
	return int(entry.base_demand_passenger * entry.modifier_passenger)


func get_effective_demand_cargo(lane_id: String, direction: String) -> int:
	var entry := get_entry(lane_id, direction)
	if entry == null:
		return 0
	return int(entry.base_demand_cargo * entry.modifier_cargo)


static func create_default_demand(galaxy: GalaxyData) -> DemandData:
	var data := DemandData.new()

	# Generate demand for ALL unique planet pairs (any-to-any connectivity).
	for i in range(galaxy.planets.size()):
		for j in range(i + 1, galaxy.planets.size()):
			var planet_a: GalaxyData.Planet = galaxy.planets[i]
			var planet_b: GalaxyData.Planet = galaxy.planets[j]
			var lane_id := GalaxyData.derive_lane_id(planet_a.id, planet_b.id)

			# Forward = alphabetically first → second
			var first_planet: GalaxyData.Planet
			var second_planet: GalaxyData.Planet
			if planet_a.id < planet_b.id:
				first_planet = planet_a
				second_planet = planet_b
			else:
				first_planet = planet_b
				second_planet = planet_a

			var fwd_pax := _demand_passenger(first_planet.total_slots, second_planet.total_slots)
			var fwd_cargo := _demand_cargo(first_planet.total_slots, second_planet.total_slots)
			var rev_pax := _demand_passenger(second_planet.total_slots, first_planet.total_slots)
			var rev_cargo := _demand_cargo(second_planet.total_slots, first_planet.total_slots)

			data.entries.append(DemandEntry.new(lane_id, "forward", fwd_pax, fwd_cargo))
			data.entries.append(DemandEntry.new(lane_id, "reverse", rev_pax, rev_cargo))

	data._build_index()
	return data


# Passengers are drawn toward popular destinations (high-slot planets).
static func _demand_passenger(origin_slots: int, dest_slots: int) -> int:
	return clampi(dest_slots * 8 + origin_slots * 2, 20, 100)


# Cargo originates from productive hubs (high-slot planets) and moves in higher volume.
static func _demand_cargo(origin_slots: int, dest_slots: int) -> int:
	return clampi(origin_slots * 18 + dest_slots * 6, 40, 250)
