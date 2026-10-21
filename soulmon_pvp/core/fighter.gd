class_name Fighter
extends CharacterBody2D
## Base fighter. Archetypes subclass this and override _apply_archetype()
## and _define_moves(). All frame counts are 60 fps physics ticks.

## Arena walls (arena/arena_manager.gd builds them at x -40..24 and 1256..1320). The body is a capsule of
## radius BODY_RADIUS, so its centre must stay that far from the inner faces. The old teleport and pull clamps
## used 32 and 1248, which left the body 6 px inside a wall: it could not get out and stopped moving.
const PROJECTILE_SCENE := preload("res://core/projectile.tscn")   # loaded once, not on every shot
const TRAP_SCRIPT := preload("res://core/trap.gd")
const WALL_LEFT_X := 24.0
const WALL_RIGHT_X := 1256.0
const BODY_RADIUS := 14.0

## The nearest x the body centre may take without sinking into a wall.
func arena_x(x: float) -> float:
	return clampf(x, WALL_LEFT_X + BODY_RADIUS, WALL_RIGHT_X - BODY_RADIUS)

signal died(fighter)
## Emitted on the defender for every connected hit (melee, projectile or trap).
## info: pos, element, dmg, mult, dir, heavy, ko, hitstop, kb
signal got_hit(info: Dictionary)
## Gameplay events for sound/VFX hooks: "jump", "dash", "attack", "special1",
## "special2", "ultimate", "shot", "trap_set".
signal event(kind: String, pos: Vector2)
## Damage over time (burn, poison) that took HP. The balance tool logs it; the arena does not react to it.
signal status_damaged(info: Dictionary)
## The fighter that last applied a status (burn, poison, slow) to this fighter; credited for its ticks.
var status_source: Fighter = null

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
const AERIAL_ON := 2               # frame the aerial hitbox switches on (the ground basic's own `on` is ignored in the air)
const AERIAL_ACTIVE := 40          # max frames the aerial hitbox stays on while diving
const AERIAL_MIN_ACTIVE := 5       # once on, the hitbox stays on at least this many frames even if you land first
const AERIAL_LAND_LAG := 7         # recovery frames after touching the ground
# Down + attack in the air: a steep spike dive (pops grounded targets up instead)
const AERIAL_DOWN_PUSH := 130.0    # horizontal speed
const AERIAL_DOWN_HOP := 820.0     # minimum downward speed
const AERIAL_DOWN_ANGLE := 1.2     # radians below horizontal (~69 deg)
const AERIAL_DOWN_KB_Y := 480.0    # downward knockback (spike)
const AERIAL_DOWN_POP_Y := -260.0  # knockback.y used instead when the target is on the ground
const AERIAL_DOWN_MIN_ACTIVE := 8
const AERIAL_DOWN_LAND_LAG := 12
const DOWN_CUT_SPEED := -40.0      # holding Down while rising cuts the rise toward this speed (short hop)
const DOWN_CUT_STEP := 180.0       # px/s per frame the rise is slowed while Down is held
const FAST_FALL_CAP := 1.35        # a fast fall may exceed max_fall by this factor

