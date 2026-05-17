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


## Generates random events based on probability and game state.
## Returns empty array if rng is null (backward compatibility with Phase 1).
static func generate_events(turn: int, galaxy: GalaxyData, rng: RandomNumberGenerator, active_events: Array) -> Array:
	if rng == null:
		return []
	if turn < 3:
		return []
	if active_events.size() >= 2:
		return []
	if rng.randf() >= 0.25:
		return []

	var event_type: int = rng.randi_range(0, 3)
	var event: GameEvent = null

	match event_type:
		0:  # Demand Surge — random lane, modifier 1.3–1.5, 2-4 turns
			var lane: GalaxyData.Lane = galaxy.lanes[rng.randi_range(0, galaxy.lanes.size() - 1)]
			var modifier: float = rng.randf_range(1.3, 1.5)
			var duration: int = rng.randi_range(2, 4)
			event = GameEvent.new(
				"event_turn_%d_0" % turn,
				"Demand Surge on %s" % lane.id,
				lane.id, "", "both", modifier, duration
			)
		1:  # Demand Slump — random lane, modifier 0.6–0.8, 2-3 turns
			var lane: GalaxyData.Lane = galaxy.lanes[rng.randi_range(0, galaxy.lanes.size() - 1)]
			var modifier: float = rng.randf_range(0.6, 0.8)
			var duration: int = rng.randi_range(2, 3)
			event = GameEvent.new(
				"event_turn_%d_0" % turn,
				"Demand Slump on %s" % lane.id,
				lane.id, "", "both", modifier, duration
			)
		2:  # Gold Rush — random planet, modifier 1.5, 3 turns, cargo only
			var planet: GalaxyData.Planet = galaxy.planets[rng.randi_range(0, galaxy.planets.size() - 1)]
			event = GameEvent.new(
				"event_turn_%d_0" % turn,
				"Gold Rush on %s" % planet.name,
				"", planet.id, "cargo", 1.5, 3
			)
		3:  # Tourism Boom — random planet, modifier 1.4, 3 turns, passenger only
			var planet: GalaxyData.Planet = galaxy.planets[rng.randi_range(0, galaxy.planets.size() - 1)]
			event = GameEvent.new(
				"event_turn_%d_0" % turn,
				"Tourism Boom on %s" % planet.name,
				"", planet.id, "passenger", 1.4, 3
			)

	if event != null:
		return [event]
	return []


## Resets all DemandEntry modifiers to 1.0, then applies active event modifiers.
## Pass galaxy to enable planet-targeted event matching.
static func apply_events(active_events: Array, demand_data: DemandData, galaxy: GalaxyData = null) -> void:
	if demand_data == null:
		return

	for entry: DemandData.DemandEntry in demand_data.entries:
		entry.modifier_passenger = 1.0
		entry.modifier_cargo = 1.0

	for event: GameEvent in active_events:
		for entry: DemandData.DemandEntry in demand_data.entries:
			var matches: bool = false

			# Lane-targeted matching
			if event.target_lane_id != "":
				matches = entry.lane_id == event.target_lane_id
			# Planet-targeted matching
			elif event.target_planet_id != "" and galaxy != null:
				var lane: GalaxyData.Lane = null
				for l: GalaxyData.Lane in galaxy.lanes:
					if l.id == entry.lane_id:
						lane = l
						break
				if lane != null:
					matches = lane.origin_id == event.target_planet_id or lane.dest_id == event.target_planet_id
			# No target — affects all lanes
			elif event.target_lane_id == "" and event.target_planet_id == "":
				matches = true

			if not matches:
				continue

			if event.demand_type == "passenger" or event.demand_type == "both":
				entry.modifier_passenger *= event.modifier
			if event.demand_type == "cargo" or event.demand_type == "both":
				entry.modifier_cargo *= event.modifier


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
