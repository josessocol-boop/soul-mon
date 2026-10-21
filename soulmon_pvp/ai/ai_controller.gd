class_name AIController
extends Node
## AI controller: a behaviour tree (fighters/<id>/profile.tres plus the personality trees below) that drives a fighter
## through InputHandler in remote mode, the same way the keyboard does.
## Fair information only: its own state, the opponent's position, velocity, state and current move, whether that
## move has connected, and the projectiles on screen. It never reads the opponent's input buffer.

# Difficulty scaling multipliers (applied on top of profile base values)
const DIFFICULTY_MULTIPLIERS := {
	"easy": {"accuracy": 0.5, "aggressiveness": 0.7},
	"medium": {"accuracy": 0.7, "aggressiveness": 1.0},
	"hard": {"accuracy": 0.85, "aggressiveness": 1.2}
}

# Base reaction times per difficulty (seconds): how often the tree makes a decision
const BASE_REACTION_TIME := {
	"easy": 0.4,
	"medium": 0.25,
	"hard": 0.15
}

const BODY_RADIUS := 14.0          # fighter body capsule radius (fighter.gd)
const FAR_RANGE := 300.0           # at or beyond this distance the bot counts as "far"
const WHIFF_WINDOW := 36           # physics frames after an opponent's melee move ends without connecting
const HOP_COOLDOWN := 1.5          # seconds between hops at an opponent who is above the bot
const ZONING_JUMP_COOLDOWN := 1.2   # one dodge hop per window; without it both bots hop on almost every decision
const ZONING_SIGHT := 360.0        # a projectile closer than this and coming our way triggers the zoning response
const PROJECTILE_MIN := 90.0       # projectile moves are not used point-blank ...
const PROJECTILE_MAX := 600.0      # ... or beyond this distance
const TRAP_MAX := 420.0            # a trap is cast only at an opponent this close or nearer
const LOB_WINDOW := 60.0            # a lob (proj_gravity, thrown up) hits when its landing spot is this close to the bot
const TRAP_LEAD := 40.0            # a trap springs on an opponent who walks into it, so its window starts this far before the trap
const WALL_EDGE := 150.0           # within this distance of an arena wall, a keep-away bot steps in instead of backing into the corner
const DODGE_CHANCE := 0.7          # chance per decision to dash out of an opponent's melee move that is about to reach us
const DODGE_MARGIN := 10.0         # extra distance the dodge check allows beyond the opponent's hitbox reach
var _dodge_serial: int = -1        # opponent move_serial the dodge check last saw
var _dodge_seen: int = 0           # _frame when that move started
var _dodge_rolled: bool = false    # the dodge roll for that move has been made
const PROJ_LOOK := 360.0           # an opponent's shot this close, flying at us in our lane, is answered (same as ZONING_SIGHT)
const PROJ_LANE_HIGH := 64.0       # a shot is in the lane from this far above the feet ...
const PROJ_LANE_LOW := 12.0        # ... down to this far below them
const PROJ_DODGE_CHANCE := 0.85    # chance per shot that the bot dashes through it once its reaction time has passed
const TRAP_AVOID_CHANCE := 0.85    # chance per opponent trap that the bot sees it and does not walk onto it
const TRAP_HOP_DIST := 110.0       # an opponent trap this close ahead of a bot walking toward it is hopped
var _proj_seen: Dictionary = {}    # Projectile -> _frame when this bot first saw it (reaction delay)
var _proj_dodge: Dictionary = {}   # Projectile -> whether this shot gets a dodge (rolled once per shot)
var _trap_avoid: Dictionary = {}   # Trap -> whether this bot sees and avoids it (rolled once per trap)
var _hazard_move := 0.0            # movement override from the hazard check, used while _hazard_frames > 0
var _hazard_frames := 0
const ATTACK_KEYS := ["attack", "basic", "special1", "special2", "ultimate"]
const MELEE_KINDS := ["melee", "dive"]
const LOG_MOVE_USAGE := true       # print how often each move was started by this bot when it is freed (tuning aid)

@export var difficulty: String = "medium"

# Internal state
var target_fighter: Fighter
var opponent_fighter: Fighter
var input_handler: InputHandler
var profile: AIProfile
var behavior_tree: AIBehavior
var decision_timer: float = 0.0
var decision_dt: float = 0.25      # real seconds since the last decision (see AIBehavior._get_delta)
var reaction_time: float = 0.25
var accuracy: float = 0.7
var aggressiveness: float = 0.6

# Movement: decided at each decision, applied every physics frame
var move_dir: float = 0.0
var _jump_hold_frames: int = 0
var _hop_cooldown := 0.0

# Opponent tracking (for whiff punish) and our own hits (for combo follow-ups)
var _opp_attacking: bool = false   # opponent is in a melee move right now
var _opp_landed: bool = false      # ...and that move has connected
var _whiff_frames: int = 0         # > 0 while a just-whiffed opponent is open to punishment
var _last_serial: int = -1         # fighter.move_serial when the last move was counted
var usage: Dictionary = {}         # move key ("basic_down", "special1", ...) -> times started
var _own_hit_seen: bool = false    # our current move's hit has already queued its follow-up

# Whiff memory: a move that connects none of its last RECENT_USES uses is taken out of the bot's options
# for a while (the balance data showed Greninja's special2_down connecting 2% of the time, used 1.25 a match).
# Persistent traps are included: a trap that catches someone later is recorded as a hit through got_hit, so a
# trap that never catches anyone (Greninja's special2_down, Toxicroak's special1_down) is banned like any other move.
const RECENT_USES := 8
## Off: a bot uses a special only 1-2 times in a ~15 s match, so the window never fills and nothing is banned.
## Down-variant preferences (down_pref) in the move data do that job instead.
const WHIFF_MEMORY := false
const WHIFF_BAN_FRAMES := 90          # 1.5 s at 60 fps, times the number of bans in a row (capped at 4)
var _frame: int = 0                   # physics frames this controller has run
var _outcomes: Dictionary = {}        # move label -> recent uses (true = connected)
var _ban_until: Dictionary = {}       # move label -> frame the ban ends
var _ban_count: Dictionary = {}       # move label -> bans in a row
var _use_serial: int = -1             # fighter.move_serial of the use being tracked
var _use_key: String = ""            # label of that use
var _use_hit: bool = false            # that use has connected

