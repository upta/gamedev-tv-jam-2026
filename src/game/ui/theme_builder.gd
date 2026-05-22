class_name ThemeBuilder
extends RefCounted

# Inline resource icons (Tabler Icons, MIT license)
const ICON_PAX := "res://assets/icons/users.svg"
const ICON_CARGO := "res://assets/icons/package.svg"
const ICON_FUEL := "res://assets/icons/gas-station.svg"

const ICON_INLINE_SIZE := 14

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

# Carrier identity colors — single source of truth for map, slots, and scoreboard
const CARRIER_COLORS := {
	"player": Color(0.24, 0.92, 0.67),            # teal-green (matches ACCENT)
	"npc_1": Color(0.85, 0.45, 0.42),             # muted coral
	"npc_2": Color(0.55, 0.65, 0.90),             # soft lavender-blue
	"npc_3": Color(0.90, 0.72, 0.35),             # warm amber
}

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
	# Separator is just a 1px colored line — all spacing comes from parent VBox separation
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = BORDER.darkened(0.2)
	sep_style.set_content_margin_all(0)
	theme.set_stylebox("separator", "HSeparator", sep_style)
	theme.set_constant("separation", "HSeparator", 1)

	# --- VSeparator ---
	# Separator is just a 1px colored line — all spacing comes from parent HBox separation
	var vsep_style := StyleBoxFlat.new()
	vsep_style.bg_color = BORDER.darkened(0.2)
	vsep_style.set_content_margin_all(0)
	theme.set_stylebox("separator", "VSeparator", vsep_style)
	theme.set_constant("separation", "VSeparator", 1)

	# --- OptionButton ---
	theme.set_stylebox("normal", "OptionButton", btn_normal)
	theme.set_stylebox("hover", "OptionButton", btn_hover)
	theme.set_stylebox("pressed", "OptionButton", btn_pressed)
	theme.set_stylebox("disabled", "OptionButton", btn_disabled)
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", ACCENT)
	theme.set_color("font_pressed_color", "OptionButton", Color.WHITE)
	theme.set_color("font_disabled_color", "OptionButton", MUTED.darkened(0.4))
	theme.set_icon("arrow", "OptionButton", null)
	theme.set_constant("arrow_margin", "OptionButton", 8)

	# --- PopupMenu (dropdown for OptionButton) ---
	var popup_panel := _flat_style(MODAL_SURFACE, BORDER, 4, 4, 0)
	var popup_hover := _flat_style(ACCENT.darkened(0.75), Color.TRANSPARENT, 0, 0, 0)
	theme.set_stylebox("panel", "PopupMenu", popup_panel)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT)
	theme.set_color("font_disabled_color", "PopupMenu", MUTED.darkened(0.4))
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	theme.set_color("font_accelerator_color", "PopupMenu", MUTED)
	theme.set_constant("v_separation", "PopupMenu", 4)
	theme.set_constant("h_separation", "PopupMenu", 8)
	theme.set_constant("item_start_padding", "PopupMenu", 8)
	theme.set_constant("item_end_padding", "PopupMenu", 8)
	var popup_sep := StyleBoxFlat.new()
	popup_sep.bg_color = BORDER.darkened(0.2)
	popup_sep.set_content_margin_all(0)
	theme.set_stylebox("labeled_separator_left", "PopupMenu", popup_sep)
	theme.set_stylebox("labeled_separator_right", "PopupMenu", popup_sep)
	theme.set_stylebox("separator", "PopupMenu", popup_sep)

	# Radio button icons — default dark icons are invisible on dark backgrounds
	theme.set_icon("radio_unchecked", "PopupMenu", _make_radio_icon(16, MUTED, false))
	theme.set_icon("radio_checked", "PopupMenu", _make_radio_icon(16, ACCENT, true))

	# --- SpinBox / LineEdit ---
	var lineedit_normal := _flat_style(SURFACE.lightened(0.05), BORDER, 4, 4, 6)
	var lineedit_focus := _flat_style(SURFACE.lightened(0.08), ACCENT, 4, 4, 6)
	theme.set_stylebox("normal", "LineEdit", lineedit_normal)
	theme.set_stylebox("focus", "LineEdit", lineedit_focus)
	theme.set_stylebox("read_only", "LineEdit", _flat_style(SURFACE, BORDER.darkened(0.4), 4, 4, 6))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", ACCENT.darkened(0.6))

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


## Creates a radio button icon texture (circle outline or filled dot).
static func _make_radio_icon(size: int, color: Color, filled: bool) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := Vector2(size / 2.0, size / 2.0)
	var outer_r := size / 2.0 - 1.0
	var inner_r := outer_r - 1.5
	for y in size:
		for x in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if filled:
				# Filled dot with antialiased edge
				var dot_r := outer_r - 1.0
				if dist <= dot_r - 0.5:
					img.set_pixel(x, y, color)
				elif dist <= dot_r + 0.5:
					var alpha := clampf(dot_r + 0.5 - dist, 0.0, 1.0)
					img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
			else:
				# Ring outline with antialiased edges
				if dist >= inner_r - 0.5 and dist <= outer_r + 0.5:
					var alpha := 1.0
					if dist < inner_r + 0.5:
						alpha = clampf(dist - inner_r + 0.5, 0.0, 1.0)
					if dist > outer_r - 0.5:
						alpha = minf(alpha, clampf(outer_r + 0.5 - dist, 0.0, 1.0))
					img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(img)


## Returns a colored Unicode glyph for use in BBCode text.
## SVG [img] tags are unreliable in RichTextLabel; colored symbols are robust.
static func pax_bb(_size: int = ICON_INLINE_SIZE) -> String:
	return "[color=#6bedc4]●[/color]"

static func cargo_bb(_size: int = ICON_INLINE_SIZE) -> String:
	return "[color=#e8c56d]◼[/color]"

static func fuel_bb(_size: int = ICON_INLINE_SIZE) -> String:
	return "[color=#73948c]◆[/color]"


## Loads an icon SVG as a properly-sized Texture2D for use in TextureRect nodes.
static func load_icon_texture(icon_path: String, icon_size: int = 16) -> ImageTexture:
	var tex := load(icon_path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.get_width() != icon_size or img.get_height() != icon_size:
		img.resize(icon_size, icon_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

## Creates a RichTextLabel pre-configured for inline icon+text use.
static func make_icon_label() -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rtl


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
