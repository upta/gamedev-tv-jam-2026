class_name TurnPresentationOverlay
extends CanvasLayer

## Full-screen turn presentation sequence.
## Reveals NPC actions line-by-line, then shows a detailed player summary.

signal presentation_complete

const LINE_REVEAL_DELAY: float = 1.0
const POST_REVEAL_DELAY: float = 1.5

var _summaries: Dictionary = {}
var _player_id: String = ""
var _npc_queue: Array = []
var _current_npc_index: int = -1
var _showing_player_summary: bool = false
var _active: bool = false
var _game_state: GameState
var _prev_financials: Dictionary = {}

# Line-by-line reveal state
var _pending_lines: Array[String] = []
var _revealed_lines: Array[String] = []
var _line_timer: float = 0.0
var _all_lines_revealed: bool = false

@onready var _overlay: ColorRect = %Overlay
@onready var _title_label: Label = %TitleLabel
@onready var _content: RichTextLabel = %Content
@onready var _skip_hint: Label = %SkipHint
@onready var _continue_button: Button = %ContinueButton
@onready var _progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	_overlay.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)


func _process(delta: float) -> void:
	if not _active or _showing_player_summary:
		return

	_line_timer -= delta
	if _line_timer > 0.0:
		return

	if _pending_lines.size() > 0:
		# Reveal next line
		_revealed_lines.append(_pending_lines.pop_front())
		_content.text = "\n".join(_revealed_lines)
		_line_timer = LINE_REVEAL_DELAY
	elif not _all_lines_revealed:
		# All lines shown — start post-reveal pause
		_all_lines_revealed = true
		_line_timer = POST_REVEAL_DELAY
	else:
		# Post-reveal pause done — advance
		_advance_npc()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _showing_player_summary:
				_finish()
			else:
				_show_player_summary()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if _showing_player_summary:
				_finish()


func present_turn(summaries: Dictionary, player_id: String, game_state: GameState = null, prev_financials: Dictionary = {}) -> void:
	_summaries = summaries
	_player_id = player_id
	_game_state = game_state
	_prev_financials = prev_financials
	_showing_player_summary = false
	_active = true
	_current_npc_index = -1

	# Build NPC queue (skip player, skip NPCs with no actions and no financials)
	_npc_queue = []
	for carrier_id: String in summaries:
		if carrier_id == player_id:
			continue
		var summary: TurnSummaryBuilder.CarrierTurnSummary = summaries[carrier_id]
		if summary.actions.size() > 0 or summary.net != 0.0:
			_npc_queue.append(carrier_id)

	_overlay.visible = true
	_continue_button.visible = false
	_progress_bar.visible = false
	_skip_hint.text = "Press Escape to skip to your summary"
	_skip_hint.visible = true

	if _npc_queue.size() > 0:
		_advance_npc()
	else:
		_show_player_summary()


func _advance_npc() -> void:
	_current_npc_index += 1
	if _current_npc_index >= _npc_queue.size():
		_show_player_summary()
		return

	var carrier_id: String = _npc_queue[_current_npc_index]
	var summary: TurnSummaryBuilder.CarrierTurnSummary = _summaries[carrier_id]

	_title_label.text = summary.carrier_name
	_content.text = ""
	_continue_button.visible = false

	# Set up line-by-line reveal
	_pending_lines = _build_npc_lines(summary)
	_revealed_lines = []
	_all_lines_revealed = false
	_line_timer = 0.3  # Brief initial delay before first line


func _show_player_summary() -> void:
	_showing_player_summary = true
	_pending_lines = []
	_progress_bar.visible = false
	_continue_button.visible = true
	_skip_hint.text = "Press Enter or Escape to continue"

	if not _summaries.has(_player_id):
		_finish()
		return

	var summary: TurnSummaryBuilder.CarrierTurnSummary = _summaries[_player_id]
	var turn_num: int = 0
	if _game_state:
		turn_num = _game_state.current_turn - 1

	_title_label.text = "Your Turn %d Summary" % turn_num
	_content.text = _build_player_content(summary)


func _build_npc_lines(summary: TurnSummaryBuilder.CarrierTurnSummary) -> Array[String]:
	var lines: Array[String] = []

	for action: String in summary.actions:
		lines.append("[indent]• %s[/indent]" % action)

	if lines.size() == 0:
		lines.append("[indent][i]No notable actions[/i][/indent]")

	lines.append("")
	lines.append("Revenue: §%.0f | Costs: §%.0f | Net: %s§%.0f" % [
		summary.total_revenue, summary.total_costs + summary.slot_upkeep,
		"+" if summary.net >= 0 else "-", absf(summary.net),
	])
	lines.append("Cash: §%.0f → §%.0f" % [summary.cash_before, summary.cash_after])

	return lines