func setup(fighter: Fighter) -> void:
	target_fighter = fighter
	input_handler = fighter.get_node("InputHandler")

	# Set input handler to remote mode so we can control it programmatically
	if input_handler:
		input_handler.remote = true
	# The bot steers its own facing (_drive_movement), so walking back never turns it round
	target_fighter.facing_locked = true

	_load_profile(fighter)
	_apply_difficulty()
	_build_behavior_tree()

func _load_profile(fighter: Fighter) -> void:
	var fighter_id: String = ""
	if fighter.scene_file_path != "":
		fighter_id = fighter.scene_file_path.get_file().replace("fighter_", "").replace(".tscn", "")

	if fighter_id == "":
		# Try to match by script class
		var script = fighter.get_script()
		if script:
			var script_class_name: String = script.get_global_name()
			match script_class_name:
				"FighterBlaziken": fighter_id = "blaziken"
				"FighterBrawler": fighter_id = "scizor"
				"FighterDecidueye": fighter_id = "decidueye"
				"FighterGengar": fighter_id = "gengar"
				"FighterGholdengo": fighter_id = "gholdengo"
				"FighterGreninja": fighter_id = "greninja"
				"FighterMarshadow": fighter_id = "marshadow"
				"FighterScizor": fighter_id = "scizor"
				"FighterTinkaton": fighter_id = "tinkaton"
				"FighterZoner": fighter_id = "gholdengo"

	if fighter_id != "" and ResourceLoader.exists(Roster.profile_path(fighter_id)):
		profile = load(Roster.profile_path(fighter_id))
	else:
		profile = AIProfile.new()
		profile.personality = "balanced"
		profile.preferred_range = "mid"
		profile.aggressiveness = 0.6
		print("AIController: No profile found for ", fighter_id, ", using default")

func _apply_difficulty() -> void:
	var mult: Dictionary = DIFFICULTY_MULTIPLIERS.get(difficulty, DIFFICULTY_MULTIPLIERS["medium"])
	var base_rt: float = BASE_REACTION_TIME.get(difficulty, 0.25)
	reaction_time = base_rt * (1.0 + profile.reaction_bonus)
	accuracy = mult["accuracy"]
	aggressiveness = profile.aggressiveness * float(mult["aggressiveness"])

# ---------------------------------------------------------------- tree

func _build_behavior_tree() -> void:
	# Root is a Selector: the first higher-priority branch that succeeds wins this decision
	var children: Array[AIBehavior] = []

	# Priority 1: anti-air (ungated: the condition already checks the jump is close and rising)
	if profile.anti_air_move != "":
		children.append(_seq([_cond(Callable(self, "_check_anti_air")), _act(profile.anti_air_move, 0.0, false)]))

	# Priority 2: punish a melee move that just whiffed
	if profile.punish_move != "":
		children.append(_seq([_cond(Callable(self, "_check_whiff_punish")), _act(profile.punish_move, 0.0, true, true)]))

	# Vine follow-up: right after Decidueye's Vine Lash has pulled the enemy in, he dives onto him from the air
	children.append(_seq([_cond(Callable(self, "_check_vine_followup")), _act("attack", 0.0, false)]))
	# Vine Lash window: the enemy stands where the whip lands and the move is ready, so throw it (it is rarely picked otherwise)
	children.append(_seq([_cond(Callable(self, "_check_vine_window")), _act("special2")]))

	# Priority 3: answer projectiles on screen. A jump dodge has a cooldown; while it is cooling down the bot goes on
	# with its own attacks instead of hopping in place.
	var zoning_act: AIBehavior = _act(_get_zoning_action())
	if _get_zoning_action() == "jump":
		zoning_act = _cd(zoning_act, ZONING_JUMP_COOLDOWN)
	children.append(_seq([_cond(Callable(self, "_check_zoning_response")), zoning_act]))

	# Priority 3b: ultimate when it is ready and can connect (no tree requested it before)
	children.append(_seq([_cond(Callable(self, "_roll_ultimate")), _act("ultimate")]))

	# Priority 4: main engagement (approach / attack / defend based on personality)
	children.append(_build_engagement_tree())

	# Fallback: when the engagement tree has nothing usable (cooldowns running, dash held back), keep closing in
	children.append(_cond(Callable(self, "_walk_in")))

	var root := Selector.new()
	root.children.assign(children)
	behavior_tree = root

func _build_engagement_tree() -> AIBehavior:
	match profile.personality:
		"aggressive":
			return _build_aggressive_tree()
		"defensive":
			return _build_defensive_tree()
		"zoning":
			return _build_zoning_tree()
		"hit_and_run":
			return _build_hit_and_run_tree()
		"tricky":
			return _build_tricky_tree()
		_:
			return _build_balanced_tree()

func _build_aggressive_tree() -> AIBehavior:
	var selector := Selector.new()
	var children: Array[AIBehavior] = []

	var close_attack := _seq([_cond(Callable(self, "_in_range").bind("close")), _act("attack")])
	children.append(close_attack)

	var mid_action := Selector.new()
	mid_action.children.assign([_cd(_act("special1"), 2.0), _cd(_act("special2"), 3.0), _act("dash")])
	var mid_seq := _seq([_cond(Callable(self, "_in_range").bind("mid")), mid_action])
	children.append(mid_seq)

	var far_sel := Selector.new()
	far_sel.children.assign([_cd(_act("special1"), 2.0), _act("dash")])
	var far_seq := _seq([_cond(Callable(self, "_in_range").bind("far")), far_sel])
	children.append(far_seq)

	selector.children.assign(children)
	return selector

