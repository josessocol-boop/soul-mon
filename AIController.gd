class_name AIController
extends Node
## AI controller using behavior tree. Drives fighter input via InputHandler in remote mode.
## Fair detection only: uses hitbox overlaps, velocity, position, cooldowns - NEVER reads opponent input buffer.

# Difficulty scaling multipliers (applied on top of profile base values)
const DIFFICULTY_MULTIPLIERS := {
	"easy": {"reaction_time": 1.6, "accuracy": 0.5, "aggressiveness": 0.7},
	"medium": {"reaction_time": 1.0, "accuracy": 0.7, "aggressiveness": 1.0},
	"hard": {"reaction_time": 0.6, "accuracy": 0.85, "aggressiveness": 1.2}
}

# Base reaction times per difficulty (seconds)
const BASE_REACTION_TIME := {
	"easy": 0.4,
	"medium": 0.25,
	"hard": 0.15
}

@export var difficulty: String = "medium"

# Internal state
var target_fighter: Fighter
var opponent_fighter: Fighter
var input_handler: InputHandler
var stats: StatsComponent
var sm: StateMachine
var profile: AIProfile
var behavior_tree: AIBehavior
var decision_timer: float = 0.0
var reaction_time: float = 0.25
var accuracy: float = 0.7
var aggressiveness: float = 0.6

# Movement: the old AI only ever pressed buttons, it never wrote move_x / facing, so bots stood still.
const PREFERRED_DISTANCE := {"close": 80.0, "mid": 170.0, "far": 300.0}   # px, by profile.preferred_range
var move_dir: float = 0.0
var _jump_hold_frames: int = 0

# Combo buffer state
var _combo_buffer: Array = []  # [{"action": String, "frames_left": int}, ...]

# Whiff punish tracking
var _opponent_last_move_key: String = ""
var _opponent_move_frames: int = 0
var _opponent_hit_confirmed: bool = false

func _ready() -> void:
	pass

func setup(fighter: Fighter) -> void:
	target_fighter = fighter
	input_handler = fighter.get_node("InputHandler")
	stats = fighter.get_node("StatsComponent")
	sm = fighter.get_node("StateMachine")

	# Set input handler to remote mode so we can control it programmatically
	if input_handler:
		input_handler.remote = true

	# Load AI profile for this fighter
	_load_profile(fighter)

	# Apply difficulty multipliers
	_apply_difficulty()

	# Build behavior tree from profile
	_build_behavior_tree()

func _load_profile(fighter: Fighter) -> void:
	var fighter_id: String = ""
	# Extract fighter ID from scene path or name
	if fighter.scene_file_path != "":
		fighter_id = fighter.scene_file_path.get_file().replace("fighter_", "").replace(".tscn", "")
	elif fighter.name.begins_with("Player_"):
		# Fallback: try to infer from player number (not reliable for CPU vs CPU)
		pass

	if fighter_id == "":
		# Try to match by script class or archetype
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

	if fighter_id != "" and ResourceLoader.exists("res://ai_profiles/" + fighter_id + ".tres"):
		profile = load("res://ai_profiles/" + fighter_id + ".tres")
	else:
		# Fallback to default balanced profile
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

func _build_behavior_tree() -> void:
	# Build a behavior tree based on profile personality and preferences
	# Root is a Selector that tries high-priority behaviors first

	var root = Selector.new()
	var children: Array[AIBehavior] = []

	# Priority 1: Combo follow-ups (highest priority - time sensitive)
	if profile.combo_chains.size() > 0:
		var combo_sequence = Sequence.new()
		var combo_children: Array[AIBehavior] = []
		for chain in profile.combo_chains:
			var trigger: String = chain.trigger
			var followup: String = chain.followup
			var window: int = chain.window

			# Condition: check if we just connected with trigger move and are in combo window
			var condition = Condition.new()
			condition.check_func = Callable(self, "_check_combo_window").bind(trigger, followup, window)
			combo_children.append(condition)

			# Action: buffer the followup
			var action = Action.new()
			action.action_name = followup
			combo_children.append(action)

		combo_sequence.children.assign(combo_children)
		children.append(combo_sequence)

	# Priority 2: Anti-air
	if profile.anti_air_move != "":
		var anti_air_seq = Sequence.new()
		var anti_air_children: Array[AIBehavior] = []

		var condition = Condition.new()
		condition.check_func = Callable(self, "_check_anti_air")
		anti_air_children.append(condition)

		var action = Action.new()
		action.action_name = profile.anti_air_move
		anti_air_children.append(action)

		anti_air_seq.children.assign(anti_air_children)
		children.append(anti_air_seq)

	# Priority 3: Whiff punish
	if profile.punish_move != "":
		var punish_seq = Sequence.new()
		var punish_children: Array[AIBehavior] = []

		var condition = Condition.new()
		condition.check_func = Callable(self, "_check_whiff_punish")
		punish_children.append(condition)

		var action = Action.new()
		action.action_name = profile.punish_move
		punish_children.append(action)

		punish_seq.children.assign(punish_children)
		children.append(punish_seq)

	# Priority 4: Zoning response
	var zoning_seq = Sequence.new()
	var zoning_children: Array[AIBehavior] = []

	var zoning_condition = Condition.new()
	zoning_condition.check_func = Callable(self, "_check_zoning_response")
	zoning_children.append(zoning_condition)

	var zoning_action = Action.new()
	zoning_action.action_name = _get_zoning_action()
	zoning_children.append(zoning_action)

	zoning_seq.children.assign(zoning_children)
	children.append(zoning_seq)

	# Priority 5: Main engagement (approach/attack/defend based on personality)
	var engagement = _build_engagement_tree()
	children.append(engagement)

	root.children.assign(children)
	behavior_tree = root

