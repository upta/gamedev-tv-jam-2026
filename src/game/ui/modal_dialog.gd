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
