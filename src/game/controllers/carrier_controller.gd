class_name CarrierController
extends RefCounted

## Base class for all carrier controllers.
## Given game state and a carrier ID, produces a CarrierIntent for the turn.


func generate_intent(game_state: GameState, carrier_id: String) -> TurnPipeline.CarrierIntent:
	# Default implementation returns empty intent (do-nothing)
	var intent := TurnPipeline.CarrierIntent.new()
	intent.carrier_id = carrier_id
	return intent
