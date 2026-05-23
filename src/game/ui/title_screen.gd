class_name TitleScreen
extends Control

signal new_game_requested

@onready var _new_game_btn: Button = %NewGameButton
@onready var _settings_btn: Button = %SettingsButton

var _settings_menu: SettingsMenu


func _ready() -> void:
	theme = ThemeBuilder.build_theme()
	ThemeBuilder.style_primary_button(_new_game_btn)
	_new_game_btn.pressed.connect(_on_new_game)
	_settings_btn.pressed.connect(_on_settings)

	_settings_menu = SettingsMenu.new()
	add_child(_settings_menu)

	_start_music()


func _start_music() -> void:
	if OS.has_feature("headless") or OS.get_cmdline_user_args().has("--test-mode"):
		return
	var am := _get_audio_manager()
	if am and not am.is_music_playing():
		am.play_music(am.MUSIC_SPACE)


func _get_audio_manager() -> Node:
	return get_node_or_null("/root/AudioManager")


func _on_new_game() -> void:
	_play_sfx_click()
	new_game_requested.emit()


func _on_settings() -> void:
	_play_sfx_click()
	_settings_menu.open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_play_sfx_switch()
			_settings_menu.toggle()
			get_viewport().set_input_as_handled()


func _play_sfx_click() -> void:
	var am := _get_audio_manager()
	if am:
		am.play_sfx(am.SFX_CLICK)


func _play_sfx_switch() -> void:
	var am := _get_audio_manager()
	if am:
		am.play_sfx(am.SFX_SWITCH)
