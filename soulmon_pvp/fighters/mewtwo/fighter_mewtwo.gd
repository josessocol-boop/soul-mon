extends Fighter
## Mewtwo (Psychic): balanced boss. Ultimate = Mega Mewtwo Y Awakening, and only that: the ULT key starts Burst
## Mode when the Burst gauge is full (the HUD ULT slot shows the gauge). For the Burst's 12 seconds the awakened
## move set and the Mega sprite replace the normal ones. The normal ultimate move is not used any more.

const AWAKEN_COST := 25.0      # extra stamina cost on every awakened special (the text's "cost penalty")
const AWAKEN_FRAMES := 104     # the whole transformation: ball, flash, burst, descent (about 1.7 s at 60 fps)
const BALL_TEX := "res://assets/fx/mega_ball.png"   # the sealing ball (tools/generate_mega_ball.py)
const BALL_BODY := Vector2(0, -18)    # where the ball forms, over Mewtwo's body
const BALL_FLOAT := Vector2(0, -50)   # where the ball hovers before it bursts
const MEGA_SHEET := "res://assets/mega_mewtwo_y_sheet.png"   # Mega Mewtwo Y art, same frame layout as the normal sheet

var normal_moves: Dictionary = {}
var awakened := false
var awaken_t := -1            # frame inside the transformation (-1 = not running)
var awaken_ball: Sprite2D

func _apply_archetype() -> void:
	hp_max = 190.0
	move_speed = 285.0
	jump_velocity = -740.0
	max_fall = 900.0
	types = [StatsComponent.Element.PSYCHIC]
	sheet_path = "res://assets/mewtwo_sheet.png"
	fx_path = "res://assets/pink_slash.png"
	base_color = Color(0.7, 0.55, 0.9)
	# Mewtwo builds its Burst gauge faster from hits and damage taken, so the transformation is reachable in a normal fight.
	burst_fill_hit = 2.0
	burst_fill_taken = 1.5
	# Burst stat buffs: the engine applies them when the burst starts and reverts them when it ends.
	burst_stat_buffs = {"speed": 1.15, "damage": 1.1}

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Psycho Cut: a heavy melee swipe.
		"basic": mv({"fx": "res://assets/fx/mewtwo_basic.png", "fx_frames": 4, "dmg": 10.0, "size": Vector2(78, 58), "off": Vector2(42, -10), "on": 6, "off_f": 14,
			"total": 20, "kb": Vector2(320, -200), "stun": 20}),
		# Shadow Ball: pierces through fighters, hitting each one again after a gap.
		"special1": mv({"kind": "projectile", "dmg": 11.5, "spawn": 8, "proj_speed": 520.0, "proj_pierce": true,
			"proj_hit_gap": 0.35, "proj_life": 2.2, "proj_tex": "res://assets/fx/proj_mewtwo_ball.png", "proj_frames": 4, "proj_scale": 3.0,
			"proj_r": 14.0, "total": 20, "kb": Vector2(160, -160), "cd": 2.5, "cost": 10.0}),
		# Disable: a short burst that roots the target briefly and stops them teching out of the hit (no_tech).
		# The dash lock is a stand-in (root) until engine support exists.
		"special2": mv({"fx": "res://assets/fx/mewtwo_special2.png", "fx_frames": 4, "dmg": 8.0, "root": 0.5, "stamina_steal": 10.0, "size": Vector2(70, 50),
			"off": Vector2(34, -6), "on": 4, "off_f": 10, "total": 22, "no_tech": true, "kb": Vector2(120, -140), "cd": 5.0, "cost": 14.0}),
		# Normal ultimate (no full Burst gauge): a large slow Shadow Ball.
		"ultimate": mv({"kind": "projectile", "dmg": 26.0, "spawn": 12, "proj_speed": 420.0, "proj_life": 3.0,
			"proj_tex": "res://assets/fx/proj_psystrike.png", "proj_frames": 4, "proj_scale": 4.0, "proj_r": 30.0, "total": 36,
			"kb": Vector2(700, -300), "cd": 8.0, "cost": 30.0}),
	}
	# Ground Wave: the swipe also sends shockwaves along the floor.
	m["basic_down"] = mv({"fx": "res://assets/fx/down_mewtwo_basic.png", "fx_frames": 4, "dmg": 6.0, "size": Vector2(40, 24), "off": Vector2(36, 22), "on": 6, "off_f": 12,
		"total": 22, "wave": true, "spawn": 6, "proj_speed": 520.0, "proj_life": 1.6, "proj_tex": "res://assets/fx/proj_mewtwo_ball.png", "proj_frames": 4,
		"proj_scale": 2.4, "proj_r": 10.0, "kb": Vector2(260, -160)})
	# Gravity Pull: drags the target into melee range.
	m["special1_down"] = mv({"fx": "res://assets/fx/down_mewtwo_special1.png", "fx_frames": 4, "dmg": 5.0, "pull": true, "pull_dist": 60.0, "pull_hold": 14, "size": Vector2(90, 60),
		"off": Vector2(60, -6), "on": 8, "off_f": 18, "total": 26, "kb": Vector2(60, -120), "stun": 16, "cd": 5.0, "cost": 16.0})
	# Psystrike: a fast dive from the air.
	m["special2_down"] = mv({"fx": "res://assets/fx/down_mewtwo_special2.png", "fx_frames": 4, "kind": "dive", "dmg": 14.0, "hop": -520.0, "dive_start": 10, "dive_dx": 260.0,
		"dive_speed": 1000.0, "size": Vector2(56, 64), "off": Vector2(20, 20), "total": 56, "kb": Vector2(300, -260),
		"cd": 5.0, "cost": 18.0})
	return m

