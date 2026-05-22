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


func _build_pages() -> void:
	_pages = [
		{
			"title": "Welcome to Astrobiz",
			"content": (
				"You are the CEO of [b]Player Corp[/b], a fledgling space transport company.\n\n"
				+ "Your mission: build a profitable interstellar airline by flying passengers and "
				+ "cargo between planets. Three rival carriers are competing for the same routes.\n\n"
				+ "The game runs for [b]30 turns[/b]. Highest score wins."
			),
		},
		{
			"title": "Your Starting Assets",
			"content": (
				"You begin with:\n\n"
				+ "  -  [b]$3,000[/b] in cash\n"
				+ "  -  [b]1 shuttle[/b] (SD-100 -- 40 capacity, split between passengers and cargo)\n"
				+ "  -  [b]2 landing slots[/b] at Earth and Mars\n\n"
				+ "Landing slots give you the right to operate at a planet. "
				+ "You need a slot at both ends of any route you create."
			),
		},
		{
			"title": "Creating Routes",
			"content": (
				"Routes are how you make money. To create one:\n\n"
				+ "  1.  Click [b]Routes[/b] in the top bar\n"
				+ "  2.  Click [b]Create Route[/b]\n"
				+ "  3.  Pick an origin and destination (you need slots at both)\n"
				+ "  4.  Assign ships and set flight frequency\n\n"
				+ "[b]Tip:[/b] Start with a route between Earth and Mars -- you already have slots there!"
			),
		},
		{
			"title": "Growing Your Network",
			"content": (
				"To expand beyond your starting planets:\n\n"
				+ "  -  [b]Slots[/b] -- Bid on landing slots at new planets. Costs money and takes a turn to process. "
				+ "Other carriers are bidding too!\n\n"
				+ "  -  [b]Ships[/b] -- Order new ships to increase your capacity. Bigger ships unlock at later turns "
				+ "and take several turns to build.\n\n"
				+ "Hover over planets on the star map to see demand levels and slot availability."
			),
		},
		{
			"title": "Each Turn",
			"content": (
				"Click [b]Next Turn[/b] when you're ready to advance. Each turn:\n\n"
				+ "  -  Your routes operate and earn (or lose) money\n"
				+ "  -  Ship orders and slot bids are processed\n"
				+ "  -  NPC carriers take their actions\n"
				+ "  -  You'll see a summary of everything that happened\n\n"
				+ "Use the [b]Dashboard[/b] to track your finances and the [b]Turn Log[/b] to review past turns."
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