# --- Phase 1: Core Combat Tech ---
const DI_INFLUENCE := 0.15         # max horizontal velocity shift per frame during hitstun
const TECH_PRESS_FRAMES := 3       # a tech needs a FRESH dash press (<= this many frames old)
const MOVE_BUFF_SECONDS := 4.0    # a move's damage/hitstun buff (Swords Dance) lapses after this if no hit uses it
const TECH_COST := 15.0            # stamina
const TECH_WINDOW := 3             # frames after landing in which a tech still works
const TECH_IFRAMES := 4            # was 12: tech invincibility
const TECH_RECOVERY := 0.35        # seconds rooted after a tech (no dash/jump/move)
const TECH_COOLDOWN := 2.0         # seconds before you can tech again
const WAVE_DMG_MULT := 0.6         # a melee move's floor shockwave (move key "wave") hits for this share of the move's damage
const COYOTE_FRAMES := 6           # grace frames to jump after leaving a ledge
const DOWN_VARIANT_KEYS := ["basic", "special1", "special2"]
const BUFFER_TAIL := 8             # combat presses are held until the last N frames of a move
const APEX_BAND := 140.0           # |vy| under this counts as jump apex
const APEX_GRAVITY_MULT := 0.7     # lighter gravity at the apex = smoother arc
const DASH_EASE_START := 0.6       # fraction of the dash after which speed eases out
const DASH_CARRY := 0.4            # momentum kept when the dash ends
const FAST_FALL_MULT := 2.5        # gravity multiplier when holding down
const DASH_CANCEL_FRAMES := 5      # last N frames of a dash can be cancelled into an action
const WAVEDASH_GLIDE := 6          # frames the wavedash keeps its speed (no air steering / gravity)
const JUMP_CUT_STEP := 100.0       # px/s per frame the rise is slowed after releasing jump (was an instant snap)
const WAVEDASH_WINDOW := 4         # frames after jump to input dash for wavedash
const WAVEDASH_SPEED_MULT := 0.8   # wavedash horizontal speed vs normal dash

## If true, burn/slow only apply when the hit is type-super-effective.
## Milestone 2 spec says Fire->Zoner burns and Water->Brawler slows, so: false.
const STATUS_REQUIRES_SUPER := false

## Runtime overlay (toggle with the "debug_hitboxes" key, F1): yellow = attack hitbox, cyan = hurtbox.
static var debug_boxes := false
var _debug_drawn := false
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
	# --- Down-move toolkit (all optional, all default to "off") ---
	"wave": false,              # melee: ALSO sends a floor shockwave projectile left AND right on frame `spawn` (uses the proj_* keys)
	"proj_gravity": 0.0,        # projectile: downward acceleration px/s^2 (lobs / arcs)
	"proj_bounce": 0,           # projectile: how many times it skips off the floor instead of vanishing
	"proj_pierce": false,       # projectile: passes through fighters and keeps hitting (once per proj_hit_gap seconds each)
	"proj_hit_gap": 0.45,
	"trap_delay": 0.0,          # trap: seconds before it arms (it blinks while arming = telegraph)
	"trap_size": Vector2(60, 16),  # trap: hit area (also stretches the sprite when not the default)
	"trap_step": 0.0,
	"trap_frames": 1,           # trap texture is a strip of this many frames (animated by trap.gd)
	"trap_marker": false,       # trap strip: frame 0 is a ground marker shown while the trap arms
	"trap_fps": 8.0,
	"trap_scale": 1.0,          # draw scale for traps with the default hit area           # trap with spawn_count > 1: extra distance of each following trap
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
var wavedash_glide := 0
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
## Set by an AI bot, which faces its opponent itself: movement and dashes then do not turn it round.
var facing_locked := false
var invincible := false
var dead := false
var hitbox_active := false
var hit_targets: Array = []
var hit_counts: Dictionary = {}
var dash_dir := 1
var cooldowns := {"special1": 0.0, "special2": 0.0}
var cur_move: Dictionary = {}
var cur_key := ""
var cur_down := false              # the running move was started as its Down variant (usage counts)
var move_serial := 0               # counts move starts; the AI uses it to notice a new move
var counter_active := false
var projectile_block := false
var rooted_time := 0.0
var next_damage_buff := 1.0
var next_hitstun_mult := 1.0
var move_buff_timer := 0.0         # seconds left on a move-given buff (not the burst buff)
var counter_timer := 0.0           # seconds a timed counter (counter_frames) stays armed; 0 = until the next hit
var counter_mult := 1.5            # damage multiplier of the armed counter (move key counter_mult)
var counter_cap := 9999.0          # most damage the armed counter sends back (move key counter_cap)
var move_iframes_left := 0
var move_spawned := 0
var move_teleported := false
var freeze_frames := 0            # hitstop: fighter is frozen while > 0
var hit_confirmed := false        # current melee move has connected on a fighter (enables cancel chains)
var landed_hit := false           # current move has connected on anything (melee or projectile); used by the AI
var shot_hit_keys: Array = []       # move keys of this fighter's shots that have hit something (balance tool reads and clears it)
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
var no_tech_hit := false              # the hit that put us in hitstun cannot be teched out of (Vine Lash)
var tech_since_land := 0
var tech_cd := 0.0
var down_next := false        # the next _enter_move uses the Down variant (set when the move is chosen)
var pull_dest_x := 0.0              # Vine Lash: the x the pulled fighter is dragged to (in front of the shooter)
var pull_frames := 0
var pull_dest_y := 0.0
var pull_lift_frames := 0            # frames the pull also drives the enemy's height (Vine Lash lifts him, then gravity takes over)
var aerial_land := -1         # move frame an aerial attack touched the ground (-1 = still airborne)

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

