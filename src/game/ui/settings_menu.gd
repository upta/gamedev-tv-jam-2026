class_name SettingsMenu
extends CanvasLayer

signal menu_closed

var _sliders: Dictionary = {}


func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()


func toggle() -> void:
	visible = !visible


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	menu_closed.emit()


func _build_ui() -> void:
	# Semi-transparent backdrop
	var overlay := ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)

	# Center container
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	# Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ThemeBuilder.MODAL_SURFACE
	panel_style.border_color = ThemeBuilder.BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	# Main VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Title bar with close button
	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)

	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var font_heading = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_heading:
		title.add_theme_font_override("font", font_heading)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(close)
	title_bar.add_child(close_btn)

	# Separator
	vbox.add_child(HSeparator.new())

	# Volume sliders grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	var bus_labels := {"Master": "Master", "Music": "Music", "Sfx": "Effects"}
	for bus_name: String in bus_labels:
		var label := Label.new()
		label.text = bus_labels[bus_name]
		label.add_theme_color_override("font_color", ThemeBuilder.TEXT)
		grid.add_child(label)

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 200
		grid.add_child(slider)

		_sliders[bus_name] = slider
		slider.value_changed.connect(_on_slider_changed.bind(bus_name))

	# Defer AudioManager connection until tree is ready
	_sync_from_audio_manager.call_deferred()


func _sync_from_audio_manager() -> void:
	var audio_manager := _get_audio_manager()
	if audio_manager == null:
		return
	for bus_name: String in _sliders:
		_sliders[bus_name].value = audio_manager.get_volume(bus_name)
	audio_manager.volume_changed.connect(_on_volume_changed_external)


func _get_audio_manager() -> Node:
	return get_node_or_null("/root/AudioManager")


func _on_slider_changed(value: float, bus_name: String) -> void:
	var audio_manager := _get_audio_manager()
	if audio_manager:
		audio_manager.set_volume(bus_name, value)


func _on_volume_changed_external(bus: String, value: float) -> void:
	if bus in _sliders:
		var slider: HSlider = _sliders[bus]
		if not is_equal_approx(slider.value, value):
			slider.value = value


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
