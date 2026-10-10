class_name Fighter
extends CharacterBody2D
## Base fighter. Archetypes subclass this and override _apply_archetype()
## and _define_moves(). All frame counts are 60 fps physics ticks.

signal died(fighter)
## Emitted on the defender for every connected hit (melee, projectile or trap).
## info: pos, element, dmg, mult, dir, heavy, ko, hitstop, kb
signal got_hit(info: Dictionary)
## Gameplay events for sound/VFX hooks: "jump", "dash", "attack", "special1",
## "special2", "ultimate", "shot", "trap_set".
signal event(kind: String, pos: Vector2)

const GRAVITY_RISE := 2200.0
const GRAVITY_FALL := 3200.0
const JUMP_CUT := -220.0          # release jump early to cap the rise
const GROUND_ACCEL := 4000.0
const AIR_ACCEL := 2600.0
const ATTACK_STAMINA_GAIN := 5.0  # basic attack hit -> stamina
const HITSTUN_FRAMES := 18
const HITSTOP_SCALE := 1.0         # global multiplier for hit freeze (0 disables)
const KO_HITSTOP := 12             # long freeze on the killing blow

# --- Aerial Attack Constants ---
const AERIAL_ATTACK_PUSH := 340.0   # horizontal speed for aerial attack (held for the whole move)
const AERIAL_HOP := 460.0           # minimum downward speed during an aerial attack (diagonal dive)
const AERIAL_KB_Y := 100.0          # downward knockback magnitude for aerial attack
const AERIAL_ANGLE := 0.5         # radians below horizontal (~29 deg): hitbox, FX and body all point this way

# --- Phase 1: Core Combat Tech ---
const DI_INFLUENCE := 0.15         # max horizontal velocity shift per frame during hitstun
const TECH_WINDOW := 5             # frames after landing in which a tech still works
const TECH_IFRAMES := 6            # was 12: tech invincibility
const TECH_RECOVERY := 0.22        # seconds rooted after a tech (no dash/jump/move)
const TECH_COOLDOWN := 1.0         # seconds before you can tech again
const COYOTE_FRAMES := 6           # grace frames to jump after leaving a ledge
const BUFFER_TAIL := 8             # combat presses are held until the last N frames of a move
const APEX_BAND := 140.0           # |vy| under this counts as jump apex
const APEX_GRAVITY_MULT := 0.7     # lighter gravity at the apex = smoother arc
const DASH_EASE_START := 0.6       # fraction of the dash after which speed eases out
const DASH_CARRY := 0.4            # momentum kept when the dash ends
const FAST_FALL_MULT := 2.5        # gravity multiplier when holding down
const WAVEDASH_WINDOW := 4         # frames after jump to input dash for wavedash
const WAVEDASH_SPEED_MULT := 0.8   # wavedash horizontal speed vs normal dash

## If true, burn/slow only apply when the hit is type-super-effective.
## Milestone 2 spec says Fire->Zoner burns and Water->Brawler slows, so: false.
const STATUS_REQUIRES_SUPER := false

const DEBUG_HITBOXES := false     # draw yellow hitbox rects for tuning
const FRAME_PX := 64
const FX_PIXEL := 2.0              # move VFX strips are authored at half-res
# [animation, frame count, fps, loop] - one sheet row each, in this order.
const ANIMS := [["idle", 4, 6.0, true], ["run", 6, 12.0, true], ["jump", 2, 6.0, false],
	["dash", 2, 10.0, false], ["attack", 4, 16.0, false], ["hitstun", 2, 8.0, true],
	["ko", 3, 6.0, false]]

const MOVE_DEFAULTS := {
	"kind": "melee",            # "melee" | "projectile" | "trap"
	"dmg": 8.0,
	"size": Vector2(44, 32),    # hitbox size
	"off": Vector2(34, -4),     # hitbox offset (x is mirrored by facing)
	"on": 4, "off_f": 8,        # hitbox active frames [on, off_f)
	"total": 16,                # total move frames
	"kb": Vector2(380, -220),
	"push": 0.0,                # horizontal speed set on move start
	"lunge": 0.0,               # horizontal speed held during active frames
	"hop": 0.0,                 # vertical velocity set on move start
	"cd": 0.0,                  # cooldown seconds
	"cost": 0.0,                # stamina cost
	"spawn": 0,                 # frame on which a projectile/trap spawns
	"proj_speed": 0.0,
	"spawn_count": 1,
	"spawn_interval": 1,
	"hit_interval": 0,
	"i_frames": 0,
	"teleport_distance": 0.0,
	"counter": false,
	"stamina_steal": 0.0,
	"self_damage": 0.0,
	"damage_buff": 1.0,
	"hitstun_mult": 1.0,
	"root": 0.0,
	"trap_lifetime": 3.0,
	"trap_persistent": false,
	"trap_tick": 0.0,
	"track_y": false,
	"projectile_block": false,
	"anim_rate": 1.0,
	"anim_tilt": 0.0,
	"anim_scale": Vector2.ONE,
	"fx_tint": Color.WHITE,
	"fx": "",                  # animated per-move VFX strip (frames side by side, drawn at FX_PIXEL scale)
	"fx_frames": 4,
	"fx_loop": false,           # loop the strip while the hitbox is active (multi-hit / dive moves)
	"fx_cast": "",             # cast flourish for projectile/trap moves (e.g. Decidueye drawing his bow)
	"fx_cast_frames": 4,
	"fx_cast_off": Vector2(26, -6),
	"proj_frames": 1,          # projectile texture is a strip with this many frames
	"proj_fps": 14.0,
	# --- Phase 3 additions ---
	"element": -1,              # attack element override (-1 = fighter's primary type)
	"apply": "auto",            # status: "auto" (by element) | "none" | "burn" | "slow" | "poison"
	"stun": 18,                 # hitstun frames inflicted
	"proj_vys": [],             # per-shot vertical speed (index = shot number)
	"proj_off": Vector2(30, -4),
	"proj_tex": "res://assets/water_orb.png",
	"proj_scale": 1.0,
	"proj_r": 10.0,             # projectile hit radius
	"proj_life": 3.0,
	"proj_spin": 0.0,           # rad/s
	"trap_tex": "res://assets/trap.png",
	"trap_dist": 90.0,
	"dive_start": 0,            # kind "dive": frame the dive begins (after the hop)
	"dive_dx": 380.0,
	"dive_speed": 1050.0,
}

