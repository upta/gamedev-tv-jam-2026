extends GutTest

## Tests for GameSetup factory (P2.6)


func test_create_default_session_returns_session() -> void:
	var session := GameSetup.create_default_session(42)
	assert_not_null(session)
	assert_is(session, GameSession)


func test_default_session_has_game_state() -> void:
	var session := GameSetup.create_default_session(42)
	assert_not_null(session.game_state)
	assert_eq(session.game_state.carriers.size(), 4)


func test_default_session_player_has_idle_controller() -> void:
	var session := GameSetup.create_default_session(42)
	assert_is(session.controllers["player"], IdleController)


func test_default_session_npcs_have_npc_controller() -> void:
	var session := GameSetup.create_default_session(42)
	assert_is(session.controllers["npc_1"], NpcController)
	assert_is(session.controllers["npc_2"], NpcController)
	assert_is(session.controllers["npc_3"], NpcController)


func test_all_npc_session_all_are_npc_controllers() -> void:
	var session := GameSetup.create_all_npc_session(42)
	for carrier: CarrierData in session.game_state.carriers:
		assert_is(session.controllers[carrier.id], NpcController)


func test_all_idle_session_all_are_idle_controllers() -> void:
	var session := GameSetup.create_all_idle_session(42)
	for carrier: CarrierData in session.game_state.carriers:
		assert_is(session.controllers[carrier.id], IdleController)


func test_seed_produces_deterministic_state() -> void:
	var s1 := GameSetup.create_all_npc_session(99)
	var s2 := GameSetup.create_all_npc_session(99)
	assert_eq(s1.game_state.rng.seed, s2.game_state.rng.seed)


func test_all_npc_session_can_run_to_completion() -> void:
	var session := GameSetup.create_all_npc_session(42)
	session.run_all_turns()
	assert_true(session.is_complete)
	var results := session.get_final_results()
	assert_true(results["turns_played"] > 0, "should play at least 1 turn")
	assert_true(results["turns_played"] <= 30, "should play at most 30 turns")
	assert_true(results["winner_id"] != "")


func test_npc_personalities_differ() -> void:
	var session := GameSetup.create_all_npc_session(42)
	var ctrl1: NpcController = session.controllers["npc_1"]
	var ctrl2: NpcController = session.controllers["npc_2"]
	var ctrl3: NpcController = session.controllers["npc_3"]
	# NPC_2 is more aggressive than NPC_3
	assert_true(ctrl2.slot_aggression > ctrl3.slot_aggression)


func test_create_player_session_returns_session() -> void:
	var pc := PlayerController.new()
	var session := GameSetup.create_player_session(pc, 42)
	assert_not_null(session)
	assert_is(session, GameSession)


func test_create_player_session_uses_player_controller() -> void:
	var pc := PlayerController.new()
	var session := GameSetup.create_player_session(pc, 42)
	assert_eq(session.controllers["player"], pc)


func test_create_player_session_npcs_have_npc_controllers() -> void:
	var pc := PlayerController.new()
	var session := GameSetup.create_player_session(pc, 42)
	assert_is(session.controllers["npc_1"], NpcController)
	assert_is(session.controllers["npc_2"], NpcController)
	assert_is(session.controllers["npc_3"], NpcController)


func test_create_player_session_with_seed() -> void:
	var pc := PlayerController.new()
	var session := GameSetup.create_player_session(pc, 99)
	assert_eq(session.game_state.rng.seed, 99)


func test_default_session_can_run_to_completion() -> void:
	var session := GameSetup.create_default_session(42)
	session.run_all_turns()
	assert_true(session.is_complete)
	var results := session.get_final_results()
	assert_true(results["turns_played"] > 0, "should play at least 1 turn")
	assert_true(results["turns_played"] <= 30, "should play at most 30 turns")
