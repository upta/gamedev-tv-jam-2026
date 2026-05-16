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
var demand_table = null  # Placeholder for DemandData (P1.7)
var events: Array = []

var _carrier_index: Dictionary = {}  # id -> CarrierData


func initialize(p_galaxy: GalaxyData, p_catalog: ShipCatalog, p_carriers: Array) -> void:
	galaxy = p_galaxy
	catalog = p_catalog
	carriers = p_carriers
	current_turn = 1
	demand_table = null
	events = []
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