# --- archetype values (set in _apply_archetype) ---
var hp_max := 100.0
var move_speed := 260.0
var jump_velocity := -760.0
var gravity_mult := 1.0
var element: StatsComponent.Element = StatsComponent.Element.NORMAL
var base_color := Color(0.3, 0.6, 1.0)
var sheet_path := "res://assets/zoner_sheet.png"   # sprite sheet (see ANIMS)
var fx_path := ""                                   # melee swing effect texture
var moves := {}
var types: Array = []             # one or two StatsComponent.Element values; [0] is the attack type

func get_types() -> Array:
	return types

var fall_mult := 1.0              # extra gravity while falling
var max_fall := 1100.0
var dash_speed := 720.0
var dash_frames := 15
var iframe_frames := 12           # dash invincibility frames (12 = 0.2 s)
var dash_cost := 25.0
var dash_sink := false            # Marshadow-style "sink into the shadows" dash visuals
var hitstun_frames := 18
var dive_active := false
var dive_end := -1
var move_inv := false

# --- Synergy Burst archetype traits ---
var burst_fill_hit := 1.0
var burst_fill_dealt := 1.0
var burst_fill_taken := 1.0
var burst_fill_passive := 1.0
var burst_stat_buffs := {}  # e.g., {"damage": 1.2, "defense": 1.15, "speed": 1.1}
var burst_passive_heal := 0.0
var burst_armor := false

var prefix := "p1"
var facing := 1
var invincible := false
var dead := false
var hitbox_active := false
var hit_targets: Array = []
var hit_counts: Dictionary = {}
var dash_dir := 1
var cooldowns := {"special1": 0.0, "special2": 0.0}
var cur_move: Dictionary = {}
var cur_key := ""
var counter_active := false
var projectile_block := false
var rooted_time := 0.0
var next_damage_buff := 1.0
var next_hitstun_mult := 1.0
var move_iframes_left := 0
var move_spawned := 0
var move_teleported := false
var freeze_frames := 0            # hitstop: fighter is frozen while > 0
var hit_confirmed := false        # current move has connected (enables cancels)
var hitbox_size := Vector2(44, 32)

var input: InputHandler
var stats: StatsComponent
var sm: StateMachine
var hurtbox: Area2D
var hitbox: Area2D
var hitbox_shape: RectangleShape2D
var synergy: SynergySystem
var support: SupportSystem
var attack_anim_scale := 1.0
var move_anim_tilt := 0.0
var move_anim_scale := Vector2.ONE
var move_fx_tint := Color.WHITE
var move_fx: Sprite2D
var default_fx_tex: Texture2D
var _fx_cache := {}
var burn_icon: Sprite2D
var slow_icon: Sprite2D
var poison_icon: Sprite2D
var hit_flash_timer := 0.0

# --- Phase 1: Core Combat Tech state ---
var di_input := 0.0                 # stored DI direction during hitstun
var tech_ready := false             # true when in tech window
var tech_input_buffer := 0          # frames since dash pressed for tech
var wavedash_buffer := 0            # frames since jump for wavedash detection
var air_dashed := false             # track if air dash used this jump
var coyote := 0
var stun_air := false              # launched into the air this hitstun (tech only after a real landing)
var tech_since_land := 0
var tech_cd := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# ---------------- overridable ----------------
func _apply_archetype() -> void:
	pass

func _define_moves() -> Dictionary:
	return {
		"basic": mv({}),
		"special1": mv({"cd": 3.0, "cost": 15.0, "dmg": 12.0}),
		"special2": mv({"cd": 5.0, "cost": 20.0, "dmg": 14.0}),
		"ultimate": mv({"dmg": 30.0, "size": Vector2(140, 90), "off": Vector2(60, -6),
			"total": 36}),
	}

func _define_moves_default() -> Dictionary:
	return {
		"basic": mv({}),
		"special1": mv({"cd": 3.0, "cost": 15.0, "dmg": 12.0}),
		"special2": mv({"cd": 5.0, "cost": 20.0, "dmg": 14.0}),
		"ultimate": mv({"dmg": 30.0, "size": Vector2(140, 90), "off": Vector2(60, -6), "total": 36}),
	}

func mv(d: Dictionary) -> Dictionary:
	var r: Dictionary = MOVE_DEFAULTS.duplicate()
	r.merge(d, true)
	return r

func configure(p_prefix: String, face: int) -> void:
	prefix = p_prefix
	facing = face

