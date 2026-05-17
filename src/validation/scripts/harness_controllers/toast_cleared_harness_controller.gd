extends "res://validation/scripts/harness_controllers/toast_harness_controller.gd"

## Fires 6 toasts then calls clear_all at reset to exercise the clear path.


func reset_harness() -> void:
	super.reset_harness()

	toast_manager.show_toast("Info toast", "info")
	toast_manager.show_toast("Success toast", "success")
	toast_manager.show_toast("Warning toast", "warning")
	toast_manager.show_toast("Danger toast", "danger")
	toast_manager.show_toast("Queued toast 1", "info")
	toast_manager.show_toast("Queued toast 2", "info")
	toasts_shown = 6

	toast_manager.clear_all()