## Generic Down variant: a lower, wider, more launching version of the normal move. Per-character
## "<key>_down" entries in _define_moves() override this.
func _derive_down_variant(key: String, base: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate()
	var kb: Vector2 = base.kb
	match String(base.kind):
		"projectile":
			d.dmg = float(base.dmg) * 0.9
			d.proj_off = Vector2(base.proj_off.x, float(base.proj_off.y) + 22.0)   # low shot along the floor
			d.proj_speed = float(base.proj_speed) * 1.15
			d.proj_vys = []
			d.spawn_count = maxi(1, int(base.spawn_count) - 1)
		"trap":
			d.trap_dist = float(base.trap_dist) * 0.5      # drops it right in front of you
			d.trap_lifetime = float(base.trap_lifetime) * 1.2
		"dive":
			d.dive_dx = float(base.dive_dx) * 0.6          # steeper dive
			d.dive_speed = float(base.dive_speed) * 1.1
		_:
			var sz: Vector2 = base.size
			d.size = Vector2(sz.x * 1.15, sz.y * 0.7)
			d.off = Vector2(base.off.x, float(base.off.y) + 20.0)        # low sweep
			d.dmg = float(base.dmg) * 0.9
			d.kb = Vector2(kb.x * 0.55, minf(kb.y * 1.5, -330.0))        # pops the target up
			d.on = int(base.on) + 1
			d.off_f = int(base.off_f) + 1
			d.total = int(base.total) + 4
	if key != "basic":
		d.cd = float(base.cd) * 1.1
	return d

## Hook: a fighter's own ultimate rule. Return true if it took the press (no standard ultimate then).
func _ultimate_press() -> bool:
	return false

## Hook: true while the ultimate key must not start the standard ultimate mid-move (see _ultimate_press).
func _ultimate_locked() -> bool:
	return false

## What the ULT slot of the HUD shows, and whether the ultimate is ready (the AI reads the same).
## Default: the stamina bar, ready when full.
func ult_meter() -> Dictionary:
	var full := stats.stamina >= stats.max_stamina - 0.01
	return {"ratio": stats.stamina / stats.max_stamina, "text": "MAX" if full else "", "ready": full}

## The data a press of `key` runs: its Down variant if Down was held, otherwise the normal move.
func _move_data(key: String, down: bool) -> Dictionary:
	if down and moves.has(key + "_down"):
		return moves[key + "_down"]
	return moves[key]

func mv(d: Dictionary) -> Dictionary:
	var r: Dictionary = MOVE_DEFAULTS.duplicate()
	r.merge(d, true)
	return r

## A copy of `base` with `over` merged on top: used to write a "<key>_down" move as "the normal move, except ...".
func variant(base: Dictionary, over: Dictionary) -> Dictionary:
	var r: Dictionary = base.duplicate()
	r.merge(over, true)
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
	# Down variants (hold Down/S while pressing the move). A fighter can define its own "<key>_down"
	# in _define_moves(); any it does not define is derived from the normal move.
	for key in DOWN_VARIANT_KEYS:
		if not moves.has(key + "_down"):
			moves[key + "_down"] = _derive_down_variant(key, moves[key])

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
	stats.burn_ticked.connect(take_dot.bind("burn"))
	stats.poison_ticked.connect(take_dot.bind("poison"))

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
	input.hold_all = freeze_frames > 0   # must be set BEFORE poll() so hitstop does not eat the buffer
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
	if move_buff_timer > 0.0:
		move_buff_timer -= delta
		if move_buff_timer <= 0.0:
			next_damage_buff = burst_stat_buffs.get("damage", 1.0) if synergy.is_burst_active() else 1.0
			next_hitstun_mult = 1.0
	if counter_active and counter_timer > 0.0:
		counter_timer -= delta
		if counter_timer <= 0.0:
			counter_active = false
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
	input.hold_buffers = ((sm.current in ["attack", "special1", "special2", "ultimate"]
		and sm.frames < int(cur_move.get("total", 0)) - BUFFER_TAIL)
		or (sm.current == "dash" and sm.frames < dash_frames - DASH_CANCEL_FRAMES))
	if wavedash_glide > 0:
		wavedash_glide -= 1
	sm.tick(delta)
	if pull_frames > 0:
		pull_frames -= 1
		velocity.x = (pull_dest_x - global_position.x) * 10.0
		if pull_lift_frames > 0:
			pull_lift_frames -= 1
			velocity.y = (pull_dest_y - global_position.y) * 10.0
	var was_on_floor := is_on_floor()
	move_and_slide()
	# Safety net: nothing (a knockback, a teleport, a pull) may leave the body inside a wall.
	global_position.x = arena_x(global_position.x)
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
func _gravity(delta: float, cap_mult := 1.0) -> void:
	var g := (GRAVITY_FALL * fall_mult if velocity.y > 0.0 else GRAVITY_RISE) * gravity_mult
	if absf(velocity.y) < APEX_BAND and not is_on_floor():
		g *= APEX_GRAVITY_MULT
	velocity.y = min(velocity.y + g * delta, max_fall * cap_mult)

func _steer(delta: float, accel: float) -> void:
	var target := input.move_x * stats.get_speed() if input.enabled and rooted_time <= 0.0 else 0.0
	velocity.x = move_toward(velocity.x, target, accel * delta)
	if not facing_locked and input.enabled and rooted_time <= 0.0 and input.move_x != 0.0:
		facing = 1 if input.move_x > 0.0 else -1

func _try_actions() -> bool:
	# Synergy: Ultimate activation during Burst Mode
	if input.want("ultimate"):
		input.consume("ultimate")
		# A fighter's own ultimate rule (e.g. Mewtwo's transformation) takes the press first.
		var taken := _ultimate_press()
		if not taken and synergy.try_use_ultimate():
			sm.change("ultimate")
			return true
		# Fallback: standard ultimate (full stamina)
		if not taken and stats.stamina >= stats.max_stamina - 0.01:
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
		var m: Dictionary = _move_data(key, input.wants_down(key))
		if input.want(key) and cooldowns[key] <= 0.0 and stats.can_spend(m.cost):
			down_next = input.wants_down(key)
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
		down_next = input.wants_down("attack")
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
		# hitstun_mult is the ATTACKER's buff: it lengthens the stun this hit inflicts
		var md: Dictionary = m
		if next_hitstun_mult != 1.0:
			md = m.duplicate()
			md["stun"] = float(m.get("stun", HITSTUN_FRAMES)) * next_hitstun_mult
		if t.receive_hit(self, dmg_dealt, m.kb, global_position.x, md):
			hit_confirmed = true
			landed_hit = true
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
			move_buff_timer = 0.0

## Returns true if the hit connected.
func receive_hit(attacker: Fighter, damage: float, kb: Vector2, from_x: float, move_data: Dictionary = {}) -> bool:
	if invincible or dead:
		return false
	if counter_active:
		counter_active = false
		counter_timer = 0.0
		attacker.receive_hit(self, minf(damage * counter_mult, counter_cap), Vector2(kb.x, kb.y), global_position.x)
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
		if move_data.get("aerial_down", false) and is_on_floor():
			kb = Vector2(kb.x, AERIAL_DOWN_POP_Y)   # a spike cannot go through the floor: pop the grounded target up
	# A pull arrow drags its target back toward the shooter instead of pushing it away
	if move_data.get("pull", false):
		# toward the shooter, whichever side of the arrow the target stands on
		dir = int(sign(attacker.global_position.x - global_position.x))
		if dir == 0:
			dir = -attacker.facing
		# drag the target to a spot directly in front of the shooter, not toward his body
		pull_dest_x = arena_x(attacker.global_position.x + attacker.facing * float(move_data.get("pull_dist", 70.0)))
		pull_frames = int(move_data.get("pull_hold", 16))
		pull_lift_frames = int(move_data.get("pull_lift_frames", 0))
		pull_dest_y = attacker.global_position.y + float(move_data.get("pull_dy", 0.0))
	velocity = Vector2(dir * kb.x, kb.y)

	# Burst Armor: reduce knockback and hitstun during Burst Mode
	if synergy.is_burst_active() and burst_armor:
		velocity *= 0.3  # 70% knockback reduction
		hitstun_frames = int(hitstun_frames * 0.4)  # 60% hitstun reduction

	# Hitstop logic
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
		# for the balance tool's per-hit log: who hit, with which move, and what HP is left
		"attacker": attacker,
		"by": String(move_data.get("_label", "")),
		"kind": String(move_data.get("kind", "")),
		"hp": stats.hp,
	})
	hitstun_frames = int(move_data.get("stun", HITSTUN_FRAMES))
	stun_air = not is_on_floor()
	no_tech_hit = bool(move_data.get("no_tech", false))
	tech_since_land = 0
	sm.change("hitstun")
	if not STATUS_REQUIRES_SUPER or mult > 1.0:
		status_source = attacker
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

