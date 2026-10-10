class_name StatsComponent
extends Node

signal burn_ticked(amount: float)
signal poison_ticked(amount: float)

enum Element { NORMAL, FIRE, WATER, GRASS, ICE, STEEL, GHOST, FIGHTING, FAIRY, BUG, DARK, POISON }

const DASH_COST := 25.0
const REGEN_PER_SEC := 20.0
const RECOVER_AT := 25.0

const BURN_DAMAGE := 2.0
const BURN_TICKS := 3          # 2 dmg/sec for 3 sec
const POISON_DAMAGE := 2.0
const POISON_TICKS := 4        # 2 dmg/sec for 4 sec
const SLOW_FACTOR := 0.75      # -25% speed
const SLOW_TIME := 3.0

# Flattened type chart (attacker -> defender). Results are +20% / -20% / -50%.
const SUPER := {
	Element.FIRE: [Element.GRASS, Element.ICE, Element.BUG, Element.STEEL],
	Element.WATER: [Element.FIRE],
	Element.GRASS: [Element.WATER],
	Element.ICE: [Element.GRASS],
	Element.STEEL: [Element.ICE, Element.FAIRY],
	Element.GHOST: [Element.GHOST],
	Element.FIGHTING: [Element.NORMAL, Element.ICE, Element.STEEL, Element.DARK],
	Element.FAIRY: [Element.FIGHTING, Element.DARK],
	Element.BUG: [Element.GRASS, Element.DARK],
	Element.DARK: [Element.GHOST],
	Element.POISON: [Element.GRASS, Element.FAIRY],
}
const RESIST := {
	Element.NORMAL: [Element.STEEL],
	Element.FIRE: [Element.FIRE, Element.WATER],
	Element.WATER: [Element.WATER, Element.GRASS],
	Element.GRASS: [Element.FIRE, Element.GRASS, Element.POISON, Element.BUG, Element.STEEL],
	Element.ICE: [Element.FIRE, Element.WATER, Element.ICE, Element.STEEL],
	Element.STEEL: [Element.FIRE, Element.WATER, Element.STEEL],
	Element.GHOST: [Element.DARK],
	Element.FIGHTING: [Element.POISON, Element.BUG, Element.FAIRY],
	Element.FAIRY: [Element.FIRE, Element.POISON, Element.STEEL],
	Element.BUG: [Element.FIRE, Element.FIGHTING, Element.POISON, Element.GHOST, Element.STEEL, Element.FAIRY],
	Element.DARK: [Element.FIGHTING, Element.DARK, Element.FAIRY],
	Element.POISON: [Element.POISON, Element.GHOST],
}
# "Immunities" are softened to -50% (no absolute immunity in an action game).
const IMMUNE := {
	Element.NORMAL: [Element.GHOST],
	Element.GHOST: [Element.NORMAL],
	Element.FIGHTING: [Element.GHOST],
	Element.POISON: [Element.STEEL],
}

var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var base_speed := 260.0
var element: Element = Element.NORMAL   # primary (attack) type
var types: Array = []                   # all types (1 or 2) used when defending
var exhausted := false

# Statuses are frame counters (not Timer nodes) so they freeze during hitstop and
# stay deterministic. Fighter calls tick_statuses() once per un-frozen physics frame.
const FPS := 60
var burn_left := 0       # frames remaining
var burn_phase := 0      # frames since last tick
var poison_left := 0
var poison_phase := 0
var slow_left := 0

func _ready() -> void:
	hp = max_hp
	stamina = max_stamina
	if types.is_empty():
		types = [element]



func tick(delta: float) -> void:
	stamina = min(max_stamina, stamina + REGEN_PER_SEC * delta)
	if exhausted and stamina >= RECOVER_AT:
		exhausted = false

func can_spend(cost: float) -> bool:
	return not exhausted and stamina >= cost

func spend(cost: float) -> void:
	stamina = max(0.0, stamina - cost)
	if stamina <= 0.0:
		exhausted = true

func gain_stamina(amount: float) -> void:
	stamina = min(max_stamina, stamina + amount)

func tick_statuses() -> void:
	if burn_left > 0:
		burn_left -= 1
		burn_phase += 1
		if burn_phase >= FPS:
			burn_phase = 0
			burn_ticked.emit(BURN_DAMAGE)
	if poison_left > 0:
		poison_left -= 1
		poison_phase += 1
		if poison_phase >= FPS:
			poison_phase = 0
			poison_ticked.emit(POISON_DAMAGE)
	if slow_left > 0:
		slow_left -= 1

# ---- micro-statuses (durations are Timer nodes) ----
func apply_burn() -> void:
	burn_left = BURN_TICKS * FPS
	burn_phase = 0

func apply_poison() -> void:
	poison_left = POISON_TICKS * FPS
	poison_phase = 0

func apply_slow() -> void:
	slow_left = int(SLOW_TIME * FPS)

func burning() -> bool:
	return burn_left > 0

func poisoned() -> bool:
	return poison_left > 0

func slowed() -> bool:
	return slow_left > 0

func get_speed() -> float:
	return base_speed * (SLOW_FACTOR if slowed() else 1.0)

func clear_statuses() -> void:
	burn_left = 0
	burn_phase = 0
	poison_left = 0
	poison_phase = 0
	slow_left = 0

## Dual-type defenders: each defending type scores +1 (weak) / -1 (resists);
## the sum is flattened to x1.2 / x1.0 / x0.8, and any immunity becomes x0.5.
static func type_multiplier(attacker: int, defenders: Array) -> float:
	var score := 0
	var immune := false
	for t in defenders:
		if t in SUPER.get(attacker, []):
			score += 1
		elif t in RESIST.get(attacker, []):
			score -= 1
		elif t in IMMUNE.get(attacker, []):
			immune = true
	if immune:
		return 0.5
	if score > 0:
		return 1.2
	if score < 0:
		return 0.8
	return 1.0
