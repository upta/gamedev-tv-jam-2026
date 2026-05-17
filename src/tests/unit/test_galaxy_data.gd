extends GutTest

# ---------------------------------------------------------------------------
# Factory tests — create_default_galaxy()
# ---------------------------------------------------------------------------

func test_default_galaxy_has_12_planets() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	assert_eq(galaxy.planets.size(), 12, "Default galaxy should have 12 planets")


func test_default_galaxy_earth_has_10_slots() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	var earth := galaxy.get_planet("earth")
	assert_not_null(earth, "Earth should exist")
	assert_eq(earth.total_slots, 10, "Earth should have 10 total slots")


func test_default_galaxy_mars_has_8_slots() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	var mars := galaxy.get_planet("mars")
	assert_not_null(mars, "Mars should exist")
	assert_eq(mars.total_slots, 8, "Mars should have 8 total slots")


func test_default_galaxy_titan_has_5_slots() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	var titan := galaxy.get_planet("titan")
	assert_not_null(titan, "Titan should exist")
	assert_eq(titan.total_slots, 5, "Titan should have 5 total slots")


func test_default_galaxy_earth_mars_distance() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	var dist := galaxy.get_distance("earth", "mars")
	assert_true(dist > 0.0, "earth-mars distance should be positive")
	assert_true(dist < 3.0, "earth-mars should be intra-system (< 3 ly)")


# ---------------------------------------------------------------------------
# get_planet()
# ---------------------------------------------------------------------------

func test_get_planet_returns_correct_planet() -> void:
	var galaxy := _make_mini_galaxy()
	var p := galaxy.get_planet("alpha")
	assert_not_null(p, "Should find planet alpha")
	assert_eq(p.name, "Alpha", "Planet name should match")
	assert_eq(p.system, "sys", "Planet system should match")


func test_get_planet_returns_null_for_unknown_id() -> void:
	var galaxy := _make_mini_galaxy()
	assert_null(galaxy.get_planet("nonexistent"), "Unknown id should return null")


# ---------------------------------------------------------------------------
# get_lane() — dynamic creation
# ---------------------------------------------------------------------------

func test_get_lane_creates_lane_dynamically() -> void:
	var galaxy := _make_mini_galaxy()
	var lane := galaxy.get_lane("alpha", "beta")
	assert_not_null(lane, "Should create lane alpha -> beta")
	assert_true(lane.distance > 0.0, "Distance should be positive")


func test_get_lane_reverse_direction() -> void:
	var galaxy := _make_mini_galaxy()
	var lane_fwd := galaxy.get_lane("alpha", "beta")
	var lane_rev := galaxy.get_lane("beta", "alpha")
	assert_not_null(lane_rev, "Reverse lookup beta -> alpha should work")
	assert_almost_eq(lane_fwd.distance, lane_rev.distance, 0.001, "Distance should match in both directions")


func test_get_lane_returns_null_for_nonexistent_planet() -> void:
	var galaxy := _make_mini_galaxy()
	assert_null(galaxy.get_lane("alpha", "nonexistent"), "Unknown planet should return null")
	assert_null(galaxy.get_lane("nonexistent", "alpha"), "Unknown planet should return null")


func test_get_lane_dynamic_correct_distance() -> void:
	var galaxy := _make_mini_galaxy()
	var lane := galaxy.get_lane("alpha", "beta")
	# alpha at (0,0), beta at (3,4) -> distance = 5.0
	assert_almost_eq(lane.distance, 5.0, 0.001, "Euclidean distance should be 5.0")


# ---------------------------------------------------------------------------
# calculate_distance()
# ---------------------------------------------------------------------------

func test_calculate_distance_returns_correct_value() -> void:
	var galaxy := _make_mini_galaxy()
	# alpha at (0,0), beta at (3,4) -> distance = 5.0
	assert_almost_eq(galaxy.calculate_distance("alpha", "beta"), 5.0, 0.001, "Distance alpha-beta should be 5.0")


func test_calculate_distance_bidirectional() -> void:
	var galaxy := _make_mini_galaxy()
	assert_almost_eq(
		galaxy.calculate_distance("beta", "alpha"),
		galaxy.calculate_distance("alpha", "beta"),
		0.001,
		"Distance should be the same in both directions"
	)


func test_calculate_distance_returns_negative_for_unknown_planet() -> void:
	var galaxy := _make_mini_galaxy()
	assert_almost_eq(galaxy.calculate_distance("alpha", "nonexistent"), -1.0, 0.001, "Unknown planet should return -1.0")


# ---------------------------------------------------------------------------
# get_distance()
# ---------------------------------------------------------------------------

func test_get_distance_returns_correct_value() -> void:
	var galaxy := _make_mini_galaxy()
	assert_almost_eq(galaxy.get_distance("alpha", "beta"), 5.0, 0.001, "Distance alpha-beta should be 5.0")


func test_get_distance_bidirectional() -> void:
	var galaxy := _make_mini_galaxy()
	assert_almost_eq(
		galaxy.get_distance("beta", "alpha"),
		galaxy.get_distance("alpha", "beta"),
		0.001,
		"Distance should be the same in both directions"
	)


func test_get_distance_returns_negative_for_unknown_planet() -> void:
	var galaxy := _make_mini_galaxy()
	assert_almost_eq(galaxy.get_distance("alpha", "nonexistent"), -1.0, 0.001, "Unknown planet should return -1.0")


# ---------------------------------------------------------------------------
# derive_lane_id()
# ---------------------------------------------------------------------------

func test_derive_lane_id_alphabetical_order() -> void:
	assert_eq(GalaxyData.derive_lane_id("earth", "mars"), "earth::mars")
	assert_eq(GalaxyData.derive_lane_id("mars", "earth"), "earth::mars")


func test_derive_lane_id_same_both_directions() -> void:
	var id1 := GalaxyData.derive_lane_id("alpha", "beta")
	var id2 := GalaxyData.derive_lane_id("beta", "alpha")
	assert_eq(id1, id2, "Both directions should produce same lane_id")


func test_derive_lane_id_format() -> void:
	var id := GalaxyData.derive_lane_id("proxima_b", "centauri_prime")
	assert_eq(id, "centauri_prime::proxima_b", "Should be alphabetically sorted with :: separator")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_empty_galaxy_returns_null_for_planet() -> void:
	var galaxy := GalaxyData.new()
	galaxy._build_indices()
	assert_null(galaxy.get_planet("anything"), "Empty galaxy has no planets")


func test_planet_default_slots() -> void:
	var p := GalaxyData.Planet.new("test", "Test", "sys")
	assert_eq(p.total_slots, 4, "Default total_slots should be 4")


func test_planet_default_position() -> void:
	var p := GalaxyData.Planet.new("test", "Test", "sys")
	assert_eq(p.position, Vector2.ZERO, "Default position should be Vector2.ZERO")


func test_lane_default_distance() -> void:
	var l := GalaxyData.Lane.new("test", "a", "b")
	assert_almost_eq(l.distance, 1.0, 0.001, "Default lane distance should be 1.0")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_mini_galaxy() -> GalaxyData:
	var galaxy := GalaxyData.new()
	galaxy.planets.append(GalaxyData.Planet.new("alpha", "Alpha", "sys", 4, Vector2(0.0, 0.0)))
	galaxy.planets.append(GalaxyData.Planet.new("beta", "Beta", "sys", 6, Vector2(3.0, 4.0)))
	galaxy.planets.append(GalaxyData.Planet.new("gamma", "Gamma", "sys", 3, Vector2(10.0, 0.0)))
	galaxy._build_indices()
	return galaxy
