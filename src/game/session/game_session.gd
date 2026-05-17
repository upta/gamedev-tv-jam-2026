class_name GameSession
extends RefCounted

## Top-level game runner. Owns game state and controller assignments.
## Runs the turn loop either all-at-once (headless) or one-at-a-time (UI).

signal session_started()
signal turn_completed(turn_number: int, result: TurnPipeline.TurnResult)
signal session_ended(winner_id: String, reason: String)

var game_state: GameState
var controllers: Dictionary = {}  # carrier_id: String -> CarrierController
var is_running: bool = false
var is_complete: bool = false
var final_results: Dictionary = {}


func setup(p_game_state: GameState, p_controllers: Dictionary) -> void:
	game_state = p_game_state
	controllers = p_controllers
	is_running = false
	is_complete = false
	final_results = {}


func run_all_turns() -> void:
	## Runs all turns synchronously (for headless/validation use).
	if game_state == null:
		push_error("GameSession: cannot run without game_state")
		return
	if is_complete:
		push_error("GameSession: session already complete")
		return

	is_running = true
	session_started.emit()

	while not _is_game_over():
		run_next_turn()

	is_running = false
	is_complete = true
	final_results = _build_final_results()
	var winner_id: String = final_results.get("winner_id", "")
	var reason: String = final_results.get("reason", "")
	session_ended.emit(winner_id, reason)


func run_next_turn() -> TurnPipeline.TurnResult:
	## Advances one turn. Returns the TurnResult.
	## Used by run_all_turns() internally and by UI pacing in Phase 3.
	if game_state == null:
		push_error("GameSession: cannot run without game_state")
		return null
	if _is_game_over():
		return null

	var intents: Array = []
	for carrier: CarrierData in game_state.carriers:
		var controller: CarrierController = controllers.get(carrier.id)
		if controller == null:
			var fallback_intent := TurnPipeline.CarrierIntent.new()
			fallback_intent.carrier_id = carrier.id
			intents.append(fallback_intent)
		else:
			intents.append(controller.generate_intent(game_state, carrier.id))

	var result = game_state.advance_turn(intents)
	turn_completed.emit(game_state.current_turn - 1, result)
	if result.game_over:
		is_complete = true
	return result


func get_final_results() -> Dictionary:
	return final_results


func _is_game_over() -> bool:
	return game_state.current_turn > 30 or is_complete


func _build_final_results() -> Dictionary:
	var rankings := ScoreCalculator.get_rankings(game_state.carriers, game_state.catalog)
	var winner_id := ""
	var winner_score := 0
	var reason := "final_turn"

	if rankings.size() > 0:
		winner_id = rankings[0].get("carrier_id", "")
		winner_score = rankings[0].get("score", 0)

	return {
		"winner_id": winner_id,
		"winner_score": winner_score,
		"reason": reason,
		"turns_played": game_state.current_turn - 1,
		"rankings": rankings,
	}
