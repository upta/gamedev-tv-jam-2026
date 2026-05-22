extends GutTest

# ---------------------------------------------------------------------------
# ThemeBuilder output tests (no scene instantiation needed)
# ---------------------------------------------------------------------------

func test_theme_has_panel_container_style() -> void:
	var theme := ThemeBuilder.build_theme()
	assert_true(theme.has_stylebox("panel", "PanelContainer"), "Theme should define PanelContainer panel")


func test_theme_panel_container_margins() -> void:
	var theme := ThemeBuilder.build_theme()
	var sb := theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_not_null(sb, "Panel stylebox should be StyleBoxFlat")
	if sb:
		assert_gt(sb.content_margin_left, 0.0, "Left margin should be > 0")
		assert_gt(sb.content_margin_top, 0.0, "Top margin should be > 0")


func test_theme_has_button_styles() -> void:
	var theme := ThemeBuilder.build_theme()
	assert_true(theme.has_stylebox("normal", "Button"), "Theme should define Button normal")
	assert_true(theme.has_stylebox("hover", "Button"), "Theme should define Button hover")
	assert_true(theme.has_stylebox("pressed", "Button"), "Theme should define Button pressed")


func test_theme_label_color_is_text() -> void:
	var theme := ThemeBuilder.build_theme()
	var color := theme.get_color("font_color", "Label")
	assert_eq(color, ThemeBuilder.TEXT, "Label font color should be TEXT")


func test_theme_hseparator_transparent_bg() -> void:
	var theme := ThemeBuilder.build_theme()
	var sb := theme.get_stylebox("separator", "HSeparator") as StyleBoxFlat
	assert_not_null(sb, "HSeparator stylebox should exist")
	if sb:
		assert_eq(sb.bg_color, Color.TRANSPARENT, "HSeparator bg should be transparent")
		assert_eq(sb.border_width_bottom, 1, "HSeparator should have 1px bottom border")


func test_theme_vseparator_transparent_bg() -> void:
	var theme := ThemeBuilder.build_theme()
	var sb := theme.get_stylebox("separator", "VSeparator") as StyleBoxFlat
	assert_not_null(sb, "VSeparator stylebox should exist")
	if sb:
		assert_eq(sb.bg_color, Color.TRANSPARENT, "VSeparator bg should be transparent")
		assert_eq(sb.border_width_right, 1, "VSeparator should have 1px right border")


func test_theme_default_font_size() -> void:
	var theme := ThemeBuilder.build_theme()
	assert_eq(theme.default_font_size, 14, "Default font size should be 14")


func test_section_header_is_uppercase_accent() -> void:
	var header := ThemeBuilder.make_section_header("Test Header")
	assert_eq(header.text, "TEST HEADER", "Header text should be uppercase")
	assert_true(header.has_theme_color_override("font_color"), "Header should have font color override")


# ---------------------------------------------------------------------------
# Scene structure tests (verify .tscn constants without full _ready)
# ---------------------------------------------------------------------------

func test_top_bar_tscn_has_margin_container() -> void:
	var scene := load("res://game/ui/top_bar.tscn") as PackedScene
	assert_not_null(scene, "top_bar.tscn should load")
	var state := scene.get_state()
	var found_margin := false
	for i in range(state.get_node_count()):
		if state.get_node_type(i) == "MarginContainer":
			found_margin = true
			break
	assert_true(found_margin, "TopBar should contain a MarginContainer")


func test_modal_content_container_margins_in_tscn() -> void:
	var scene := load("res://game/ui/modal_dialog.tscn") as PackedScene
	assert_not_null(scene, "modal_dialog.tscn should load")
	var state := scene.get_state()
	var found_content := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == "ContentContainer":
			found_content = true
			break
	assert_true(found_content, "Modal should contain ContentContainer")
