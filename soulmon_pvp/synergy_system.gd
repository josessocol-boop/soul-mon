class_name SynergySystem
extends Node
## Manages Synergy Burst gauge, Burst Mode activation, and One-Time Ultimate gating.

signal burst_activated(player_id: int)
signal burst_ended(player_id: int)
signal ultimate_ready(player_id: int)
signal ultimate_used(player_id: int)
signal gauge_changed(player_id: int, value: float, max_value: float)

# Burst gauge constants
const GAUGE_MAX := 1000.0
const GAUGE_FILL_ON_HIT := 25.0
const GAUGE_FILL_ON_DEALT := 15.0
const GAUGE_FILL_ON_TAKEN := 35.0
const GAUGE_FILL_PASSIVE := 5.0  # per second
const BURST_DURATION := 12.0     # seconds
const BURST_COOLDOWN := 30.0     # seconds before can build again

# Ultimate constants
const ULTIMATE_COST := 1000.0    # requires full gauge

enum BurstState { READY, ACTIVE, COOLDOWN, ULTIMATE_USED }

var player_id: int = 1
var gauge: float = 0.0
var state: BurstState = BurstState.READY
var burst_timer: float = 0.0
var cooldown_timer: float = 0.0
var ultimate_used_this_burst: bool = false
var passive_fill_enabled: bool = true

# Archetype-specific fill multipliers (set by fighter)
var fill_multiplier_hit := 1.0
var fill_multiplier_dealt := 1.0
var fill_multiplier_taken := 1.0
var fill_multiplier_passive := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_player(pid: int) -> void:
	player_id = pid

func set_archetype_traits(traits: Dictionary) -> void:
	fill_multiplier_hit = traits.get("burst_fill_hit", 1.0)
	fill_multiplier_dealt = traits.get("burst_fill_dealt", 1.0)
	fill_multiplier_taken = traits.get("burst_fill_taken", 1.0)
	fill_multiplier_passive = traits.get("burst_fill_passive", 1.0)

func _process(delta: float) -> void:
	match state:
		BurstState.ACTIVE:
			burst_timer -= delta
			if burst_timer <= 0.0:
				_end_burst()
		BurstState.COOLDOWN:
			cooldown_timer -= delta
			if cooldown_timer <= 0.0:
				state = BurstState.READY
				passive_fill_enabled = true
		BurstState.READY:
			if passive_fill_enabled:
				_fill_gauge(GAUGE_FILL_PASSIVE * fill_multiplier_passive * delta)

func _fill_gauge(amount: float) -> void:
	if state == BurstState.ULTIMATE_USED or state == BurstState.COOLDOWN:
		return
	gauge = min(GAUGE_MAX, gauge + amount)
	gauge_changed.emit(player_id, gauge, GAUGE_MAX)
	if gauge >= GAUGE_MAX and state == BurstState.READY:
		ultimate_ready.emit(player_id)

func on_hit_connect(is_counter: bool = false) -> void:
	_fill_gauge(GAUGE_FILL_ON_HIT * fill_multiplier_hit * (1.5 if is_counter else 1.0))

func on_damage_dealt(amount: float) -> void:
	_fill_gauge(GAUGE_FILL_ON_DEALT * fill_multiplier_dealt * (amount / 10.0))

func on_damage_taken(amount: float) -> void:
	_fill_gauge(GAUGE_FILL_ON_TAKEN * fill_multiplier_taken * (amount / 10.0))

func try_activate_burst() -> bool:
	if state != BurstState.READY or gauge < GAUGE_MAX:
		return false
	state = BurstState.ACTIVE
	burst_timer = BURST_DURATION
	ultimate_used_this_burst = false
	passive_fill_enabled = false
	burst_activated.emit(player_id)
	return true

func _end_burst() -> void:
	if ultimate_used_this_burst:
		state = BurstState.ULTIMATE_USED
		cooldown_timer = BURST_COOLDOWN
	else:
		state = BurstState.COOLDOWN
		cooldown_timer = BURST_COOLDOWN
	burst_ended.emit(player_id)

func try_use_ultimate() -> bool:
	if state != BurstState.ACTIVE or ultimate_used_this_burst:
		return false
	if gauge < ULTIMATE_COST:
		return false
	gauge = 0.0
	ultimate_used_this_burst = true
	ultimate_used.emit(player_id)
	gauge_changed.emit(player_id, gauge, GAUGE_MAX)
	# End burst early after ultimate
	_end_burst()
	return true

func get_burst_time_remaining() -> float:
	return max(0.0, burst_timer) if state == BurstState.ACTIVE else 0.0

func get_cooldown_remaining() -> float:
	return max(0.0, cooldown_timer) if state == BurstState.COOLDOWN else 0.0

func is_burst_active() -> bool:
	return state == BurstState.ACTIVE

func is_ultimate_available() -> bool:
	return state == BurstState.ACTIVE and not ultimate_used_this_burst and gauge >= ULTIMATE_COST

func reset() -> void:
	gauge = 0.0
	state = BurstState.READY
	burst_timer = 0.0
	cooldown_timer = 0.0
	ultimate_used_this_burst = false
	passive_fill_enabled = true
	gauge_changed.emit(player_id, gauge, GAUGE_MAX)