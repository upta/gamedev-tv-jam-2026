class_name OrderShipModal
extends ModalDialog

## Modal for ordering a new ship.
## Two-step flow: Step 0 = browse ship cards, Step 1 = customize selected ship.

signal ship_ordered

var _player_controller: PlayerController
var _game_state: GameState
var _content: VBoxContainer

# Step tracking
var _current_step: int = 0  # 0 = selection, 1 = customization
var _selected_type: ShipCatalog.ShipType = null

# Customization controls (step 1)
var _pax_spin: SpinBox
var _cargo_spin: SpinBox
var _qty_spin: SpinBox
var _cost_label: Label
var _order_button: Button

var _available_types: Array = []
var _updating_spinboxes: bool = false


func _ready() -> void:
	super._ready()
	set_title("Order Ship")
	var scroll: ScrollContainer = _content_container.get_child(0)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


func bind(player_controller: PlayerController, game_state: GameState) -> void:
	_player_controller = player_controller
	_game_state = game_state


func open() -> void:
	super.open()
	_current_step = 0
	_selected_type = null
	_available_types = _game_state.catalog.get_available_types(_game_state.current_turn) if _game_state else []
	_build_selection_step()


# ---------------------------------------------------------------------------
# Step 0: Ship Selection (card browser)
# ---------------------------------------------------------------------------

func _build_selection_step() -> void:
	_clear_content()
	set_title("Order Ship")

	if _available_types.is_empty():
		var empty := Label.new()
		empty.text = "No ships available this turn."
		_content.add_child(empty)
		return

	for st: ShipCatalog.ShipType in _available_types:
		_content.add_child(_make_ship_card(st))


func _make_ship_card(st: ShipCatalog.ShipType) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = ThemeBuilder.MODAL_SURFACE.lightened(0.06)
	card_style.border_color = ThemeBuilder.BORDER
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Row 1: Name + Price
	var row1 := HBoxContainer.new()
	var name_label := Label.new()
	var font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_bold:
		name_label.add_theme_font_override("font", font_bold)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.text = st.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "§%d" % st.cost
	price_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	if font_bold:
		price_label.add_theme_font_override("font", font_bold)
	row1.add_child(price_label)
	vbox.add_child(row1)

	# Stats grid: 2 rows × 4 columns (label, value, label, value)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)

	# Row 1: Capacity | Fuel
	_add_stat(grid, "Capacity", str(st.max_capacity))
	_add_stat(grid, "Fuel", st.get_efficiency_rating())

	# Row 2: Range | Build
	_add_stat(grid, "Range", "%.1f ly" % st.range)
	_add_stat(grid, "Build", "%d turn%s" % [st.build_turns, "s" if st.build_turns != 1 else ""])

	vbox.add_child(grid)

	# Select button (right-aligned)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	var select_btn := Button.new()
	select_btn.text = "Select"
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = ThemeBuilder.ACCENT.darkened(0.6)
	btn_style.border_color = ThemeBuilder.ACCENT
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(4)
	btn_style.content_margin_left = 16
	btn_style.content_margin_right = 16
	select_btn.add_theme_stylebox_override("normal", btn_style)
	select_btn.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = ThemeBuilder.ACCENT.darkened(0.4)
	select_btn.add_theme_stylebox_override("hover", btn_hover)
	select_btn.pressed.connect(_on_card_selected.bind(st))
	btn_row.add_child(select_btn)
	vbox.add_child(btn_row)

	return card