func _build_defensive_tree() -> AIBehavior:
	var selector := Selector.new()
	var children: Array[AIBehavior] = []

	var retreat := _seq([_cond(Callable(self, "_in_range").bind("close")), _act("dash", 0.3)])
	children.append(retreat)

	var poke_sel := Selector.new()
	poke_sel.children.assign([_cd(_act("special1"), 3.0), _act("attack")])
	var mid_poke := _seq([_cond(Callable(self, "_in_range").bind("mid")), poke_sel])
	children.append(mid_poke)

	var far_wait := _seq([_cond(Callable(self, "_in_range").bind("far")), _act("")])
	children.append(far_wait)

	selector.children.assign(children)
	return selector

func _build_zoning_tree() -> AIBehavior:
	var selector := Selector.new()
	var children: Array[AIBehavior] = []

	# Point-blank: still swing when an attack reaches (its Down sweep and basic cover this range)
	var close_hit := _seq([_cond(Callable(self, "_in_range").bind("close")), _act("attack")])
	children.append(close_hit)
	var close_escape := _seq([_cond(Callable(self, "_in_range").bind("close")), _act("dash", 0.3)])
	children.append(close_escape)

	var zone_sel := Selector.new()
	zone_sel.children.assign([_cd(_act("special1"), 2.5), _cd(_act("special2"), 3.0), _act("attack")])
	var mid_zone := _seq([_cond(Callable(self, "_in_range").bind("mid")), zone_sel])
	children.append(mid_zone)

	var far_sel := Selector.new()
	# The attack fallback is gated by reach, so it only fires when the Down projectile can hit from this range
	far_sel.children.assign([_cd(_act("special1"), 2.0), _cd(_act("special2"), 2.5), _act("attack")])
	var far_zone := _seq([_cond(Callable(self, "_in_range").bind("far")), far_sel])
	children.append(far_zone)

	selector.children.assign(children)
	return selector

func _build_hit_and_run_tree() -> AIBehavior:
	var selector := Selector.new()
	var children: Array[AIBehavior] = []

	var hitrun_sel := Selector.new()
	hitrun_sel.children.assign([_seq([_act("attack"), _act("dash", 0.2)]), _act("dash")])
	var close_hitrun := _seq([_cond(Callable(self, "_in_range").bind("close")), hitrun_sel])
	children.append(close_hitrun)

	# Mid range: the attack here is the gap-closer (Greninja's Down basic teleports in, so it only connects from this range)
	var mid_hitrun_sel := Selector.new()
	mid_hitrun_sel.children.assign([_cd(_act("special1"), 2.5), _cd(_act("special2"), 3.0), _cd(_act("attack"), 1.5), _act("dash")])
	var mid_hitrun := _seq([_cond(Callable(self, "_in_range").bind("mid")), mid_hitrun_sel])
	children.append(mid_hitrun)

	var far_approach := _seq([_cond(Callable(self, "_in_range").bind("far")), _act("dash")])
	children.append(far_approach)

	selector.children.assign(children)
	return selector

func _build_tricky_tree() -> AIBehavior:
	var selector := Selector.new()

	# Hops are the tricky part, but they must not replace the attack: a close attack goes first, the specials and
	# dash come next, the hop only when none of those can go, and the walk-in last so the bot never idles in place.
	var tricky_sel := Selector.new()
	tricky_sel.children.assign([
		_seq([_cond(Callable(self, "_in_range").bind("close")), _act("attack")]),
		_cd(_act("special2"), 3.0),
		_cd(_act("special1"), 2.5),
		_cd(_act("dash"), 2.0),
		_act("attack"),
		_cond(Callable(self, "_walk_in"))
	])

	var always := _seq([_cond(Callable(self, "_always_true")), tricky_sel])
	selector.children.assign([always])
	return selector

func _build_balanced_tree() -> AIBehavior:
	var selector := Selector.new()
	var children: Array[AIBehavior] = []

	var close_sel := Selector.new()
	close_sel.children.assign([_cd(_act("special1"), 2.5), _act("attack")])
	var close_bal := _seq([_cond(Callable(self, "_in_range").bind("close")), close_sel])
	children.append(close_bal)

	var mid_sel := Selector.new()
	# special2 before dash: dash is always usable, so with dash first the special2 (Mewtwo's Disable) was never reached
	mid_sel.children.assign([_cd(_act("special1"), 3.0), _cd(_act("special2"), 3.5), _act("dash"), _act("attack")])
	var mid_bal := _seq([_cond(Callable(self, "_in_range").bind("mid")), mid_sel])
	children.append(mid_bal)

	var far_bal := _seq([_cond(Callable(self, "_in_range").bind("far")), _act("dash")])
	children.append(far_bal)

	selector.children.assign(children)
	return selector

# ---------------------------------------------------------------- conditions

func _always_true(_ai: AIController) -> bool:
	return true

## Root fallback, used when the engagement tree has nothing to do. It must agree with _update_movement's spacing:
## a bot that keeps its distance (zoning, mid) backs off when too close and holds inside its band. Walking in past
## the band here made the bot reverse every decision (approach, back off, approach ...).
## True for the moments after a Vine Lash (Decidueye's Down special 2): he is airborne, the enemy is close and level
## or a little below him, and special 2 is still cooling down (it was just used).
func _check_vine_followup(_ai: AIController) -> bool:
	if not _has_opponent() or target_fighter.is_on_floor():
		return false
	if not target_fighter.moves.has("special2_down") or not bool(target_fighter.moves["special2_down"].get("pull", false)):
		return false
	if float(target_fighter.cooldowns.get("special2", 0.0)) <= 2.5:
		return false     # the vine was not used in the last ~1.5 s
	var dx := _horizontal_gap()
	var dy := opponent_fighter.global_position.y - target_fighter.global_position.y
	return dx < 110.0 and dy > -30.0 and dy < 70.0

## True when Decidueye's Vine Lash can connect from here and is off cooldown: the enemy is 150-250 px away, level with him, and he is on the ground.
func _check_vine_window(_ai: AIController) -> bool:
	if not _has_opponent() or not target_fighter.is_on_floor() or not opponent_fighter.is_on_floor():
		return false
	if not target_fighter.moves.has("special2_down") or not bool(target_fighter.moves["special2_down"].get("pull", false)):
		return false
	if float(target_fighter.cooldowns.get("special2", 0.0)) > 0.0:
		return false
	if not target_fighter.stats.can_spend(float(target_fighter.moves["special2_down"].cost)):
		return false
	var dx := _horizontal_gap()
	return dx > 150.0 and dx < 250.0 and absf(opponent_fighter.global_position.y - target_fighter.global_position.y) < 50.0

