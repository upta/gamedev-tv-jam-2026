extends GutTest

## Tests for EventSystem event generation (P2.4)

var galaxy: GalaxyData
var rng: RandomNumberGenerator


func before_each() -> void:
	galaxy = GalaxyData.create_default_galaxy()
	rng = RandomNumberGenerator.new()
	rng.seed = 42


func test_no_events_before_turn_3() -> void:
	var events := EventSystem.generate_events(1, galaxy, rng, [])
	assert_eq(events.size(), 0)
	events = EventSystem.generate_events(2, galaxy, rng, [])
	assert_eq(events.size(), 0)


func test_max_2_active_events() -> void:
	var existing: Array = [
		EventSystem.GameEvent.new("e1", "test1", "sol_earth_mars", "", "both", 1.3, 2),
		EventSystem.GameEvent.new("e2", "test2", "sol_earth_mars", "", "both", 0.7, 2),
	]
	# With 2 already active, should never generate more regardless of RNG
	for i in range(100):
		rng.seed = i
		var events := EventSystem.generate_events(10, galaxy, rng, existing)
		assert_eq(events.size(), 0, "Should not generate events when 2 already active")


func test_generates_events_with_favorable_rng() -> void:
	# Find a seed that triggers event generation (probability is 25%)
	var generated: Array = []
	for seed_val in range(1, 100):
		rng.seed = seed_val
		var events := EventSystem.generate_events(5, galaxy, rng, [])
		if events.size() > 0:
			generated = events
			break
	assert_true(generated.size() > 0, "Should eventually generate an event with some seed")


func test_generated_event_has_valid_structure() -> void:
	# Find a seed that generates
	var event: EventSystem.GameEvent = null
	for seed_val in range(1, 200):
		rng.seed = seed_val
		var events := EventSystem.generate_events(5, galaxy, rng, [])
		if events.size() > 0:
			event = events[0]
			break
	assert_not_null(event, "Should find a seed that generates an event")
	if event == null:
		return
	assert_true(event.id != "", "Event should have an ID")
	assert_true(event.description != "", "Event should have a description")
	assert_true(event.modifier != 1.0, "Event should have a non-1.0 modifier")
	assert_true(event.duration_turns >= 2, "Event should last at least 2 turns")
	assert_true(event.remaining_turns == event.duration_turns, "Remaining should equal duration initially")


func test_null_rng_returns_empty() -> void:
	var events := EventSystem.generate_events(5, galaxy, null, [])
	assert_eq(events.size(), 0)


func test_planet_targeted_event_affects_connected_lanes() -> void:
	# Create a planet-targeted event for "earth"
	var event := EventSystem.GameEvent.new(
		"test_planet", "Gold Rush on Earth", "", "earth", "cargo", 1.5, 3
	)
	var demand := DemandData.create_default_demand(galaxy)

	# Apply — planet matching now uses lane_id format "planet_a::planet_b"
	EventSystem.apply_events([event], demand)

	# Earth lanes use derived IDs: "earth::mars", "earth::titan", "earth::proxima_b"
	var earth_mars := demand.get_entry("earth::mars", "forward")
	assert_not_null(earth_mars, "earth::mars demand entry should exist")
	assert_ne(earth_mars.modifier_cargo, 1.0, "Earth lane should be affected")

	var earth_titan := demand.get_entry("earth::titan", "forward")
	assert_not_null(earth_titan, "earth::titan demand entry should exist")
	assert_ne(earth_titan.modifier_cargo, 1.0, "Earth lane should be affected")

	# Europa-Mars should NOT be affected (doesn't touch earth)
	var europa_mars := demand.get_entry("europa::mars", "forward")
	assert_not_null(europa_mars, "europa::mars demand entry should exist")
	assert_eq(europa_mars.modifier_cargo, 1.0, "Non-earth lane should not be affected")


func test_lane_targeted_event_only_affects_that_lane() -> void:
	var event := EventSystem.GameEvent.new(
		"test_lane", "Demand Surge", "earth::mars", "", "both", 1.4, 2
	)
	var demand := DemandData.create_default_demand(galaxy)
	EventSystem.apply_events([event], demand)

	var target := demand.get_entry("earth::mars", "forward")
	assert_eq(target.modifier_passenger, 1.4)
	assert_eq(target.modifier_cargo, 1.4)

	var other := demand.get_entry("earth::titan", "forward")
	assert_eq(other.modifier_passenger, 1.0)
	assert_eq(other.modifier_cargo, 1.0)


func test_deterministic_with_same_seed() -> void:
	rng.seed = 99
	var events1 := EventSystem.generate_events(5, galaxy, rng, [])
	rng.seed = 99
	var events2 := EventSystem.generate_events(5, galaxy, rng, [])
	assert_eq(events1.size(), events2.size())
	for i in range(events1.size()):
		assert_eq(events1[i].id, events2[i].id)
		assert_eq(events1[i].modifier, events2[i].modifier)
