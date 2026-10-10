extends Node
## Builds the arena, owns the selected matchup, HUD, and win/menu flow.

const FLOOR_TOP := 620.0
const SHAKE_SCALE := 1.0       # 0 disables screen shake
const ELEMENT_PITCH := {       # hit-sound pitch per attack element
	StatsComponent.Element.GHOST: 0.85, StatsComponent.Element.STEEL: 1.25,
	StatsComponent.Element.FAIRY: 1.4, StatsComponent.Element.FIRE: 0.95,
	StatsComponent.Element.DARK: 0.8, StatsComponent.Element.POISON: 0.9,
}
const EVENT_SOUNDS := {"jump": "jump", "dash": "dash", "attack": "swing", "special1": "swing_special",
	"special2": "swing_special", "ultimate": "ultimate", "shot": "shot", "trap_set": "trap_set"}
const ROSTER := [
	{"id": "gholdengo", "name": "Gholdengo", "scene": "res://fighter_gholdengo.tscn", "sheet": "res://assets/gholdengo_sheet.png", "color": Color(0.8, 0.8, 0.6)},
	{"id": "marshadow", "name": "Marshadow", "scene": "res://fighter_marshadow.tscn", "sheet": "res://assets/marshadow_sheet.png", "color": Color(0.2, 0.2, 0.2)},
	{"id": "tinkaton", "name": "Tinkaton", "scene": "res://fighter_tinkaton.tscn", "sheet": "res://assets/tinkaton_sheet.png", "color": Color(0.95, 0.55, 0.75)},
	{"id": "greninja", "name": "Greninja", "scene": "res://fighter_greninja.tscn", "sheet": "res://assets/greninja_sheet.png", "color": Color(0.25, 0.5, 0.9)},
	{"id": "scizor", "name": "Scizor", "scene": "res://fighter_scizor.tscn", "sheet": "res://assets/scizor_sheet.png", "color": Color(0.85, 0.2, 0.25)},
	{"id": "decidueye", "name": "Decidueye", "scene": "res://fighter_decidueye.tscn", "sheet": "res://assets/decidueye_sheet.png", "color": Color(0.35, 0.55, 0.35)},
	{"id": "blaziken", "name": "Blaziken", "scene": "res://fighter_blaziken.tscn", "sheet": "res://assets/blaziken_sheet.png", "color": Color(0.9, 0.35, 0.2)},
	{"id": "gengar", "name": "Gengar", "scene": "res://fighter_gengar.tscn", "sheet": "res://assets/gengar_sheet.png", "color": Color(0.45, 0.25, 0.6)},
]

var p1: Fighter
var p2: Fighter
var hud
var select_menu
var combat_root: Node2D
var over = false
var camera: ArenaCamera
var sfx: Sfx
var flash: ColorRect
var selected_p1 = "marshadow"
var selected_p2 = "gholdengo"
var cpu_mode := false
var current_mode: String = "pvp"  # pvp, pvcpu, cpuvcpu
var p1_difficulty: String = "medium"
var p2_difficulty: String = "medium"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_setup")

func _setup() -> void:
	InputHandler.register_actions()
	var root := get_parent()
	_build_arena(root)
	_build_juice(root)
	hud = load("res://hud.tscn").instantiate()
	root.add_child(hud)
	select_menu = load("res://character_select.tscn").instantiate()
	root.add_child(select_menu)
	select_menu.start_requested.connect(_on_selection_applied)
	select_menu.cancel_requested.connect(_on_selection_cancelled)
	select_menu.mode_changed.connect(_on_mode_changed)

	# Check if we should just open character select in view mode (from "Characters" button)
	if Settings:
		current_mode = Settings.get_last_mode()   # keep the chosen mode (pvp / pvcpu / cpuvcpu)
	if Settings and Settings.get_view_mode_only():
		Settings.clear_view_mode_only()
		current_mode = Settings.get_last_mode()      # chosen on the Mode Select screen
		p1_difficulty = Settings.get_difficulty()
		p2_difficulty = p1_difficulty
		select_menu.open_select(ROSTER, _roster_index(selected_p1), _roster_index(selected_p2), current_mode, p1_difficulty)
		get_tree().paused = true
	else:
		var ids: Array[String] = _current_match_ids()
		_start_match(ids[0], ids[1])

