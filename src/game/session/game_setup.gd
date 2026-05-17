class_name GameSetup
extends RefCounted

## Factory that creates fully-configured GameSession instances.
## Keeps configuration separate from the session runner.


static func create_default_session(seed: int = 0) -> GameSession:
	## Creates a standard game: player gets IdleController, NPCs get NpcController.
	## This is what Phase 3 UI will use (swapping IdleController for PlayerController).
	var game_state := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state.initialize(galaxy, catalog, carriers, seed)

	var controllers: Dictionary = {}
	for carrier: CarrierData in carriers:
		if carrier.id == "player":
			controllers[carrier.id] = IdleController.new()
		else:
			controllers[carrier.id] = _create_npc_controller(carrier.id)

	var session := GameSession.new()
	session.setup(game_state, controllers)
	return session


static func create_player_session(player_controller: PlayerController, seed: int = 0) -> GameSession:
	## Creates a session where the player's carrier uses the provided PlayerController
	## and NPCs use NpcControllers. This is what the UI GameScene uses.
	var game_state := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state.initialize(galaxy, catalog, carriers, seed)

	var controllers: Dictionary = {}
	for carrier: CarrierData in carriers:
		if carrier.id == "player":
			controllers[carrier.id] = player_controller
		else:
			controllers[carrier.id] = _create_npc_controller(carrier.id)

	var session := GameSession.new()
	session.setup(game_state, controllers)
	return session


static func create_all_npc_session(seed: int = 0) -> GameSession:
	## All four carriers get NpcController. For full headless testing/validation.
	var game_state := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state.initialize(galaxy, catalog, carriers, seed)

	var controllers: Dictionary = {}
	for carrier: CarrierData in carriers:
		controllers[carrier.id] = _create_npc_controller(carrier.id)

	var session := GameSession.new()
	session.setup(game_state, controllers)
	return session


static func create_all_idle_session(seed: int = 0) -> GameSession:
	## All carriers idle. For testing infrastructure without AI noise.
	var game_state := GameState.new()
	var galaxy := GalaxyData.create_default_galaxy()
	var catalog := ShipCatalog.create_default_catalog()
	var carriers := CarrierData.create_default_carriers(catalog)
	game_state.initialize(galaxy, catalog, carriers, seed)

	var controllers: Dictionary = {}
	for carrier: CarrierData in carriers:
		controllers[carrier.id] = IdleController.new()

	var session := GameSession.new()
	session.setup(game_state, controllers)
	return session


static func _create_npc_controller(carrier_id: String) -> NpcController:
	## Creates an NpcController with personality tuning based on carrier identity.
	var ctrl := NpcController.new()
	match carrier_id:
		"npc_1":  # Nova Transit — balanced
			ctrl.slot_aggression = 0.5
			ctrl.route_preference = 0.5
			ctrl.ship_eagerness = 0.5
		"npc_2":  # Stellar Lines — aggressive expander
			ctrl.slot_aggression = 0.8
			ctrl.route_preference = 0.7
			ctrl.ship_eagerness = 0.6
		"npc_3":  # Frontier Express — cautious optimizer
			ctrl.slot_aggression = 0.3
			ctrl.route_preference = 0.4
			ctrl.ship_eagerness = 0.4
		"player":  # If player is NPC-controlled (all-NPC mode)
			ctrl.slot_aggression = 0.5
			ctrl.route_preference = 0.5
			ctrl.ship_eagerness = 0.5
	return ctrl
