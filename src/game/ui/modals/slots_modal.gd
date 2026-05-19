class_name SlotsModal
extends ModalDialog

## Modal showing slot holdings and pending slot actions.
## Slot bidding/selling is handled by ManageSlotsModal, opened via "Buy/Sell Slots" button.

signal manage_slots_requested

var _player_controller: PlayerController
var _game_state: GameState

var _content_vbox: VBoxContainer


func _ready() -> void:
	super()
	set_title("Planet Slots")


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state
	_player_controller.intent_changed.connect(_on_intent_changed)


func open() -> void:
	super.open()
	refresh()


func refresh() -> void:
	var scroll: ScrollContainer = get_content_container().get_child(0) as ScrollContainer
	for child in scroll.get_children():
		child.queue_free()

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_vbox)

	_build_holdings_section()
	_build_pending_section()
	_build_manage_button()


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

func _build_holdings_section() -> void:
	_add_section_header("Your Slot Holdings")

	var carrier := _game_state.get_player_carrier()
	if carrier.slots.is_empty():
		var lbl := Label.new()
		lbl.text = "No slots owned."
		_content_vbox.add_child(lbl)
		return

	for planet_id: String in carrier.slots:
		var count: int = carrier.slots[planet_id]
		if count <= 0:
			continue
		var planet: GalaxyData.Planet = _game_state.galaxy.get_planet(planet_id)
		var planet_name := planet.name if planet else planet_id
		var available: int = carrier.get_available_slots_at(planet_id)
		var lbl := Label.new()
		lbl.text = "%s: %d owned, %d available" % [planet_name, count, available]
		_content_vbox.add_child(lbl)


func _build_pending_section() -> void:
	_add_section_header("Pending Slot Actions")

	var intent := _player_controller.pending_intent
	var has_actions := false

	for i in intent.slot_bids.size():
		has_actions = true
		var bid: Dictionary = intent.slot_bids[i]
		var planet: GalaxyData.Planet = _game_state.galaxy.get_planet(bid["planet_id"])
		var planet_name: String = planet.name if planet else str(bid["planet_id"])
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "Bid: %s x %d @ $%.0f/slot" % [planet_name, bid["quantity"], bid["price_per_slot"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		var idx := i
		cancel_btn.pressed.connect(func() -> void: _player_controller.remove_slot_bid(idx))
		row.add_child(cancel_btn)
		_content_vbox.add_child(row)

	for i in intent.slot_sales.size():
		has_actions = true
		var sale: Dictionary = intent.slot_sales[i]
		var planet: GalaxyData.Planet = _game_state.galaxy.get_planet(sale["planet_id"])
		var planet_name: String = planet.name if planet else str(sale["planet_id"])
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "Sell: %s x %d" % [planet_name, sale["count"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		var idx := i
		cancel_btn.pressed.connect(func() -> void: _player_controller.remove_slot_sale(idx))
		row.add_child(cancel_btn)
		_content_vbox.add_child(row)

	if not has_actions:
		var lbl := Label.new()
		lbl.text = "No pending actions."
		_content_vbox.add_child(lbl)


# ---------------------------------------------------------------------------
# Buy/Sell Button
# ---------------------------------------------------------------------------

func _build_manage_button() -> void:
	_content_vbox.add_child(HSeparator.new())
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var manage_btn := Button.new()
	manage_btn.text = "Buy / Sell Slots"
	manage_btn.pressed.connect(func() -> void: manage_slots_requested.emit())
	btn_row.add_child(manage_btn)
	_content_vbox.add_child(btn_row)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _add_section_header(text: String) -> void:
	var sep := HSeparator.new()
	_content_vbox.add_child(sep)
	var lbl := Label.new()
	lbl.text = text
	_content_vbox.add_child(lbl)


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_intent_changed(_intent: TurnPipeline.CarrierIntent) -> void:
	if visible:
		refresh()
