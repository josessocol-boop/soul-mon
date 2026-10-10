extends CanvasLayer

signal mode_selected(mode: String, difficulty: String)

@onready var pvp_btn = %PvPButton
@onready var pvcpu_btn = %PvCPUButton
@onready var cpuvcpu_btn = %CPUvCPUButton
@onready var difficulty_slider = %DifficultySlider
@onready var difficulty_label = %DifficultyLabel
@onready var difficulty_container = %DifficultyContainer
@onready var back_btn = %BackButton
@onready var confirm_btn = %ConfirmButton

var selected_mode: String = "pvp"

func _ready() -> void:
	pvp_btn.pressed.connect(_on_pvp)
	pvcpu_btn.pressed.connect(_on_pvcpu)
	cpuvcpu_btn.pressed.connect(_on_cpuvcpu)
	difficulty_slider.value_changed.connect(_on_difficulty_changed)
	back_btn.pressed.connect(_on_back)
	confirm_btn.pressed.connect(_on_mode_confirmed)

	# Load saved difficulty
	if Settings:
		difficulty_slider.value = {"easy": 0, "medium": 1, "hard": 2}[Settings.get_difficulty()]
	_on_difficulty_changed(difficulty_slider.value)

	_update_mode_buttons()
	_update_difficulty_visibility()

func _on_pvp() -> void:
	selected_mode = "pvp"
	_update_mode_buttons()
	_update_difficulty_visibility()

func _on_pvcpu() -> void:
	selected_mode = "pvcpu"
	_update_mode_buttons()
	_update_difficulty_visibility()

func _on_cpuvcpu() -> void:
	selected_mode = "cpuvcpu"
	_update_mode_buttons()
	_update_difficulty_visibility()

func _on_difficulty_changed(value: float) -> void:
	var difficulties: Array[String] = ["easy", "medium", "hard"]
	var idx: int = roundi(value)
	idx = clampi(idx, 0, 2)
	difficulty_label.text = "DIFFICULTY: " + difficulties[idx].to_upper()

func _update_mode_buttons() -> void:
	pvp_btn.button_pressed = (selected_mode == "pvp")
	pvcpu_btn.button_pressed = (selected_mode == "pvcpu")
	cpuvcpu_btn.button_pressed = (selected_mode == "cpuvcpu")

func _update_difficulty_visibility() -> void:
	# Show difficulty for modes with CPU
	var show_difficulty := selected_mode in ["pvcpu", "cpuvcpu"]
	difficulty_container.visible = show_difficulty

func _on_back() -> void:
	UIManager.go_back()

# CONTINUE: remember the choice, then open the arena with the fighter-select screen in front.
func _on_mode_confirmed() -> void:
	var difficulties: Array[String] = ["easy", "medium", "hard"]
	var diff: String = difficulties[clampi(roundi(difficulty_slider.value), 0, 2)]
	if Settings:
		Settings.set_last_mode(selected_mode)
		Settings.set_difficulty(diff)
		Settings.set_view_mode_only(true)   # arena opens the fighter select instead of auto-starting
	mode_selected.emit(selected_mode, diff)
	UIManager.clear_stack()
	get_tree().change_scene_to_file("res://main.tscn")