func _walk_in(_ai: AIController) -> bool:
	if _has_opponent():
		var dx: float = opponent_fighter.global_position.x - target_fighter.global_position.x
		var dist: float = absf(dx)
		var band: float = 16.0 + (1.0 - accuracy) * 30.0
		var lo: float
		var hi: float
		if profile.preferred_range == "close":
			lo = _melee_reach("basic") - 10.0
			hi = lo
		else:
			var want: float = 170.0 if profile.preferred_range == "mid" else FAR_RANGE
			lo = want - band
			hi = want + band
		if dist > hi:
			move_dir = signf(dx)          # too far: close in
		elif dist >= lo:
			move_dir = 0.0                # inside the band: hold
		# too close for a keep-away fighter: keep the back-off _update_movement chose
	return true

func _has_opponent() -> bool:
	return target_fighter != null and opponent_fighter != null and is_instance_valid(opponent_fighter)

func _horizontal_gap() -> float:
	return absf(opponent_fighter.global_position.x - target_fighter.global_position.x)

## Distance window (body centre to opponent body centre) in which a melee move's hitbox can touch the opponent.
## The near edge matters for Down sweeps that start ahead of the fighter: they pass over someone standing right next
## to him. A teleporting move (Greninja's Down basic) jumps the fighter forward before its hitbox comes out, so the
## whole window moves by that distance.
func _melee_window(key: String) -> Vector2:
	var m: Dictionary = target_fighter.moves.get(key, {})
	if m.is_empty():
		return Vector2(0.0, 70.0)
	var off: Vector2 = m.off
	var box: Vector2 = m.size
	# Only Down variants have a near edge: making the normal moves wait for distance left close-range bots standing
	# still inside it (the timed-out matches).
	var near := maxf(0.0, absf(off.x) - box.x * 0.5 + BODY_RADIUS) if key.ends_with("_down") else 0.0
	var far := absf(off.x) + box.x * 0.5 + BODY_RADIUS
	var lunge := absf(float(m.lunge))
	if lunge > 0.0:
		far += lunge * float(maxi(0, int(m.off_f) - int(m.on))) / 60.0
	var tp := float(m.teleport_distance)
	return Vector2(near + tp, far + tp)

## How fast the opponent is closing on us, in px/s (negative: backing off). Uses the opponent's sideways velocity.
func _opponent_toward() -> float:
	if not _has_opponent():
		return 0.0
	var s: float = signf(opponent_fighter.global_position.x - target_fighter.global_position.x)
	return -opponent_fighter.velocity.x * s

## Reach of a melee move, measured from our body centre to the opponent's body centre: the hitbox's far edge plus
## the opponent's body radius. Derived from the move's own numbers, so new moves are picked up automatically.
func _melee_reach(key: String) -> float:
	var m: Dictionary = target_fighter.moves.get(key, {})
	if m.is_empty():
		return 70.0
	var off: Vector2 = m.off
	var box: Vector2 = m.size
	var reach := absf(off.x) + box.x * 0.5 + BODY_RADIUS
	# Moves that carry the fighter forward while active (lunging sweeps) reach further than their hitbox alone.
	var lunge := absf(float(m.lunge))
	if lunge > 0.0:
		reach += lunge * float(maxi(0, int(m.off_f) - int(m.on))) / 60.0
	return reach

func _in_range(_ai: AIController, range_type: String) -> bool:
	if not _has_opponent():
		return false
	var dx := _horizontal_gap()
	var close_limit := _melee_reach("basic")
	match range_type:
		"close": return dx <= close_limit
		"mid": return dx > close_limit and dx < FAR_RANGE
		"far": return dx >= FAR_RANGE
	return false

## Would this move (normal or Down variant) connect from where the bot stands right now? Each move kind has its own rule.
func _variant_reaches(key: String) -> bool:
	if not _has_opponent() or not target_fighter.moves.has(key):
		return false
	var m: Dictionary = target_fighter.moves[key]
	# utility moves need no target (a buff, a counter, a blink): cast them at any spacing, or they are never picked
	if float(m.get("dmg", 0.0)) <= 0.0 and (float(m.get("damage_buff", 1.0)) != 1.0 or bool(m.get("counter", false)) or float(m.get("teleport_distance", 0.0)) > 0.0):
		return true
	var dx := _horizontal_gap()
	match String(m.kind):
		"projectile":
			var vys: Array = m.get("proj_vys", [])
			var grav := float(m.get("proj_gravity", 0.0))
			if grav > 0.0 and not vys.is_empty() and float(vys[0]) < 0.0:
				# A lob comes back down to its launch height after 2 x rise / gravity seconds, so it lands about
				# speed x that time out (Sludge Bomb: about 390 px). Its lifetime range was far too long, so it missed.
				var landing := float(m.proj_speed) * 2.0 * absf(float(vys[0])) / grav
				return dx >= PROJECTILE_MIN and absf(dx - landing) <= LOB_WINDOW
			# a shot only reaches as far as its speed x lifetime (a quill spray is short; an arrow goes far)
			var shot_reach: float = float(m.proj_speed) * float(m.proj_life) * 0.9
			return dx >= PROJECTILE_MIN and dx <= minf(PROJECTILE_MAX, shot_reach)
		"trap":
			# A trap is planted trap_dist ahead and springs on whoever walks through it. Cast at a still or retreating
			# opponent it almost never hits, so it is only cast when the opponent is coming toward us.
			var tdist := float(m.trap_dist)
			var half := float(m.trap_size.x) * 0.5 + BODY_RADIUS
			# A persistent trap lingers for seconds, so it is also set at a still opponent in its zone.
			var lingers := bool(m.get("trap_persistent", false))
			var coming := lingers or _opponent_toward() > 40.0
			return dx >= maxf(0.0, tdist - half - TRAP_LEAD) and dx <= TRAP_MAX and coming
	# Melee and dive
	var dy := absf(opponent_fighter.global_position.y - target_fighter.global_position.y)
	var win := _melee_window(key)
	if dx < win.x or dx > win.y or dy > 50.0:
		return false
	# The hitbox only comes out after the windup, and a retreating opponent is out of it by then. Check the gap
	# at the middle of the active frames, using how fast the opponent is closing, so the bot does not swing at air.
	var mid_frame: float = (float(m.on) + float(m.off_f)) * 0.5
	var dx_mid: float = dx - _opponent_toward() * mid_frame / 60.0
	if dx_mid < win.x or dx_mid > win.y:
		return false
	# A dashing or invincible opponent cannot be hit (dash frames are invincible and it is moving away), so do not swing into it
	if opponent_fighter.invincible or opponent_fighter.sm.current == "dash":
		return false
	# A low Down sweep only catches a grounded opponent.
	if key.ends_with("_down") and String(m.kind) == "melee" and not opponent_fighter.is_on_floor():
		return false
	return true