func _build_engagement_tree() -> AIBehavior:
	# Build engagement subtree based on personality
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
		"balanced":
			return _build_balanced_tree()
		_:
			return _build_balanced_tree()

func _build_aggressive_tree() -> AIBehavior:
	var selector = Selector.new()
	var children: Array[AIBehavior] = []

	var close_attack = _seq([_cond(Callable(self, "_in_range").bind("close")), _act("attack")])
	children.append(close_attack)

	var mid_action = Selector.new()
	mid_action.children.assign([_cd(_act("special1"), 2.0), _act("dash")])
	var mid_seq = _seq([_cond(Callable(self, "_in_range").bind("mid")), mid_action])
	children.append(mid_seq)

	var far_seq = _seq([_cond(Callable(self, "_in_range").bind("far")), _act("dash")])
	children.append(far_seq)

	selector.children.assign(children)
	return selector

func _build_defensive_tree() -> AIBehavior:
	var selector = Selector.new()
	var children: Array[AIBehavior] = []

	var retreat = _seq([_cond(Callable(self, "_in_range").bind("close")), _act("dash", 0.3)])
	children.append(retreat)

	var poke_sel = Selector.new()
	poke_sel.children.assign([_cd(_act("special1"), 3.0), _act("attack")])
	var mid_poke = _seq([_cond(Callable(self, "_in_range").bind("mid")), poke_sel])
	children.append(mid_poke)

	var far_wait = _seq([_cond(Callable(self, "_in_range").bind("far")), _act("")])
	children.append(far_wait)

	selector.children.assign(children)
	return selector

func _build_zoning_tree() -> AIBehavior:
	var selector = Selector.new()
	var children: Array[AIBehavior] = []

	var close_escape = _seq([_cond(Callable(self, "_in_range").bind("close")), _act("dash", 0.3)])
	children.append(close_escape)

	var zone_sel = Selector.new()
	zone_sel.children.assign([_cd(_act("special1"), 2.5), _cd(_act("special2"), 3.0), _act("attack")])
	var mid_zone = _seq([_cond(Callable(self, "_in_range").bind("mid")), zone_sel])
	children.append(mid_zone)

	var far_sel = Selector.new()
	far_sel.children.assign([_cd(_act("special1"), 2.0), _cd(_act("special2"), 2.5)])
	var far_zone = _seq([_cond(Callable(self, "_in_range").bind("far")), far_sel])
	children.append(far_zone)

	selector.children.assign(children)
	return selector

func _build_hit_and_run_tree() -> AIBehavior:
	var selector = Selector.new()
	var children: Array[AIBehavior] = []

	var hitrun_sel = Selector.new()
	hitrun_sel.children.assign([_seq([_act("attack"), _act("dash", 0.2)]), _act("dash")])
	var close_hitrun = _seq([_cond(Callable(self, "_in_range").bind("close")), hitrun_sel])
	children.append(close_hitrun)

	var mid_hitrun = _seq([_cond(Callable(self, "_in_range").bind("mid")), _act("dash")])
	children.append(mid_hitrun)

	var far_approach = _seq([_cond(Callable(self, "_in_range").bind("far")), _act("dash")])
	children.append(far_approach)

	selector.children.assign(children)
	return selector

func _build_tricky_tree() -> AIBehavior:
	var selector = Selector.new()
	
	var tricky_sel = Selector.new()
	tricky_sel.children.assign([
		_cd(_act("jump"), 1.5),
		_cd(_act("dash"), 2.0),
		_cd(_act("special2"), 3.0),
		_act("attack")
	])

	var always = _seq([_cond(Callable(self, "_always_true")), tricky_sel])
	selector.children.assign([always])
	return selector

