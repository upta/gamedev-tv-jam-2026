extends GutTest

## Diagnostic test: runs a full 30-turn NPC-only game and validates behavioral diversity.
## Asserts that NPC personalities drive meaningfully different strategies.

var session: GameSession
var telemetry: GameTelemetry


func before_each() -> void:
	session = GameSetup.create_all_npc_session(12345)
	session.run_all_turns()
	telemetry = session.telemetry


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_carrier_intents(carrier_id: String) -> Array:
	## Returns all intent entries for a carrier across all turns.
	var result: Array = []
	for turn: Dictionary in telemetry.get_turns():
		var intents: Dictionary = turn.get("intents", {})
		if intents.has(carrier_id):
			result.append(intents[carrier_id])
	return result


func _get_carrier_routes_at_end(carrier_id: String) -> Array:
	## Returns the routes array from the final turn's state_after for a carrier.
	var turns := telemetry.get_turns()
	if turns.is_empty():
		return []
	var last_state: Dictionary = turns[turns.size() - 1].get("state_after", {})
	var carrier_state: Dictionary = last_state.get(carrier_id, {})
	return carrier_state.get("routes", [])


func _get_route_destinations(carrier_id: String) -> Array:
	## Returns unique destination planet IDs from a carrier's final routes.
	var dests: Dictionary = {}
	for route: Dictionary in _get_carrier_routes_at_end(carrier_id):
		if route.get("active", false):
			dests[route.get("origin_id", "")] = true
			dests[route.get("dest_id", "")] = true
	return dests.keys()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_game_completes_30_turns() -> void:
	assert_eq(telemetry.get_turn_count(), 30, "Game should run all 30 turns")


func test_route_diversity_not_all_same_destinations() -> void:
	## At least 2 NPCs should have routes to destinations the others don't share.
	var carrier_ids := ["player", "npc_1", "npc_2", "npc_3"]
	var carrier_dests: Dictionary = {}
	for cid: String in carrier_ids:
		carrier_dests[cid] = _get_route_destinations(cid)

	var unique_route_carriers := 0
	for cid: String in carrier_ids:
		var my_dests: Array = carrier_dests[cid]
		if my_dests.is_empty():
			continue
		var has_unique := false
		for dest in my_dests:
			var shared := false
			for other_cid: String in carrier_ids:
				if other_cid == cid:
					continue
				if carrier_dests[other_cid].has(dest):
					shared = true
					break
			if not shared:
				has_unique = true
				break
		if has_unique:
			unique_route_carriers += 1

	assert_gte(unique_route_carriers, 2,
		"At least 2 NPCs should have route destinations not shared by all others")


func test_action_diversity_beyond_price_modifications() -> void:
	## Over 30 turns, at least one NPC should do more than just modify prices.
	## They should add ships to routes, change frequency, or open multiple routes.
	var carrier_ids := ["player", "npc_1", "npc_2", "npc_3"]
	var found_non_price_mod := false

	for cid: String in carrier_ids:
		var intents := _get_carrier_intents(cid)
		for intent: Dictionary in intents:
			# Check route modifications for ship or frequency changes
			var mods: Array = intent.get("route_modifications", [])
			for mod: Dictionary in mods:
				var ship_ids: Array = mod.get("ship_ids", [])
				# If a modification has more ships than the original route, that's a ship add
				if ship_ids.size() > 1:
					found_non_price_mod = true
					break
				var freq: int = mod.get("frequency", 1)
				if freq != 1:
					found_non_price_mod = true
					break
			if found_non_price_mod:
				break
			# Check if carrier created multiple routes total
			var creates: Array = intent.get("route_creates", [])
			if creates.size() >= 2:
				found_non_price_mod = true
				break
		if found_non_price_mod:
			break

	assert_true(found_non_price_mod,
		"At least one NPC should do more than just modify prices (add ships, change frequency, or open multiple routes)")


func test_strategic_differentiation_aggressive_vs_cautious() -> void:
	## npc_2 (slot_aggression=0.8) should bid at higher prices than npc_3 (slot_aggression=0.3).
	## Bid price directly reflects aggression: base_price = 120 + slot_aggression * 60.
	var npc2_total_spend := 0.0
	var npc2_bid_count := 0
	var npc3_total_spend := 0.0
	var npc3_bid_count := 0

	for intent: Dictionary in _get_carrier_intents("npc_2"):
		for bid: Dictionary in intent.get("slot_bids", []):
			npc2_total_spend += bid.get("price_per_slot", 0.0) * bid.get("quantity", 1)
			npc2_bid_count += 1

	for intent: Dictionary in _get_carrier_intents("npc_3"):
		for bid: Dictionary in intent.get("slot_bids", []):
			npc3_total_spend += bid.get("price_per_slot", 0.0) * bid.get("quantity", 1)
			npc3_bid_count += 1

	# At least one NPC should have bid on slots
	assert_true(npc2_bid_count > 0 or npc3_bid_count > 0,
		"At least one NPC should bid on slots during 30 turns")

	# Aggressive NPC should spend more per bid or invest more total in slots
	if npc2_bid_count > 0 and npc3_bid_count > 0:
		var npc2_avg := npc2_total_spend / npc2_bid_count
		var npc3_avg := npc3_total_spend / npc3_bid_count
		assert_gt(npc2_avg, npc3_avg,
			"Aggressive NPC (npc_2) should bid higher per slot than cautious NPC (npc_3). Got npc_2=%.0f, npc_3=%.0f avg" % [npc2_avg, npc3_avg])