## The keys (normal and/or Down variant) that could connect right now for this action. In the air a basic attack is
## the aerial dive, so only the normal key is listed there (the steep spike is chosen in _pick_down).
func _usable_keys(action: String) -> Array[String]:
	var base: String = "basic" if action == "attack" else action
	var out: Array[String] = []
	if not _banned(base) and _variant_reaches(base):
		out.append(base)
	var dkey: String = base + "_down"
	if not _banned(dkey) and (base != "basic" or target_fighter.is_on_floor()) and _variant_reaches(dkey) and not _disfavored(dkey):
		out.append(dkey)
	return out

## A Down with a low down_pref (the balance data showed it rarely connects) is never used.
## Called only after _variant_reaches(dkey), so the move exists.
func _disfavored(dkey: String) -> bool:
	var pref := float(target_fighter.moves[dkey].get("down_pref", -1.0))
	return pref >= 0.0 and pref < 0.2

## Can this action connect right now? Used to gate attacks so the bot does not swing at air or at nothing.
## Either the normal move or its Down variant counts: a variant can reach much further (a lunging sweep, a trap).
func _can_use(_ai: AIController, action: String) -> bool:
	if not _has_opponent():
		return false
	return _can_connect(_ai, action)

## The reach test without the stamina rule. The whiff punish uses it, so a saving bot still punishes.
func _can_connect(_ai: AIController, action: String) -> bool:
	if not _has_opponent():
		return false
	if action == "ultimate" and not _ultimate_ready():
		return false
	# A self-transform (Mewtwo's Burst) has no reach: the full gauge is the whole condition
	if action == "ultimate" and _self_transform():
		return true
	if _usable_keys(action).is_empty():
		return false
	# Plain attacks are only thrown with the profile's aggressiveness (specials always go when they can connect)
	if action == "attack" and randf() > clampf(aggressiveness, 0.2, 1.0):
		return false
	return true

## True when the fighter's ultimate press is a self-transform (its _ultimate_locked hook), not a move that needs reach.
func _self_transform() -> bool:
	return target_fighter != null and target_fighter._ultimate_locked()

## The same test the fighter applies: Burst Mode with a full gauge, or a full stamina bar.
func _ultimate_ready() -> bool:
	if not _has_opponent():
		return false
	if target_fighter.synergy.is_ultimate_available():
		return true
	return bool(target_fighter.ult_meter().ready)

## Should the tree cast its ultimate on this decision? meter_management decides how eagerly it does.
## Is this bot holding its stamina back for the ultimate? (meter_management decides; adaptive stops once the opponent is low)
func _saving_stamina() -> bool:
	match profile.meter_management:
		"save_for_ultimate":
			return true
		"adaptive":
			return not (_has_opponent() and opponent_fighter.stats.hp < opponent_fighter.stats.max_hp * 0.5)
	return false

func _stamina_full() -> bool:
	return target_fighter.stats.stamina >= target_fighter.stats.max_stamina - 0.01

## Dashes spend 25 stamina, the bulk of a bot's drain. A saving bot dashes only from a full bar.
func _may_dash(_ai: AIController) -> bool:
	return not _saving_stamina() or _stamina_full()

## Ultimate roll: only when it is ready (full gauge or full stamina), then a chance per decision.
func _roll_ultimate(_ai: AIController) -> bool:
	if not _ultimate_ready():
		return false
	var chance := 0.6
	match profile.meter_management:
		"save_for_ultimate":
			chance = 0.75
	if _has_opponent() and opponent_fighter.stats.hp < opponent_fighter.stats.max_hp * 0.5:
		chance = 0.9     # opponent is low: press the advantage
	return randf() < chance * clampf(accuracy, 0.5, 1.0)

func _check_anti_air(_ai: AIController) -> bool:
	if not _has_opponent():
		return false
	var dx := _horizontal_gap()
	var opponent_rising := opponent_fighter.velocity.y < 0.0
	return opponent_rising and dx < 100.0 and target_fighter.is_on_floor()

func _check_whiff_punish(_ai: AIController) -> bool:
	return _has_opponent() and _whiff_frames > 0

## A projectile flying at us (from the opponent, close enough), or the opponent casting one right now.
func _check_zoning_response(_ai: AIController) -> bool:
	if not _has_opponent():
		return false
	var parent := target_fighter.get_parent()
	if parent:
		for node in parent.get_children():
			var p := node as Projectile
			if p == null or p.shooter != opponent_fighter:
				continue
			var dist := absf(p.global_position.x - target_fighter.global_position.x)
			var coming := signf(target_fighter.global_position.x - p.global_position.x) == signf(float(p.dir))
			if coming and dist < ZONING_SIGHT:
				return true
	if opponent_fighter.sm.current in ["special1", "special2", "ultimate"]:
		if String(opponent_fighter.cur_move.get("kind", "")) == "projectile":
			return true
	return false

