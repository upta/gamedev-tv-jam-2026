extends Control

## Validation harness for the toast notification system.
## Instantiates a ToastManager and exposes its observable state.
## Subclasses or scenarios drive behavior via show_toast / clear_all calls.

var toast_manager: ToastManager
var toasts_shown: int = 0


func reset_harness() -> void:
	toasts_shown = 0

	if toast_manager != null and is_instance_valid(toast_manager):
		toast_manager.queue_free()
		toast_manager = null

	var scene: PackedScene = load("res://game/ui/notifications/toast_manager.tscn")
	toast_manager = scene.instantiate() as ToastManager
	add_child(toast_manager)


func get_observed_state() -> Dictionary:
	var state := _build_harness_state()
	state["metrics"] = _build_metrics()
	state["nodes"] = {}
	state["signals"] = {}
	return state


func _build_harness_state() -> Dictionary:
	var container: VBoxContainer = toast_manager._toast_container if toast_manager else null
	var visible_count := 0
	if container:
		for child: Node in container.get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				visible_count += 1

	return {
		"active_count": toast_manager._active_count if toast_manager else 0,
		"queue_size": toast_manager._queue.size() if toast_manager else 0,
		"visible_toast_count": visible_count,
		"max_visible": ToastManager.MAX_VISIBLE,
		"display_duration": ToastManager.DISPLAY_DURATION,
		"fade_duration": ToastManager.FADE_DURATION,
	}


func _build_metrics() -> Dictionary:
	return {
		"toasts_shown": toasts_shown,
	}
