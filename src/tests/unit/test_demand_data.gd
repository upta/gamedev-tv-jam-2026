extends GutTest


func test_default_demand_gives_earth_mars_high_volume_cargo() -> void:
	var galaxy := GalaxyData.create_default_galaxy()
	var demand := DemandData.create_default_demand(galaxy)
	var entry := demand.get_entry("earth::mars", "forward")
	assert_not_null(entry, "earth::mars forward demand should exist")
	assert_eq(entry.base_demand_passenger, 84, "earth→mars passenger demand should stay destination-weighted")
	assert_eq(entry.base_demand_cargo, 228, "earth→mars cargo demand should reflect high-volume cargo formula")
	assert_gt(entry.base_demand_cargo, entry.base_demand_passenger, "cargo should exceed passenger demand on productive lanes")
