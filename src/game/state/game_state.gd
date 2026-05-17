class_name GameState
extends Node

## Central autoload owning all simulation data (D001).
## Single source of truth for galaxy topology, ship catalog, carriers, and turn state.

signal turn_resolved(turn_number: int)
signal game_over(carrier_id: String, reason: String)

var galaxy: GalaxyData
var catalog: ShipCatalog
var carriers: Array = []  # Array of CarrierData
var current_turn: int = 0
var demand_table: DemandData = null
var events: Array = []
var rng: RandomNumberGenerator

var last_turn_financials: Dictionary = {}  # carrier_id -> financial summary from last turn
var _carrier_index: Dictionary = {}  # id -> CarrierData


func initialize(p_galaxy: GalaxyData, p_catalog: ShipCatalog, p_carriers: Array, seed: int = 0) -> void:
	galaxy = p_galaxy
	catalog = p_catalog
	carriers = p_carriers
	current_turn = 1
	demand_table = DemandData.create_default_demand(p_galaxy)
	events = []
	last_turn_financials = {}
	rng = RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	else:
		rng.seed = randi()
	_build_carrier_index()


func get_carrier(id: String) -> CarrierData:
	return _carrier_index.get(id, null)


func get_all_carriers() -> Array:
	return carriers


func get_player_carrier() -> CarrierData:
	return get_carrier("player")


func _build_carrier_index() -> void:
	_carrier_index.clear()
	for carrier: CarrierData in carriers:
		_carrier_index[carrier.id] = carrier


## Resolves one turn and advances the counter.
## Returns the TurnResult (untyped to avoid circular dependency with TurnPipeline).
func advance_turn(intents: Array):
	var pipeline_script = load("res://game/simulation/turn_pipeline.gd")
	var result = pipeline_script.resolve_turn(self, intents)
	last_turn_financials = result.financials
	current_turn += 1
	turn_resolved.emit(result.turn_number)
	if result.game_over:
		var reason := "bankruptcy" if result.bankruptcies.size() > 0 else "final_turn"
		var winner_id: String = result.winner.get("carrier_id", "")
		game_over.emit(winner_id, reason)
	return result
