extends GutTest

## Tests for GameSession orchestrator (P2.5)

var session: GameSession
var game_state: GameState


func _create_session_with_idle_controllers() -> GameSession:
	var gs := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	gs.initialize(galaxy, catalog, carriers, 42)  # Fixed seed for determinism

	var ctrl := {}
	for carrier: CarrierData in carriers:
		ctrl[carrier.id] = IdleController.new()

	var s := GameSession.new()
	s.setup(gs, ctrl)
	return s


func test_setup_assigns_state_and_controllers() -> void:
	var s := _create_session_with_idle_controllers()
	assert_not_null(s.game_state)
	assert_eq(s.controllers.size(), 4)
	assert_false(s.is_running)
	assert_false(s.is_complete)


func test_run_next_turn_advances_one_turn() -> void:
	var s := _create_session_with_idle_controllers()
	assert_eq(s.game_state.current_turn, 1)
	var result = s.run_next_turn()
	assert_not_null(result)
	assert_eq(s.game_state.current_turn, 2)


func test_run_all_turns_completes_game() -> void:
	var s := _create_session_with_idle_controllers()
	s.run_all_turns()
	assert_true(s.is_complete)
	assert_false(s.is_running)
	assert_true(s.game_state.current_turn > 30)


func test_final_results_have_winner() -> void:
	var s := _create_session_with_idle_controllers()
	s.run_all_turns()
	var results := s.get_final_results()
	assert_has(results, "winner_id")
	assert_has(results, "winner_score")
	assert_has(results, "reason")
	assert_has(results, "turns_played")
	assert_has(results, "rankings")
	assert_eq(results["turns_played"], 30)


func test_session_ended_signal_fires() -> void:
	var s := _create_session_with_idle_controllers()
	var signal_fired := [false]
	s.session_ended.connect(func(winner_id: String, reason: String):
		signal_fired[0] = true
	)
	s.run_all_turns()
	assert_true(signal_fired[0])


func test_turn_completed_signal_fires_each_turn() -> void:
	var s := _create_session_with_idle_controllers()
	var turn_count := [0]
	s.turn_completed.connect(func(turn_number: int, result: TurnPipeline.TurnResult):
		turn_count[0] += 1
	)
	s.run_all_turns()
	assert_eq(turn_count[0], 30)


func test_run_all_turns_errors_without_game_state() -> void:
	var s := GameSession.new()
	s.run_all_turns()
	assert_push_error("GameSession: cannot run without game_state")


func test_cannot_run_completed_session() -> void:
	var s := _create_session_with_idle_controllers()
	s.run_all_turns()
	s.run_all_turns()
	assert_push_error("GameSession: session already complete")


func test_missing_controller_uses_empty_intent() -> void:
	# Setup with only some controllers
	var gs := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	gs.initialize(galaxy, catalog, carriers, 42)

	var ctrl := {"player": IdleController.new()}  # Only player has controller
	var s := GameSession.new()
	s.setup(gs, ctrl)

	# Should not crash — missing controllers get empty intents
	var result = s.run_next_turn()
	assert_not_null(result)
