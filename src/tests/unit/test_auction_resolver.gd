extends GutTest

## Unit tests for AuctionResolver — blind slot auctions and slot sales.

var galaxy: GalaxyData
var catalog: ShipCatalog


func before_each() -> void:
	galaxy = GalaxyData.new()
	galaxy.planets.append(GalaxyData.Planet.new("earth", "Earth", "sol", 10, Vector2(0.0, 0.0)))
	galaxy.planets.append(GalaxyData.Planet.new("mars", "Mars", "sol", 8, Vector2(1.2, -0.8)))
	galaxy._build_indices()

	catalog = ShipCatalog.create_default_catalog()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_carrier(id: String, cash: float = 5000.0) -> CarrierData:
	var c := CarrierData.new()
	c.id = id
	c.carrier_name = id.capitalize()
	c.cash = cash
	return c


func _make_bid(carrier_id: String, planet_id: String, quantity: int, price: float) -> Dictionary:
	return {
		"carrier_id": carrier_id,
		"planet_id": planet_id,
		"quantity": quantity,
		"price_per_slot": price,
	}


func _add_active_route(carrier: CarrierData, origin: String, dest: String) -> CarrierData.Route:
	var ship := catalog.create_ship_instance("sd-100", 20, 20, carrier.id, -2)
	carrier.ships.append(ship)
	var ship_ids: Array[String] = [ship.id]
	var route := CarrierData.Route.new(
		"route_%d" % carrier.routes.size(),
		origin,
		dest,
		ship_ids,
		10.0,
		5.0,
		1,
		true,
	)
	carrier.routes.append(route)
	return route


# ---------------------------------------------------------------------------
# get_available_slots
# ---------------------------------------------------------------------------

func test_available_slots_empty_planet() -> void:
	var result := AuctionResolver.get_available_slots("earth", galaxy, [])
	assert_eq(result, 10, "all 10 slots available when no carriers")


func test_available_slots_with_occupied() -> void:
	var c := _make_carrier("c1")
	c.slots["earth"] = 3

	var result := AuctionResolver.get_available_slots("earth", galaxy, [c])
	assert_eq(result, 7, "10 - 3 = 7")


func test_available_slots_multiple_carriers() -> void:
	var c1 := _make_carrier("c1")
	c1.slots["earth"] = 4
	var c2 := _make_carrier("c2")
	c2.slots["earth"] = 2

	var result := AuctionResolver.get_available_slots("earth", galaxy, [c1, c2])
	assert_eq(result, 4, "10 - 4 - 2 = 4")


func test_available_slots_nonexistent_planet() -> void:
	var result := AuctionResolver.get_available_slots("pluto", galaxy, [])
	assert_eq(result, 0, "unknown planet → 0")


func test_available_slots_fully_occupied() -> void:
	var c := _make_carrier("c1")
	c.slots["mars"] = 8

	var result := AuctionResolver.get_available_slots("mars", galaxy, [c])
	assert_eq(result, 0, "fully occupied")


# ---------------------------------------------------------------------------
# resolve_auctions — basic awards
# ---------------------------------------------------------------------------

func test_single_bid_awarded() -> void:
	var c := _make_carrier("c1", 5000.0)
	var bids := [_make_bid("c1", "earth", 2, 100.0)]

	var result := AuctionResolver.resolve_auctions(bids, galaxy, [c], ["c1"])
	assert_eq(result["awards"].size(), 1, "one award")
	assert_eq(result["rejections"].size(), 0, "no rejections")
	assert_eq(result["awards"][0]["slots_won"], 2, "got 2 slots")
	assert_almost_eq(result["awards"][0]["cost"], 200.0, 0.01, "2 × 100")


func test_higher_bid_wins_over_lower() -> void:
	var c1 := _make_carrier("high_bidder", 5000.0)
	var c2 := _make_carrier("low_bidder", 5000.0)

	# Mars has 8 slots. Both want 5 — only one can get all 5.
	var bids := [
		_make_bid("low_bidder", "mars", 5, 50.0),
		_make_bid("high_bidder", "mars", 5, 100.0),
	]

	var result := AuctionResolver.resolve_auctions(bids, galaxy, [c1, c2], ["high_bidder", "low_bidder"])
	var awards: Array = result["awards"]
	assert_eq(awards.size(), 2, "both get some slots")

	# high_bidder gets first pick (5 slots), low_bidder gets remaining 3
	var high_award: Dictionary = awards[0] if awards[0]["carrier_id"] == "high_bidder" else awards[1]
	var low_award: Dictionary = awards[1] if awards[1]["carrier_id"] != "high_bidder" else awards[0]
	assert_eq(high_award["slots_won"], 5, "high bidder gets full request")
	assert_eq(low_award["slots_won"], 3, "low bidder gets remainder")


func test_tie_broken_by_carrier_order() -> void:
	var c1 := _make_carrier("first_in_order", 5000.0)
	var c2 := _make_carrier("second_in_order", 5000.0)

	# Same price — carrier_order decides
	var bids := [
		_make_bid("second_in_order", "mars", 5, 100.0),
		_make_bid("first_in_order", "mars", 5, 100.0),
	]
	var carrier_order := ["first_in_order", "second_in_order"]

	var result := AuctionResolver.resolve_auctions(bids, galaxy, [c1, c2], carrier_order)
	var awards: Array = result["awards"]
	assert_eq(awards.size(), 2, "both awarded")

	# first_in_order should get priority
	var first_award: Dictionary
	var second_award: Dictionary
	for award: Dictionary in awards:
		if award["carrier_id"] == "first_in_order":
			first_award = award
		else:
			second_award = award
	assert_eq(first_award["slots_won"], 5, "first in order gets full request")
	assert_eq(second_award["slots_won"], 3, "second gets remainder")


