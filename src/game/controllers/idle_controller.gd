class_name IdleController
extends CarrierController

## Controller that does nothing every turn.
## Used for: headless player slot (no UI yet), testing individual systems,
## parking a carrier that shouldn't act.


func generate_intent(game_state: GameState, carrier_id: String) -> TurnPipeline.CarrierIntent:
	var intent := TurnPipeline.CarrierIntent.new()
	intent.carrier_id = carrier_id
	return intent
