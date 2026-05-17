class_name DebugStateSaver
extends RefCounted

## Serializes the full GameState to user://debug_state.json for agent inspection.
##
## OS path (Windows): %APPDATA%/Godot/app_userdata/My Prototype/debug_state.json
## Godot path: user://debug_state.json
##
## Trigger: F12 key or 💾 button in TopBar.

const SAVE_PATH := "user://debug_state.json"


static func save(game_state: GameState, player_controller: PlayerController = null) -> String:
	var data := _build_state_dict(game_state, player_controller)
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var err_msg := "DebugStateSaver: failed to open %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()]
		push_error(err_msg)
		return err_msg
	file.store_string(json_string)
	file.close()
	var os_path := ProjectSettings.globalize_path(SAVE_PATH)
	print("DebugStateSaver: saved to %s (%s)" % [SAVE_PATH, os_path])
	return os_path


static func _build_state_dict(game_state: GameState, player_controller: PlayerController) -> Dictionary:
	var result := {}
	result["_meta"] = {
		"saved_at": Time.get_datetime_string_from_system(true),
		"godot_path": SAVE_PATH,
		"description": "Full game state snapshot for AI agent debugging.",
	}
	result["current_turn"] = game_state.current_turn
	result["galaxy"] = _serialize_galaxy(game_state.galaxy)
	result["carriers"] = _serialize_carriers(game_state.carriers, game_state.catalog, game_state.galaxy)
	if player_controller != null:
		result["player_pending_intent"] = _serialize_intent(player_controller.pending_intent)
	result["events"] = _serialize_events(game_state.events)
	result["console_errors"] = _serialize_console_log()
	return result


static func _serialize_galaxy(galaxy: GalaxyData) -> Dictionary:
	var planets := []
	for planet: GalaxyData.Planet in galaxy.planets:
		planets.append({
			"id": planet.id,
			"name": planet.name,
			"system": planet.system,
			"total_slots": planet.total_slots,
			"position": {"x": planet.position.x, "y": planet.position.y},
		})

	return { "planets": planets }


static func _serialize_carriers(carriers: Array, catalog: ShipCatalog, galaxy: GalaxyData = null) -> Array:
	var result := []
	for carrier: CarrierData in carriers:
		var score_data: Dictionary = ScoreCalculator.calculate_score(carrier, catalog, galaxy)
		result.append({
			"id": carrier.id,
			"carrier_name": carrier.carrier_name,
			"cash": carrier.cash,
			"score": score_data.get("total", 0),
			"slots": carrier.slots.duplicate(),
			"ships": _serialize_ships(carrier.ships),
			"pending_orders": _serialize_ships(carrier.pending_orders),
			"routes": _serialize_routes(carrier.routes),
		})
	return result


static func _serialize_ships(ships: Array) -> Array:
	var result := []
	for ship: ShipCatalog.ShipInstance in ships:
		result.append({
			"id": ship.id,
			"type_id": ship.type_id,
			"passenger_capacity": ship.passenger_capacity,
			"cargo_capacity": ship.cargo_capacity,
			"owner_id": ship.owner_id,
			"available_turn": ship.available_turn,
		})
	return result


static func _serialize_routes(routes: Array) -> Array:
	var result := []
	for route: CarrierData.Route in routes:
		result.append({
			"id": route.id,
			"lane_id": route.lane_id,
			"origin_id": route.origin_id,
			"dest_id": route.dest_id,
			"ship_ids": route.ship_ids.duplicate(),
			"passenger_price": route.passenger_price,
			"cargo_price": route.cargo_price,
			"frequency": route.frequency,
			"active": route.active,
		})
	return result


static func _serialize_intent(intent: TurnPipeline.CarrierIntent) -> Dictionary:
	return {
		"carrier_id": intent.carrier_id,
		"slot_bids": intent.slot_bids.duplicate(),
		"route_creates": intent.route_creates.duplicate(),
		"route_modifications": intent.route_modifications.duplicate(),
		"route_cancellations": intent.route_cancellations.duplicate(),
		"ship_orders": intent.ship_orders.duplicate(),
		"slot_sales": intent.slot_sales.duplicate(),
	}


static func _serialize_events(events: Array) -> Array:
	var result := []
	for event: EventSystem.GameEvent in events:
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


static func _serialize_console_log() -> Array:
	var log_path := "user://logs/godot.log"
	var file := FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return ["(could not open %s)" % log_path]

	var all_lines: PackedStringArray = file.get_as_text().split("\n")
	file.close()

	# Keep last 200 lines as the search window
	var start_idx := maxi(0, all_lines.size() - 200)
	var filtered := []
	for i in range(start_idx, all_lines.size()):
		var line := all_lines[i].strip_edges()
		if line.is_empty():
			continue
		if line.contains("ERROR") or line.contains("WARNING") or line.contains("SCRIPT ERROR"):
			filtered.append(line)

	# Cap at 100 entries
	if filtered.size() > 100:
		filtered = filtered.slice(filtered.size() - 100)

	return filtered
