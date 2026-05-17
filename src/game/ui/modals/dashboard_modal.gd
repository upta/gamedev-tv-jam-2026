class_name DashboardModal
extends ModalDialog

@onready var _dashboard_panel: DashboardPanel = $Panel/VBoxContainer/ContentContainer/ScrollContainer/DashboardPanel


func _ready() -> void:
	super()
	set_title("📊 Dashboard")


func bind(game_state: GameState, carrier_id: String) -> void:
	_dashboard_panel.bind(game_state, carrier_id)


func refresh() -> void:
	_dashboard_panel.refresh()