func _build_balanced_tree() -> AIBehavior:
	var selector = Selector.new()
	var children: Array[AIBehavior] = []

	var close_sel = Selector.new()
	close_sel.children.assign([_cd(_act("special1"), 2.5), _act("attack")])
	var close_bal = _seq([_cond(Callable(self, "_in_range").bind("close")), close_sel])
	children.append(close_bal)

	var mid_sel = Selector.new()
	mid_sel.children.assign([_act("dash"), _cd(_act("special1"), 3.0), _act("attack")])
	var mid_bal = _seq([_cond(Callable(self, "_in_range").bind("mid")), mid_sel])
	children.append(mid_bal)

	var far_bal = _seq([_cond(Callable(self, "_in_range").bind("far")), _act("dash")])
	children.append(far_bal)

	selector.children.assign(children)
	return selector

func _always_true(ai: AIController) -> bool:
	return true

func _in_range(ai: AIController, range_type: String) -> bool:
	if not opponent_fighter or not is_instance_valid(opponent_fighter):
		return false

	var dx: float = abs(opponent_fighter.global_position.x - target_fighter.global_position.x)
	match range_type:
		"close": return dx < 150
		"mid": return dx >= 150 and dx < 300
		"far": return dx >= 300
	return false

func _check_combo_window(ai: AIController, trigger: String, followup: String, window: int) -> bool:
	# Check if we have a buffered combo for this followup
	for combo in _combo_buffer:
		if combo.action == followup and combo.frames_left > 0:
			return true
	return false

func _check_anti_air(ai: AIController) -> bool:
	if not opponent_fighter or not is_instance_valid(opponent_fighter):
		return false

	# Opponent jumping in: velocity.y < 0 (rising), close horizontally, we're on floor
	var dx: float = abs(opponent_fighter.global_position.x - target_fighter.global_position.x)
	var opponent_rising := opponent_fighter.velocity.y < 0
	var we_on_floor := target_fighter.is_on_floor()

	return opponent_rising and dx < 100 and we_on_floor

func _check_whiff_punish(ai: AIController) -> bool:
	if not opponent_fighter or not is_instance_valid(opponent_fighter):
		return false

	# Check if opponent just whiffed a move (move ended without hit_confirmed)
	# We track this by monitoring opponent's state machine and hit_confirmed
	var opponent_sm: StateMachine = opponent_fighter.get_node("StateMachine")
	if not opponent_sm:
		return false

	# If opponent was in attack state and now transitioned out without hit_confirmed
	# This is a simplified check - in practice we'd track more carefully
	return _opponent_last_move_key != "" and not _opponent_hit_confirmed and _opponent_move_frames > 0

func _check_zoning_response(ai: AIController) -> bool:
	if not opponent_fighter or not is_instance_valid(opponent_fighter):
		return false

	# Check if opponent has active projectiles
	# We can check overlapping areas for projectiles
	var projectiles: Array = target_fighter.hitbox.get_overlapping_areas()
	for area in projectiles:
		var proj: Node = area.get_parent()
		if proj and proj.has_method("is_projectile") and proj.is_projectile():
			return true

	# Also check if opponent is in a projectile-spawning move
	var opponent_sm: StateMachine = opponent_fighter.get_node("StateMachine")
	if opponent_sm and opponent_sm.current in ["special1", "special2", "ultimate"]:
		var opp_moves: Dictionary = opponent_fighter.moves
		if opp_moves.has(opponent_sm.current):
			var move: Dictionary = opp_moves[opponent_sm.current]
			if move.get("kind", "") == "projectile":
				return true

	return false

func _get_zoning_action() -> String:
	match profile.zoning_response:
		"approach": return "dash"
		"jump": return "jump"
		"dash": return "dash"
		"reflect": return "special1"  # assume special1 has projectile_block
		_: return "dash"

func set_target(target: Fighter) -> void:
	opponent_fighter = target

func _physics_process(delta: float) -> void:
	if not target_fighter or not input_handler or not behavior_tree:
		return

	# Update combo buffer timers
	for combo in _combo_buffer:
		combo.frames_left -= 1
	_combo_buffer = _combo_buffer.filter(func(c): return c.frames_left > 0)

	# Update whiff punish tracking
	_update_whiff_tracking()

	_drive_movement()

	# Make decisions at the configured reaction interval
	decision_timer += delta
	if decision_timer < reaction_time:
		return
	decision_timer = 0.0
	_update_movement()

	# Execute behavior tree
	behavior_tree.tick(self)

	# Apply buffered inputs
	_apply_buffered_inputs()