## Fighter ids for the CURRENT match, with the "cpu_" prefix restored for bot-controlled sides.
## (_start_match strips the prefix, so restarting with the bare ids silently turned CPU games into PvP.)
func _current_match_ids() -> Array[String]:
	var p1_id: String = ("cpu_" if current_mode == "cpuvcpu" else "") + str(selected_p1)
	var p2_id: String = ("cpu_" if current_mode in ["pvcpu", "cpuvcpu"] else "") + str(selected_p2)
	var ids: Array[String] = [p1_id, p2_id]
	return ids

func _fighter_data(fighter_id: String) -> Dictionary:
	for entry in ROSTER:
		if entry.id == fighter_id:
			return entry
	return ROSTER[0]

func _roster_index(fighter_id: String) -> int:
	for i in ROSTER.size():
		if ROSTER[i].id == fighter_id:
			return i
	return 0

func _start_match(p1_id: String, p2_id: String) -> void:
	# Determine mode and difficulties
	var p1_is_cpu := p1_id.begins_with("cpu_")
	var p2_is_cpu := p2_id.begins_with("cpu_")

	if p1_is_cpu and p2_is_cpu:
		current_mode = "cpuvcpu"
	elif p2_is_cpu:
		current_mode = "pvcpu"
	else:
		current_mode = "pvp"

	selected_p1 = p1_id.trim_prefix("cpu_")
	selected_p2 = p2_id.trim_prefix("cpu_")

	# Bot difficulty comes from the Mode Select / Options setting (it was stuck on "medium").
	if Settings:
		p1_difficulty = Settings.get_difficulty()
		p2_difficulty = p1_difficulty

	# Get difficulties from Settings (with fallback)
	if Settings:
		p1_difficulty = Settings.get_value("game/difficulty", "medium")
		p2_difficulty = Settings.get_value("game/difficulty", "medium")
	else:
		p1_difficulty = "medium"
		p2_difficulty = "medium"

	over = false
	if is_instance_valid(combat_root):
		combat_root.queue_free()
	combat_root = Node2D.new()
	combat_root.name = "Combat"
	get_parent().add_child(combat_root)

	var first := _fighter_data(selected_p1)
	var second := _fighter_data(selected_p2)
	p1 = load(first.scene).instantiate()
	p1.name = "Player_1"
	p1.configure("p1", 1)
	p1.position = Vector2(380, 580)
	combat_root.add_child(p1)
	p2 = load(second.scene).instantiate()
	p2.name = "Player_2"
	p2.configure("p2", -1)
	p2.position = Vector2(900, 580)
	combat_root.add_child(p2)
	p1.died.connect(_on_died)
	p2.died.connect(_on_died)
	p1.got_hit.connect(_on_got_hit)
	p2.got_hit.connect(_on_got_hit)
	p1.event.connect(_on_fighter_event)
	p2.event.connect(_on_fighter_event)
	hud.bind(p1, p2, "P1 " + first.name.to_upper(), "P2 " + second.name.to_upper())
	hud.show_banner("")

	# Set camera targets for dynamic framing.
	if is_instance_valid(camera):
		camera.set_targets(p1, p2)

	# Attach AI controllers based on mode
	if p1_is_cpu:
		_attach_ai(p1, p2, p1_difficulty)
	if p2_is_cpu:
		_attach_ai(p2, p1, p2_difficulty)

func _attach_ai(fighter: Fighter, target: Fighter, difficulty: String) -> void:
	var ai_controller: AIController = AIController.new()
	ai_controller.difficulty = difficulty
	fighter.add_child(ai_controller)
	ai_controller.setup(fighter)
	ai_controller.set_target(target)

func _on_selection_applied(p1_id: String, p2_id: String) -> void:
	_start_match(p1_id, p2_id)
	select_menu.visible = false
	get_tree().paused = false

func _on_selection_cancelled() -> void:
	select_menu.visible = false
	get_tree().paused = false

func _on_mode_changed(is_pvp: bool) -> void:
	cpu_mode = not is_pvp

