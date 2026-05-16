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

	for lane: GalaxyData.Lane in galaxy.lanes:
		var origin := galaxy.get_planet(lane.origin_id)
		var dest := galaxy.get_planet(lane.dest_id)
		if origin == null or dest == null:
			continue

		# Passengers gravitate toward the destination; cargo flows from the origin.
		# Asymmetry between forward and reverse makes directional competition meaningful.
		var fwd_passenger := _demand_passenger(origin.total_slots, dest.total_slots)
		var fwd_cargo := _demand_cargo(origin.total_slots, dest.total_slots)
		var rev_passenger := _demand_passenger(dest.total_slots, origin.total_slots)
		var rev_cargo := _demand_cargo(dest.total_slots, origin.total_slots)

		data.entries.append(DemandEntry.new(lane.id, "forward", fwd_passenger, fwd_cargo))
		data.entries.append(DemandEntry.new(lane.id, "reverse", rev_passenger, rev_cargo))

	data._build_index()
	return data


# Passengers are drawn toward popular destinations (high-slot planets).
static func _demand_passenger(origin_slots: int, dest_slots: int) -> int:
	return clampi(dest_slots * 8 + origin_slots * 2, 20, 100)


# Cargo originates from productive hubs (high-slot planets).
static func _demand_cargo(origin_slots: int, dest_slots: int) -> int:
	return clampi(origin_slots * 6 + dest_slots * 2, 10, 80)
