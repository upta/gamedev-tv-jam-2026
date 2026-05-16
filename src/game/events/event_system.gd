class_name EventSystem
extends RefCounted

## Stub event system for Phase 1. Events are demand modifiers that affect
## lanes for a set number of turns. Phase 2 adds random event generation.


class GameEvent:
	var id: String
	var description: String
	var target_lane_id: String
	var target_planet_id: String
	var demand_type: String  # "passenger", "cargo", or "both"
	var modifier: float
	var duration_turns: int
	var remaining_turns: int

	func _init(
		p_id: String = "",
		p_description: String = "",
		p_target_lane_id: String = "",
		p_target_planet_id: String = "",
		p_demand_type: String = "both",
		p_modifier: float = 1.0,
		p_duration_turns: int = 1
	) -> void:
		id = p_id
		description = p_description
		target_lane_id = p_target_lane_id
		target_planet_id = p_target_planet_id
		demand_type = p_demand_type
		modifier = p_modifier
		duration_turns = p_duration_turns
		remaining_turns = p_duration_turns


## STUB: Returns empty array for Phase 1. Phase 2 adds random event generation.
static func generate_events(_turn: int, _galaxy: GalaxyData) -> Array:
	return []


## Resets all DemandEntry modifiers to 1.0, then applies active event modifiers.
## Expects demand_data to have an `entries` Array of objects with:
##   - lane_id: String
##   - passenger_modifier: float
##   - cargo_modifier: float
static func apply_events(active_events: Array, demand_data) -> void:
	if demand_data == null:
		return

	for entry in demand_data.entries:
		entry.passenger_modifier = 1.0
		entry.cargo_modifier = 1.0

	for event: GameEvent in active_events:
		for entry in demand_data.entries:
			var lane_matches: bool = event.target_lane_id == "" or entry.lane_id == event.target_lane_id
			if not lane_matches:
				continue

			if event.demand_type == "passenger" or event.demand_type == "both":
				entry.passenger_modifier *= event.modifier
			if event.demand_type == "cargo" or event.demand_type == "both":
				entry.cargo_modifier *= event.modifier


## Decrements remaining_turns on each event and removes expired ones.
static func tick_events(active_events: Array) -> Array:
	var still_active: Array = []
	for event: GameEvent in active_events:
		event.remaining_turns -= 1
		if event.remaining_turns > 0:
			still_active.append(event)
	return still_active


## Returns human-readable descriptions for the turn report.
static func get_active_event_descriptions(active_events: Array) -> Array:
	var descriptions: Array = []
	for event: GameEvent in active_events:
		var pct: int = roundi((event.modifier - 1.0) * 100.0)
		var sign: String = "+" if pct >= 0 else ""
		var type_label: String = event.demand_type + " demand"
		var desc: String = "%s — %s %s%d%% (%d turns remaining)" % [
			event.description, type_label, sign, pct, event.remaining_turns
		]
		descriptions.append(desc)
	return descriptions
