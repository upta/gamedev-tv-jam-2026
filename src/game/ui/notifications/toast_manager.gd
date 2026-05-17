class_name ToastManager
extends Control

const MAX_VISIBLE := 4
const DISPLAY_DURATION := 3.0
const FADE_DURATION := 0.3

const TYPE_COLORS := {
	"info": Color.WHITE,
	"success": Color(0.2, 0.9, 0.2),
	"warning": Color(0.9, 0.9, 0.2),
	"danger": Color(0.9, 0.2, 0.2),
}

var _queue: Array = []
var _active_count: int = 0

@onready var _toast_container: VBoxContainer = $ToastContainer


func show_toast(message: String, type: String = "info") -> void:
	if _active_count < MAX_VISIBLE:
		_show_immediately(message, type)
	else:
		_queue.append({"message": message, "type": type})


func clear_all() -> void:
	_queue.clear()
	for child: Node in _toast_container.get_children():
		child.queue_free()
	_active_count = 0


func _show_immediately(message: String, type: String) -> void:
	var toast: PanelContainer = _create_toast_label(message, type)
	_toast_container.add_child(toast)
	_active_count += 1

	var timer: SceneTreeTimer = get_tree().create_timer(DISPLAY_DURATION)
	timer.timeout.connect(_dismiss_toast.bind(toast))


func _create_toast_label(message: String, type: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)

	var color: Color = TYPE_COLORS.get(type, Color.WHITE)
	panel.modulate = color

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)

	return panel


func _dismiss_toast(toast: PanelContainer) -> void:
	if not is_instance_valid(toast):
		return

	var tween: Tween = create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
		_active_count -= 1
		_show_next_from_queue()
	)


func _show_next_from_queue() -> void:
	if _queue.is_empty() or _active_count >= MAX_VISIBLE:
		return
	var next: Dictionary = _queue.pop_front()
	_show_immediately(next["message"], next["type"])
