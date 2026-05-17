class_name TurnPipeline
extends RefCounted

## Central turn resolution engine (D004).
## Orchestrates all simulation subsystems into a single deterministic turn.
## Pipeline order: Deliver → Auctions → Routes → Ships → Slot Sales → Financials → Events → Report.


class CarrierIntent:
	var carrier_id: String
	var slot_bids: Array = []           # [{ "planet_id": str, "quantity": int, "price_per_slot": float }]
	var route_creates: Array = []       # [{ "lane_id": str, "origin_id": str, "dest_id": str, "ship_ids": Array, "passenger_price": float, "cargo_price": float, "frequency": int }]
	var route_modifications: Array = [] # [{ "route_id": str, "ship_ids": Array, "passenger_price": float, "cargo_price": float, "frequency": int }]
	var route_cancellations: Array = [] # [route_id: str]
	var ship_orders: Array = []         # [{ "type_id": str, "passenger_capacity": int, "cargo_capacity": int }]
	var slot_sales: Array = []          # [{ "planet_id": str, "count": int }]


class TurnResult:
	var turn_number: int
	var deliveries: Array = []
	var auction_results: Dictionary = {}
	var route_changes: Array = []
	var ship_orders: Array = []
	var slot_sales: Array = []
	var financials: Dictionary = {}
	var events: Array = []
	var event_descriptions: Array = []
	var rankings: Array = []
	var bankruptcies: Array = []
	var game_over: bool = false
	var winner: Dictionary = {}


static func resolve_turn(game_state: GameState, intents: Array) -> TurnResult:
	var result := TurnResult.new()
	result.turn_number = game_state.current_turn

	# 1. DELIVER — move ready ships from pending_orders to fleet
	result.deliveries = FinancialCalculator.deliver_pending_ships(
		game_state.carriers, game_state.current_turn
	)

	# 2. AUCTIONS — resolve slot bids
	_resolve_auctions(game_state, intents, result)

	# 3. ROUTES — cancellations, modifications, creations (in carrier index order)
	_resolve_routes(game_state, intents, result)

	# 4. SHIPS — process ship orders
	_resolve_ship_orders(game_state, intents, result)

	# 5. SLOT SALES — process slot sales
	_resolve_slot_sales(game_state, intents, result)

	# 6. FINANCIALS — revenue, costs, bankruptcy detection
	result.financials = FinancialCalculator.process_financials(
		game_state.carriers, game_state.catalog, game_state.galaxy, game_state.demand_table
	)
	for carrier: CarrierData in game_state.carriers:
		var summary: Dictionary = result.financials.get(carrier.id, {})
		if summary.get("bankrupt", false):
			result.bankruptcies.append(carrier.id)

	# 7. EVENTS — generate, apply, tick
	var new_events: Array = EventSystem.generate_events(
		game_state.current_turn, game_state.galaxy, game_state.rng, game_state.events
	)
	result.events = new_events
	for event: EventSystem.GameEvent in new_events:
		game_state.events.append(event)

	EventSystem.apply_events(game_state.events, game_state.demand_table, game_state.galaxy)
	game_state.events = EventSystem.tick_events(game_state.events)

	result.event_descriptions = EventSystem.get_active_event_descriptions(game_state.events)

	# 8. REPORT — rankings and game-over check
	result.rankings = ScoreCalculator.get_rankings(game_state.carriers, game_state.catalog)

	if game_state.current_turn >= 30 or result.bankruptcies.size() > 0:
		result.game_over = true
		var winner_carrier := ScoreCalculator.determine_winner(game_state.carriers, game_state.catalog)
		if winner_carrier != null:
			var winner_score := ScoreCalculator.calculate_score(
				winner_carrier, game_state.catalog
			)
			result.winner = {
				"carrier_id": winner_carrier.id,
				"score": winner_score["total"],
			}

	return result


# ---------------------------------------------------------------------------
# Step 2: Auctions
# ---------------------------------------------------------------------------

static func _resolve_auctions(
	game_state: GameState, intents: Array, result: TurnResult
) -> void:
	var all_bids: Array = []
	var carrier_order: Array = []

	for carrier: CarrierData in game_state.carriers:
		carrier_order.append(carrier.id)

	for intent: CarrierIntent in intents:
		for bid: Dictionary in intent.slot_bids:
			all_bids.append({
				"carrier_id": intent.carrier_id,
				"planet_id": bid["planet_id"],
				"quantity": bid.get("quantity", bid.get("count", 0)),
				"price_per_slot": bid["price_per_slot"],
			})

	if all_bids.is_empty():
		return

	var auction_out: Dictionary = AuctionResolver.resolve_auctions(
		all_bids, game_state.galaxy, game_state.carriers, carrier_order
	)
	result.auction_results = auction_out

	for award: Dictionary in auction_out.get("awards", []):
		var carrier: CarrierData = game_state.get_carrier(award["carrier_id"])
		if carrier == null:
			continue
		var planet_id: String = award["planet_id"]
		var slots_won: int = award["slots_won"]
		var cost: float = award["cost"]
		carrier.slots[planet_id] = carrier.get_slot_count(planet_id) + slots_won
		carrier.cash -= cost


# ---------------------------------------------------------------------------
# Step 3: Routes
# ---------------------------------------------------------------------------