# ---------------- setup ----------------
func _ready() -> void:
	_apply_archetype()
	if types.is_empty():
		types = [element]
	element = types[0]
	moves = _define_moves()
	# Every fighter needs all move keys because the shared input/state handlers
	# dispatch them directly. Older roster definitions inherit safe defaults.
	var fallback_moves := _define_moves_default()
	for key in ["basic", "special1", "special2", "ultimate"]:
		if not moves.has(key):
			moves[key] = fallback_moves[key]

	collision_layer = 4   # fighters pass through each other
	collision_mask = 1    # but collide with the world

	var cap := CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 52.0

	var body_shape := CollisionShape2D.new()
	body_shape.name = "CollisionShape2D"
	body_shape.shape = cap
	add_child(body_shape)

	hurtbox = Area2D.new()
	hurtbox.name = "HurtboxArea2D"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	var hs := CollisionShape2D.new()
	hs.shape = cap
	hurtbox.add_child(hs)
	add_child(hurtbox)

	hitbox = Area2D.new()
	hitbox.name = "HitboxArea2D"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.monitoring = false
	hitbox_shape = RectangleShape2D.new()
	hitbox_shape.size = hitbox_size
	var hbs := CollisionShape2D.new()
	hbs.shape = hitbox_shape
	hitbox.add_child(hbs)
	add_child(hitbox)

	input = InputHandler.new()
	input.name = "InputHandler"
	input.prefix = prefix
	add_child(input)

	stats = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.max_hp = hp_max
	stats.base_speed = move_speed
	stats.element = element
	stats.types = types
	add_child(stats)
	stats.burn_ticked.connect(take_dot)
	stats.poison_ticked.connect(take_dot)

	sm = StateMachine.new()
	sm.name = "StateMachine"
	add_child(sm)
	sm.start(self, "idle")

	# Synergy System
	synergy = SynergySystem.new()
	synergy.name = "SynergySystem"
	synergy.set_player(1 if prefix == "p1" else 2)
	synergy.set_archetype_traits({
		"burst_fill_hit": burst_fill_hit,
		"burst_fill_dealt": burst_fill_dealt,
		"burst_fill_taken": burst_fill_taken,
		"burst_fill_passive": burst_fill_passive
	})
	synergy.burst_activated.connect(_on_burst_activated)
	synergy.burst_ended.connect(_on_burst_ended)
	synergy.ultimate_ready.connect(_on_ultimate_ready)
	synergy.ultimate_used.connect(_on_ultimate_used)
	add_child(synergy)

	# Support System
	support = SupportSystem.new()
	support.name = "SupportSystem"
	support.set_player(1 if prefix == "p1" else 2)
	support.support_called.connect(_on_support_called)
	add_child(support)

	_setup_visuals()

func _physics_process(delta: float) -> void:
	input.poll()

	# Handle hit flash effect
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			# Reset sprite modulation when flash ends
			sprite.self_modulate = Color.WHITE

	if freeze_frames > 0:
		# Hitstop: nothing advances (states, cooldowns, statuses, regen) but the
		# input buffer keeps listening, so presses made during the freeze count.
		freeze_frames -= 1
		_update_visuals()
		sprite.speed_scale = 0.0
		return
	stats.tick(delta)
	stats.tick_statuses()
	# Synergy: passive heal during Burst Mode
	if synergy.is_burst_active() and burst_passive_heal > 0.0:
		stats.hp = min(stats.max_hp, stats.hp + burst_passive_heal * delta)
	rooted_time = maxf(0.0, rooted_time - delta)
	tech_cd = maxf(0.0, tech_cd - delta)
	for k in cooldowns:
		cooldowns[k] = max(0.0, cooldowns[k] - delta)
	if move_iframes_left > 0:
		move_iframes_left -= 1
		move_inv = true
		invincible = true
		hurtbox.monitorable = false
	elif move_inv:
		move_inv = false
		if sm.current != "dash":
			_restore_hurtbox()
	# Hold buffered combat presses during a move so mashing inside a long recovery isn't lost.
	input.hold_buffers = (sm.current in ["attack", "special1", "special2", "ultimate"]
		and sm.frames < int(cur_move.get("total", 0)) - BUFFER_TAIL)
	sm.tick(delta)
	var was_on_floor := is_on_floor()
	move_and_slide()
	if is_on_floor() and velocity.y >= 0.0:
		coyote = COYOTE_FRAMES
	elif coyote > 0:
		coyote -= 1
	# Reset air dash on landing
	if is_on_floor() and not was_on_floor:
		air_dashed = false
		wavedash_buffer = 0
	_update_visuals()

func cooldown_ratio(key: String) -> float:
	var cd: float = moves[key].cd
	if cd <= 0.0:
		return 1.0
	return clamp(1.0 - cooldowns[key] / cd, 0.0, 1.0)

# ---------------- helpers ----------------
func _gravity(delta: float) -> void:
	var g := (GRAVITY_FALL * fall_mult if velocity.y > 0.0 else GRAVITY_RISE) * gravity_mult
	if absf(velocity.y) < APEX_BAND and not is_on_floor():
		g *= APEX_GRAVITY_MULT
	velocity.y = min(velocity.y + g * delta, max_fall)

func _steer(delta: float, accel: float) -> void:
	var target := input.move_x * stats.get_speed() if input.enabled and rooted_time <= 0.0 else 0.0
	velocity.x = move_toward(velocity.x, target, accel * delta)
	if input.enabled and rooted_time <= 0.0 and input.move_x != 0.0:
		facing = 1 if input.move_x > 0.0 else -1

