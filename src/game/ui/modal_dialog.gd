class_name ModalDialog
extends Control

signal closed

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/VBoxContainer/TitleBar/TitleLabel
@onready var _close_button: Button = $Panel/VBoxContainer/TitleBar/CloseButton
@onready var _content_container: MarginContainer = $Panel/VBoxContainer/ContentContainer


func _ready() -> void:
	_close_button.pressed.connect(close)
	_overlay.gui_input.connect(_on_overlay_input)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_modal_style()


func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func set_title(text: String) -> void:
	_title_label.text = text


func get_content_container() -> MarginContainer:
	return _content_container


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _apply_modal_style() -> void:
	# Panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ThemeBuilder.MODAL_SURFACE
	panel_style.border_color = ThemeBuilder.BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", panel_style)

	# Title styling
	var font_heading = load("res://assets/fonts/SpaceGrotesk-Bold.ttf") as Font
	if font_heading:
		_title_label.add_theme_font_override("font", font_heading)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	_title_label.uppercase = true
