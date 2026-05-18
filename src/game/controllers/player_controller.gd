class_name PlayerController
extends CarrierController

## Player controller that accumulates intent from UI interactions.
## Call add_*/remove_*/clear_intent() as the player makes decisions,
## then generate_intent() hands the built-up intent to the turn pipeline.
##
## Escrow: When bids/orders are added, cash is immediately deducted from the
## carrier so the UI reflects committed funds. On generate_intent() or
## clear_intent(), all escrowed cash is refunded before the turn pipeline runs.

signal intent_changed(intent: TurnPipeline.CarrierIntent)

var pending_intent: TurnPipeline.CarrierIntent
var _carrier: CarrierData
var _catalog: ShipCatalog
var _escrowed: float = 0.0


func _init() -> void:
	pending_intent = TurnPipeline.CarrierIntent.new()


func bind_carrier(carrier: CarrierData, catalog: ShipCatalog) -> void:
	_carrier = carrier
	_catalog = catalog
	_escrowed = 0.0


# ---------------------------------------------------------------------------
# Accumulation
# ---------------------------------------------------------------------------

func add_slot_bid(planet_id: String, quantity: int, price_per_slot: float) -> void:
	var cost := float(quantity) * price_per_slot
	for i in pending_intent.slot_bids.size():
		if pending_intent.slot_bids[i]["planet_id"] == planet_id:
			var old_bid: Dictionary = pending_intent.slot_bids[i]
			var old_cost := float(old_bid["quantity"]) * float(old_bid["price_per_slot"])
			_refund_escrow(old_cost)
			pending_intent.slot_bids[i] = {
				"planet_id": planet_id,
				"quantity": quantity,
				"price_per_slot": price_per_slot,
			}
			_deduct_escrow(cost)
			intent_changed.emit(pending_intent)
			return
	pending_intent.slot_bids.append({
		"planet_id": planet_id,
		"quantity": quantity,
		"price_per_slot": price_per_slot,
	})
	_deduct_escrow(cost)
	intent_changed.emit(pending_intent)


func add_route_create(
	origin_id: String,
	dest_id: String,
	ship_ids: Array,
	passenger_price: float,
	cargo_price: float,
	frequency: int = 1,
) -> void:
	pending_intent.route_creates.append({
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
	# Replace any existing modification for the same route
	for i: int in range(pending_intent.route_modifications.size()):
		if pending_intent.route_modifications[i]["route_id"] == route_id:
			pending_intent.route_modifications[i] = {
				"route_id": route_id,
				"ship_ids": ship_ids,
				"passenger_price": passenger_price,
				"cargo_price": cargo_price,
				"frequency": frequency,
			}
			intent_changed.emit(pending_intent)
			return
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
	_deduct_escrow(_get_ship_cost(type_id))
	intent_changed.emit(pending_intent)


func add_slot_sale(planet_id: String, count: int) -> void:
	for i in pending_intent.slot_sales.size():
		if pending_intent.slot_sales[i]["planet_id"] == planet_id:
			pending_intent.slot_sales[i] = {
				"planet_id": planet_id,
				"count": count,
			}
			intent_changed.emit(pending_intent)
			return
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
	var bid: Dictionary = pending_intent.slot_bids[index]
	var cost := float(bid["quantity"]) * float(bid["price_per_slot"])
	_refund_escrow(cost)
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
	var order: Dictionary = pending_intent.ship_orders[index]
	_refund_escrow(_get_ship_cost(order["type_id"]))
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
	_refund_all_escrow()
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
	_refund_all_escrow()
	pending_intent.carrier_id = carrier_id
	var result := pending_intent
	pending_intent = TurnPipeline.CarrierIntent.new()
	return result


# ---------------------------------------------------------------------------
# Escrow helpers
# ---------------------------------------------------------------------------

func _deduct_escrow(amount: float) -> void:
	if _carrier == null:
		return
	_carrier.cash -= amount
	_escrowed += amount


func _refund_escrow(amount: float) -> void:
	if _carrier == null:
		return
	_carrier.cash += amount
	_escrowed -= amount


func _refund_all_escrow() -> void:
	if _carrier == null or _escrowed == 0.0:
		return
	_carrier.cash += _escrowed
	_escrowed = 0.0


func _get_ship_cost(type_id: String) -> float:
	if _catalog == null:
		return 0.0
	var ship_type := _catalog.get_type(type_id)
	if ship_type == null:
		return 0.0
	return float(ship_type.cost)