func test_no_pure_price_spiral() -> void:
	## At least one NPC should not ONLY reduce prices. They should raise prices
	## on an overloaded route, add capacity, or change frequency at some point.
	var carrier_ids := ["player", "npc_1", "npc_2", "npc_3"]
	var found_non_decrease := false

	for cid: String in carrier_ids:
		var intents := _get_carrier_intents(cid)
		for intent: Dictionary in intents:
			var mods: Array = intent.get("route_modifications", [])
			for mod: Dictionary in mods:
				var ship_ids: Array = mod.get("ship_ids", [])
				# Ship additions break the price spiral
				if ship_ids.size() > 1:
					found_non_decrease = true
					break
				# Frequency changes break the price spiral
				var freq: int = mod.get("frequency", 1)
				if freq > 1:
					found_non_decrease = true
					break
			if found_non_decrease:
				break
		if found_non_decrease:
			break

	# If no mods had ship/frequency changes, check if any NPC raised prices
	if not found_non_decrease:
		for cid: String in carrier_ids:
			# Track price history per route to detect price increases
			var route_prices: Dictionary = {}  # route_id -> last_seen_prices
			for intent: Dictionary in _get_carrier_intents(cid):
				var mods: Array = intent.get("route_modifications", [])
				for mod: Dictionary in mods:
					var rid: String = mod.get("route_id", "")
					var pax_price: float = mod.get("passenger_price", 0.0)
					if route_prices.has(rid):
						if pax_price > route_prices[rid]:
							found_non_decrease = true
							break
					route_prices[rid] = pax_price
				if found_non_decrease:
					break
			if found_non_decrease:
				break

	assert_true(found_non_decrease,
		"At least one NPC should not only decrease prices — should raise prices, add ships, or increase frequency at some point")


func test_ship_order_type_varies_by_personality() -> void:
	## Across all NPCs, not all ship orders should be for the same type.
	var ordered_types: Dictionary = {}
	var carrier_ids := ["player", "npc_1", "npc_2", "npc_3"]

	for cid: String in carrier_ids:
		for intent: Dictionary in _get_carrier_intents(cid):
			var orders: Array = intent.get("ship_orders", [])
			for order: Dictionary in orders:
				var type_id: String = order.get("type_id", "")
				if type_id != "":
					ordered_types[type_id] = true

	# With personality-driven ship selection, we should see at least 2 different types
	# across all NPCs over 30 turns (aggressive prefers big, cautious prefers cheap, balanced picks best value)
	assert_gte(ordered_types.size(), 2,
		"NPCs with different personalities should order different ship types (got %d unique: %s)" % [ordered_types.size(), ", ".join(ordered_types.keys())])


func test_npcs_earn_revenue() -> void:
	## After the first few turns (ships need time to arrive), NPCs must earn revenue.
	## Revenue = 0 across many turns means a fundamental economic failure.
	var carrier_ids := ["npc_1", "npc_2", "npc_3"]
	var turns := telemetry.get_turns()

	for cid: String in carrier_ids:
		var total_revenue := 0.0
		# Only check turns 5+ (ships need 3 turns to build, routes need to exist)
		for i in range(4, turns.size()):
			var financials: Dictionary = turns[i].get("results", {}).get("financials", {})
			var carrier_fin: Dictionary = financials.get(cid, {})
			total_revenue += carrier_fin.get("total_revenue", 0.0)

		assert_gt(total_revenue, 0.0,
			"NPC '%s' should earn some revenue after turn 5 (got %.1f across turns 5-%d)" % [cid, total_revenue, turns.size()])


func test_at_least_one_npc_profitable_by_end() -> void:
	## At least one NPC should have more cash at the end than a pure-losses trajectory.
	## This validates the full economic loop: routes -> demand -> revenue > costs.
	var turns := telemetry.get_turns()
	var last_turn: Dictionary = turns[turns.size() - 1]

	var profitable_npcs := 0
	for cid in ["npc_1", "npc_2", "npc_3"]:
		var final_state: Dictionary = last_turn.get("state_after", {}).get(cid, {})
		var final_cash: float = final_state.get("cash", 0.0)
		# Starting cash is 3000. If cash > 2500 after 30 turns, NPC at least broke close to even.
		if final_cash > 2500.0:
			profitable_npcs += 1

	assert_gte(profitable_npcs, 1,
		"At least one NPC should be near break-even or profitable by turn 30")


func test_no_npc_idles_for_5_consecutive_turns() -> void:
	## No NPC should go completely idle (zero actions) for 5+ turns in a row.
	## Idle means the AI has no strategy left — it should always be bidding, expanding, or optimizing.
	var turns := telemetry.get_turns()
	var carrier_ids := ["npc_1", "npc_2", "npc_3"]

	for cid: String in carrier_ids:
		var consecutive_idle := 0
		var max_idle := 0
		for turn: Dictionary in turns:
			var intent: Dictionary = turn.get("intents", {}).get(cid, {})
			var has_action := false
			for key in ["slot_bids", "route_creates", "route_modifications", "ship_orders", "route_cancellations", "slot_sales"]:
				if not intent.get(key, []).is_empty():
					has_action = true
					break
			if has_action:
				consecutive_idle = 0
			else:
				consecutive_idle += 1
				if consecutive_idle > max_idle:
					max_idle = consecutive_idle

		assert_lt(max_idle, 5,
			"NPC '%s' was idle for %d consecutive turns — should always have strategic options" % [cid, max_idle])
