class_name CharacterSelect
extends CanvasLayer

signal start_requested(p1_id: String, p2_id: String)
signal cancel_requested
signal mode_changed(is_pvp: bool)

# Roster data from ArenaManager
var roster: Array = []
var mode: String = "pvp"  # pvp, pvcpu, cpuvcpu
var difficulty: String = "medium"

# Selection state
var p1_index := 0
var p2_index := 1
var p1_ready := false
var p2_ready := false

# UI references
@onready var p1_name = %P1Name
@onready var p2_name = %P2Name
@onready var p1_portrait = %P1Portrait
@onready var p2_portrait = %P2Portrait
@onready var p1_ready_btn = %P1ReadyButton
@onready var p2_ready_btn = %P2ReadyButton
@onready var p1_details = %P1Details
@onready var p2_details = %P2Details
@onready var start_btn = %StartButton
@onready var back_btn = %BackButton
@onready var mode_label = %ModeLabel
@onready var difficulty_container = %DifficultyContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	p1_ready_btn.pressed.connect(_on_p1_ready)
	p2_ready_btn.pressed.connect(_on_p2_ready)
	start_btn.pressed.connect(_on_start)
	back_btn.pressed.connect(_on_back)

	# Ensure input actions are registered
	InputHandler.register_actions()

	# Load roster if not already provided (e.g., when opened from MainMenu)
	if roster.is_empty():
		_load_roster_from_arena()

	# Keyboard navigation
	# P1: WASD to navigate, Enter to ready
	# P2: Numpad 8/4/5/6 to navigate, KP_Enter to ready

func _load_roster_from_arena() -> void:
	var arena_script: GDScript = load("res://arena_manager.gd")
	if arena_script:
		var constants: Dictionary = arena_script.get_script_constant_map()
		if constants.has("ROSTER"):
			roster = constants["ROSTER"]

func open_select(fighters: Array, p1_idx: int, p2_idx: int, p_mode: String = "pvp", p_difficulty: String = "medium") -> void:
	roster = fighters
	mode = p_mode
	difficulty = p_difficulty
	p1_index = clampi(p1_idx, 0, roster.size() - 1)
	p2_index = clampi(p2_idx, 0, roster.size() - 1)
	p1_ready = false
	p2_ready = false

	_refresh_all()
	visible = true

func _refresh_all() -> void:
	_refresh_portraits()
	_refresh_details()
	_refresh_ready_buttons()
	_refresh_start_button()
	_update_mode_ui()

func _update_mode_ui() -> void:
	match mode:
		"pvp":
			mode_label.text = "MODE: PLAYER vs PLAYER"
			difficulty_container.visible = false
			p2_name.text = "PLAYER 2"
			p2_ready_btn.visible = true
			p2_ready_btn.disabled = false
		"pvcpu":
			mode_label.text = GameText.mode_hint("pvcpu")
			difficulty_container.visible = true
			p2_name.text = "CPU"
			p2_ready_btn.visible = false
			p2_ready = true  # CPU is always "ready"
		"cpuvcpu":
			mode_label.text = GameText.mode_hint("cpuvcpu")
			difficulty_container.visible = true
			p1_name.text = "CPU 1"
			p2_name.text = "CPU 2"
			p1_ready_btn.visible = false
			p2_ready_btn.visible = false
			p1_ready = true
			p2_ready = true

func _refresh_portraits() -> void:
	if roster.is_empty():
		return

	var p1_data: Dictionary = roster[p1_index]
	var p2_data: Dictionary = roster[p2_index]

	p1_portrait.set_fighter(p1_data)
	p2_portrait.set_fighter(p2_data)

	# Update name labels
	p1_name.text = p1_data.name
	p2_name.text = p2_data.name if mode == "pvp" else "CPU"

