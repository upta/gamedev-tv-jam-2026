class_name TurnLogPanel
extends PanelContainer

## Scrollable read-only panel displaying turn-by-turn results history.

const COLOR_POSITIVE := "#3DEAAB"
const COLOR_NEGATIVE := "#FF5959"
const COLOR_EVENT := "#FFC73D"

var _game_state: GameState

@onready var _log_entries: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/LogEntries
@onready var _scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer


func _ready() -> void:
	pass


func set_game_state(game_state: GameState) -> void:
	_game_state = game_state


func add_turn_result(turn_number: int, result: TurnPipeline.TurnResult, carrier_id: String) -> void:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.selection_enabled = false
	rtl.text = _build_turn_bbcode(turn_number, result, carrier_id)

	# Prepend — newest turn at top
	_log_entries.add_child(rtl)
	_log_entries.move_child(rtl, 0)

	# Add separator after new entry (if there are older entries below)
	if _log_entries.get_child_count() > 1:
		var sep := HSeparator.new()
		_log_entries.add_child(sep)
		_log_entries.move_child(sep, 1)

	# Scroll to top to show newest
	await get_tree().process_frame
	_scroll_container.scroll_vertical = 0


func clear_log() -> void:
	for child: Node in _log_entries.get_children():
		child.queue_free()


func _build_turn_bbcode(turn_number: int, result: TurnPipeline.TurnResult, carrier_id: String) -> String:
	var lines: PackedStringArray = PackedStringArray()

	# Header
	lines.append("[b]Turn %d[/b]" % turn_number)

	# Financials
	var fin: Dictionary = result.financials.get(carrier_id, {})
	if not fin.is_empty():
		var revenue: float = fin.get("total_revenue", 0.0)
		var costs: float = fin.get("total_costs", 0.0)
		var net: float = fin.get("net", 0.0)
		var net_color: String = COLOR_POSITIVE if net >= 0 else COLOR_NEGATIVE
		var net_sign: String = "+" if net >= 0 else ""
		lines.append(
			"Revenue: [color=%s]§%d[/color] | Costs: [color=%s]§%d[/color] | Net: [color=%s]§%s%d[/color]" % [
				COLOR_POSITIVE, int(revenue),
				COLOR_NEGATIVE, int(costs),
				net_color, net_sign, int(net),
			]
		)

	# Auction results
	_append_auction_lines(result, carrier_id, lines)

	# Ship deliveries
	for delivery: Dictionary in result.deliveries:
		if delivery.get("carrier_id", "") == carrier_id:
			var type_id: String = delivery.get("type_id", "ship")
			lines.append("[color=%s]Ship %s delivered![/color]" % [COLOR_POSITIVE, _get_ship_name(type_id)])

	# Events
	for desc: String in result.event_descriptions:
		lines.append("[color=%s]%s[/color]" % [COLOR_EVENT, desc])

	# Newly available ships
	if _game_state and _game_state.catalog:
		for ship_type: ShipCatalog.ShipType in _game_state.catalog.get_available_types(turn_number):
			if ship_type.unlock_turn == turn_number and ship_type.unlock_turn > 0:
				lines.append("[color=%s]New ship available: %s (%d cap, range %.0f, §%dk)[/color]" % [
					COLOR_EVENT, ship_type.name, ship_type.max_capacity,
					ship_type.range, ship_type.cost / 1000,
				])

	# Ranking
	for entry: Dictionary in result.rankings:
		if entry.get("carrier_id", "") == carrier_id:
			var rank: int = entry.get("rank", 0)
			var total: int = result.rankings.size()
			lines.append("Rank: %d/%d" % [rank, total])
			break

	return "\n".join(lines)


func _append_auction_lines(result: TurnPipeline.TurnResult, carrier_id: String, lines: PackedStringArray) -> void:
	var auction: Dictionary = result.auction_results
	if auction.is_empty():
		return

	for award: Dictionary in auction.get("awards", []):
		if award.get("carrier_id", "") == carrier_id:
			var planet_id: String = award.get("planet_id", "")
			var slots_won: int = award.get("slots_won", 0)
			lines.append("[color=%s]Won %d slot(s) at %s[/color]" % [COLOR_POSITIVE, slots_won, _get_planet_name(planet_id)])

	for rejection: Dictionary in auction.get("rejections", []):
		if rejection.get("carrier_id", "") == carrier_id:
			var planet_id: String = rejection.get("planet_id", "")
			lines.append("[color=%s]Lost bid at %s[/color]" % [COLOR_NEGATIVE, _get_planet_name(planet_id)])


func _get_ship_name(type_id: String) -> String:
	if _game_state and _game_state.catalog:
		var ship_type := _game_state.catalog.get_type(type_id)
		if ship_type:
			return ship_type.name
	return type_id


func _get_planet_name(planet_id: String) -> String:
	if _game_state and _game_state.galaxy:
		var planet := _game_state.galaxy.get_planet(planet_id)
		if planet:
			return planet.name
	return planet_id