func _try_actions() -> bool:
	# Synergy: Ultimate activation during Burst Mode
	if input.want("ultimate"):
		input.consume("ultimate")
		if synergy.try_use_ultimate():
			sm.change("ultimate")
			return true
		# Fallback: standard ultimate (full stamina)
		if stats.stamina >= stats.max_stamina - 0.01:
			stats.spend(stats.max_stamina)
			sm.change("ultimate")
			return true

	# Support call (L1/R1 or equivalent)
	if input.want("support"):
		input.consume("support")
		var slot := 0
		if input.want("support_2"):
			slot = 1
		elif input.want("support_3"):
			slot = 2
		support.try_call_support(slot)
		# Don't return true - support calls don't interrupt current action
	for key in ["special2", "special1"]:
		var m: Dictionary = moves[key]
		if input.want(key) and cooldowns[key] <= 0.0 and stats.can_spend(m.cost):
			input.consume(key)
			stats.spend(m.cost)
			cooldowns[key] = m.cd
			sm.change(key)
			return true
	if input.want("dash") and rooted_time <= 0.0 and stats.can_spend(dash_cost) and (is_on_floor() or not air_dashed):
		input.consume("dash")
		event.emit("dash", global_position)
		sm.change("dash")
		return true
	if input.want("attack"):
		input.consume("attack")
		sm.change("attack")
		return true
	if input.want("jump") and rooted_time <= 0.0 and (is_on_floor() or coyote > 0):
		input.consume("jump")
		coyote = 0
		event.emit("jump", global_position)
		velocity.y = jump_velocity
		sm.change("jump")
		return true
	return false

func _restore_hurtbox() -> void:
	invincible = false
	hurtbox.monitorable = true

func _hitbox_off() -> void:
	hitbox_active = false
	hitbox.monitoring = false

func _check_hits() -> void:
	if not hitbox_active:
		return
	var m: Dictionary = cur_move
	for area in hitbox.get_overlapping_areas():
		var t := area.get_parent()
		if t == self or not (t is Fighter):
			continue
		var last_hit: int = int(hit_counts.get(t, -100000))
		if last_hit > -100000 and (m.hit_interval <= 0 or sm.frames - last_hit < m.hit_interval):
			continue
		hit_counts[t] = sm.frames
		hit_targets.append(t)
		var dmg_dealt: float = m.dmg * next_damage_buff
		if t.receive_hit(self, dmg_dealt, m.kb, global_position.x, m):
			if cur_key == "basic":
				stats.gain_stamina(ATTACK_STAMINA_GAIN)
			if m.stamina_steal > 0.0:
				stats.gain_stamina(m.stamina_steal)
			if m.root > 0.0:
				t.rooted_time = maxf(t.rooted_time, m.root)
			# Synergy: fill gauge on hit connect
			synergy.on_hit_connect(m.counter)
			synergy.on_damage_dealt(dmg_dealt)
			next_damage_buff = 1.0
			next_hitstun_mult = 1.0

## Returns true if the hit connected.
func receive_hit(attacker: Fighter, damage: float, kb: Vector2, from_x: float, move_data: Dictionary = {}) -> bool:
	if invincible or dead:
		return false
	if counter_active:
		counter_active = false
		attacker.receive_hit(self, damage * 1.5, Vector2(kb.x, kb.y), global_position.x)
		return false
	if projectile_block and attacker != self:
		return false
	var atk_el: int = int(move_data.get("element", -1))
	if atk_el < 0:
		atk_el = attacker.types[0]
	var mult := StatsComponent.type_multiplier(atk_el, stats.types)
	stats.hp = max(0.0, stats.hp - damage * mult)
	# 'dir' is declared at function scope: the hit VFX below needs it for every branch.
	var dir := int(sign(global_position.x - from_x))
	if dir == 0:
		dir = attacker.facing
	if move_data.get("is_aerial", false):
		# Aerial attack: knockback in attacker's facing direction
		dir = attacker.facing
	velocity = Vector2(dir * kb.x, kb.y)
	if next_hitstun_mult != 1.0:
		velocity *= next_hitstun_mult

	# Burst Armor: reduce knockback and hitstun during Burst Mode
	if synergy.is_burst_active() and burst_armor:
		velocity *= 0.3  # 70% knockback reduction
		hitstun_frames = int(hitstun_frames * 0.4)  # 60% hitstun reduction

	# Hitstop logic
	hit_confirmed = true
	var damage_dealt := damage * mult
	# Synergy: fill gauge on damage taken
	synergy.on_damage_taken(damage_dealt)
	var hitstop := _hitstop_frames(damage_dealt, move_data)
	if stats.hp <= 0.0:
		hitstop = KO_HITSTOP
	# Brief white hit flash scales with hit intensity
	hit_flash_timer = 0.08 + float(hitstop) * 0.006
	sprite.self_modulate = Color(1.8, 1.8, 1.8)
	freeze_frames = max(freeze_frames, hitstop)
	attacker.freeze_frames = max(attacker.freeze_frames, hitstop)
	input.clear()
	got_hit.emit({
	    "pos": global_position + Vector2(-dir * 12.0, -6.0),
	    "element": atk_el,
	    "dmg": damage_dealt,
	    "mult": mult,
	    "dir": dir,
	    "heavy": damage_dealt >= 14.0 or kb.length() >= 600.0,
	    "ko": stats.hp <= 0.0,
	    "hitstop": hitstop,
	    "kb": kb,
	})
	hitstun_frames = int(move_data.get("stun", HITSTUN_FRAMES))
	stun_air = not is_on_floor()
	tech_since_land = 0
	sm.change("hitstun")
	if not STATUS_REQUIRES_SUPER or mult > 1.0:
		_apply_status(atk_el, str(move_data.get("apply", "auto")))
	_check_death()
	return true

## 3-7 frames by damage; multi-hit flurries stay short so they remain fluid.
func _hitstop_frames(dmg: float, m: Dictionary) -> int:
	var f := 3
	if dmg >= 30.0:
		f = 7
	elif dmg >= 18.0:
		f = 6
	elif dmg >= 10.0:
		f = 5
	elif dmg >= 6.0:
		f = 4
	if int(m.get("hit_interval", 0)) > 0:
		f = 2
	return int(round(f * HITSTOP_SCALE))


