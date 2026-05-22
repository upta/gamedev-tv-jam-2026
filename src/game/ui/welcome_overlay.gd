class_name WelcomeOverlay
extends CanvasLayer

## In-game tutorial shown at first launch. Click or press any key to advance pages.

signal tutorial_complete

const BODY_SIZE := 16
const ICON_SIZE := 18

var _page_builders: Array[Callable] = []
var _current_page: int = 0
var _active: bool = false
var _font_bold: Font
var _pax_tex: ImageTexture
var _cargo_tex: ImageTexture
var _fuel_tex: ImageTexture

@onready var _overlay: ColorRect = %Overlay
@onready var _title_label: Label = %TitleLabel
@onready var _content: VBoxContainer = %Content
@onready var _page_indicator: Label = %PageIndicator
@onready var _continue_hint: Label = %ContinueHint
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)

	_font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	_pax_tex = ThemeBuilder.load_icon_texture(ThemeBuilder.ICON_PAX, ICON_SIZE)
	_cargo_tex = ThemeBuilder.load_icon_texture(ThemeBuilder.ICON_CARGO, ICON_SIZE)
	_fuel_tex = ThemeBuilder.load_icon_texture(ThemeBuilder.ICON_FUEL, ICON_SIZE)

	_register_pages()

	# Apply game theme (CanvasLayer doesn't inherit parent theme)
	var margin_container: MarginContainer = _overlay.get_node("MarginContainer")
	margin_container.theme = ThemeBuilder.build_theme()

	# Style the overlay background
	_overlay.color = Color(ThemeBuilder.SURFACE.r, ThemeBuilder.SURFACE.g, ThemeBuilder.SURFACE.b, 0.95)

	# Title: heading font + accent color
	if _font_bold:
		_title_label.add_theme_font_override("font", _font_bold)
	_title_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT)

	# Page indicator and continue hint colors
	_page_indicator.add_theme_color_override("font_color", ThemeBuilder.MUTED)
	_continue_hint.add_theme_color_override("font_color", ThemeBuilder.TEXT)


func show_tutorial() -> void:
	_current_page = 0
	_active = true
	_overlay.visible = true
	_show_current_page()


# ---------------------------------------------------------------------------
# Node builders
# ---------------------------------------------------------------------------

func _label(text: String, color: Color = ThemeBuilder.TEXT, bold: bool = false, size: int = BODY_SIZE) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold and _font_bold:
		lbl.add_theme_font_override("font", _font_bold)
	return lbl


func _section_header(text: String) -> Label:
	return _label(text.to_upper(), ThemeBuilder.ACCENT, true, 13)


func _spacer(height: int = 8) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = height
	return s


