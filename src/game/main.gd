extends Node2D

func _ready() -> void:
	var label := Label.new()
	label.text = "Hello, Prototype!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	add_child(label)