## The awakened move set (Mega Mewtwo Y). Built from the normal moves' costs, plus the awakening penalty.
func _awakened_moves() -> Dictionary:
	var m: Dictionary = {
		# Psystrike Flurry: four quick hits inside the first 17 frames.
		"basic": mv({"fx": "res://assets/fx/mewtwo_basic.png", "fx_frames": 4, "dmg": 3.0, "size": Vector2(64, 48), "off": Vector2(36, -6), "on": 3, "off_f": 17,
			"total": 28, "hit_interval": 6, "kb": Vector2(120, -140), "stun": 10}),
		# Supernova Shadow Ball: three piercing shots in a spread.
		"special1": mv({"kind": "projectile", "dmg": 5.0, "spawn": 8, "spawn_count": 3, "spawn_interval": 5,
			"proj_vys": [-90.0, 0.0, 90.0], "proj_speed": 560.0,
			"proj_life": 2.0, "proj_tex": "res://assets/fx/proj_mega_psystorm.png", "proj_frames": 4, "proj_scale": 1.5,
			"proj_r": 13.0, "total": 30, "kb": Vector2(170, -160), "cd": 3.0, "cost": _awakened_cost("special1")}),
		# Amnesia Blink: a teleport forward, then the next attack hits harder.
		"special2": mv({"fx": "res://assets/fx/mewtwo_awakened_special2.png", "fx_frames": 4, "dmg": 0.0, "teleport_distance": 180.0, "damage_buff": 1.5, "total": 22, "cd": 5.0,
			"cost": _awakened_cost("special2", 10.0)}),
		"ultimate": normal_moves["ultimate"],
	}
	# Psychic Wave: a big shockwave both ways along the floor.
	m["basic_down"] = mv({"fx": "res://assets/fx/down_mewtwo_awakened_basic.png", "fx_frames": 4, "dmg": 9.0, "wave": true, "spawn": 6, "size": Vector2(70, 40), "off": Vector2(40, 18),
		"on": 6, "off_f": 14, "total": 26, "kb": Vector2(300, -220), "stun": 18, "proj_speed": 600.0, "proj_life": 1.6,
		"proj_tex": "res://assets/fx/proj_psywave.png", "proj_frames": 4, "proj_scale": 2.2, "proj_r": 14.0})
	# Singularity: a delayed trap that pulls the target in.
	m["special1_down"] = mv({"kind": "trap", "dmg": 10.0, "spawn": 8, "total": 24, "trap_dist": 140.0,
		"trap_delay": 1.0, "trap_lifetime": 4.0, "trap_tex": "res://assets/fx/trap_psychic_field.png", "trap_frames": 4, "trap_fps": 8.0, "trap_size": Vector2(120, 22),
		"pull": true, "pull_dist": 60.0, "pull_hold": 18, "kb": Vector2(60, -160), "cd": 5.0,
		"cost": _awakened_cost("special1_down")})
	# Meteor Dive: a steep spike; grounded targets are popped up.
	m["special2_down"] = mv({"fx": "res://assets/fx/down_mewtwo_awakened_special2.png", "fx_frames": 4, "kind": "dive", "dmg": 16.0, "hop": -520.0, "dive_start": 10, "dive_dx": 200.0,
		"dive_speed": 1100.0, "is_aerial": true, "aerial_down": true, "size": Vector2(64, 70), "off": Vector2(20, 20),
		"total": 56, "kb": Vector2(300, -260), "cd": 5.0, "cost": _awakened_cost("special2_down", 12.0)})
	# the balance tool and the hit log name these moves "awaken_<key>". The ultimate is the normal one.
	for k in m.keys():
		if k != "ultimate":
			m[k] = m[k].duplicate()
			m[k]["awakened"] = true
	return m

func _awakened_cost(key: String, extra: float = AWAKEN_COST) -> float:
	return float(normal_moves[key].cost) + extra

## The ULT key is the transformation only. With a full Burst gauge it starts Burst Mode; otherwise, or while
## already transformed, it does nothing. It never starts the standard ultimate (that needs full stamina).
func _ultimate_press() -> bool:
	if not synergy.is_burst_active():
		synergy.try_activate_burst()
	return true

func _ultimate_locked() -> bool:
	return true