func _refresh_details() -> void:
	if roster.is_empty():
		return

	var p1_data: Dictionary = roster[p1_index]
	var p2_data: Dictionary = roster[p2_index]

	# Clear existing detail children
	for child in p1_details.get_children():
		child.queue_free()
	for child in p2_details.get_children():
		child.queue_free()

	# Build details for P1
	_build_fighter_details(p1_details, p1_data, 1)

	# Build details for P2
	_build_fighter_details(p2_details, p2_data, 2)

func _build_fighter_details(container: VBoxContainer, data: Dictionary, player_num: int) -> void:
	# Name and types
	var name_label = Label.new()
	name_label.text = data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	container.add_child(name_label)

	# Get element/type info from fighter scene
	var types_text := _get_types_text(data)
	var type_label = Label.new()
	type_label.text = types_text
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 20)
	type_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1))
	container.add_child(type_label)

	# HP and Speed
	var hp_label = Label.new()
	hp_label.text = _get_stats_text(data)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 18)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	container.add_child(hp_label)

	var sep = HSeparator.new()
	container.add_child(sep)

	# Moves list
	var moves_label = Label.new()
	moves_label.text = "MOVES:"
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moves_label.add_theme_font_size_override("font_size", 20)
	moves_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	container.add_child(moves_label)

	# Try to get move info from fighter scene
	var move_info := _get_move_info(data)
	for move in move_info:
		var move_label = Label.new()
		move_label.text = move
		move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		move_label.add_theme_font_size_override("font_size", 16)
		move_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		container.add_child(move_label)

## Fighters are only instantiated for display here (never added to the tree), so their _ready() --
## which normally applies the archetype -- never runs. Apply it by hand so hp/speed/types are real.
const GameText := preload("res://game_text.gd")

func _data_instance(data: Dictionary) -> Fighter:
	var scene = load(data.scene)
	if scene == null:
		return null
	var inst = scene.instantiate()
	if not (inst is Fighter):
		if inst:
			inst.free()
		return null
	inst._apply_archetype()
	if inst.types.is_empty():
		inst.types = [inst.element]
	return inst

func _get_types_text(data: Dictionary) -> String:
	var inst := _data_instance(data)
	if inst == null:
		return "TYPE: UNKNOWN"
	var element_names: Array = StatsComponent.Element.keys()
	var names: Array[String] = []
	for t in inst.get_types():
		names.append(String(element_names[t]) if int(t) >= 0 and int(t) < element_names.size() else "UNKNOWN")
	inst.free()
	return "TYPE: " + " / ".join(names)

func _get_stats_text(data: Dictionary) -> String:
	var inst := _data_instance(data)
	if inst == null:
		return "HP: ?  |  SPEED: ?  |  JUMP: ?"
	var txt := "HP: %d  |  SPEED: %d  |  JUMP: %d" % [roundi(inst.hp_max), roundi(inst.move_speed), roundi(absf(inst.jump_velocity))]
	inst.free()
	return txt

func _get_move_info(data: Dictionary) -> Array[String]:
	var moves: Array[String] = []
	var inst := _data_instance(data)
	if inst == null:
		return moves
	var move_dict: Dictionary = inst._define_moves()
	for key in ["basic", "special1", "special2", "ultimate"]:
		if not move_dict.has(key):
			continue
		var m: Dictionary = move_dict[key]
		# Multi-hit moves: show per-hit damage x number of hits so the number reflects real damage.
		var hits := 1
		if int(m.get("hit_interval", 0)) > 0:
			hits = maxi(1, (int(m.get("off_f", 0)) - int(m.get("on", 0))) / int(m.hit_interval) + 1)
		elif String(m.get("kind", "melee")) == "projectile":
			hits = maxi(1, int(m.get("spawn_count", 1)))
		var line := "%s: %.0f DMG" % [String(key).to_upper(), float(m.dmg)]
		if hits > 1:
			line += " x%d" % hits
		moves.append(line)
	inst.free()
	return moves

