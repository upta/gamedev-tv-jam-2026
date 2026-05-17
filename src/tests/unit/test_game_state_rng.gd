extends GutTest

## Tests for GameState RNG integration (P2.7)


func _create_game_state(seed: int = 0) -> GameState:
	var gs := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	gs.initialize(galaxy, catalog, carriers, seed)
	return gs


func test_rng_exists_after_initialize() -> void:
	var gs := _create_game_state()
	assert_not_null(gs.rng)
	assert_is(gs.rng, RandomNumberGenerator)


func test_rng_with_explicit_seed() -> void:
	var gs := _create_game_state(42)
	assert_eq(gs.rng.seed, 42)


func test_rng_with_zero_seed_gets_random() -> void:
	var gs := _create_game_state(0)
	assert_not_null(gs.rng)
	# Seed should be set (non-zero after randi)
	# We just verify it exists and produces values
	var val := gs.rng.randf()
	assert_true(val >= 0.0 and val <= 1.0)


func test_deterministic_with_same_seed() -> void:
	var gs1 := _create_game_state(12345)
	var gs2 := _create_game_state(12345)
	var values1: Array = []
	var values2: Array = []
	for i in range(10):
		values1.append(gs1.rng.randf())
		values2.append(gs2.rng.randf())
	assert_eq(values1, values2)


func test_different_seeds_produce_different_values() -> void:
	var gs1 := _create_game_state(111)
	var gs2 := _create_game_state(222)
	var same_count := 0
	for i in range(10):
		if gs1.rng.randf() == gs2.rng.randf():
			same_count += 1
	# Extremely unlikely all 10 match with different seeds
	assert_true(same_count < 10)


func test_initialize_without_seed_still_works() -> void:
	# Test backward compatibility — calling without seed parameter
	var gs := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	gs.initialize(galaxy, catalog, carriers)
	assert_not_null(gs.rng)