func _apply_status(element_id: int, apply: String) -> void:
	var s := apply
	if s == "auto":
		match element_id:
			StatsComponent.Element.FIRE:
				s = "burn"
			StatsComponent.Element.WATER:
				s = "slow"
			StatsComponent.Element.POISON:
				s = "poison"
			_:
				s = "none"
	match s:
		"burn":
			stats.apply_burn()
		"slow":
			stats.apply_slow()
		"poison":
			stats.apply_poison()

func take_dot(amount: float) -> void:
	if dead:
		return
	stats.hp = max(0.0, stats.hp - amount)
	_check_death()

func _check_death() -> void:
	if stats.hp <= 0.0 and not dead:
		dead = true
		input.enabled = false
		stats.clear_statuses()
		if sm.current != "hitstun":
			sm.change("hitstun")
		died.emit(self)

# --- Synergy Burst callbacks ---
func _on_burst_activated(_pid: int) -> void:
	# Apply burst stat buffs
	if burst_stat_buffs.has("damage"):
		next_damage_buff *= burst_stat_buffs.damage
	if burst_stat_buffs.has("defense"):
		# Reduce incoming damage by increasing effective defense
		pass  # handled in receive_hit
	if burst_stat_buffs.has("speed"):
		move_speed *= burst_stat_buffs.speed
		stats.base_speed = move_speed
	# Visual indicator
	sprite.modulate = base_color.lightened(0.3)

func _on_burst_ended(_pid: int) -> void:
	# Revert stat buffs
	if burst_stat_buffs.has("damage"):
		next_damage_buff = 1.0
	if burst_stat_buffs.has("speed"):
		move_speed /= burst_stat_buffs.speed
		stats.base_speed = move_speed
	# Restore visual
	sprite.modulate = Color.WHITE

func _on_ultimate_ready(_pid: int) -> void:
	# Visual feedback - ultimate ready
	sprite.modulate = Color.GOLD

func _on_ultimate_used(_pid: int) -> void:
	# Ultimate consumed
	sprite.modulate = Color.WHITE

# --- Support System callbacks ---
func _on_support_called(_pid: int, support_id: String) -> void:
	# Visual feedback for support call
	var def: Dictionary = SupportSystem.get_support_definition(support_id)
	if def:
		event.emit("support_" + support_id, global_position)

# ---------------- generic move runner ----------------
func _enter_move(key: String) -> void:
	cur_key = key
	cur_move = moves[key].duplicate()
	hit_targets.clear()
	hit_counts.clear()
	hit_confirmed = false
	move_spawned = 0
	move_teleported = false
	var m: Dictionary = cur_move
	var profile := _move_animation_profile(key)
	move_anim_tilt = (m.anim_tilt + profile.tilt) * facing
	move_anim_scale = m.anim_scale * profile.scale
	move_fx_tint = m.fx_tint * profile.tint
	if m.i_frames > 0:
		move_iframes_left = int(m.i_frames)
	if m.counter:
		counter_active = true
	if m.projectile_block:
		projectile_block = true
	if m.damage_buff != 1.0:
		next_damage_buff = m.damage_buff
	if m.hitstun_mult != 1.0:
		next_hitstun_mult = m.hitstun_mult
	if m.teleport_distance > 0.0:
		global_position.x = clampf(global_position.x + facing * m.teleport_distance, 32.0, 1248.0)
		move_teleported = true
	if m.self_damage > 0.0:
		stats.hp = maxf(1.0, stats.hp - m.self_damage)
	hitbox_size = m.size
	hitbox_shape.size = m.size
	hitbox.position = Vector2(facing * m.off.x, m.off.y)
	hitbox.rotation = 0.0
	velocity.x = facing * m.push
	if m.hop != 0.0:
		velocity.y = m.hop
	# Aerial attack: when not grounded, basic attack moves diagonally down
	if key == "basic" and not is_on_floor():
		velocity.x = facing * AERIAL_ATTACK_PUSH
		velocity.y = AERIAL_HOP
		cur_move.is_aerial = true
		cur_move.kb = Vector2(cur_move.kb.x, AERIAL_KB_Y)
		# Aim the hitbox down the diagonal of the dive: longer box, centred along the dive line, rotated to match.
		var aim := Vector2(facing * cos(AERIAL_ANGLE), sin(AERIAL_ANGLE))
		var hs: Vector2 = m.size
		hitbox_size = Vector2(hs.x * 1.15, hs.y)
		hitbox_shape.size = hitbox_size
		hitbox.position = aim * (absf(float(m.off.x)) + hs.x * 0.2) + Vector2(0.0, 6.0)
		hitbox.rotation = facing * AERIAL_ANGLE
	# Stretch the attack frames over this move, then apply its signature tempo.
	attack_anim_scale = (4.0 / (float(m.total) / 60.0)) / 16.0 * m.anim_rate * profile.rate
	sprite.play("attack")
	sprite.frame = 0
	event.emit("attack" if key == "basic" else key, global_position)

func _move_animation_profile(key: String) -> Dictionary:
	# The roster sheets share their 4-frame attack row. Give each move slot
	# its own anticipation/follow-through tempo and pose while retaining that art.
	match key:
		"basic":
			return {"rate": 1.28, "tilt": 0.16, "scale": Vector2(1.02, 0.98), "tint": base_color.lightened(0.18)}
		"special1":
			return {"rate": 0.96, "tilt": -0.24, "scale": Vector2(1.1, 1.04), "tint": base_color.lightened(0.28)}
		"special2":
			return {"rate": 0.82, "tilt": 0.32, "scale": Vector2(1.16, 0.9), "tint": base_color.lightened(0.38)}
		"ultimate":
			return {"rate": 0.66, "tilt": -0.12, "scale": Vector2(1.28, 1.2), "tint": base_color.lightened(0.52)}
	return {"rate": 1.0, "tilt": 0.0, "scale": Vector2.ONE, "tint": Color.WHITE}