func _refresh_ready_buttons() -> void:
	if mode == "pvp":
		p1_ready_btn.text = "READY" if not p1_ready else "WAITING..."
		p1_ready_btn.disabled = p1_ready
		p2_ready_btn.text = "READY" if not p2_ready else "WAITING..."
		p2_ready_btn.disabled = p2_ready
	elif mode == "pvcpu":
		p1_ready_btn.text = "READY" if not p1_ready else "WAITING..."
		p1_ready_btn.disabled = p1_ready
		p2_ready_btn.visible = false

func _refresh_start_button() -> void:
	var can_start := false
	match mode:
		"pvp":
			can_start = p1_ready and p2_ready
		"pvcpu":
			can_start = p1_ready
		"cpuvcpu":
			can_start = true

	start_btn.disabled = not can_start
	start_btn.text = "START" if can_start else "WAITING FOR READY..."

func _on_p1_ready() -> void:
	if mode == "cpuvcpu":
		return
	p1_ready = true
	_refresh_ready_buttons()
	_refresh_start_button()

func _on_p2_ready() -> void:
	if mode != "pvp":
		return
	p2_ready = true
	_refresh_ready_buttons()
	_refresh_start_button()

func _on_start() -> void:
	if roster.is_empty():
		return

	var p1_id: String = roster[p1_index].id
	var p2_id: String = roster[p2_index].id

	match mode:
		"pvcpu":
			p2_id = "cpu_" + p2_id
		"cpuvcpu":
			p1_id = "cpu_" + p1_id
			p2_id = "cpu_" + p2_id

	# Save last selections
	if Settings:
		Settings.set_last_p1_fighter(p1_id.trim_prefix("cpu_"))
		Settings.set_last_p2_fighter(p2_id.trim_prefix("cpu_"))
		Settings.set_last_mode(mode)

	start_requested.emit(p1_id, p2_id)
	visible = false
	get_tree().paused = false

func _on_back() -> void:
	cancel_requested.emit()
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# P1 Navigation (WASD)
	if event.is_action_pressed("p1_nav_left"):
		p1_index = wrapi(p1_index - 1, 0, roster.size())
		p1_ready = false
		_refresh_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("p1_nav_right"):
		p1_index = wrapi(p1_index + 1, 0, roster.size())
		p1_ready = false
		_refresh_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("p1_nav_up"):
		p1_index = wrapi(p1_index - 4, 0, roster.size())  # 4 cols
		p1_ready = false
		_refresh_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("p1_nav_down"):
		p1_index = wrapi(p1_index + 4, 0, roster.size())
		p1_ready = false
		_refresh_all()
		get_viewport().set_input_as_handled()

	# P1 Ready (Enter)
	elif event.is_action_pressed("p1_select") and mode in ["pvp", "pvcpu"]:
		if not p1_ready:
			_on_p1_ready()
		get_viewport().set_input_as_handled()

	# P2 Navigation (Numpad / arrows). In PvCPU / CPUvCPU this picks the CPU fighter(s).
	elif mode in ["pvp", "pvcpu", "cpuvcpu"]:
		if event.is_action_pressed("p2_nav_left"):
			p2_index = wrapi(p2_index - 1, 0, roster.size())
			p2_ready = false
			_refresh_all()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("p2_nav_right"):
			p2_index = wrapi(p2_index + 1, 0, roster.size())
			p2_ready = false
			_refresh_all()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("p2_nav_up"):
			p2_index = wrapi(p2_index - 4, 0, roster.size())
			p2_ready = false
			_refresh_all()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("p2_nav_down"):
			p2_index = wrapi(p2_index + 4, 0, roster.size())
			p2_ready = false
			_refresh_all()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("p2_select"):
			if not p2_ready:
				_on_p2_ready()
			get_viewport().set_input_as_handled()

	# Cancel/Menu (Tab)
	elif event.is_action_pressed("menu_toggle"):
		_on_back()
		get_viewport().set_input_as_handled()
