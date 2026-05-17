extends GutTest

# ---------------------------------------------------------------------------
# Factory tests — create_default_galaxy()
# ---------------------------------------------------------------------------

func test_default_galaxy_has_12_planets() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	assert_eq(galaxy.planets.size(), 12, "Default galaxy should have 12 planets")


func test_default_galaxy_has_15_lanes() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	assert_eq(galaxy.lanes.size(), 15, "Default galaxy should have 15 lanes")


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
	assert_almost_eq(
		galaxy.get_distance("earth", "mars"), 1.5, 0.001,
		"sol_earth_mars lane distance should be 1.5"
	)


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
# get_lane() — bidirectional lookup
# ---------------------------------------------------------------------------

func test_get_lane_forward_direction() -> void:
	var galaxy := _make_mini_galaxy()
	var lane := galaxy.get_lane("alpha", "beta")
	assert_not_null(lane, "Should find lane alpha -> beta")
	assert_eq(lane.id, "lane_ab")


func test_get_lane_reverse_direction() -> void:
	var galaxy := _make_mini_galaxy()
	var lane := galaxy.get_lane("beta", "alpha")
	assert_not_null(lane, "Reverse lookup beta -> alpha should work")
	assert_eq(lane.id, "lane_ab")


func test_get_lane_returns_null_for_nonexistent() -> void:
	var galaxy := _make_mini_galaxy()
	assert_null(galaxy.get_lane("alpha", "gamma"), "No direct lane should return null")


# ---------------------------------------------------------------------------
# get_lanes_from()
# ---------------------------------------------------------------------------

func test_get_lanes_from_returns_connected_lanes() -> void:
	var galaxy := _make_mini_galaxy()
	var lanes := galaxy.get_lanes_from("beta")
	assert_eq(lanes.size(), 2, "Beta connects to alpha and gamma")


func test_get_lanes_from_single_connection() -> void:
	var galaxy := _make_mini_galaxy()
	var lanes := galaxy.get_lanes_from("alpha")
	assert_eq(lanes.size(), 1, "Alpha connects only to beta")


func test_get_lanes_from_unknown_planet_returns_empty() -> void:
	var galaxy := _make_mini_galaxy()
	var lanes := galaxy.get_lanes_from("nonexistent")
	assert_eq(lanes.size(), 0, "Unknown planet should return empty array")


# ---------------------------------------------------------------------------
# get_distance()
# ---------------------------------------------------------------------------

func test_get_distance_returns_correct_value() -> void:
	var galaxy := _make_mini_galaxy()
	assert_almost_eq(galaxy.get_distance("alpha", "beta"), 3.0, 0.001, "Distance alpha-beta should be 3.0")


func test_get_distance_bidirectional() -> void:
	var galaxy := _make_mini_galaxy()
	assert_almost_eq(
		galaxy.get_distance("beta", "alpha"),
		galaxy.get_distance("alpha", "beta"),
		0.001,
		"Distance should be the same in both directions"
	)


func test_get_distance_returns_negative_for_no_lane() -> void:
	var galaxy := _make_mini_galaxy()
	assert_almost_eq(galaxy.get_distance("alpha", "gamma"), -1.0, 0.001, "Missing lane should return -1.0")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_empty_galaxy_returns_null_for_planet() -> void:
	var galaxy := GalaxyData.new()
	galaxy._build_indices()
	assert_null(galaxy.get_planet("anything"), "Empty galaxy has no planets")


func test_empty_galaxy_returns_empty_lanes() -> void:
	var galaxy := GalaxyData.new()
	galaxy._build_indices()
	assert_eq(galaxy.get_lanes_from("anything").size(), 0, "Empty galaxy has no lanes")


func test_planet_default_slots() -> void:
	var p := GalaxyData.Planet.new("test", "Test", "sys")
	assert_eq(p.total_slots, 4, "Default total_slots should be 4")


func test_lane_default_distance() -> void:
	var l := GalaxyData.Lane.new("test", "a", "b")
	assert_almost_eq(l.distance, 1.0, 0.001, "Default lane distance should be 1.0")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_mini_galaxy() -> GalaxyData:
	var galaxy := GalaxyData.new()
	galaxy.planets.append(GalaxyData.Planet.new("alpha", "Alpha", "sys", 4))
	galaxy.planets.append(GalaxyData.Planet.new("beta", "Beta", "sys", 6))
	galaxy.planets.append(GalaxyData.Planet.new("gamma", "Gamma", "sys", 3))
	galaxy.lanes.append(GalaxyData.Lane.new("lane_ab", "alpha", "beta", 3.0))
	galaxy.lanes.append(GalaxyData.Lane.new("lane_bg", "beta", "gamma", 5.0))
	galaxy._build_indices()
	return galaxy
