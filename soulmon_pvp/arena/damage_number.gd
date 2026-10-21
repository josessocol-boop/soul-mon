class_name DamageNumber
extends Label
## Floating damage popup. Gold for super-effective hits, muted for resisted hits.

static func spawn(parent: Node, info: Dictionary) -> void:
	if parent == null:
		return

	var label := DamageNumber.new()
	var mult: float = info.get("mult", 1.0)
	var damage: float = info.get("dmg", 0.0)
	var heavy: bool = info.get("heavy", false)
	var ko: bool = info.get("ko", false)
	var big := heavy or ko

	# Main damage value, with a short effectiveness marker.
	var suffix := "!" if mult > 1.0 else ""
	label.text = "%d%s" % [roundi(damage), suffix]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34 if ko else (28 if big else 20))
	label.add_theme_color_override("font_color", _damage_color(mult, ko))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.08, 1.0))
	label.add_theme_constant_override("outline_size", 6 if big else 4)
	label.z_index = 20
	label.position = info.get("pos", Vector2.ZERO) + Vector2(randf_range(-10.0, 10.0), -34.0)
	label.scale = Vector2(0.65, 0.65)
	parent.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - (58.0 if big else 44.0), 0.65)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_delay(0.12)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.35)
	if ko:
		tween.tween_property(label, "rotation", randf_range(-0.12, 0.12), 0.2)
	tween.finished.connect(label.queue_free)

static func _damage_color(mult: float, ko: bool) -> Color:
	if ko:
		return Color(1.0, 0.32, 0.22)
	if mult > 1.0:
		return Color(1.0, 0.84, 0.2)
	if mult < 1.0:
		return Color(0.68, 0.72, 0.82)
	return Color.WHITE