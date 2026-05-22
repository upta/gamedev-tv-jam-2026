class_name ThemeBuilder
extends RefCounted

# Color palette - HUD / Sci-fi Control Console
const SURFACE := Color(0.055, 0.075, 0.075)        # #0E1313
const MODAL_SURFACE := Color(0.07, 0.10, 0.10)     # #121A1A
const TOP_BAR_BG := Color(0.05, 0.07, 0.07)        # #0D1212
const BORDER := Color(0.15, 0.30, 0.28)            # #264D47
const TEXT := Color(0.90, 0.96, 0.94)              # #E6F5F0
const MUTED := Color(0.45, 0.58, 0.55)             # #73948C
const ACCENT := Color(0.24, 0.92, 0.67)            # #3DEAAB
const POSITIVE := Color(0.24, 0.92, 0.67)          # #3DEAAB (same as accent)
const NEGATIVE := Color(1.0, 0.35, 0.35)           # #FF5959
const WARNING := Color(1.0, 0.78, 0.24)            # #FFC73D
const CLEAR_COLOR := Color(0.04, 0.055, 0.055)     # #0A0E0E

static func build_theme() -> Theme:
	var theme := Theme.new()

	# Load fonts
	var font_regular = load("res://assets/fonts/Inter-Regular.ttf") as Font
	var font_bold = load("res://assets/fonts/Inter-Bold.ttf") as Font
	var font_heading = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font

	# Default font
	if font_regular:
		theme.default_font = font_regular
	theme.default_font_size = 14

	# --- Label ---
	theme.set_color("font_color", "Label", TEXT)
	theme.set_font_size("font_size", "Label", 14)

	# --- Button ---
	var btn_normal := _flat_style(SURFACE.lightened(0.05), BORDER, 4, 6, 10)
	var btn_hover := _flat_style(ACCENT.darkened(0.8), ACCENT, 4, 6, 10)
	var btn_pressed := _flat_style(ACCENT.darkened(0.6), ACCENT, 4, 6, 10)
	var btn_disabled := _flat_style(SURFACE, BORDER.darkened(0.4), 4, 6, 10)
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", ACCENT)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.4))

	# --- PanelContainer ---
	var panel_style := _flat_style(SURFACE, BORDER, 4, 4, 8)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# --- ScrollContainer / ScrollBar ---
	var scroll_bg := _flat_style(SURFACE.darkened(0.2), Color.TRANSPARENT, 0, 4, 0)
	var scroll_grabber := _flat_style(BORDER.lightened(0.1), Color.TRANSPARENT, 0, 4, 0)
	var scroll_grabber_hover := _flat_style(ACCENT.darkened(0.3), Color.TRANSPARENT, 0, 4, 0)
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_grabber_hover)

	# --- HSeparator ---
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color.TRANSPARENT
	sep_style.border_color = BORDER.darkened(0.2)
	sep_style.border_width_bottom = 1
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 8
	sep_style.content_margin_bottom = 8
	theme.set_stylebox("separator", "HSeparator", sep_style)
	theme.set_constant("separation", "HSeparator", 1)

	# --- VSeparator ---
	var vsep_style := StyleBoxFlat.new()
	vsep_style.bg_color = Color.TRANSPARENT
	vsep_style.border_color = BORDER.darkened(0.2)
	vsep_style.border_width_right = 1
	vsep_style.set_content_margin_all(0)
	vsep_style.content_margin_left = 6
	vsep_style.content_margin_right = 6
	theme.set_stylebox("separator", "VSeparator", vsep_style)
	theme.set_constant("separation", "VSeparator", 1)

	# --- RichTextLabel ---
	theme.set_color("default_color", "RichTextLabel", TEXT)

	return theme


## Flat stylebox with configurable border width, corner radius, and content margin.
static func _flat_style(bg: Color, border: Color, border_w: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## Creates a styled section header label (uppercase, accent-colored, with top spacing).
static func make_section_header(text: String) -> Label:
	var header := Label.new()
	header.text = text.to_upper()
	header.add_theme_color_override("font_color", ACCENT)
	var font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_bold:
		header.add_theme_font_override("font", font_bold)
	header.add_theme_font_size_override("font_size", 13)
	return header
