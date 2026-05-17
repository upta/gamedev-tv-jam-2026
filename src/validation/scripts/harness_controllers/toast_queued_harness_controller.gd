extends "res://validation/scripts/harness_controllers/toast_harness_controller.gd"

## Fires 6 toasts at reset to exercise queuing (4 active + 2 queued).


func reset_harness() -> void:
	super.reset_harness()

	toast_manager.show_toast("Info toast", "info")
	toast_manager.show_toast("Success toast", "success")
	toast_manager.show_toast("Warning toast", "warning")
	toast_manager.show_toast("Danger toast", "danger")
	toast_manager.show_toast("Queued toast 1", "info")
	toast_manager.show_toast("Queued toast 2", "info")
	toasts_shown = 6
