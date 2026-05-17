extends Node

## Validation harness for a full 30-turn game session.
## Runs one turn per physics frame so scenarios can use wait_frames to step.

var session: GameSession
var turns_completed: int = 0
var events_generated: int = 0
var first_event_turn: int = -1
var total_routes_created: int = 0


func reset_harness() -> void:
	session = GameSetup.create_all_npc_session(42)  # Fixed seed for determinism
	turns_completed = 0
	events_generated = 0
	first_event_turn = -1
	total_routes_created = 0

	session.turn_completed.connect(_on_turn_completed)


func _physics_process(_delta: float) -> void:
	if session == null:
		return
	if session.is_complete:
		return

	session.run_next_turn()


func _on_turn_completed(turn_number: int, result: TurnPipeline.TurnResult) -> void:
	turns_completed += 1
	if result.events.size() > 0 and first_event_turn == -1:
		first_event_turn = turn_number
	events_generated += result.events.size()
	total_routes_created += _count_route_creates(result)


func _count_route_creates(result: TurnPipeline.TurnResult) -> int:
	var count := 0
	for change: Dictionary in result.route_changes:
		if change.get("type", "") == "created":
			count += 1
	return count


func get_observed_state() -> Dictionary:
	return {
		"harness_state": _build_harness_state(),
		"metrics": _build_metrics(),
		"nodes": {},
		"signals": {},
	}


func _build_harness_state() -> Dictionary:
	var state: Dictionary = {
		"session_status": _get_session_status(),
		"turns_completed": turns_completed,
		"events_generated": events_generated,
		"first_event_turn": first_event_turn,
		"carriers": {},
	}

	if session == null or session.game_state == null:
		return state

	for carrier: CarrierData in session.game_state.carriers:
		var active_routes := carrier.get_active_routes()
		var score := ScoreCalculator.calculate_score(carrier, session.game_state.catalog)
		state["carriers"][carrier.id] = {
			"cash": carrier.cash,
			"ship_count": carrier.ships.size(),
			"route_count": active_routes.size(),
			"slot_count": _total_slots(carrier),
			"score": score["total"],
		}

	if session.is_complete:
		var results := session.get_final_results()
		if results.is_empty():
			# run_next_turn doesn't populate final_results; compute inline
			var rankings := ScoreCalculator.get_rankings(
				session.game_state.carriers, session.game_state.catalog
			)
			if rankings.size() > 0:
				state["winner"] = {
					"carrier_id": rankings[0].get("carrier_id", ""),
					"score": rankings[0].get("score", 0),
				}
		else:
			state["winner"] = {
				"carrier_id": results.get("winner_id", ""),
				"score": results.get("winner_score", 0),
			}

	return state


func _build_metrics() -> Dictionary:
	if session == null or session.game_state == null:
		return {}

	var total_ships := 0
	var total_routes := 0
	var total_slots := 0
	for carrier: CarrierData in session.game_state.carriers:
		total_ships += carrier.ships.size()
		total_routes += carrier.get_active_routes().size()
		total_slots += _total_slots(carrier)

	return {
		"game_duration_turns": turns_completed,
		"total_routes_created": total_routes_created,
		"total_ships_in_play": total_ships,
		"total_active_routes": total_routes,
		"total_slots_held": total_slots,
		"events_generated": events_generated,
	}


func _get_session_status() -> String:
	if session == null:
		return "not_started"
	if session.is_complete:
		return "completed"
	if turns_completed > 0:
		return "running"
	return "not_started"


func _total_slots(carrier: CarrierData) -> int:
	var total := 0
	for count: int in carrier.slots.values():
		total += count
	return total
