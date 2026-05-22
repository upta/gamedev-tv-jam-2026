class_name WelcomeOverlay
extends CanvasLayer

## In-game tutorial shown at first launch. Click or press any key to advance pages.

signal tutorial_complete

var _pages: Array[Dictionary] = []
var _current_page: int = 0
var _active: bool = false

@onready var _overlay: ColorRect = %Overlay
@onready var _title_label: Label = %TitleLabel
@onready var _content: RichTextLabel = %Content
@onready var _page_indicator: Label = %PageIndicator
@onready var _continue_hint: Label = %ContinueHint
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_build_pages()

	# Apply game theme (CanvasLayer doesn't inherit parent theme)
	var margin_container: MarginContainer = _overlay.get_node("MarginContainer")
	margin_container.theme = ThemeBuilder.build_theme()

	# Style the overlay background
	_overlay.color = Color(ThemeBuilder.SURFACE.r, ThemeBuilder.SURFACE.g, ThemeBuilder.SURFACE.b, 0.95)

	# Title: heading font + accent color
	var font_heading = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_heading:
		_title_label.add_theme_font_override("font", font_heading)
	_title_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT)

	# Page indicator and continue hint colors
	_page_indicator.add_theme_color_override("font_color", ThemeBuilder.MUTED)
	_continue_hint.add_theme_color_override("font_color", ThemeBuilder.TEXT)


func show_tutorial() -> void:
	_current_page = 0
	_active = true
	_overlay.visible = true
	_show_current_page()


func _section(text: String) -> String:
	return "[color=#3DEAAB]%s[/color]" % text.to_upper()


func _hl(text: String) -> String:
	return "[color=#3DEAAB]%s[/color]" % text


func _muted(text: String) -> String:
	return "[color=#73948C]%s[/color]" % text


func _build_pages() -> void:
	_pages = [
		{
			"title": "Welcome to Astrobiz",
			"content": (
				"You are the CEO of %s, a fledgling space transport company.\n\n" % _hl("Player Corp")
				+ "Your mission: build a profitable interstellar airline by flying passengers and "
				+ "cargo between planets. Three rival carriers are competing for the same routes.\n\n"
				+ "The game runs for %s. Highest score wins." % _hl("30 turns")
			),
		},
		{
			"title": "Your Starting Assets",
			"content": (
				"You begin with:\n\n"
				+ "  •  %s in cash\n" % _hl("$30,000")
				+ "  •  %s %s\n" % [_hl("1 shuttle"), _muted("(SD-100 — 40 capacity, passengers + cargo)")]
				+ "  •  %s at Earth and Mars\n\n" % _hl("2 landing slots")
				+ _section("Slots") + "\n"
				+ "Landing slots give you the right to operate at a planet. "
				+ "You need a slot at both ends of any route you create."
			),
		},
		{
			"title": "Creating Routes",
			"content": (
				_section("From the Toolbar") + "\n"
				+ "  1.  Click %s in the top bar\n" % _hl("Routes")
				+ "  2.  Click %s\n" % _hl("Create Route")
				+ "  3.  Pick an origin and destination\n"
				+ "  4.  Assign ships and set flight frequency\n\n"
				+ _section("From the Star Map") + "\n"
				+ "%s a planet to enter guide mode — a dashed line follows your cursor. " % _hl("Click")
				+ "Hover another planet to see the route distance, then %s it to jump " % _hl("click")
				+ "straight into route creation with both planets pre-selected.\n\n"
				+ _muted("Tip: Start with Earth ↔ Mars — you already have slots there!")
			),
		},
		{
			"title": "The Star Map",
			"content": (
				_section("Hover") + "\n"
				+ "Hover over any planet to see its demand levels, slot availability, and active routes.\n\n"
				+ _section("Click — Guide Mode") + "\n"
				+ "Click a planet to draw a guide line to your cursor. Hover a second planet to see "
				+ "the distance between them. Click the second planet to create a route.\n\n"
				+ _section("Right-Click — Planet Menu") + "\n"
				+ "Right-click a planet to open a quick menu where you can purchase a landing slot directly."
			),
		},
		{
			"title": "Growing Your Network",
			"content": (
				_section("Slots") + "\n"
				+ "Bid on landing slots at new planets. Costs money and takes a turn to process. "
				+ "Other carriers are bidding too! You can also right-click a planet on the star "
				+ "map to buy a slot directly.\n\n"
				+ _section("Ships") + "\n"
				+ "Order new ships to increase capacity. Bigger ships unlock at later turns "
				+ "and take several turns to build."
			),
		},
		{
			"title": "Each Turn",
			"content": (
				"Click %s when you're ready to advance.\n\n" % _hl("Next Turn")
				+ _section("What Happens") + "\n"
				+ "  •  Your routes operate and earn (or lose) money\n"
				+ "  •  Ship orders and slot bids are processed\n"
				+ "  •  NPC carriers take their actions\n"
				+ "  •  A summary of everything that happened is shown\n\n"
				+ _section("Tracking Progress") + "\n"
				+ "Use the %s to monitor finances, the %s to review " % [_hl("Dashboard"), _hl("Turn Log")]
				+ "past turns, and the standings panel to see how you rank."
			),
		},
	]


func _show_current_page() -> void:
	var page: Dictionary = _pages[_current_page]
	_title_label.text = page["title"]
	_content.text = page["content"]
	_page_indicator.text = "%d / %d" % [_current_page + 1, _pages.size()]

	var is_last: bool = _current_page >= _pages.size() - 1
	_continue_hint.visible = not is_last
	_start_button.visible = is_last


func _advance_page() -> void:
	if _current_page < _pages.size() - 1:
		_current_page += 1
		_show_current_page()


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _current_page < _pages.size() - 1:
				_advance_page()
				get_viewport().set_input_as_handled()

	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_RIGHT:
				if _current_page < _pages.size() - 1:
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