func _collider(parent: Node, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	body.position = rect.get_center()
	body.add_child(cs)
	parent.add_child(body)

func _tile(parent: Node, rect: Rect2, tex_path: String, tint: Color = Color.WHITE, z: int = 0) -> void:
	var tr := TextureRect.new()
	tr.texture = load(tex_path)
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.modulate = tint
	tr.z_index = z
	tr.position = rect.position
	tr.size = rect.size
	parent.add_child(tr)

func _build_arena(root: Node) -> void:
	var arena := Node2D.new()
	arena.name = "Arena"
	root.add_child(arena)

	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load("res://assets/background.png")
	bg.z_index = -10
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.position = Vector2(-40, -40)     # oversized so camera shake never reveals the edge
	bg.size = Vector2(1360, 800)
	arena.add_child(bg)

	var stone := "res://assets/stone_tile.png"
	var dark := Color(0.75, 0.75, 0.85)
	_tile(arena, Rect2(-40, FLOOR_TOP, 1360, 140), stone)                  # floor
	_tile(arena, Rect2(-40, FLOOR_TOP - 9, 1360, 20), "res://assets/grass_top.png")
	_tile(arena, Rect2(-40, -40, 1360, 64), stone, dark)                   # ceiling
	_tile(arena, Rect2(-40, -40, 64, 800), stone, dark)                    # left wall
	_tile(arena, Rect2(1256, -40, 64, 800), stone, dark)                   # right wall

	_collider(arena, Rect2(-40, FLOOR_TOP, 1360, 140))
	_collider(arena, Rect2(-40, -40, 1360, 64))
	_collider(arena, Rect2(-40, -40, 64, 800))
	_collider(arena, Rect2(1256, -40, 64, 800))

func _on_died(loser: Fighter) -> void:
	if over:
		return
	over = true
	var round_p1 := p1
	var round_p2 := p2
	var winner := p2 if loser == p1 else p1
	var winner_name: String = str(_fighter_data(selected_p1 if winner == p1 else selected_p2).name).to_upper()
	hud.show_banner(preload("res://game_text.gd").win_banner(winner_name))
	p1.stats.clear_statuses()
	p2.stats.clear_statuses()
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(round_p1) and is_instance_valid(round_p2) and p1 == round_p1 and p2 == round_p2:
		round_p1.set_physics_process(false)
		round_p2.set_physics_process(false)

func _build_juice(root: Node) -> void:
	camera = ArenaCamera.new()
	camera.position = Vector2(640, 360)
	root.add_child(camera)
	camera.make_current()
	sfx = Sfx.new()
	root.add_child(sfx)
	var layer := CanvasLayer.new()
	layer.layer = 5
	root.add_child(layer)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)

func _on_got_hit(info: Dictionary) -> void:
	var dmg: float = info.dmg
	var amp := 0.0
	if info.ko:
		amp = 16.0
	elif dmg >= 25.0:
		amp = 12.0
	elif dmg >= 14.0 or info.heavy:
		amp = 7.0
	elif dmg >= 8.0:
		amp = 3.0
	if amp > 0.0 and SHAKE_SCALE > 0.0:
		camera.shake(amp * SHAKE_SCALE, 8 + int(amp))
		# Add trauma based on hit intensity
		var trauma_amount := 0.0
		if info.ko:
			trauma_amount = 0.8
		elif dmg >= 25.0:
			trauma_amount = 0.6
		elif dmg >= 14.0 or info.heavy:
			trauma_amount = 0.4
		elif dmg >= 8.0:
			trauma_amount = 0.2
		camera.add_trauma(trauma_amount)
	HitVfx.spawn(combat_root, info)
	DamageNumber.spawn(combat_root, info)
	var pitch: float = ELEMENT_PITCH.get(info.element, 1.0)
	if info.ko:
		sfx.play("hit_ko", info.pos, 0.0, pitch)
	elif info.heavy:
		sfx.play("hit_heavy", info.pos, 0.0, pitch)
	else:
		sfx.play("hit_light", info.pos, -3.0, pitch)
	if info.mult > 1.0:
		sfx.play("hit_super", info.pos, -6.0)

func _on_fighter_event(kind: String, pos: Vector2) -> void:
	if kind == "ultimate":
		camera.shake(5.0 * SHAKE_SCALE, 12)
		# Add trauma for ultimate moves
		camera.add_trauma(0.5)
		flash.color.a = 0.55
		var tw := create_tween()
		tw.tween_property(flash, "color:a", 0.0, 0.3)
	sfx.play(EVENT_SOUNDS.get(kind, ""), pos, -4.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not is_instance_valid(select_menu):
		return
	if select_menu.visible:
		return
	if event.is_action_pressed("menu_toggle"):
		select_menu.open_select(ROSTER, _roster_index(selected_p1), _roster_index(selected_p2), current_mode, p1_difficulty)
		get_tree().paused = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_round"):
		var ids: Array[String] = _current_match_ids()
		_start_match(ids[0], ids[1])
		get_viewport().set_input_as_handled()
