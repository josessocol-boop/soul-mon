extends Node
## Persistent settings singleton. Saves to user://settings.cfg

const SETTINGS_PATH := "user://settings.cfg"
var data: ConfigFile

func _ready() -> void:
	data = ConfigFile.new()
	load_settings()
	_apply_audio.call_deferred()    # the buses exist by then; saved volumes were never pushed to them before

## Pushes the saved volumes to the audio buses (without writing the file again).
func _apply_audio() -> void:
	_set_bus("Master", get_master_volume())
	_set_bus("SFX", get_sfx_volume())
	_set_bus("Music", get_music_volume())

func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func load_settings() -> void:
	var err = data.load(SETTINGS_PATH)
	if err != OK:
		_defaults()

func save_settings() -> void:
	data.save(SETTINGS_PATH)

func _defaults() -> void:
	data.set_value("game", "difficulty", "medium")
	data.set_value("game", "master_volume", 0.8)
	data.set_value("game", "sfx_volume", 1.0)
	data.set_value("game", "music_volume", 0.7)
	data.set_value("game", "last_p1_fighter", "marshadow")
	data.set_value("game", "last_p2_fighter", "gholdengo")
	data.set_value("game", "last_mode", "pvp")
	save_settings()

func get_value(key: String, default = null) -> Variant:
	var parts = key.split("/", 1)
	if parts.size() != 2:
		return default
	return data.get_value(parts[0], parts[1], default)

func set_value(key: String, value: Variant) -> void:
	var parts = key.split("/", 1)
	if parts.size() != 2:
		return
	data.set_value(parts[0], parts[1], value)
	save_settings()

# Convenience getters/setters
func get_difficulty() -> String:
	return get_value("game/difficulty", "medium")

func set_difficulty(value: String) -> void:
	set_value("game/difficulty", value)

func get_master_volume() -> float:
	return get_value("game/master_volume", 0.8)

func set_master_volume(value: float) -> void:
	set_value("game/master_volume", value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func get_sfx_volume() -> float:
	return get_value("game/sfx_volume", 1.0)

func set_sfx_volume(value: float) -> void:
	set_value("game/sfx_volume", value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))

func get_music_volume() -> float:
	return get_value("game/music_volume", 0.7)

func set_music_volume(value: float) -> void:
	set_value("game/music_volume", value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))

func get_last_p1_fighter() -> String:
	return get_value("game/last_p1_fighter", "marshadow")

func set_last_p1_fighter(value: String) -> void:
	set_value("game/last_p1_fighter", value)

func get_last_p2_fighter() -> String:
	return get_value("game/last_p2_fighter", "gholdengo")

func set_last_p2_fighter(value: String) -> void:
	set_value("game/last_p2_fighter", value)

func get_last_mode() -> String:
	return get_value("game/last_mode", "pvp")

func set_last_mode(value: String) -> void:
	set_value("game/last_mode", value)

# View mode flag - when true, arena_manager opens character select without auto-starting
var view_mode_only: bool = false

func set_view_mode_only(value: bool) -> void:
	view_mode_only = value

func get_view_mode_only() -> bool:
	return view_mode_only

func clear_view_mode_only() -> void:
	view_mode_only = false