func _run_move(delta: float) -> void:
	var m: Dictionary = cur_move
	var f := sm.frames
	if m.kind == "dive":
		_move_dive(m, f, delta)
		return
	_gravity(delta)
	if m.kind == "melee":
		if f == m.on:
			hitbox_active = true
			hitbox.monitoring = true
		elif f == m.off_f:
			_hitbox_off()
		if m.lunge != 0.0 and f >= m.on and f < m.off_f:
			velocity.x = facing * m.lunge
		elif bool(m.get("is_aerial", false)) and not is_on_floor():
			# Aerial attack: keep driving diagonally down for the whole move (was decayed in ~5 frames).
			velocity.x = facing * AERIAL_ATTACK_PUSH
			velocity.y = maxf(velocity.y, AERIAL_HOP)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
		_check_hits()
		if bool(m.get("is_aerial", false)) and is_on_floor() and f > 2:
			_finish_move()   # landing cancels the rest of the aerial
			return
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
		_spawn_scheduled(m, f)
	# Cancel chains: once a basic/special connects, a buffered special/ultimate
	# can interrupt the recovery (basic -> special1/2, special1 -> special2 ...).
	if hit_confirmed and (cur_key == "basic" or cur_key == "special1") and f >= int(m.on):
		if _try_special_cancel():
			return
	if f >= m.total:
		_finish_move()

func _try_special_cancel() -> bool:
	if input.want("ultimate") and stats.stamina >= stats.max_stamina - 0.01:
		input.consume("ultimate")
		stats.spend(stats.max_stamina)
		sm.change("ultimate")
		return true
	for key in ["special2", "special1"]:
		var sm_data: Dictionary = moves[key]
		if key != cur_key and input.want(key) and cooldowns[key] <= 0.0 and stats.can_spend(sm_data.cost):
			input.consume(key)
			stats.spend(sm_data.cost)
			cooldowns[key] = sm_data.cd
			sm.change(key)
			return true
	return false


func _finish_move() -> void:
	sm.change("idle" if is_on_floor() else "jump")

## Hop up, then dive diagonally down until landing (Blaziken's dive kick).
func _move_dive(m: Dictionary, f: int, delta: float) -> void:
	var start := int(m.dive_start)
	if f < start:
		_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		return
	if f == start:
		dive_active = true
		dive_end = -1
		hitbox_active = true
		hitbox.monitoring = true
	if dive_active:
		velocity = Vector2(facing * m.dive_dx, m.dive_speed)
		_check_hits()
		if f > start and is_on_floor():
			dive_active = false
			_hitbox_off()
			velocity.x = 0.0
			dive_end = f + 8      # landing recovery
	else:
		_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
		if (dive_end >= 0 and f >= dive_end) or f > 150:
			_finish_move()

func _spawn_scheduled(m: Dictionary, f: int) -> void:
	var n := int(m.spawn_count)
	for i in n:
		if f != int(m.spawn) + i * int(m.spawn_interval):
			continue
		if m.kind == "projectile":
			var vys: Array = m.proj_vys
			_spawn_projectile(m, float(vys[i]) if i < vys.size() else 0.0)
		elif m.kind == "trap":
			_spawn_trap(m)

func _spawn_projectile(m: Dictionary, vy: float) -> void:
	var p = load("res://projectile.tscn").instantiate()
	p.setup(self, facing, m, vy)
	var off: Vector2 = m.proj_off
	p.position = global_position + Vector2(facing * off.x, off.y)
	get_parent().add_child(p)
	event.emit("shot", p.position)