static func _resolve_routes(
	game_state: GameState, intents: Array, result: TurnResult
) -> void:
	var intent_map: Dictionary = {}
	for intent: CarrierIntent in intents:
		intent_map[intent.carrier_id] = intent

	for carrier: CarrierData in game_state.carriers:
		var intent: CarrierIntent = intent_map.get(carrier.id)
		if intent == null:
			continue

		# Cancellations first
		for route_id: String in intent.route_cancellations:
			var route := _find_route(carrier, route_id)
			if route == null:
				push_warning("TurnPipeline: route '%s' not found for cancellation" % route_id)
				continue
			route.active = false
			result.route_changes.append({
				"type": "cancelled",
				"carrier_id": carrier.id,
				"route_id": route_id,
			})

		# Modifications
		for mod: Dictionary in intent.route_modifications:
			var route := _find_route(carrier, mod["route_id"])
			if route == null:
				push_warning("TurnPipeline: route '%s' not found for modification" % mod["route_id"])
				continue
			var validation := RouteValidator.validate_route_modification(
				carrier, game_state.galaxy, game_state.catalog, route,
				mod["ship_ids"], mod["frequency"],
				mod["passenger_price"], mod["cargo_price"],
				game_state.current_turn
			)
			if not validation["valid"]:
				push_warning("TurnPipeline: route modification rejected — %s" % validation["reason"])
				continue
			route.ship_ids.assign(mod["ship_ids"])
			route.passenger_price = mod["passenger_price"]
			route.cargo_price = mod["cargo_price"]
			route.frequency = validation["clamped_frequency"]
			result.route_changes.append({
				"type": "modified",
				"carrier_id": carrier.id,
				"route_id": route.id,
			})

		# Creations
		var route_counter: int = carrier.routes.size()
		for create: Dictionary in intent.route_creates:
			var validation := RouteValidator.validate_route_creation(
				carrier, game_state.galaxy, game_state.catalog,
				create["lane_id"], create["origin_id"], create["dest_id"],
				create["ship_ids"], create["frequency"],
				game_state.current_turn
			)
			if not validation["valid"]:
				push_warning("TurnPipeline: route creation rejected — %s" % validation["reason"])
				continue

			var route_id := "%s-route-%d" % [carrier.id, route_counter]
			route_counter += 1

			var typed_ship_ids: Array[String] = []
			for sid: String in create["ship_ids"]:
				typed_ship_ids.append(sid)

			var new_route := CarrierData.Route.new(
				route_id,
				create["lane_id"],
				create["origin_id"],
				create["dest_id"],
				typed_ship_ids,
				create.get("passenger_price", 0.0),
				create.get("cargo_price", 0.0),
				validation["clamped_frequency"],
				true
			)
			carrier.routes.append(new_route)
			result.route_changes.append({
				"type": "created",
				"carrier_id": carrier.id,
				"route_id": route_id,
			})


# ---------------------------------------------------------------------------
# Step 4: Ship Orders
# ---------------------------------------------------------------------------

static func _resolve_ship_orders(
	game_state: GameState, intents: Array, result: TurnResult
) -> void:
	var intent_map: Dictionary = {}
	for intent: CarrierIntent in intents:
		intent_map[intent.carrier_id] = intent

	for carrier: CarrierData in game_state.carriers:
		var intent: CarrierIntent = intent_map.get(carrier.id)
		if intent == null:
			continue

		for order: Dictionary in intent.ship_orders:
			var type_id: String = order["type_id"]
			var ship_type := game_state.catalog.get_type(type_id)
			if ship_type == null:
				push_warning("TurnPipeline: unknown ship type '%s'" % type_id)
				continue

			if ship_type.unlock_turn > game_state.current_turn:
				push_warning("TurnPipeline: ship type '%s' not yet available" % type_id)
				continue

			var cost: float = ship_type.cost
			if carrier.cash < cost:
				push_warning("TurnPipeline: carrier '%s' cannot afford ship '%s' (needs %d, has %.1f)" % [
					carrier.id, type_id, cost, carrier.cash
				])
				continue

			var ship := game_state.catalog.create_ship_instance(
				type_id,
				order["passenger_capacity"],
				order["cargo_capacity"],
				carrier.id,
				game_state.current_turn
			)
			if ship == null:
				continue

			carrier.cash -= cost
			carrier.pending_orders.append(ship)
			result.ship_orders.append({
				"carrier_id": carrier.id,
				"ship_id": ship.id,
				"type_id": type_id,
				"cost": cost,
			})


# ---------------------------------------------------------------------------
# Step 5: Slot Sales
# ---------------------------------------------------------------------------

static func _resolve_slot_sales(
	game_state: GameState, intents: Array, result: TurnResult
) -> void:
	var intent_map: Dictionary = {}
	for intent: CarrierIntent in intents:
		intent_map[intent.carrier_id] = intent

	for carrier: CarrierData in game_state.carriers:
		var intent: CarrierIntent = intent_map.get(carrier.id)
		if intent == null:
			continue

		for sale: Dictionary in intent.slot_sales:
			var planet_id: String = sale["planet_id"]
			var count: int = sale["count"]
			var sale_result := AuctionResolver.process_slot_sale(carrier, planet_id, count)
			if sale_result["success"]:
				carrier.slots[planet_id] = carrier.get_slot_count(planet_id) - count
				result.slot_sales.append({
					"carrier_id": carrier.id,
					"planet_id": planet_id,
					"count": count,
				})
			else:
				push_warning("TurnPipeline: slot sale rejected — %s" % sale_result["reason"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _find_route(carrier: CarrierData, route_id: String) -> CarrierData.Route:
	for route: CarrierData.Route in carrier.routes:
		if route.id == route_id:
			return route
	return null