func _get_zoning_action() -> String:
	match profile.zoning_response:
		"approach": return "dash"
		"jump": return "jump"
		"dash": return "dash"
		"reflect": return "special1"  # assume special1 has projectile_block
		_: return "dash"

# ---------------------------------------------------------------- per-frame logic

func set_target(target: Fighter) -> void:
	opponent_fighter = target
	if target and not target.got_hit.is_connected(_on_opponent_hit):
		target.got_hit.connect(_on_opponent_hit)

## A hit on the opponent. Counts as a connect for the move that landed it, wherever that move is now.
func _on_opponent_hit(info: Dictionary) -> void:
	if not target_fighter or info.get("attacker") != target_fighter:
		return
	var key := String(info.get("by", ""))
	if key == "":
		return
	if key == _use_key:
		_use_hit = true
	_record_outcome(key, true)

func _physics_process(delta: float) -> void:
	_frame += 1
	if not target_fighter or not input_handler or not behavior_tree:
		return

	_track_outcomes()
	_update_whiff_tracking()
	_update_own_hits()
	_drop_stale_presses()
	_tally_moves()
	_try_dodge()
	_avoid_hazards()
	_drive_movement()

	# Decisions happen at the reaction interval, so difficulty scales how sharp the bot is
	decision_timer += delta
	if decision_timer < reaction_time:
		return
	decision_dt = decision_timer
	decision_timer = 0.0
	_update_movement()
	behavior_tree.tick(self)

## Decide where to walk (at each decision).
func _update_movement() -> void:
	if not _has_opponent():
		move_dir = 0.0
		return
	var dx: float = opponent_fighter.global_position.x - target_fighter.global_position.x
	var dist: float = absf(dx)
	var dir: float = signf(dx)
	var band: float = 16.0 + (1.0 - accuracy) * 30.0          # sloppier spacing on easy
	if profile.preferred_range == "close":
		# Walk in until the basic attack reaches (a little inside it, so the swing lands)
		move_dir = dir if dist > _melee_reach("basic") - 10.0 else 0.0
	else:
		var want: float = 170.0 if profile.preferred_range == "mid" else FAR_RANGE
		if dist > want + band:
			move_dir = dir                                       # close the gap
		elif dist < want - band:
			# keep-away fighters back off, but not into a corner: pinned against a wall they step in instead
			move_dir = dir if _pinned_against_wall(-dir) else -dir
		else:
			move_dir = 0.0
	# Opponent above us and near: hop at them. Cooled down, because in a mirror each hop puts the other bot below
	# the jump, which made it hop back, and the two bots kept hopping at each other.
	_hop_cooldown = maxf(0.0, _hop_cooldown - decision_dt)
	if _hop_cooldown <= 0.0 and target_fighter.is_on_floor() and dist < 200.0 and opponent_fighter.global_position.y < target_fighter.global_position.y - 90.0 and randf() < 0.5:
		buffer_action("jump")
		_hop_cooldown = HOP_COOLDOWN

## True when moving in direction dir would take the bot into a wall (it is within WALL_EDGE of that wall).
func _pinned_against_wall(dir: float) -> bool:
	var x: float = target_fighter.global_position.x
	if dir < 0.0:
		return x - Fighter.WALL_LEFT_X < WALL_EDGE
	return Fighter.WALL_RIGHT_X - x < WALL_EDGE

## True when the opponent is mid melee move whose hitbox is about to come out within reach, and the bot is standing
## or running on the ground.
func _melee_threat_now() -> bool:
	if not _has_opponent() or not target_fighter.is_on_floor():
		return false
	if target_fighter.sm.current not in ["idle", "run"]:
		return false
	if opponent_fighter.sm.current != "attack" or opponent_fighter.cur_move.is_empty():
		return false
	var om: Dictionary = opponent_fighter.cur_move
	if String(om.get("kind", "")) != "melee" or bool(om.get("is_aerial", false)):
		return false
	if opponent_fighter.sm.frames >= int(om.get("off_f", 0)):
		return false                       # its hitbox is already out (or it is recovering)
	var dy := absf(opponent_fighter.global_position.y - target_fighter.global_position.y)
	var om_off: Vector2 = om.get("off", Vector2.ZERO)
	var om_size: Vector2 = om.get("size", Vector2.ZERO)
	var reach: float = absf(om_off.x) + om_size.x * 0.5 + BODY_RADIUS + absf(float(om.get("lunge", 0.0))) * 0.2
	if dy > 50.0 or _horizontal_gap() > reach + DODGE_MARGIN:
		return false
	return true

## Dodge check, every physics frame. The bot only sees an opponent's melee move once the bot's reaction time has passed
## since that move started, so a windup shorter than the reaction time cannot be dodged. One roll per move. A dodge is
## a dash straight away from the opponent.
func _try_dodge() -> void:
	if not _has_opponent():
		return
	var serial: int = opponent_fighter.move_serial
	if serial != _dodge_serial:
		_dodge_serial = serial
		_dodge_seen = _frame
		_dodge_rolled = false
	if _dodge_rolled or _frame - _dodge_seen < int(reaction_time * 60.0):
		return
	if not _melee_threat_now():
		return
	_dodge_rolled = true
	if randf() > DODGE_CHANCE or not _may_dash(self):
		return
	move_dir = -signf(opponent_fighter.global_position.x - target_fighter.global_position.x)
	buffer_action("dash")

