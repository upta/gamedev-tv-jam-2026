class_name Audio
extends RefCounted

const MUSIC_MENU := "res://assets/music/menu_chill.ogg"
const SFX_BEEP_HIGH := "res://assets/sfx/beep_high.wav"

static func load_music_menu() -> AudioStream:
	return load(MUSIC_MENU)

static func load_sfx_beep_high() -> AudioStream:
	return load(SFX_BEEP_HIGH)