## The HUD ULT slot shows the Burst gauge, or the remaining Burst time while transformed.
func ult_meter() -> Dictionary:
	if synergy.is_burst_active():
		return {"ratio": synergy.get_burst_time_remaining() / SynergySystem.BURST_DURATION, "text": "AWAKE", "ready": false}
	var full: bool = synergy.gauge >= SynergySystem.GAUGE_MAX
	return {"ratio": synergy.gauge / SynergySystem.GAUGE_MAX, "text": "BURST" if full else "", "ready": full}

func _on_burst_activated(pid: int) -> void:
	super._on_burst_activated(pid)
	if awakened:
		return
	# The transformation spends the Burst gauge, so it cannot be repeated straight away.
	normal_moves = moves.duplicate()
	awakened = true
	moves = _awakened_moves()
	synergy.gauge = 0.0
	synergy.gauge_changed.emit(synergy.player_id, 0.0, SynergySystem.GAUGE_MAX)
	sprite.modulate = Color.WHITE
	_start_awaken()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # the fighter's own update (returns early while frozen, as intended)
	if awaken_t >= 0:
		_tick_awaken()

## The transformation: Mewtwo fades into a ball, the ball rises and hovers, flashes for about a second, bursts,
## and Mega Mewtwo Y comes down from the same height to the ground. He is frozen and cannot be hit throughout.
func _start_awaken() -> void:
	awaken_t = 0
	freeze_frames = maxi(freeze_frames, AWAKEN_FRAMES)
	if awaken_ball == null:
		awaken_ball = Sprite2D.new()
		awaken_ball.texture = load(BALL_TEX)
		awaken_ball.hframes = 4
		awaken_ball.z_index = 2
		add_child(awaken_ball)
	awaken_ball.visible = false
	awaken_ball.scale = Vector2(3, 3)
	awaken_ball.modulate = Color.WHITE

func _tick_awaken() -> void:
	modulate.a = 1.0           # the dash i-frame dimming must not dim the ball
	invincible = true
	var t := awaken_t
	awaken_t += 1
	if t < 12:                  # Mewtwo fades and is pulled into the ball
		var u := float(t) / 12.0
		sprite.visible = true
		sprite.modulate.a = 1.0 - u
		sprite.offset = BALL_BODY * u
		awaken_ball.visible = true
		awaken_ball.position = BALL_BODY
		awaken_ball.scale = Vector2(3, 3) * u
		awaken_ball.frame = 0
	elif t < 24:                # the ball rises to float height
		sprite.visible = false
		awaken_ball.visible = true
		awaken_ball.position = BALL_BODY.lerp(BALL_FLOAT, _smooth(float(t - 12) / 12.0))
		awaken_ball.scale = Vector2(3, 3)
		awaken_ball.frame = 0
	elif t < 60:                # about a second: it hovers, bobs and flashes
		sprite.visible = false
		awaken_ball.visible = true
		awaken_ball.position = BALL_FLOAT + Vector2(0, sin(float(t) * 0.3) * 2.0)
		awaken_ball.frame = [0, 1, 2, 3][(t / 4) % 4]
	elif t < 72:                # the flashing speeds up
		sprite.visible = false
		awaken_ball.visible = true
		awaken_ball.position = BALL_FLOAT
		awaken_ball.frame = [1, 3][(t / 2) % 2]
	elif t < 80:                # the ball bursts; Mega Mewtwo Y is revealed at the same height
		if t == 72:
			_awaken_reveal()
		var u3 := float(t - 72) / 8.0
		awaken_ball.visible = true
		awaken_ball.scale = Vector2(3, 3) * (1.0 + 1.5 * u3)
		awaken_ball.modulate.a = 1.0 - u3
		awaken_ball.position = BALL_FLOAT
		sprite.visible = true
		sprite.modulate.a = u3
		sprite.offset = BALL_FLOAT
	elif t < AWAKEN_FRAMES:     # Mega Mewtwo Y comes down to the ground
		var u4 := _smooth(float(t - 80) / float(AWAKEN_FRAMES - 80))
		awaken_ball.visible = false
		sprite.visible = true
		sprite.modulate.a = 1.0
		sprite.offset = BALL_FLOAT * (1.0 - u4)
	else:
		_end_awaken()

func _awaken_reveal() -> void:
	_use_sheet(MEGA_SHEET)
	event.emit("awaken", global_position)   # the arena: flash, shake, banner

func _end_awaken() -> void:
	awaken_t = -1
	sprite.offset = Vector2.ZERO
	sprite.modulate = Color.WHITE
	awaken_ball.visible = false
	awaken_ball.modulate = Color.WHITE
	invincible = move_iframes_left > 0

func _smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

func _on_burst_ended(pid: int) -> void:
	super._on_burst_ended(pid)
	if awakened:
		awakened = false
		moves = normal_moves.duplicate()
		_use_sheet(sheet_path)

## Swap the sprite sheet but keep the current animation and frame, so a transformation mid-move does not jump.
func _use_sheet(path: String) -> void:
	var anim := sprite.animation
	var frame := sprite.frame
	sprite.sprite_frames = _build_frames(load(path))
	sprite.play(anim)
	sprite.frame = frame
