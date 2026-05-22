extends Node

signal volume_changed(bus: String, value: float)

const SETTINGS_PATH := "user://settings.cfg"
const SFX_POOL_SIZE := 8
const DEFAULT_VOLUME := 0.5
const BUS_NAMES := ["Master", "Music", "Sfx"]

const MUSIC_SPACE := preload("res://assets/music/space_ambient.ogg")
const SFX_CLICK := preload("res://assets/sfx/click.ogg")
const SFX_SWITCH := preload("res://assets/sfx/switch.ogg")
const SFX_ROLLOVER := preload("res://assets/sfx/rollover.ogg")
const SFX_TICK := preload("res://assets/sfx/tick.ogg")

var _config := ConfigFile.new()
var _bus_values: Dictionary = {}
var _music_player: AudioStreamPlayer
var _sfx_available: Array[AudioStreamPlayer] = []
var _sfx_active: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_config.load(SETTINGS_PATH)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	for bus_name: String in BUS_NAMES:
		var saved: float = _config.get_value("audio", bus_name, DEFAULT_VOLUME)
		_bus_values[bus_name] = saved
		_apply_bus_volume(bus_name, saved)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Sfx"
		add_child(player)
		_sfx_available.append(player)
		player.finished.connect(_on_sfx_finished.bind(player))


func play_sfx(stream: AudioStream) -> void:
	if _sfx_available.is_empty():
		push_warning("AudioManager: no SFX player available")
		return
	var player: AudioStreamPlayer = _sfx_available.pop_back()
	_sfx_active.append(player)
	player.stream = stream
	player.play()


func play_music(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func is_music_playing() -> bool:
	return _music_player.playing


func get_volume(bus: String) -> float:
	return _bus_values.get(bus, DEFAULT_VOLUME)


func set_volume(bus: String, value: float) -> void:
	if not bus in _bus_values:
		push_error("AudioManager: unknown bus '%s'" % bus)
		return
	_bus_values[bus] = value
	_apply_bus_volume(bus, value)
	_config.set_value("audio", bus, value)
	_config.save(SETTINGS_PATH)
	volume_changed.emit(bus, value)


func _apply_bus_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_error("AudioManager: bus '%s' not found in AudioServer" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(value))


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	_sfx_active.erase(player)
	_sfx_available.append(player)