func _spawn_trap(m: Dictionary) -> void:
	var tx: float = clamp(global_position.x + facing * float(m.trap_dist), 40.0, 1240.0)
	var q := PhysicsRayQueryParameters2D.create(
		Vector2(tx, global_position.y), Vector2(tx, global_position.y + 900.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var pos := Vector2(tx, global_position.y + 26.0)
	if hit:
		pos = hit.position
	var t = load("res://trap.gd").new()
	t.setup(self, m)
	t.position = pos
	get_parent().add_child(t)
	event.emit("trap_set", pos)

func _end_move() -> void:
	_hitbox_off()
	hitbox.rotation = 0.0
	dive_active = false
	if move_inv:
		move_iframes_left = 0
		move_inv = false
		_restore_hurtbox()

# ---------------- states ----------------
func state_idle(delta: float) -> void:
	_gravity(delta)
	_steer(delta, GROUND_ACCEL)
	if _try_actions():
		return
	if not is_on_floor():
		sm.change("jump")
	elif input.move_x != 0.0 and input.enabled:
		sm.change("run")

func state_run(delta: float) -> void:
	_gravity(delta)
	_steer(delta, GROUND_ACCEL)
	if _try_actions():
		return
	if not is_on_floor():
		sm.change("jump")
	elif input.move_x == 0.0 or not input.enabled:
		sm.change("idle")

func state_jump(delta: float) -> void:
	# Fast-fall: holding down increases gravity
	var fast_falling := input.enabled and input.move_x == 0.0 and velocity.y > 0.0 and Input.is_action_pressed(prefix + "_down")
	var grav_mult := FAST_FALL_MULT if fast_falling else 1.0
	_gravity(delta * grav_mult)
	_steer(delta, AIR_ACCEL)

	if not input.jump_held and velocity.y < JUMP_CUT:
		velocity.y = JUMP_CUT

	# Wavedash detection: buffer dash input shortly after jump
	if wavedash_buffer < WAVEDASH_WINDOW:
		wavedash_buffer += 1
		if input.want("dash") and not air_dashed and stats.can_spend(dash_cost):
			_wavedash()
			return

	if _try_actions():
		return
	if is_on_floor() and velocity.y >= 0.0:
		sm.change("idle")

func _wavedash() -> void:
	# Air dodge into wavedash - quick horizontal burst with i-frames
	air_dashed = true
	stats.spend(dash_cost)
	dash_dir = (1 if input.move_x > 0.0 else -1) if input.move_x != 0.0 else facing
	facing = dash_dir
	invincible = true
	hurtbox.monitorable = false
	move_iframes_left = 8  # shorter i-frames than ground dash
	velocity = Vector2(dash_dir * dash_speed * WAVEDASH_SPEED_MULT, 0.0)
	event.emit("wavedash", global_position)
	# Stay in jump state but with wavedash velocity

func enter_dash() -> void:
	stats.spend(dash_cost)
	dash_dir = (1 if input.move_x > 0.0 else -1) if input.move_x != 0.0 else facing
	facing = dash_dir
	invincible = true
	hurtbox.monitorable = false
	wavedash_buffer = 0  # reset wavedash buffer on ground dash
	air_dashed = not is_on_floor()   # one air dash per airtime

func state_dash(_delta: float) -> void:
	var t := float(sm.frames) / float(maxi(dash_frames, 1))
	var ease_mult := 1.0 if t < DASH_EASE_START else lerpf(1.0, 0.55, (t - DASH_EASE_START) / (1.0 - DASH_EASE_START))
	velocity = Vector2(dash_dir * dash_speed * ease_mult, 0.0)
	if sm.frames > iframe_frames and invincible:
		_restore_hurtbox()
	if sm.frames >= dash_frames:
		velocity.x = dash_dir * dash_speed * DASH_CARRY
		sm.change("idle" if is_on_floor() else "jump")

func exit_dash() -> void:
	_restore_hurtbox()

# Four move states share the runner above.
func enter_attack() -> void: _enter_move("basic")
func state_attack(delta: float) -> void: _run_move(delta)
func exit_attack() -> void: _end_move()

func enter_special1() -> void: _enter_move("special1")
func state_special1(delta: float) -> void: _run_move(delta)
func exit_special1() -> void: _end_move()

func enter_special2() -> void: _enter_move("special2")
func state_special2(delta: float) -> void: _run_move(delta)
func exit_special2() -> void: _end_move()

func enter_ultimate() -> void: _enter_move("ultimate")
func state_ultimate(delta: float) -> void: _run_move(delta)
func exit_ultimate() -> void: _end_move()

func state_hitstun(delta: float) -> void:
	_gravity(delta)

	# DI (Directional Influence): allow player to shift trajectory during hitstun
	if input.enabled:
		di_input = input.move_x
		velocity.x += di_input * DI_INFLUENCE * 600.0 * delta * 60.0  # scale by physics frames

	# Tech: only after being LAUNCHED and landing (no more teching out of grounded hits),
	# with dash pressed shortly before touchdown or within TECH_WINDOW frames after it.
	if not is_on_floor():
		stun_air = true
		tech_since_land = 0
	elif stun_air:
		if input.want("dash") and tech_cd <= 0.0 and tech_since_land <= TECH_WINDOW:
			_tech()
			return
		tech_since_land += 1
		if tech_since_land > TECH_WINDOW:
			stun_air = false

	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if sm.frames >= hitstun_frames and not dead:
		sm.change("idle")

func _tech() -> void:
	# Quick recovery: short invincibility, then a recovery lockout and a cooldown.
	invincible = true
	hurtbox.monitorable = false
	move_iframes_left = TECH_IFRAMES
	rooted_time = TECH_RECOVERY
	tech_cd = TECH_COOLDOWN
	stun_air = false
	velocity = Vector2.ZERO
	sm.change("idle" if is_on_floor() else "jump")
	event.emit("tech", global_position)

# ---------------- sprites & effects ----------------
func _build_frames(tex: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for row in ANIMS.size():
		var a: Array = ANIMS[row]
		sf.add_animation(a[0])
		sf.set_animation_speed(a[0], a[2])
		sf.set_animation_loop(a[0], a[3])
		for i in a[1]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME_PX, row * FRAME_PX, FRAME_PX, FRAME_PX)
			sf.add_frame(a[0], at)
	return sf

func _setup_visuals() -> void:
	sprite.sprite_frames = _build_frames(load(sheet_path))
	sprite.position = Vector2(0, -3)   # feet line up with the capsule bottom
	sprite.play("idle")

	move_fx = Sprite2D.new()
	move_fx.name = "MoveFX"
	move_fx.z_index = 1
	move_fx.visible = false
	move_fx.texture = load(fx_path if fx_path != "" else "res://assets/fire_slash.png")
	move_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	default_fx_tex = move_fx.texture
	add_child(move_fx)

	burn_icon = Sprite2D.new()
	burn_icon.name = "BurnIcon"
	burn_icon.texture = load("res://assets/icon_burn.png")
	burn_icon.position = Vector2(-12, -50)
	burn_icon.visible = false
	add_child(burn_icon)

	slow_icon = Sprite2D.new()
	slow_icon.name = "SlowIcon"
	slow_icon.texture = load("res://assets/icon_slow.png")
	slow_icon.position = Vector2(12, -50)
	slow_icon.visible = false
	add_child(slow_icon)

	poison_icon = Sprite2D.new()
	poison_icon.name = "PoisonIcon"
	poison_icon.texture = load("res://assets/icon_poison.png")
	poison_icon.position = Vector2(0, -58)
	poison_icon.visible = false
	add_child(poison_icon)

func _update_visuals() -> void:
	var a := "idle"
	match sm.current:
		"run": a = "run"
		"jump": a = "jump"
		"dash": a = "dash"
		"attack", "special1", "special2", "ultimate": a = "attack"
		"hitstun": a = "ko" if dead else "hitstun"
	if sprite.animation != a:
		sprite.play(a)
	if a == "jump":
		sprite.speed_scale = 0.0
		sprite.frame = 0 if velocity.y < 0.0 else 1   # rising / falling pose
	elif a == "attack":
		sprite.speed_scale = attack_anim_scale
		var progress := clampf(float(sm.frames) / maxf(1.0, float(cur_move.total)), 0.0, 1.0)
		var accent := sin(progress * PI)
		sprite.scale = move_anim_scale * (1.0 + accent * 0.08)
		sprite.rotation = move_anim_tilt * accent
		if bool(cur_move.get("is_aerial", false)):
			sprite.rotation = facing * AERIAL_ANGLE   # whole body dives along the attack diagonal
	else:
		sprite.speed_scale = 1.0
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
	sprite.flip_h = facing < 0
	var sink := dash_sink and sm.current == "dash" and invincible
	if sink:
		sprite.scale = Vector2(1.15, 0.5)     # squash into the floor
		sprite.position = Vector2(0, 11)      # keep the feet on the ground
	else:
		sprite.position = Vector2(0, -3)
	if freeze_frames > 0 and sm.current == "hitstun":
		sprite.position.x += (freeze_frames % 2 * 2 - 1) * 2.5   # hit-shake while frozen

	var tint := Color.WHITE
	if stats.burning():
		tint = Color(1.25, 0.8, 0.6)
	elif stats.slowed():
		tint = Color(0.7, 0.85, 1.3)
	elif stats.poisoned():
		tint = Color(0.85, 0.65, 1.2)
	if sm.current == "hitstun" and not dead:
		tint = Color(1.4, 0.6, 0.6)
	if sink:
		tint = Color(0.35, 0.2, 0.55, 0.8)
	if hit_flash_timer > 0.0:
		var flash_strength := clampf(hit_flash_timer / 0.12, 0.0, 1.0)
		tint = tint.lerp(Color(1.8, 1.8, 1.8), flash_strength)
	sprite.self_modulate = tint
	modulate.a = 0.45 if invincible else 1.0   # dash i-frames

	burn_icon.visible = stats.burning()
	slow_icon.visible = stats.slowed()
	poison_icon.visible = stats.poisoned()

	var in_move: bool = sm.current in ["attack", "special1", "special2", "ultimate"]
	var strip: String = String(cur_move.get("fx", "")) if in_move else ""
	var cast: String = String(cur_move.get("fx_cast", "")) if in_move else ""
	var show_fx := false
	if strip != "" and hitbox_active:
		# Per-move animated VFX (fist / hammer / bow / claws ...), crisp 2x pixels centred on the hitbox.
		var tex := _fx_tex(strip)
		var nf := maxi(1, int(cur_move.fx_frames))
		move_fx.texture = tex
		move_fx.hframes = nf
		var on_f := int(cur_move.on)
		if bool(cur_move.fx_loop) or int(cur_move.hit_interval) > 0 or String(cur_move.kind) == "dive":
			move_fx.frame = (maxi(0, sm.frames - on_f) / 3) % nf
		else:
			var span := maxf(1.0, float(int(cur_move.off_f) - on_f))
			move_fx.frame = clampi(int(float(sm.frames - on_f) / span * nf), 0, nf - 1)
		move_fx.position = hitbox.position
		move_fx.rotation = hitbox.rotation
		move_fx.scale = Vector2.ONE * FX_PIXEL
		move_fx.modulate = Color.WHITE
		show_fx = true
	elif cast != "" and sm.frames >= int(cur_move.spawn) - 4 and sm.frames <= int(cur_move.spawn) + 6:
		# Cast flourish: the bow being drawn, coins glinting, etc.
		var ctex := _fx_tex(cast)
		var cn := maxi(1, int(cur_move.fx_cast_frames))
		move_fx.texture = ctex
		move_fx.hframes = cn
		move_fx.frame = clampi(int(float(sm.frames - (int(cur_move.spawn) - 4)) / 11.0 * cn), 0, cn - 1)
		var co: Vector2 = cur_move.fx_cast_off
		move_fx.position = Vector2(facing * co.x, co.y)
		move_fx.rotation = 0.0
		move_fx.scale = Vector2.ONE * FX_PIXEL
		move_fx.modulate = Color.WHITE
		show_fx = true
	elif strip == "" and cast == "" and hitbox_active and default_fx_tex != null:
		# Legacy single-texture slash (moves without their own strip).
		move_fx.texture = default_fx_tex
		move_fx.hframes = 1
		move_fx.frame = 0
		var ts := default_fx_tex.get_size()
		var progress := clampf(float(sm.frames) / maxf(1.0, float(cur_move.total)), 0.0, 1.0)
		var pulse := 1.0 + sin(progress * PI) * 0.22
		move_fx.position = hitbox.position
		move_fx.rotation = hitbox.rotation
		move_fx.scale = Vector2(hitbox_size.x / ts.x, hitbox_size.y / ts.y) * pulse
		move_fx.modulate = move_fx_tint
		show_fx = true
	move_fx.visible = show_fx
	if show_fx:
		move_fx.flip_h = facing < 0
	if DEBUG_HITBOXES:
		queue_redraw()

func _fx_tex(path: String) -> Texture2D:
	if not _fx_cache.has(path):
		_fx_cache[path] = load(path)
	return _fx_cache[path]

func _draw() -> void:
	if DEBUG_HITBOXES and hitbox_active:
		draw_set_transform(hitbox.position, hitbox.rotation)
		draw_rect(Rect2(-hitbox_size / 2.0, hitbox_size), Color(1, 1, 0, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0)
