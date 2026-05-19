class_name GameTelemetry
extends RefCounted

## Accumulates per-turn game state and actions, then serializes to JSON.
## Instance lives on GameSession — not static, accumulates across turns.

const SAVE_PATH := "user://game_telemetry.json"

var _turns: Array = []


func record_turn(turn_number: int, intents: Array, result, game_state: GameState) -> void:
	var turn_entry := {
		"turn": turn_number,
		"intents": _serialize_intents(intents),
		"results": _serialize_results(result),
		"state_after": _serialize_state_after(game_state),
	}
	_turns.append(turn_entry)


func save_to_file() -> String:
	var data := {
		"_meta": {
			"saved_at": Time.get_datetime_string_from_system(true),
			"turns_recorded": _turns.size(),
			"description": "Full per-turn game telemetry for AI analysis",
		},
		"turns": _turns,
	}
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var err_msg := "GameTelemetry: failed to open %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()]
		push_error(err_msg)
		return err_msg
	file.store_string(json_string)
	file.close()
	var os_path := ProjectSettings.globalize_path(SAVE_PATH)
	print("GameTelemetry: saved %d turns to %s (%s)" % [_turns.size(), SAVE_PATH, os_path])
	return os_path


func get_turn_count() -> int:
	return _turns.size()


func get_turns() -> Array:
	return _turns


func clear() -> void:
	_turns.clear()


# ---------------------------------------------------------------------------
# Intent serialization
# ---------------------------------------------------------------------------

func _serialize_intents(intents: Array) -> Dictionary:
	var result := {}
	for intent in intents:
		result[intent.carrier_id] = {
			"slot_bids": intent.slot_bids.duplicate(true),
			"route_creates": intent.route_creates.duplicate(true),
			"route_modifications": intent.route_modifications.duplicate(true),
			"route_cancellations": intent.route_cancellations.duplicate(true),
			"ship_orders": intent.ship_orders.duplicate(true),
			"slot_sales": intent.slot_sales.duplicate(true),
		}
	return result


# ---------------------------------------------------------------------------
# Result serialization
# ---------------------------------------------------------------------------

func _serialize_results(result) -> Dictionary:
	return {
		"auction_results": result.auction_results.duplicate(true),
		"route_changes": result.route_changes.duplicate(true),
		"ship_orders": result.ship_orders.duplicate(true),
		"deliveries": result.deliveries.duplicate(true),
		"financials": result.financials.duplicate(true),
		"events": _serialize_events(result.events),
		"rankings": result.rankings.duplicate(true),
		"bankruptcies": result.bankruptcies.duplicate(true),
	}


func _serialize_events(events: Array) -> Array:
	var result := []
	for event in events:
		result.append({
			"id": event.id,
			"description": event.description,
			"target_lane_id": event.target_lane_id,
			"target_planet_id": event.target_planet_id,
			"demand_type": event.demand_type,
			"modifier": event.modifier,
			"duration_turns": event.duration_turns,
			"remaining_turns": event.remaining_turns,
		})
	return result


# ---------------------------------------------------------------------------
# Post-turn state snapshot
# ---------------------------------------------------------------------------

func _serialize_state_after(game_state: GameState) -> Dictionary:
	var result := {}
	for carrier: CarrierData in game_state.carriers:
		var score_data: Dictionary = ScoreCalculator.calculate_score(
			carrier, game_state.catalog, game_state.galaxy
		)
		result[carrier.id] = {
			"cash": carrier.cash,
			"slots": carrier.slots.duplicate(),
			"routes": _serialize_routes(carrier.routes),
			"ships": _serialize_ships(carrier.ships),
			"pending_orders": _serialize_ships(carrier.pending_orders),
			"score": score_data.get("total", 0),
		}
	return result


func _serialize_ships(ships: Array) -> Array:
	var result := []
	for ship: ShipCatalog.ShipInstance in ships:
		result.append({
			"id": ship.id,
			"type_id": ship.type_id,
			"passenger_capacity": ship.passenger_capacity,
			"cargo_capacity": ship.cargo_capacity,
		})
	return result


func _serialize_routes(routes: Array) -> Array:
	var result := []
	for route: CarrierData.Route in routes:
		result.append({
			"id": route.id,
			"origin_id": route.origin_id,
			"dest_id": route.dest_id,
			"ship_ids": route.ship_ids.duplicate(),
			"passenger_price": route.passenger_price,
			"cargo_price": route.cargo_price,
			"frequency": route.frequency,
			"active": route.active,
		})
	return result