## Projectiles and traps. While one of the opponent's shots is coming down the bot's lane, the bot does not walk toward
## it; once its reaction time has passed it dashes straight through the shot (dash frames are invincible, and a shot
## passes through the bot in a few frames). An opponent trap on its path is hopped; a bot already standing in one dashes out.
func _avoid_hazards() -> void:
	_hazard_frames = maxi(0, _hazard_frames - 1)
	if not _has_opponent() or target_fighter.sm.current in ["attack", "special1", "special2", "ultimate", "dash"]:
		return
	var parent := target_fighter.get_parent()
	if parent == null:
		return
	if _frame % 60 == 0:
		_prune_hazards()
	var me: Vector2 = target_fighter.global_position
	var reaction_frames := int(reaction_time * 60.0)
	for node in parent.get_children():
		var p := node as Projectile
		if p == null or p.shooter != opponent_fighter or not is_instance_valid(p):
			continue
		if not _proj_seen.has(p):
			_proj_seen[p] = _frame
			_proj_dodge[p] = randf() < PROJ_DODGE_CHANCE
		var dx: float = me.x - p.global_position.x
		var incoming: bool = signf(dx) == signf(float(p.dir)) and absf(dx) < PROJ_LOOK
		var in_lane: bool = p.global_position.y > me.y - PROJ_LANE_HIGH and p.global_position.y < me.y + PROJ_LANE_LOW
		if not incoming or not in_lane:
			continue
		var toward: float = -signf(dx)           # toward the shot, which is the direction a dash has to go to pass through it
		if move_dir == toward:
			_hazard_move = 0.0                    # do not walk into it while it is still coming
			_hazard_frames = 1
		if _frame - int(_proj_seen[p]) < reaction_frames or not bool(_proj_dodge[p]):
			continue
		if not target_fighter.is_on_floor() or target_fighter.sm.current not in ["idle", "run"] or not _may_dash(self):
			continue
		_proj_dodge[p] = false                    # one dodge per shot
		_hazard_move = toward
		_hazard_frames = 20
		buffer_action("dash")
		return
	for node in parent.get_children():
		var t := node as Trap
		if t == null or t.owner_fighter != opponent_fighter or not is_instance_valid(t) or t.arm_left > 0.0:
			continue
		if not _trap_avoid.has(t):
			_trap_avoid[t] = randf() < TRAP_AVOID_CHANCE
		if not bool(_trap_avoid[t]):
			continue
		var half: float = t.area_size.x * 0.5 + BODY_RADIUS
		var tdx: float = t.global_position.x - me.x
		if absf(tdx) <= half:
			# standing in it already: dash out the side it is not on
			if target_fighter.is_on_floor() and target_fighter.sm.current in ["idle", "run"] and _may_dash(self):
				_hazard_move = -signf(tdx) if tdx != 0.0 else -float(target_fighter.facing)
				_hazard_frames = 20
				buffer_action("dash")
				return
		elif signf(tdx) == signf(move_dir) and absf(tdx) - half <= TRAP_HOP_DIST and target_fighter.is_on_floor():
			buffer_action("jump")                 # still walking toward it: the hop clears it on the way

## Forget shots and traps that have been freed, so the lookup tables stay small.
func _prune_hazards() -> void:
	for k in _proj_seen.keys():
		if not is_instance_valid(k):
			_proj_seen.erase(k)
			_proj_dodge.erase(k)
	for k in _trap_avoid.keys():
		if not is_instance_valid(k):
			_trap_avoid.erase(k)

## A press waits in the input buffer while a move is still playing, so it can start well after it was made, by
## which time the opponent may have walked out of reach. Drop an attack press as soon as it can no longer connect.
func _drop_stale_presses() -> void:
	if not _has_opponent():
		return
	# The Down choice was made when the button was pressed. If the opponent has moved since, switch to the version that now reaches.
	for act in ["attack", "special1", "special2"]:
		if int(input_handler.buffer.get(act, 0)) <= 0:
			continue
		var base: String = "basic" if act == "attack" else act
		if not target_fighter.moves.has(base + "_down") or not target_fighter.is_on_floor() and base == "basic":
			continue
		var norm_ok: bool = _variant_reaches(base) and not _banned(base)
		var down_ok: bool = _variant_reaches(base + "_down") and not _banned(base + "_down") and not _disfavored(base + "_down")
		if norm_ok and not down_ok:
			input_handler.down_at[act] = false
		elif down_ok and not norm_ok:
			input_handler.down_at[act] = true
	for action in ["attack", "special1", "special2", "ultimate"]:
		var transform_ready: bool = action == "ultimate" and _self_transform() and _ultimate_ready()
		if int(input_handler.buffer.get(action, 0)) > 0 and not transform_ready and _usable_keys(action).is_empty():
			input_handler.buffer[action] = 0

## Every frame: apply the chosen movement, hold jump, decay the buffers, face the opponent.
func _drive_movement() -> void:
	input_handler.move_x = _hazard_move if _hazard_frames > 0 else move_dir
	_jump_hold_frames = maxi(0, _jump_hold_frames - 1)
	input_handler.jump_held = _jump_hold_frames > 0
	input_handler.decay_buffers()        # remote mode skips InputHandler.poll(), so the buffers count down here
	# Always face the opponent, except while a move is playing (its hitbox and projectiles use the facing it started with)
	if _has_opponent() and target_fighter.sm.current not in ["attack", "special1", "special2", "ultimate"]:
		var dx: float = opponent_fighter.global_position.x - target_fighter.global_position.x
		target_fighter.facing = 1 if dx >= 0.0 else -1

## Watches the opponent's melee moves. If one ends without connecting, the bot gets a short punish window.
func _update_whiff_tracking() -> void:
	if not _has_opponent():
		return
	var opp_busy: bool = opponent_fighter.sm.current in ["attack", "special1", "special2", "ultimate"]
	var melee_now: bool = opp_busy and String(opponent_fighter.cur_move.get("kind", "melee")) in MELEE_KINDS
	if melee_now:
		_opp_attacking = true
		if opponent_fighter.landed_hit:
			_opp_landed = true
	elif _opp_attacking:
		_opp_attacking = false
		if not _opp_landed:
			_whiff_frames = WHIFF_WINDOW
		_opp_landed = false
	if _whiff_frames > 0:
		_whiff_frames -= 1

## Our own move has connected: queue the profile's follow-up now, frame-accurately, instead of waiting for the
## next decision (combo windows are only 8-10 frames). Accuracy decides whether the bot finds the follow-up.
func _update_own_hits() -> void:
	if not target_fighter:
		return
	if not target_fighter.landed_hit:
		_own_hit_seen = false
		return
	if _own_hit_seen:
		return
	_own_hit_seen = true
	for chain in profile.combo_chains:
		if String(chain.trigger) == target_fighter.cur_key and randf() < accuracy \
				and not _usable_keys(String(chain.followup)).is_empty():
			buffer_action(String(chain.followup))