func _bullet(parts: Array) -> HBoxContainer:
	## parts is Array of [text, color] pairs rendered inline after a bullet dot.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var dot := _label("  •  ", ThemeBuilder.MUTED)
	dot.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(dot)

	for i: int in range(parts.size()):
		var part: Array = parts[i]
		var lbl := _label(part[0] as String, part[1] as Color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(lbl)
	return row


func _icon_bullet(tex: ImageTexture, parts: Array) -> HBoxContainer:
	## Like _bullet but with an icon before the first text part.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var dot := _label("  •  ", ThemeBuilder.MUTED)
	dot.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(dot)

	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		row.add_child(icon)

	for part: Array in parts:
		var lbl := _label(part[0] as String, part[1] as Color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(lbl)
	return row


func _step(number: int, parts: Array) -> HBoxContainer:
	## Numbered step like "1. Click Routes in the top bar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var num_lbl := _label("  %d.  " % number, ThemeBuilder.MUTED)
	num_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(num_lbl)

	for part: Array in parts:
		var lbl := _label(part[0] as String, part[1] as Color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(lbl)
	return row


# ---------------------------------------------------------------------------
# Page definitions
# ---------------------------------------------------------------------------

func _register_pages() -> void:
	_page_builders = [
		_build_welcome,
		_build_starting_assets,
		_build_creating_routes,
		_build_star_map,
		_build_growing_network,
	]


func _build_welcome() -> void:
	_title_label.text = "Welcome to Astrobiz"
	_content.add_child(_label(
		"You are the CEO of Player Corp, a fledgling space transport company.",
	))
	_content.add_child(_spacer())
	_content.add_child(_label(
		"Your mission: build a profitable interstellar airline by flying "
		+ "passengers and cargo between planets. Three rival carriers are "
		+ "competing for the same routes.",
	))
	_content.add_child(_spacer())
	_content.add_child(_label(
		"The game runs for 30 turns. Highest score wins.",
	))


func _build_starting_assets() -> void:
	_title_label.text = "Your Starting Assets"
	_content.add_child(_label("You begin with:"))
	_content.add_child(_spacer(4))
	_content.add_child(_bullet([["§30,000", ThemeBuilder.ACCENT], [" in cash", ThemeBuilder.TEXT]]))
	_content.add_child(_bullet([["1 ship", ThemeBuilder.ACCENT]]))
	_content.add_child(_bullet([["2 landing slots", ThemeBuilder.ACCENT], [" at Earth and Mars", ThemeBuilder.TEXT]]))
	_content.add_child(_spacer())
	_content.add_child(_section_header("Slots"))
	_content.add_child(_label(
		"Landing slots give you the right to operate at a planet. "
		+ "You need a slot at both ends of any route you create.",
	))


func _build_creating_routes() -> void:
	_title_label.text = "Creating Routes"
	_content.add_child(_section_header("From the Toolbar"))
	_content.add_child(_step(1, [["Click ", ThemeBuilder.TEXT], ["Routes", ThemeBuilder.ACCENT], [" in the top bar", ThemeBuilder.TEXT]]))
	_content.add_child(_step(2, [["Click ", ThemeBuilder.TEXT], ["Create Route", ThemeBuilder.ACCENT]]))
	_content.add_child(_step(3, [["Pick an origin and destination", ThemeBuilder.TEXT]]))
	_content.add_child(_step(4, [["Assign ships and set flight frequency", ThemeBuilder.TEXT]]))
	_content.add_child(_spacer())
	_content.add_child(_section_header("From the Star Map"))
	_content.add_child(_label(
		"Click a planet to enter guide mode — a dashed line follows your "
		+ "cursor. Hover another planet to see the route distance, then "
		+ "click it to jump straight into route creation with both planets "
		+ "pre-selected.",
	))
	_content.add_child(_spacer(4))
	_content.add_child(_label(
		"Tip: Start with Earth ↔ Mars — you already have slots there!",
		ThemeBuilder.MUTED,
	))


func _build_star_map() -> void:
	_title_label.text = "The Star Map"
	_content.add_child(_section_header("Hover"))
	_content.add_child(_label(
		"Hover over any planet to see its demand levels, slot availability, "
		+ "and active routes.",
	))
	_content.add_child(_spacer())
	_content.add_child(_section_header("Click — Guide Mode"))
	_content.add_child(_label(
		"Click a planet to draw a guide line to your cursor. Hover a second "
		+ "planet to see the distance between them. Click the second planet "
		+ "to create a route.",
	))
	_content.add_child(_spacer())
	_content.add_child(_section_header("Right-Click — Planet Menu"))
	_content.add_child(_label(
		"Right-click a planet to open a quick menu where you can purchase "
		+ "a landing slot directly.",
	))


func _build_growing_network() -> void:
	_title_label.text = "Growing Your Network"
	_content.add_child(_section_header("Slots"))
	_content.add_child(_label(
		"Bid on landing slots at new planets. Costs money and takes a turn "
		+ "to process. Other carriers are bidding too! You can also "
		+ "right-click a planet on the star map to buy a slot directly.",
	))
	_content.add_child(_spacer())
	_content.add_child(_section_header("Ships"))
	_content.add_child(_label(
		"Order new ships to increase capacity. New ship types become "
		+ "available as the game progresses. Each ship has three key stats:",
	))
	_content.add_child(_spacer(4))
	_content.add_child(_icon_bullet(_pax_tex, [["Passengers", ThemeBuilder.ACCENT], [" — lower demand, higher margin", ThemeBuilder.TEXT]]))
	_content.add_child(_icon_bullet(_cargo_tex, [["Cargo", ThemeBuilder.ACCENT], [" — higher demand, lower margin", ThemeBuilder.TEXT]]))
	_content.add_child(_icon_bullet(_fuel_tex, [["Fuel", ThemeBuilder.ACCENT], [" — efficiency rating; affects operating costs", ThemeBuilder.TEXT]]))


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _show_current_page() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	_page_builders[_current_page].call()
	_page_indicator.text = "%d / %d" % [_current_page + 1, _page_builders.size()]

	var is_last: bool = _current_page >= _page_builders.size() - 1
	_continue_hint.visible = not is_last
	_start_button.visible = is_last


func _advance_page() -> void:
	if _current_page < _page_builders.size() - 1:
		_current_page += 1
		_show_current_page()


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _current_page < _page_builders.size() - 1:
				_advance_page()
				get_viewport().set_input_as_handled()

	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_RIGHT:
				if _current_page < _page_builders.size() - 1:
					_advance_page()
					get_viewport().set_input_as_handled()
				elif _start_button.visible:
					_on_start_pressed()
					get_viewport().set_input_as_handled()
			elif key.keycode == KEY_LEFT:
				if _current_page > 0:
					_current_page -= 1
					_show_current_page()
					get_viewport().set_input_as_handled()
			elif key.keycode == KEY_ESCAPE:
				_on_start_pressed()
				get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	_active = false
	_overlay.visible = false
	tutorial_complete.emit()
