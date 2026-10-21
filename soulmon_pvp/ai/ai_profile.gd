class_name AIProfile
extends Resource
## Data-driven AI configuration per fighter. Loaded from fighters/<fighter_id>/profile.tres (see roster/roster.gd)

## Personality archetype: aggressive, defensive, zoning, balanced, hit_and_run, tricky
@export var personality: String = "balanced"

## Preferred engagement range: close, mid, far
@export var preferred_range: String = "mid"

## Base aggressiveness (0.0 - 1.0), scaled by difficulty
@export var aggressiveness: float = 0.6

## Bonus/penalty added to difficulty reaction_time (seconds)
@export var reaction_bonus: float = 0.0

## Combo chains: [{"trigger": "basic", "followup": "special1", "window": 8}, ...]
## When 'trigger' move connects (hit_confirmed), queue 'followup' for 'window' physics frames
@export var combo_chains: Array = []

## Move key to use as anti-air when opponent jumps in
@export var anti_air_move: String = ""

## Move key to use for whiff punish when opponent misses
@export var punish_move: String = ""

## Response to zoning/projectiles: approach, jump, dash, reflect
@export var zoning_response: String = "approach"

## Meter management: spend (no saving), save_for_ultimate (specials and dashes only from a full stamina bar),
## adaptive (saves like save_for_ultimate until the opponent is below half HP)
@export var meter_management: String = "spend"