# ---------------------------------------------------------------------------
# resolve_auctions — rejections
# ---------------------------------------------------------------------------

func test_insufficient_funds_rejected() -> void:
	var c := _make_carrier("broke", 10.0)
	var bids := [_make_bid("broke", "earth", 2, 100.0)]

	var result := AuctionResolver.resolve_auctions(bids, galaxy, [c], ["broke"])
	assert_eq(result["awards"].size(), 0, "no awards")
	assert_eq(result["rejections"].size(), 1, "one rejection")
	assert_eq(result["rejections"][0]["reason"], "Insufficient funds")


func test_no_slots_available_rejected() -> void:
	var occupier := _make_carrier("occupier")
	occupier.slots["mars"] = 8  # fills all 8 mars slots
	var bidder := _make_carrier("bidder", 5000.0)

	var bids := [_make_bid("bidder", "mars", 1, 100.0)]

	var result := AuctionResolver.resolve_auctions(bids, galaxy, [occupier, bidder], ["bidder"])
	assert_eq(result["awards"].size(), 0, "no awards")
	assert_eq(result["rejections"].size(), 1, "rejected")
	assert_eq(result["rejections"][0]["reason"], "No slots available")


func test_unknown_carrier_rejected() -> void:
	var bids := [_make_bid("ghost", "earth", 1, 100.0)]

	var result := AuctionResolver.resolve_auctions(bids, galaxy, [], ["ghost"])
	assert_eq(result["rejections"].size(), 1, "rejected")
	assert_eq(result["rejections"][0]["reason"], "Carrier not found")


func test_partial_award_when_limited_slots() -> void:
	var c := _make_carrier("c1", 5000.0)
	c.slots["mars"] = 6  # occupies 6 of 8

	var bidder := _make_carrier("bidder", 5000.0)
	var bids := [_make_bid("bidder", "mars", 5, 100.0)]

	var result := AuctionResolver.resolve_auctions(bids, galaxy, [c, bidder], ["bidder"])
	assert_eq(result["awards"].size(), 1, "partial award given")
	assert_eq(result["awards"][0]["slots_won"], 2, "only 2 remaining slots awarded")
	assert_almost_eq(result["awards"][0]["cost"], 200.0, 0.01, "2 × 100")


func test_empty_bids() -> void:
	var result := AuctionResolver.resolve_auctions([], galaxy, [], [])
	assert_eq(result["awards"].size(), 0, "no awards")
	assert_eq(result["rejections"].size(), 0, "no rejections")


func test_multiple_planets_independent() -> void:
	var c := _make_carrier("c1", 50000.0)
	var bids := [
		_make_bid("c1", "earth", 2, 100.0),
		_make_bid("c1", "mars", 3, 80.0),
	]

	var result := AuctionResolver.resolve_auctions(bids, galaxy, [c], ["c1"])
	assert_eq(result["awards"].size(), 2, "awards for both planets")


# ---------------------------------------------------------------------------
# process_slot_sale
# ---------------------------------------------------------------------------

func test_sell_slots_success() -> void:
	var c := _make_carrier("seller")
	c.slots["earth"] = 3

	var result := AuctionResolver.process_slot_sale(c, "earth", 2)
	assert_true(result["success"], "sale succeeds")
	assert_eq(result["slots_freed"], 2, "2 slots freed")


func test_sell_all_slots_no_routes() -> void:
	var c := _make_carrier("seller")
	c.slots["earth"] = 2

	var result := AuctionResolver.process_slot_sale(c, "earth", 2)
	assert_true(result["success"], "can sell all when no routes")


func test_sell_more_than_owned_fails() -> void:
	var c := _make_carrier("seller")
	c.slots["earth"] = 1

	var result := AuctionResolver.process_slot_sale(c, "earth", 3)
	assert_false(result["success"], "cannot sell more than owned")
	assert_eq(result["slots_freed"], 0, "nothing freed")


func test_sell_with_no_slots_fails() -> void:
	var c := _make_carrier("seller")

	var result := AuctionResolver.process_slot_sale(c, "earth", 1)
	assert_false(result["success"], "cannot sell 0 slots")


func test_sell_blocked_by_active_route() -> void:
	var c := _make_carrier("routed")
	c.slots["earth"] = 1
	c.slots["mars"] = 1
	_add_active_route(c, "earth", "mars")

	# Owns 1 slot at earth, 1 active route uses earth → need at least 1
	var result := AuctionResolver.process_slot_sale(c, "earth", 1)
	assert_false(result["success"], "route blocks sale")


func test_sell_partial_ok_with_route() -> void:
	var c := _make_carrier("routed")
	c.slots["earth"] = 3
	c.slots["mars"] = 1
	_add_active_route(c, "earth", "mars")

	# 1 route uses earth, owns 3, sell 2 → 1 remains for route
	var result := AuctionResolver.process_slot_sale(c, "earth", 2)
	assert_true(result["success"], "partial sale ok when routes satisfied")
	assert_eq(result["slots_freed"], 2, "2 freed")
