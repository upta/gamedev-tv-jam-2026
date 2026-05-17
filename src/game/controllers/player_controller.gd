class_name PlayerController
extends CarrierController

## Player controller that accumulates intent from UI interactions.
## Call add_*/remove_*/clear_intent() as the player makes decisions,
## then generate_intent() hands the built-up intent to the turn pipeline.

signal intent_changed(intent: TurnPipeline.CarrierIntent)

var pending_intent: TurnPipeline.CarrierIntent


func _init() -> void:
	pending_intent = TurnPipeline.CarrierIntent.new()


# ---------------------------------------------------------------------------
# Accumulation
# ---------------------------------------------------------------------------

func add_slot_bid(planet_id: String, quantity: int, price_per_slot: float) -> void:
	pending_intent.slot_bids.append({
		"planet_id": planet_id,
		"quantity": quantity,
		"price_per_slot": price_per_slot,
	})
	intent_changed.emit(pending_intent)


func add_route_create(
	lane_id: String,
	origin_id: String,
	dest_id: String,
	ship_ids: Array,
	passenger_price: float,
	cargo_price: float,
	frequency: int = 1,
) -> void:
	pending_intent.route_creates.append({
		"lane_id": lane_id,
		"origin_id": origin_id,
		"dest_id": dest_id,
		"ship_ids": ship_ids,
		"passenger_price": passenger_price,
		"cargo_price": cargo_price,
		"frequency": frequency,
	})
	intent_changed.emit(pending_intent)


func modify_route(
	route_id: String,
	ship_ids: Array,
	passenger_price: float,
	cargo_price: float,
	frequency: int = 1,
) -> void:
	pending_intent.route_modifications.append({
		"route_id": route_id,
		"ship_ids": ship_ids,
		"passenger_price": passenger_price,
		"cargo_price": cargo_price,
		"frequency": frequency,
	})
	intent_changed.emit(pending_intent)


func cancel_route(route_id: String) -> void:
	pending_intent.route_cancellations.append(route_id)
	intent_changed.emit(pending_intent)


func add_ship_order(type_id: String, passenger_capacity: int, cargo_capacity: int) -> void:
	pending_intent.ship_orders.append({
		"type_id": type_id,
		"passenger_capacity": passenger_capacity,
		"cargo_capacity": cargo_capacity,
	})
	intent_changed.emit(pending_intent)


func add_slot_sale(planet_id: String, count: int) -> void:
	pending_intent.slot_sales.append({
		"planet_id": planet_id,
		"count": count,
	})
	intent_changed.emit(pending_intent)


# ---------------------------------------------------------------------------
# Removal
# ---------------------------------------------------------------------------

func remove_slot_bid(index: int) -> void:
	if index < 0 or index >= pending_intent.slot_bids.size():
		return
	pending_intent.slot_bids.remove_at(index)
	intent_changed.emit(pending_intent)


func remove_route_create(index: int) -> void:
	if index < 0 or index >= pending_intent.route_creates.size():
		return
	pending_intent.route_creates.remove_at(index)
	intent_changed.emit(pending_intent)


func remove_route_modification(index: int) -> void:
	if index < 0 or index >= pending_intent.route_modifications.size():
		return
	pending_intent.route_modifications.remove_at(index)
	intent_changed.emit(pending_intent)


func remove_route_cancellation(index: int) -> void:
	if index < 0 or index >= pending_intent.route_cancellations.size():
		return
	pending_intent.route_cancellations.remove_at(index)
	intent_changed.emit(pending_intent)


func remove_ship_order(index: int) -> void:
	if index < 0 or index >= pending_intent.ship_orders.size():
		return
	pending_intent.ship_orders.remove_at(index)
	intent_changed.emit(pending_intent)


func remove_slot_sale(index: int) -> void:
	if index < 0 or index >= pending_intent.slot_sales.size():
		return
	pending_intent.slot_sales.remove_at(index)
	intent_changed.emit(pending_intent)


# ---------------------------------------------------------------------------
# Control
# ---------------------------------------------------------------------------

func clear_intent() -> void:
	var carrier_id := pending_intent.carrier_id
	pending_intent = TurnPipeline.CarrierIntent.new()
	pending_intent.carrier_id = carrier_id
	intent_changed.emit(pending_intent)


func get_pending_summary() -> Dictionary:
	return {
		"slot_bids": pending_intent.slot_bids.size(),
		"route_creates": pending_intent.route_creates.size(),
		"route_modifications": pending_intent.route_modifications.size(),
		"route_cancellations": pending_intent.route_cancellations.size(),
		"ship_orders": pending_intent.ship_orders.size(),
		"slot_sales": pending_intent.slot_sales.size(),
	}


# ---------------------------------------------------------------------------
# Override
# ---------------------------------------------------------------------------

func generate_intent(game_state: GameState, carrier_id: String) -> TurnPipeline.CarrierIntent:
	pending_intent.carrier_id = carrier_id
	var result := pending_intent
	pending_intent = TurnPipeline.CarrierIntent.new()
	return result
