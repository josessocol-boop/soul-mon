extends CanvasLayer

@onready var difficulty_slider = %DifficultySlider
@onready var difficulty_label = %DifficultyLabel
@onready var master_slider = %MasterSlider
@onready var master_label = %MasterLabel
@onready var sfx_slider = %SFXSlider
@onready var sfx_label = %SFXLabel
@onready var music_slider = %MusicSlider
@onready var music_label = %MusicLabel
@onready var back_btn = %BackButton

func _ready() -> void:
	difficulty_slider.value_changed.connect(_on_difficulty_changed)
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	back_btn.pressed.connect(_on_back)

	# Load saved settings
	if Settings:
		difficulty_slider.value = {"easy": 0, "medium": 1, "hard": 2}[Settings.get_difficulty()]
		master_slider.value = Settings.get_master_volume()
		sfx_slider.value = Settings.get_sfx_volume()
		music_slider.value = Settings.get_music_volume()

	_on_difficulty_changed(difficulty_slider.value)
	_on_master_changed(master_slider.value)
	_on_sfx_changed(sfx_slider.value)
	_on_music_changed(music_slider.value)

func _on_difficulty_changed(value: float) -> void:
	var difficulties: Array[String] = ["easy", "medium", "hard"]
	var idx: int = roundi(value)
	idx = clampi(idx, 0, 2)
	difficulty_label.text = "DIFFICULTY: " + difficulties[idx].to_upper()
	if Settings:
		Settings.set_difficulty(difficulties[idx])

func _on_master_changed(value: float) -> void:
	master_label.text = "MASTER: %d%%" % int(value * 100)
	if Settings:
		Settings.set_master_volume(value)

func _on_sfx_changed(value: float) -> void:
	sfx_label.text = "SFX: %d%%" % int(value * 100)
	if Settings:
		Settings.set_sfx_volume(value)

func _on_music_changed(value: float) -> void:
	music_label.text = "MUSIC: %d%%" % int(value * 100)
	if Settings:
		Settings.set_music_volume(value)

func _on_back() -> void:
	UIManager.go_back()