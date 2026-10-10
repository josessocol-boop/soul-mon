class_name SupportSystem
extends Node
## Manages Support Pokémon calls - assist attacks, buffs, and utility.

signal support_called(player_id: int, support_id: String)
signal support_ready(player_id: int, slot: int)
signal support_cooldown(player_id: int, slot: int, time: float)

const MAX_SUPPORTS := 3
const BASE_COOLDOWN := 20.0  # seconds

enum SupportType { ATTACK, BUFF, HEAL, UTILITY }

# Pre-defined support characters - accessed via static function to avoid parser issues
static func get_support_definition(support_id: String) -> Dictionary:
	match support_id:
		"pikachu":
			return {
				"name": "Pikachu",
				"type": SupportType.ATTACK,
				"icon": "res://assets/pikachu_icon.png",
				"cooldown": 18.0,
				"effect": {
					"kind": "projectile",
					"dmg": 12.0,
					"size": Vector2(32, 32),
					"off": Vector2(40, -8),
					"on": 2, "off_f": 6,
					"total": 20,
					"kb": Vector2(200, -100),
					"proj_speed": 800.0,
					"proj_tex": "res://assets/fx/proj_thunderbolt.png", "proj_frames": 4, "proj_scale": 2.0,
					"element": StatsComponent.Element.STEEL  # using STEEL for electric
				}
			}
		"eevee":
			return {
				"name": "Eevee",
				"type": SupportType.BUFF,
				"icon": "res://assets/eevee_icon.png",
				"cooldown": 25.0,
				"effect": {
					"buff_type": "damage",
					"multiplier": 1.3,
					"duration": 8.0
				}
			}
		"chansey":
			return {
				"name": "Chansey",
				"type": SupportType.HEAL,
				"icon": "res://assets/chansey_icon.png",
				"cooldown": 30.0,
				"effect": {
					"heal_amount": 30.0,
					"cure_status": true
				}
			}
		"ditto":
			return {
				"name": "Ditto",
				"type": SupportType.UTILITY,
				"icon": "res://assets/ditto_icon.png",
				"cooldown": 22.0,
				"effect": {
					"copy_move": true,
					"duration": 10.0
				}
			}
		"snorlax":
			return {
				"name": "Snorlax",
				"type": SupportType.ATTACK,
				"icon": "res://assets/snorlax_icon.png",
				"cooldown": 28.0,
				"effect": {
					"kind": "melee",
					"dmg": 25.0,
					"size": Vector2(120, 80),
					"off": Vector2(80, -20),
					"on": 4, "off_f": 10,
					"total": 30,
					"kb": Vector2(600, -300),
					"element": StatsComponent.Element.NORMAL
				}
			}
		"gardevoir":
			return {
				"name": "Gardevoir",
				"type": SupportType.UTILITY,
				"icon": "res://assets/gardevoir_icon.png",
				"cooldown": 24.0,
				"effect": {
					"reflect_projectiles": true,
					"duration": 6.0
				}
			}
	return {}

var player_id: int = 1
var selected_supports: Array = []  # Array of support IDs (max 3)
var cooldowns: Dictionary = {}
var active_effects: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in MAX_SUPPORTS:
		cooldowns[i] = 0.0

func set_player(pid: int) -> void:
	player_id = pid

func set_supports(support_ids: Array) -> void:
	selected_supports = support_ids.duplicate()
	for i in MAX_SUPPORTS:
		cooldowns[i] = 0.0
		if i < selected_supports.size() and selected_supports[i] != "":
			support_ready.emit(player_id, i)

func _process(delta: float) -> void:
	for i in MAX_SUPPORTS:
		if cooldowns[i] > 0.0:
			cooldowns[i] = max(0.0, cooldowns[i] - delta)
			if cooldowns[i] <= 0.0 and i < selected_supports.size() and selected_supports[i] != "":
				support_ready.emit(player_id, i)

	# Update active effects
	for effect in active_effects:
		effect.timer -= delta
		if effect.timer <= 0.0:
			_remove_effect(effect)

func try_call_support(slot: int) -> bool:
	if slot >= MAX_SUPPORTS or slot >= selected_supports.size():
		return false
	var support_id: String = selected_supports[slot]
	if support_id == "" or cooldowns[slot] > 0.0:
		return false

	var def: Dictionary = get_support_definition(support_id)
	if def.is_empty():
		return false

	cooldowns[slot] = def.cooldown
	support_cooldown.emit(player_id, slot, def.cooldown)
	support_called.emit(player_id, support_id)

	_apply_support_effect(def.effect)
	return true

func _apply_support_effect(effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "instant")
	match effect_type:
		"instant":
			_apply_instant_effect(effect)
		"duration":
			_apply_duration_effect(effect)

func _apply_instant_effect(effect: Dictionary) -> void:
	var kind: String = effect.get("kind", "")
	if kind == "projectile":
		# Spawn projectile - handled by arena_manager via signal
		pass
	elif kind == "melee":
		# Spawn melee hitbox - handled by arena_manager
		pass

func _apply_duration_effect(effect: Dictionary) -> void:
	var buff_type: String = effect.get("buff_type", "")
	if buff_type == "damage":
		active_effects.append({
			"type": "damage_buff",
			"multiplier": effect.multiplier,
			"timer": effect.duration
		})
	elif buff_type == "heal":
		# Heal handled instantly
		pass

func _remove_effect(effect: Dictionary) -> void:
	active_effects.erase(effect)

func get_damage_multiplier() -> float:
	var mult := 1.0
	for effect in active_effects:
		if effect.type == "damage_buff":
			mult *= effect.multiplier
	return mult

func get_cooldown_remaining(slot: int) -> float:
	return max(0.0, cooldowns.get(slot, 0.0))

func is_support_ready(slot: int) -> bool:
	return cooldowns.get(slot, 0.0) <= 0.0 and slot < selected_supports.size() and selected_supports[slot] != ""

func reset() -> void:
	for i in MAX_SUPPORTS:
		cooldowns[i] = 0.0
	active_effects.clear()