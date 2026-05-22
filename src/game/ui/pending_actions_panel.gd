class_name PendingActionsPanel
extends PanelContainer

var _game_state: GameState
var _carrier_id: String
var _player_controller: PlayerController
var _content: VBoxContainer


func _ready() -> void:
	_apply_style()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	_content = VBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 2)
	margin.add_child(_content)

	var title := Label.new()
	title.text = "PENDING ACTIONS"
	title.add_theme_color_override("font_color", ThemeBuilder.MUTED)
	title.add_theme_font_size_override("font_size", 11)
	var font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_bold:
		title.add_theme_font_override("font", font_bold)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(title)


func bind(player_controller: PlayerController, game_state: GameState, carrier_id: String) -> void:
	_player_controller = player_controller
	_game_state = game_state
	_carrier_id = carrier_id
	refresh()


func refresh() -> void:
	if _content == null or _player_controller == null or _game_state == null:
		return

	# Clear everything except the title label
	var children := _content.get_children()
	for i in range(children.size() - 1, 0, -1):
		_content.remove_child(children[i])
		children[i].queue_free()

	var intent := _player_controller.pending_intent
	var has_anything := false

	# --- ROUTES ---
	var route_items: Array[String] = []
	for rc: Dictionary in intent.route_creates:
		var origin := _planet_name(rc.get("origin_id", ""))
		var dest := _planet_name(rc.get("dest_id", ""))
		route_items.append("Start|%s → %s" % [origin, dest])
	for rm: Dictionary in intent.route_modifications:
		var route_id: String = rm.get("route_id", "")
		var route := _find_route(route_id)
		if route:
			var origin := _planet_name(route.origin_id)
			var dest := _planet_name(route.dest_id)
			route_items.append("Edit|%s → %s" % [origin, dest])
		else:
			route_items.append("Edit|Route %s" % route_id)
	for route_id: String in intent.route_cancellations:
		var route := _find_route(route_id)
		if route:
			var origin := _planet_name(route.origin_id)
			var dest := _planet_name(route.dest_id)
			route_items.append("End|%s → %s" % [origin, dest])
		else:
			route_items.append("End|Route %s" % route_id)
	if not route_items.is_empty():
		has_anything = true
		_add_section("ROUTES", route_items)
	else:
		_add_section_empty("ROUTES")

	# --- SHIPS ---
	_add_spacer()
	var ship_items: Array[String] = []
	var ship_counts: Dictionary = {}
	for order: Dictionary in intent.ship_orders:
		var type_id: String = order.get("type_id", "Ship")
		ship_counts[type_id] = ship_counts.get(type_id, 0) + 1
	for type_id: String in ship_counts:
		var count: int = ship_counts[type_id]
		var display_name := _ship_display_name(type_id)
		if count > 1:
			ship_items.append("Order|%s (%d)" % [display_name, count])
		else:
			ship_items.append("Order|%s" % display_name)
	if not ship_items.is_empty():
		has_anything = true
		_add_section("SHIPS", ship_items)
	else:
		_add_section_empty("SHIPS")

	# --- SLOTS ---
	_add_spacer()
	var slot_items: Array[String] = []
	for bid: Dictionary in intent.slot_bids:
		var planet := _planet_name(bid.get("planet_id", ""))
		var qty: int = bid.get("quantity", 1)
		if qty > 1:
			slot_items.append("Buy|%s (%d)" % [planet, qty])
		else:
			slot_items.append("Buy|%s" % planet)
	for sale: Dictionary in intent.slot_sales:
		var planet := _planet_name(sale.get("planet_id", ""))
		var count: int = sale.get("count", 1)
		if count > 1:
			slot_items.append("Sell|%s (%d)" % [planet, count])
		else:
			slot_items.append("Sell|%s" % planet)
	if not slot_items.is_empty():
		has_anything = true
		_add_section("SLOTS", slot_items)
	else:
		_add_section_empty("SLOTS")


func _add_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(spacer)


func _add_section(header_text: String, items: Array[String]) -> void:
	var header := Label.new()
	header.text = header_text
	header.add_theme_color_override("font_color", ThemeBuilder.MUTED)
	header.add_theme_font_size_override("font_size", 10)
	var font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_bold:
		header.add_theme_font_override("font", font_bold)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(header)

	for item: String in items:
		var parts := item.split("|", true, 1)
		var action_text: String = parts[0]
		var detail_text: String = parts[1] if parts.size() > 1 else ""
		_content.add_child(_create_action_row(action_text, detail_text))


func _add_section_empty(header_text: String) -> void:
	var header := Label.new()
	header.text = header_text
	header.add_theme_color_override("font_color", ThemeBuilder.MUTED)
	header.add_theme_font_size_override("font_size", 10)
	var font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_bold:
		header.add_theme_font_override("font", font_bold)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(header)

	var none_label := Label.new()
	none_label.text = "None"
	none_label.add_theme_font_size_override("font_size", 11)
	none_label.add_theme_color_override("font_color", ThemeBuilder.TEXT)
	none_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(none_label)


func _create_action_row(action_text: String, detail_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)

	# Action badge (green label)
	var badge := Label.new()
	badge.text = action_text
	badge.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	badge.add_theme_font_size_override("font_size", 11)
	var font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_bold:
		badge.add_theme_font_override("font", font_bold)
	badge.custom_minimum_size.x = 40
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)

	# Detail text
	var detail := Label.new()
	detail.text = detail_text
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", ThemeBuilder.TEXT)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(detail)

	return row


func _planet_name(planet_id: String) -> String:
	if _game_state and _game_state.galaxy:
		var planet := _game_state.galaxy.get_planet(planet_id)
		if planet:
			return planet.name
	return planet_id


func _ship_display_name(type_id: String) -> String:
	if _game_state and _game_state.catalog:
		var ship_type := _game_state.catalog.get_type(type_id)
		if ship_type:
			return ship_type.name
	return type_id


func _find_route(route_id: String) -> CarrierData.Route:
	var carrier := _game_state.get_carrier(_carrier_id)
	if carrier:
		for route: CarrierData.Route in carrier.routes:
			if route.id == route_id:
				return route
	return null


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	var bg := ThemeBuilder.SURFACE
	bg.a = 0.85
	style.bg_color = bg
	style.border_color = ThemeBuilder.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
