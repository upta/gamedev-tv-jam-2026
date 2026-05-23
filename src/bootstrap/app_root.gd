extends Node

const TITLE_SCENE := preload("res://game/ui/title_screen.tscn")
const GAME_SCENE := preload("res://game/main.tscn")
const TEST_SCENE_PATH := "res://addons/agentic_godot_validation/runtime/scenes/test_bootstrap.tscn"
const ACTION_KEYS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"pause": KEY_ESCAPE,
	"ui_accept": KEY_ENTER,
}

var _current_scene: Node


func _ready() -> void:
	_ensure_input_actions()
	if _is_test_mode():
		_current_scene = load(TEST_SCENE_PATH).instantiate()
		add_child(_current_scene)
	else:
		_show_title()


func _show_title() -> void:
	var title: TitleScreen = TITLE_SCENE.instantiate()
	title.new_game_requested.connect(_on_new_game)
	_current_scene = title
	add_child(_current_scene)


func _on_new_game() -> void:
	_current_scene.queue_free()
	_current_scene = GAME_SCENE.instantiate()
	add_child(_current_scene)

func _is_test_mode() -> bool:
	return OS.get_cmdline_user_args().has("--test-mode")

func _ensure_input_actions() -> void:
	for action_name in ACTION_KEYS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		var input_event := _build_key_event(ACTION_KEYS[action_name])
		if not InputMap.action_has_event(action_name, input_event):
			InputMap.action_add_event(action_name, input_event)

func _build_key_event(keycode: Key) -> InputEventKey:
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	return input_event