func _add_stat(container: Container, label_text: String, value_text: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", ThemeBuilder.MUTED)
	lbl.custom_minimum_size.x = 80
	container.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.custom_minimum_size.x = 80
	container.add_child(val)


func _on_card_selected(st: ShipCatalog.ShipType) -> void:
	_selected_type = st
	_current_step = 1
	_build_customization_step()


# ---------------------------------------------------------------------------
# Step 1: Customization (after selecting a ship type)
# ---------------------------------------------------------------------------

func _build_customization_step() -> void:
	_clear_content()
	if _selected_type == null:
		return

	set_title("Configure — %s" % _selected_type.name)
	var st := _selected_type
	var carrier := _game_state.get_player_carrier()

	# Ship header summary
	var header_rtl := ThemeBuilder.make_icon_label()
	header_rtl.text = "[b]%s[/b]  §%d  |  %s Cap: %d  |  %s %s  |  Range: %.1f ly  |  Build: %d turn%s" % [
		st.name, st.cost,
		ThemeBuilder.pax_bb(), st.max_capacity,
		ThemeBuilder.fuel_bb(), st.get_efficiency_rating(),
		st.range, st.build_turns,
		"s" if st.build_turns != 1 else "",
	]
	_content.add_child(header_rtl)

	_content.add_child(HSeparator.new())

	# Capacity split
	var cap_header := ThemeBuilder.make_section_header("Capacity Split")
	_content.add_child(cap_header)

	var pax_row := _create_label_spinbox("Passengers:", 0, st.max_capacity, 1, st.max_capacity / 2, ThemeBuilder.ICON_PAX)
	_pax_spin = pax_row.get_child(pax_row.get_child_count() - 1) as SpinBox
	_content.add_child(pax_row)

	var cargo_row := _create_label_spinbox("Cargo:", 0, st.max_capacity, 1, st.max_capacity - st.max_capacity / 2, ThemeBuilder.ICON_CARGO)
	_cargo_spin = cargo_row.get_child(cargo_row.get_child_count() - 1) as SpinBox
	_content.add_child(cargo_row)

	_pax_spin.value_changed.connect(_on_pax_changed)
	_cargo_spin.value_changed.connect(_on_cargo_changed)

	_content.add_child(HSeparator.new())

	# Quantity
	var qty_row := _create_label_spinbox("Quantity:", 1, 10, 1, 1)
	_qty_spin = qty_row.get_child(qty_row.get_child_count() - 1) as SpinBox
	_qty_spin.value_changed.connect(_on_qty_changed)
	_content.add_child(qty_row)

	_content.add_child(HSeparator.new())

	# Total cost
	_cost_label = Label.new()
	_cost_label.add_theme_color_override("font_color", ThemeBuilder.TEXT)
	var font_bold = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_bold:
		_cost_label.add_theme_font_override("font", font_bold)
	_content.add_child(_cost_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	btn_row.add_child(back_button)

	_order_button = Button.new()
	_order_button.text = "Order"
	var order_style := StyleBoxFlat.new()
	order_style.bg_color = ThemeBuilder.ACCENT.darkened(0.6)
	order_style.border_color = ThemeBuilder.ACCENT
	order_style.set_border_width_all(2)
	order_style.set_corner_radius_all(4)
	order_style.set_content_margin_all(6)
	order_style.content_margin_left = 20
	order_style.content_margin_right = 20
	_order_button.add_theme_stylebox_override("normal", order_style)
	_order_button.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	var order_hover := order_style.duplicate()
	order_hover.bg_color = ThemeBuilder.ACCENT.darkened(0.4)
	_order_button.add_theme_stylebox_override("hover", order_hover)
	_order_button.pressed.connect(_on_order_pressed)
	btn_row.add_child(_order_button)

	_content.add_child(btn_row)

	_update_cost_and_button(carrier)


func _create_label_spinbox(label_text: String, min_val: float, max_val: float, step: float, default_val: float, icon_path: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	if not icon_path.is_empty():
		var icon_tex := ThemeBuilder.load_icon_texture(icon_path, 16)
		if icon_tex:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(16, 16)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon_rect)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = default_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return row


func _update_cost_and_button(carrier: CarrierData) -> void:
	if _selected_type == null:
		return
	var qty := int(_qty_spin.value) if _qty_spin else 1
	var total_cost := _selected_type.cost * qty
	_cost_label.text = "Total: §%d × %d = §%d" % [_selected_type.cost, qty, total_cost]
	_order_button.disabled = carrier.cash < total_cost


func _on_back_pressed() -> void:
	_current_step = 0
	_selected_type = null
	_build_selection_step()


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


# ---------------------------------------------------------------------------
# Programmatic API for validation harness
# ---------------------------------------------------------------------------

func get_form_state() -> Dictionary:
	return {
		"type_id": _selected_type.id if _selected_type else "",
		"type_name": _selected_type.name if _selected_type else "",
		"passenger_capacity": int(_pax_spin.value) if _pax_spin else 0,
		"cargo_capacity": int(_cargo_spin.value) if _cargo_spin else 0,
		"quantity": int(_qty_spin.value) if _qty_spin else 1,
		"can_order": not _order_button.disabled if _order_button else false,
	}


func select_type(index: int) -> void:
	if index >= 0 and index < _available_types.size():
		_selected_type = _available_types[index]
		_current_step = 1
		_build_customization_step()


func set_passenger_capacity(value: int) -> void:
	if _pax_spin:
		_pax_spin.value = value


func confirm_order() -> void:
	_on_order_pressed()


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_pax_changed(value: float) -> void:
	if _updating_spinboxes or _selected_type == null:
		return
	_updating_spinboxes = true
	_cargo_spin.value = _selected_type.max_capacity - int(value)
	_updating_spinboxes = false


func _on_cargo_changed(value: float) -> void:
	if _updating_spinboxes or _selected_type == null:
		return
	_updating_spinboxes = true
	_pax_spin.value = _selected_type.max_capacity - int(value)
	_updating_spinboxes = false


func _on_qty_changed(_value: float) -> void:
	if _game_state:
		_update_cost_and_button(_game_state.get_player_carrier())


func _on_order_pressed() -> void:
	if _selected_type == null:
		return
	var qty := int(_qty_spin.value) if _qty_spin else 1
	for i in range(qty):
		_player_controller.add_ship_order(_selected_type.id, int(_pax_spin.value), int(_cargo_spin.value))
	ship_ordered.emit()
	close()