func take_dot(amount: float, kind: String = "status") -> void:
	if dead:
		return
	var before: float = stats.hp
	stats.hp = max(0.0, stats.hp - amount)
	# logged before the death check, so a DOT kill has its event (the balance tool needs it)
	status_damaged.emit({"dmg": before - stats.hp, "hp": stats.hp, "ko": stats.hp <= 0.0,
		"by": kind, "attacker": status_source})
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
	# Ground basic uses its Down variant; an airborne basic is the aerial dive (Down = the steep spike dive).
	var airborne_basic := key == "basic" and not is_on_floor()
	var want_down := down_next
	var use_down := want_down and not airborne_basic
	down_next = false
	cur_down = (use_down and moves.has(key + "_down")) or (airborne_basic and want_down)
	move_serial += 1
	aerial_land = -1
	cur_move = _move_data(key, use_down).duplicate()
	# label used by the balance tool to name the move that dealt a hit (melee, projectile, trap alike)
	cur_move["_label"] = current_label()
	hit_targets.clear()
	hit_counts.clear()
	hit_confirmed = false
	landed_hit = false
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
		counter_timer = float(m.get("counter_frames", 0.0)) / 60.0
		counter_mult = float(m.get("counter_mult", 1.5))
		counter_cap = float(m.get("counter_cap", 9999.0))
	if m.projectile_block:
		projectile_block = true
	if m.damage_buff != 1.0:
		next_damage_buff = m.damage_buff
	if m.damage_buff != 1.0 or m.hitstun_mult != 1.0:
		move_buff_timer = MOVE_BUFF_SECONDS
	if m.hitstun_mult != 1.0:
		next_hitstun_mult = m.hitstun_mult
	if m.teleport_distance > 0.0:
		global_position.x = arena_x(global_position.x + facing * m.teleport_distance)
		move_teleported = true
	if m.self_damage > 0.0:
		stats.hp = maxf(1.0, stats.hp - m.self_damage)
	hitbox_size = m.size
	hitbox_shape.size = m.size
	hitbox.position = Vector2(facing * m.off.x, m.off.y)
	hitbox.rotation = facing * float(m.get("aim", 0.0))   # a whip can be angled down toward the floor
	velocity.x = facing * m.push
	if m.hop != 0.0:
		velocity.y = m.hop
	# Aerial attack: when not grounded, basic attack moves diagonally down. Its timing does NOT come from the
	# ground move (a late `on` frame used to mean the dive landed before the hitbox ever existed).
	var anim_total := float(m.total)
	if airborne_basic:
		var ang := AERIAL_DOWN_ANGLE if want_down else AERIAL_ANGLE
		var push := AERIAL_DOWN_PUSH if want_down else AERIAL_ATTACK_PUSH
		var hop := AERIAL_DOWN_HOP if want_down else AERIAL_HOP
		velocity.x = facing * push
		velocity.y = hop
		cur_move.is_aerial = true
		cur_move.aerial_down = want_down
		cur_move.aerial_ang = ang
		cur_move.aerial_push = push
		cur_move.aerial_hop = hop
		var kbx: float = float(cur_move.kb.x) * (0.5 if want_down else 1.0)
		cur_move.kb = Vector2(kbx, AERIAL_DOWN_KB_Y if want_down else AERIAL_KB_Y)
		if want_down:
			cur_move.dmg = float(cur_move.dmg) * 1.15
		cur_move.on = AERIAL_ON
		cur_move.off_f = AERIAL_ON + AERIAL_ACTIVE
		cur_move.total = int(cur_move.off_f) + 12
		cur_move.lunge = 0.0
		# Aim the hitbox down the diagonal of the dive: longer box, centred along the dive line, rotated to match.
		var aim := Vector2(facing * cos(ang), sin(ang))
		var hs: Vector2 = m.size
		hitbox_size = Vector2(hs.x * 1.15, hs.y)
		hitbox_shape.size = hitbox_size
		hitbox.position = aim * (absf(float(m.off.x)) + hs.x * 0.2) + Vector2(0.0, 6.0)
		hitbox.rotation = facing * ang
	# Stretch the attack frames over this move, then apply its signature tempo.
	attack_anim_scale = (4.0 / (anim_total / 60.0)) / 16.0 * m.anim_rate * profile.rate
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
		# hit_on / hit_off let a move's hit window differ from its lunge window (Vine Lash's whip opens at frame 4, while the hop is still low, so it reaches a close target)
		if f == int(m.get("hit_on", m.on)):
			hitbox_active = true
			hitbox.monitoring = true
		elif f == int(m.get("hit_off", m.off_f)):
			_hitbox_off()
		if bool(m.get("is_aerial", false)):
			if _aerial_motion(m, f, delta):
				return
		elif m.lunge != 0.0 and f >= m.on and f < m.off_f:
			velocity.x = facing * m.lunge
		else:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
		_check_hits()
		# a hit with a hang move (Vine Lash) freezes the fighter in mid-air until hang_until
		if hit_confirmed and f < int(m.get("hang_until", 0)):
			# keep rising, but let the upward speed bleed off so he peaks and then hangs
			velocity.x = 0.0
			velocity.y = move_toward(velocity.y, 0.0, 2600.0 * delta)
		if bool(m.get("wave", false)):
			_spawn_scheduled(m, f)    # melee + floor shockwave (Tinkaton's Quake Smash)
	else:
		# projectile / trap moves: a lunge carries the fighter forward through its active frames (Hook Shot's leap)
		if m.lunge != 0.0 and f >= m.on and f < m.off_f:
			velocity.x = facing * m.lunge
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