## Decide where to walk (at the reaction interval, so difficulty scales how sharp the bot is).
func _update_movement() -> void:
	if not opponent_fighter or not is_instance_valid(opponent_fighter):
		move_dir = 0.0
		return
	var dx: float = opponent_fighter.global_position.x - target_fighter.global_position.x
	var dist: float = absf(dx)
	var dir: float = signf(dx)
	var want: float = PREFERRED_DISTANCE.get(profile.preferred_range, 170.0)
	var band: float = 30.0 + (1.0 - accuracy) * 40.0          # sloppier spacing on easy
	if dist > want + band:
		move_dir = dir                                          # close the gap
	elif dist < want - band and want > 120.0:
		move_dir = -dir                                         # keep-away fighters back off
	else:
		move_dir = 0.0
	# Opponent above us and near: hop at them.
	if target_fighter.is_on_floor() and dist < 200.0 and opponent_fighter.global_position.y < target_fighter.global_position.y - 90.0 and randf() < 0.5:
		buffer_action("jump")

## Every frame: apply the chosen movement, hold jump, face the opponent, expire stale buffered presses.
func _drive_movement() -> void:
	input_handler.move_x = move_dir
	_jump_hold_frames = maxi(0, _jump_hold_frames - 1)
	input_handler.jump_held = _jump_hold_frames > 0
	for a in input_handler.buffer.keys():                       # remote mode skips InputHandler.poll(), so decay here
		input_handler.buffer[a] = maxi(0, int(input_handler.buffer[a]) - 1)
	if opponent_fighter and is_instance_valid(opponent_fighter) and sm.current in ["idle", "run", "jump"]:
		var dx: float = opponent_fighter.global_position.x - target_fighter.global_position.x
		if move_dir == 0.0 or signf(move_dir) == signf(dx):
			target_fighter.facing = 1 if dx >= 0.0 else -1

func _update_whiff_tracking() -> void:
	if not opponent_fighter or not is_instance_valid(opponent_fighter):
		return

	var opponent_sm: StateMachine = opponent_fighter.get_node("StateMachine")
	if not opponent_sm:
		return

	# Track opponent move state for whiff detection
	if opponent_sm.current in ["attack", "special1", "special2", "ultimate"]:
		if _opponent_last_move_key != opponent_sm.current:
			_opponent_last_move_key = opponent_sm.current
			_opponent_move_frames = 0
			_opponent_hit_confirmed = false
		_opponent_move_frames += 1

		# Check if move connected
		if opponent_fighter.hit_confirmed:
			_opponent_hit_confirmed = true
	else:
		# Opponent not in attack state
		if _opponent_last_move_key != "":
			# Move just ended
			if not _opponent_hit_confirmed and _opponent_move_frames > 0:
				# Whiff detected - could trigger punish
				pass
			_opponent_last_move_key = ""
			_opponent_move_frames = 0
			_opponent_hit_confirmed = false

func buffer_action(action: String) -> void:
	if not input_handler:
		return

	# Use buffer windows from InputHandler (same as player)
	var buffer_windows := {
		"jump": 6, "dash": 6, "attack": 9,
		"special1": 9, "special2": 9, "ultimate": 9,
		"support": 6, "support_2": 6, "support_3": 6
	}
	var frames: int = buffer_windows.get(action, 6)
	input_handler.buffer[action] = frames
	if action == "jump":
		_jump_hold_frames = 18      # hold so the jump isn't cut short

	# Also track for combo system
	if action in ["basic", "special1", "special2", "ultimate"]:
		# Check if this triggers a combo
		for chain in profile.combo_chains:
			if chain.trigger == action:
				_combo_buffer.append({"action": chain.followup, "frames_left": chain.window})

func _apply_buffered_inputs() -> void:
	# InputHandler automatically processes buffer in its poll()
	# We just need to ensure remote mode is set
	if input_handler:
		input_handler.remote = true

# Called by Fighter when a move connects (to enable combo buffering)
func on_hit_connect(move_key: String) -> void:
	for chain in profile.combo_chains:
		if chain.trigger == move_key:
			_combo_buffer.append({"action": chain.followup, "frames_left": chain.window})
# --- Behavior Tree Helpers ---
func _cond(func_callable: Callable) -> Condition:
	var c = Condition.new()
	c.check_func = func_callable
	return c

func _act(act_name: String, duration: float = 0.0) -> Action:
	var a = Action.new()
	a.action_name = act_name
	if duration > 0.0:
		a.set("duration", duration)
	return a

func _cd(child_node: AIBehavior, time: float) -> Cooldown:
	var c = Cooldown.new()
	c.child = child_node
	c.cooldown_time = time
	return c

func _seq(nodes: Array) -> Sequence:
	var s = Sequence.new()
	var casted: Array[AIBehavior] = []
	for n in nodes: casted.append(n as AIBehavior)
	s.children.assign(casted)
	return s