## Closes out a use when the move changes: a use that connected nothing counts as a miss.
func _track_outcomes() -> void:
	var s: int = int(target_fighter.move_serial)
	if s == _use_serial:
		return
	if _use_serial >= 0 and _use_key != "" and not _use_hit:
		_record_outcome(_use_key, false)
	_use_serial = s
	_use_key = String(target_fighter.current_label())
	_use_hit = false

func _record_outcome(key: String, hit: bool) -> void:
	if key == "ultimate" or key.begins_with("awaken"):
		return
	var rec: Array = _outcomes.get(key, [])
	rec.append(hit)
	if rec.size() > RECENT_USES:
		rec.pop_front()
	_outcomes[key] = rec
	if hit:
		_ban_count[key] = 0
		return
	if rec.size() >= RECENT_USES and not rec.has(true):
		var n: int = int(_ban_count.get(key, 0)) + 1
		_ban_count[key] = n
		_ban_until[key] = _frame + WHIFF_BAN_FRAMES * mini(n, 4)
		_outcomes[key] = []

func _banned(key: String) -> bool:
	if not WHIFF_MEMORY:
		return false
	return _frame < int(_ban_until.get(key, 0))

## Should this press be a Down variant? The Down version is used when it is the one that can actually connect
## (a sweep that lunges past the normal basic's reach, a trap placed further out). When both connect it is a choice,
## weighted by what the Down move is. In the air a basic attack's Down is the steep spike.
func _pick_down(action: String) -> bool:
	if not _has_opponent():
		return false
	var key: String = "basic" if action == "attack" else action
	var dkey: String = key + "_down"
	if not target_fighter.moves.has(dkey) or _banned(dkey) or _disfavored(dkey):
		return false
	if _banned(key):
		return true     # the normal move is banned: the Down version is the only one left
	var dx: float = _horizontal_gap()
	if not target_fighter.is_on_floor():
		var dy: float = opponent_fighter.global_position.y - target_fighter.global_position.y
		return action == "attack" and dy > 30.0 and dx < 160.0 and randf() < 0.4 * clampf(accuracy, 0.3, 1.0)
	if not _variant_reaches(dkey):
		return false
	if not _variant_reaches(key):
		return true     # only the Down version can hit from here: the normal move would whiff, so always take Down
	# Both connect: judge by what the Down move actually is
	var dm: Dictionary = target_fighter.moves[dkey]
	# A per-move preference from the balance data (hit rate and use). Absent: the kind's default below.
	var pref := float(dm.get("down_pref", -1.0))
	if pref >= 0.0:
		return randf() < pref * clampf(accuracy, 0.3, 1.0)
	if dm.get("pull", false):
		# Vine Lash: whip the enemy in from mid range, then follow up with an aerial basic
		var pull_chance: float = 0.9 if (dx > 150.0 and dx < 250.0) else 0.1
		return randf() < pull_chance * clampf(accuracy, 0.3, 1.0)
	var chance := 0.0
	match String(dm.kind):
		"projectile":
			# Short-range sprays want to be close; long skimming shots are for range.
			var reach: float = float(dm.proj_speed) * float(dm.proj_life)
			if dx < reach * 0.9 and dx > (40.0 if reach < 300.0 else 120.0):
				chance = 0.25
		"trap":
			chance = 0.35
		"dive":
			chance = 0.3
		_:
			chance = 0.4     # a grounded Down sweep is the stronger pick when both connect
	return randf() < chance * clampf(accuracy, 0.3, 1.0)

## Counts each move the bot actually starts (not just the presses it buffers), normal and Down variant apart.
func _tally_moves() -> void:
	if not LOG_MOVE_USAGE or not target_fighter:
		return
	if target_fighter.move_serial == 0 or target_fighter.move_serial == _last_serial:
		return
	_last_serial = target_fighter.move_serial
	var k: String = target_fighter.cur_key + ("_down" if target_fighter.cur_down else "")
	usage[k] = int(usage.get(k, 0)) + 1

func _exit_tree() -> void:
	if LOG_MOVE_USAGE and not usage.is_empty():
		var who: String = get_parent().name if get_parent() else "AI"
		print("[AI] ", who, " moves started: ", usage)

func buffer_action(action_name: String) -> void:
	if not input_handler or action_name == "":
		return
	# Profiles may say "basic"; the fighter reads its buffer under "attack"
	var action: String = "attack" if action_name == "basic" else action_name
	input_handler.buffer[action] = InputHandler.BUFFER_WINDOWS.get(action, 6)
	if action in ["attack", "special1", "special2"]:
		input_handler.down_at[action] = _pick_down(action)   # the bot holds Down for this press (or not)
	if action == "jump":
		_jump_hold_frames = 18      # hold so the jump isn't cut short

# --- Behavior Tree Helpers ---
func _cond(func_callable: Callable) -> Condition:
	var c := Condition.new()
	c.check_func = func_callable
	return c

## An action. Attack-type actions are wrapped in a range check (gated) so the bot only presses them when they can
## connect; the anti-air and punish branches pass gated = false / keep their own checks.
func _act(act_name: String, duration: float = 0.0, gated: bool = true, free: bool = false) -> AIBehavior:
	var a := Action.new()
	a.action_name = act_name
	if duration > 0.0:
		a.duration = duration
	if gated and act_name in ATTACK_KEYS:
		var gate := "_can_connect" if free else "_can_use"
		return _seq([_cond(Callable(self, gate).bind(act_name)), a])
	if act_name == "dash":
		return _seq([_cond(Callable(self, "_may_dash")), a])
	return a

func _cd(child_node: AIBehavior, time: float) -> Cooldown:
	var c := Cooldown.new()
	c.child = child_node
	c.cooldown_time = time
	return c

func _seq(nodes: Array) -> Sequence:
	var s := Sequence.new()
	var casted: Array[AIBehavior] = []
	for n in nodes:
		casted.append(n as AIBehavior)
	s.children.assign(casted)
	return s