func _build_player_content(summary: TurnSummaryBuilder.CarrierTurnSummary) -> String:
	var lines: Array[String] = []

	# Routes section
	if summary.route_financials.size() > 0:
		lines.append("[b]Routes:[/b]")
		for rf: Dictionary in summary.route_financials:
			var origin_name := _get_planet_name(rf.get("origin_id", ""))
			var dest_name := _get_planet_name(rf.get("dest_id", ""))
			var pax_str := "Pax: %d/%d" % [rf.get("pax_served", 0), rf.get("pax_capacity", 0)]
			var cargo_str := "Cargo: %d/%d" % [rf.get("cargo_served", 0), rf.get("cargo_capacity", 0)]

			# Deltas from previous turn
			var pax_delta_str := ""
			var cargo_delta_str := ""
			var profit_delta_str := ""
			if _prev_financials.has(_player_id):
				var prev_routes: Array = _prev_financials[_player_id].get("routes", [])
				for prev_rs: Dictionary in prev_routes:
					if prev_rs.get("route_id", "") == rf.get("route_id", ""):
						var prev_pax: int = prev_rs.get("passengers_served", 0)
						var prev_cargo: int = prev_rs.get("cargo_served", 0)
						var prev_rev_dict: Dictionary = prev_rs.get("revenue", {})
						var prev_revenue: float = prev_rev_dict.get("total_revenue", 0.0)
						var prev_cost: float = prev_rs.get("operating_cost", 0.0)
						var prev_profit: float = prev_revenue - prev_cost
						var pax_diff: int = rf.get("pax_served", 0) - prev_pax
						var cargo_diff: int = rf.get("cargo_served", 0) - prev_cargo
						var profit_diff: float = rf.get("profit", 0.0) - prev_profit
						if pax_diff != 0:
							pax_delta_str = " (%s%d)" % ["+" if pax_diff > 0 else "", pax_diff]
						if cargo_diff != 0:
							cargo_delta_str = " (%s%d)" % ["+" if cargo_diff > 0 else "", cargo_diff]
						if absf(profit_diff) >= 1.0:
							var delta_color := "green" if profit_diff > 0 else "red"
							profit_delta_str = " [color=%s](%s§%.0f)[/color]" % [
								delta_color, "+" if profit_diff > 0 else "", profit_diff,
							]
						break

			var profit: float = rf.get("profit", 0.0)
			var profit_color := "green" if profit >= 0 else "red"
			var profit_str := "[color=%s]%s§%.0f[/color]%s" % [
				profit_color, "+" if profit >= 0 else "-", absf(profit), profit_delta_str,
			]

			lines.append("[indent]%s → %s    %s%s  %s%s  Profit: %s[/indent]" % [
				origin_name, dest_name,
				pax_str, pax_delta_str,
				cargo_str, cargo_delta_str,
				profit_str,
			])
		lines.append("")

	# Events section
	if _game_state and _game_state.events.size() > 0:
		var event_lines: Array[String] = []
		for event in _game_state.events:
			if event.has_method("get") or true:
				# Use event_descriptions from the result if available
				pass
		# Use the game state events display
		var active_descs := EventSystem.get_active_event_descriptions(_game_state.events)
		if active_descs.size() > 0:
			lines.append("[b]Events:[/b]")
			for desc: String in active_descs:
				lines.append("[indent]• %s[/indent]" % desc)
			lines.append("")

	# Financials section
	lines.append("[b]Financials:[/b]")
	lines.append("[indent]Revenue: §%.0f | Costs: §%.0f | Slot Upkeep: §%.0f | Net: %s§%.0f[/indent]" % [
		summary.total_revenue, summary.total_costs, summary.slot_upkeep,
		"+" if summary.net >= 0 else "-", absf(summary.net),
	])
	lines.append("[indent]Cash: §%.0f → §%.0f[/indent]" % [summary.cash_before, summary.cash_after])
	lines.append("")

	# Other section
	var other_lines: Array[String] = []
	for delivery: Dictionary in summary.ships_delivered:
		other_lines.append("• Ship delivered: %s" % delivery.get("type_id", ""))
	for slot: Dictionary in summary.slots_won:
		var pname := _get_planet_name(slot.get("planet_id", ""))
		other_lines.append("• Won %d slot%s at %s" % [
			slot.get("count", 0), "s" if slot.get("count", 0) != 1 else "", pname,
		])
	for slot: Dictionary in summary.slots_lost:
		var pname := _get_planet_name(slot.get("planet_id", ""))
		other_lines.append("• Lost bid at %s" % pname)
	for order: Dictionary in summary.ships_ordered:
		other_lines.append("• Ordered %s" % order.get("type_id", ""))

	if other_lines.size() > 0:
		lines.append("[b]Other:[/b]")
		for line: String in other_lines:
			lines.append("[indent]%s[/indent]" % line)

	return "\n".join(lines)


func _get_planet_name(planet_id: String) -> String:
	if _game_state:
		var planet := _game_state.galaxy.get_planet(planet_id)
		if planet:
			return planet.name
	return planet_id


func _on_continue_pressed() -> void:
	_finish()


func _finish() -> void:
	_active = false
	_overlay.visible = false
	presentation_complete.emit()