## Aerial basic attack: dive diagonally (or steeply, with Down) until the ground. Landing does NOT cancel the
## move: the hitbox is kept on for a minimum number of frames, then there is a short landing lag. Returns true
## when the move has finished.
func _aerial_motion(m: Dictionary, f: int, delta: float) -> bool:
	var spike := bool(m.get("aerial_down", false))
	var min_active := AERIAL_DOWN_MIN_ACTIVE if spike else AERIAL_MIN_ACTIVE
	var lag := AERIAL_DOWN_LAND_LAG if spike else AERIAL_LAND_LAG
	if aerial_land < 0 and f > 0 and is_on_floor():
		aerial_land = f
	if aerial_land < 0:
		velocity.x = facing * float(m.aerial_push)
		velocity.y = maxf(velocity.y, float(m.aerial_hop))
		return false
	velocity.x = move_toward(velocity.x, 0.0, 3200.0 * delta)
	var hold_until := maxi(aerial_land, AERIAL_ON + min_active)
	if hitbox_active and f >= hold_until:
		_hitbox_off()
	if f >= hold_until + lag:
		_finish_move()
		return true
	return false

func _try_special_cancel() -> bool:
	if input.want("ultimate") and not _ultimate_locked() and stats.stamina >= stats.max_stamina - 0.01:
		input.consume("ultimate")
		stats.spend(stats.max_stamina)
		sm.change("ultimate")
		return true
	for key in ["special2", "special1"]:
		var sm_data: Dictionary = _move_data(key, input.wants_down(key))
		if key != cur_key and input.want(key) and cooldowns[key] <= 0.0 and stats.can_spend(sm_data.cost):
			down_next = input.wants_down(key)
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
			_spawn_projectile(m, float(vys[i]) if i < vys.size() else 0.0, facing)
		elif m.kind == "trap":
			_spawn_trap(m, i)
		elif m.kind == "melee" and bool(m.get("wave", false)):
			var wm: Dictionary = m.duplicate()
			wm.dmg = float(m.dmg) * WAVE_DMG_MULT
			_spawn_projectile(wm, 0.0, facing)    # floor shockwave: one each way
			_spawn_projectile(wm, 0.0, -facing)

