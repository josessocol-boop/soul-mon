class_name ArenaCamera
extends Camera2D

## Tracks both fighters, adapts framing to their distance, and shakes on impact.

const ZOOM_MIN := 1.6
const ZOOM_MAX := 2.4
const ZOOM_DISTANCE := 1200.0
const ZOOM_SMOOTHING := 5.0
const POSITION_SMOOTHING := 7.0
const TRAUMA_DECAY := 1.4
const TRAUMA_SHAKE_MULT := 0.6
const MAX_TRAUMA := 1.0
const ARENA_RECT := Rect2(-40.0, -40.0, 1360.0, 800.0)

var amp := 0.0
var frames_left := 0
var total := 1
var trauma := 0.0
var target_p1: Node2D
var target_p2: Node2D

func set_targets(p1: Node2D, p2: Node2D) -> void:
	target_p1 = p1
	target_p2 = p2

func shake(strength: float, frames: int) -> void:
	var current := amp * float(frames_left) / float(total) if frames_left > 0 else 0.0
	if strength >= current:
		amp = strength
		total = maxi(1, frames)
		frames_left = total

func add_trauma(amount: float) -> void:
	trauma = minf(MAX_TRAUMA, trauma + amount)

func _physics_process(delta: float) -> void:
	trauma = move_toward(trauma, 0.0, delta * TRAUMA_DECAY)
	var timed_strength := 0.0
	if frames_left > 0:
		frames_left -= 1
		timed_strength = amp * float(frames_left) / float(total)
	var trauma_strength := pow(trauma, 2.0) * TRAUMA_SHAKE_MULT * 24.0
	var strength: float = maxf(timed_strength, trauma_strength)
	if strength > 0.0:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	else:
		offset = Vector2.ZERO

func _process(delta: float) -> void:
	if not is_instance_valid(target_p1) or not is_instance_valid(target_p2):
		return

	var p1_pos := target_p1.global_position
	var p2_pos := target_p2.global_position
	var midpoint := (p1_pos + p2_pos) * 0.5
	var distance := p1_pos.distance_to(p2_pos)
	var distance_ratio := clampf(distance / ZOOM_DISTANCE, 0.0, 1.0)
	# Close fighters use the larger zoom; distant fighters use the wider view.
	var target_zoom := lerpf(ZOOM_MAX, ZOOM_MIN, distance_ratio)
	var zoom_weight := 1.0 - exp(-ZOOM_SMOOTHING * delta)
	var zoom_value := lerpf(zoom.x, target_zoom, zoom_weight)
	zoom = Vector2(zoom_value, zoom_value)

	var position_weight := 1.0 - exp(-POSITION_SMOOTHING * delta)
	global_position = global_position.lerp(midpoint, position_weight)
	var visible_size := get_viewport_rect().size / zoom
	var min_x := ARENA_RECT.position.x + visible_size.x * 0.5
	var max_x := ARENA_RECT.end.x - visible_size.x * 0.5
	var min_y := ARENA_RECT.position.y + visible_size.y * 0.5
	var max_y := ARENA_RECT.end.y - visible_size.y * 0.5
	global_position.x = clampf(global_position.x, min_x, max_x)
	global_position.y = clampf(global_position.y, min_y, max_y)
