class_name ThemeBuilder
extends RefCounted

# Color palette - Space Control Room aesthetic
const SURFACE := Color(0.102, 0.102, 0.149)       # #1A1A26
const MODAL_SURFACE := Color(0.125, 0.141, 0.212)  # #202436
const TOP_BAR_BG := Color(0.090, 0.106, 0.149)     # #171B26
const BORDER := Color(0.204, 0.231, 0.322)         # #343B52
const TEXT := Color(0.910, 0.933, 0.969)            # #E8EEF7
const MUTED := Color(0.588, 0.639, 0.722)          # #96A3B8
const ACCENT := Color(0.431, 0.784, 1.0)           # #6EC8FF
const POSITIVE := Color(0.404, 0.851, 0.549)       # #67D98C
const NEGATIVE := Color(1.0, 0.420, 0.420)         # #FF6B6B
const WARNING := Color(1.0, 0.784, 0.341)          # #FFC857
const CLEAR_COLOR := Color(0.078, 0.086, 0.11)     # #14161C

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
	var btn_normal := _flat_style(SURFACE, BORDER, 6)
	var btn_hover := _flat_style(SURFACE.lightened(0.1), ACCENT, 6)
	var btn_pressed := _flat_style(ACCENT.darkened(0.3), ACCENT, 6)
	var btn_disabled := _flat_style(SURFACE.darkened(0.2), BORDER.darkened(0.3), 6)
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", ACCENT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	
	# --- PanelContainer ---
	var panel_style := _flat_style(SURFACE, BORDER, 8)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	
	# --- ScrollContainer / ScrollBar ---
	var scroll_bg := _flat_style(SURFACE.darkened(0.1), Color.TRANSPARENT, 4)
	var scroll_grabber := _flat_style(BORDER, Color.TRANSPARENT, 4)
	var scroll_grabber_hover := _flat_style(ACCENT.darkened(0.2), Color.TRANSPARENT, 4)
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_grabber_hover)
	
	# --- HSeparator ---
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = BORDER
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 4
	sep_style.content_margin_bottom = 4
	theme.set_stylebox("separator", "HSeparator", sep_style)
	theme.set_constant("separation", "HSeparator", 1)
	
	# --- RichTextLabel ---
	theme.set_color("default_color", "RichTextLabel", TEXT)
	
	return theme


static func _flat_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8)
	return style