## The name a hit is logged under: the move key, with the Down and awakened prefixes.
func current_label() -> String:
	return ("awaken_" if bool(cur_move.get("awakened", false)) else "") + cur_key + ("_down" if cur_down else "")

## A move dictionary that carries its label. Projectiles and traps keep the label of the move that fired them,
## so their hits are never logged as "other".
func _labelled(m: Dictionary) -> Dictionary:
	if m.has("_label"):
		return m
	var d: Dictionary = m.duplicate()
	d["_label"] = current_label()
	return d

func _spawn_projectile(m: Dictionary, vy: float, dir: int) -> void:
	var p = PROJECTILE_SCENE.instantiate()
	p.move_key = cur_key + ("_down" if cur_down else "")
	p.setup(self, dir, _labelled(m), vy)
	var off: Vector2 = m.proj_off
	p.position = global_position + Vector2(dir * off.x, off.y)
	get_parent().add_child(p)
	event.emit("shot", p.position)

func _spawn_trap(m: Dictionary, index: int = 0) -> void:
	var tx: float = clamp(global_position.x + facing * (float(m.trap_dist) + float(m.trap_step) * index), 40.0, 1240.0)
	var q := PhysicsRayQueryParameters2D.create(
		Vector2(tx, global_position.y), Vector2(tx, global_position.y + 900.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var pos := Vector2(tx, global_position.y + 26.0)
	if hit:
		pos = hit.position
	var t = TRAP_SCRIPT.new()
	t.setup(self, _labelled(m))
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
	# Down in the air: while FALLING it is a fast fall (works while steering left/right too); while RISING it
	# cuts the jump short (short hop) by braking the rise toward DOWN_CUT_SPEED.
	var down := input.enabled and input.down_held and rooted_time <= 0.0
	var fast_falling := down and velocity.y >= 0.0
	var grav_mult := FAST_FALL_MULT if fast_falling else 1.0
	if wavedash_glide > 0:
		velocity = Vector2(dash_dir * dash_speed * WAVEDASH_SPEED_MULT, 0.0)   # hold the burst
	else:
		_gravity(delta * grav_mult, FAST_FALL_CAP if fast_falling else 1.0)
		_steer(delta, AIR_ACCEL)
		if down and velocity.y < DOWN_CUT_SPEED:
			velocity.y = minf(velocity.y + DOWN_CUT_STEP, DOWN_CUT_SPEED)
		elif not input.jump_held and velocity.y < JUMP_CUT:
			velocity.y = minf(velocity.y + JUMP_CUT_STEP, JUMP_CUT)

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
	if not facing_locked:
		facing = dash_dir
	invincible = true
	hurtbox.monitorable = false
	move_iframes_left = 8  # shorter i-frames than ground dash
	velocity = Vector2(dash_dir * dash_speed * WAVEDASH_SPEED_MULT, 0.0)
	wavedash_glide = WAVEDASH_GLIDE
	event.emit("wavedash", global_position)
	# Stay in jump state but with wavedash velocity

func enter_dash() -> void:
	stats.spend(dash_cost)
	dash_dir = (1 if input.move_x > 0.0 else -1) if input.move_x != 0.0 else facing
	if not facing_locked:
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
	if sm.frames >= dash_frames - DASH_CANCEL_FRAMES and _try_actions():
		return   # dash cancel: attack / special / jump out of the dash's tail
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
	if no_tech_hit:
		stun_air = false
	elif not is_on_floor():
		stun_air = true
		tech_since_land = 0
	elif stun_air:
		if input.fresh("dash", TECH_PRESS_FRAMES) and tech_cd <= 0.0 and tech_since_land <= TECH_WINDOW and stats.can_spend(TECH_COST):
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
	input.consume("dash")
	stats.spend(TECH_COST)
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
		if bool(cur_move.get("is_aerial", false)) and aerial_land < 0:
			sprite.rotation = facing * float(cur_move.get("aerial_ang", AERIAL_ANGLE))   # whole body dives along the attack diagonal
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
		if a == "attack":
			# A squashed / stretched pose (crouching Down moves, rising uppercuts) pivots about the sprite centre:
			# shift it so the feet stay on the floor (a frame's feet sit ~29 px below its centre).
			sprite.position.y = -3.0 + 29.0 * (1.0 - sprite.scale.y)
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
		move_fx.rotation = hitbox.rotation + facing * float(cur_move.get("fx_tilt", 0.0))   # the sprite can tilt more than the hit box
		if bool(cur_move.get("fx_fit", false)):
			# fit the strip exactly to the hit box, so the vine starts and ends where the hit box does
			move_fx.scale = Vector2(hitbox_size.x / (float(tex.get_width()) / float(nf)), hitbox_size.y / float(tex.get_height()))
		else:
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
	if debug_boxes or _debug_drawn:
		_debug_drawn = debug_boxes
		queue_redraw()

func _fx_tex(path: String) -> Texture2D:
	if not _fx_cache.has(path):
		_fx_cache[path] = load(path)
	return _fx_cache[path]

func _draw() -> void:
	if not debug_boxes:
		return
	if hitbox_active:
		draw_set_transform(hitbox.position, hitbox.rotation)
		draw_rect(Rect2(-hitbox_size / 2.0, hitbox_size), Color(1, 1, 0, 0.4))
		draw_rect(Rect2(-hitbox_size / 2.0, hitbox_size), Color(1, 1, 0, 0.9), false, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0)
	# Hurtbox capsule (r 14, h 52); dimmed while the fighter is invulnerable.
	var col := Color(0.2, 0.9, 1.0, 0.9) if hurtbox.monitorable else Color(0.6, 0.6, 0.6, 0.6)
	var r := 14.0
	var half := 26.0 - r
	draw_arc(Vector2(0, -half), r, PI, TAU, 16, col, 1.5)
	draw_arc(Vector2(0, half), r, 0.0, PI, 16, col, 1.5)
	draw_line(Vector2(-r, -half), Vector2(-r, half), col, 1.5)
	draw_line(Vector2(r, -half), Vector2(r, half), col, 1.5)
