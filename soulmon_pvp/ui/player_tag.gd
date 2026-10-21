extends Label
## Floating tag above a fighter, such as "P1 · GENGAR", so you can tell which player is which
## even when both fighters are the same Pokemon. It is a child of the fighter (freed with it, and
## removed with the match) but top-level, so it keeps its own orientation when the fighter turns.

var target: Node2D
const LIFT := 84.0    # pixels above the fighter feet (sprite top is about 52px up)

func setup(fighter: Node2D, text_: String, color: Color) -> void:
	target = fighter
	top_level = true
	text = text_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 15)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	add_theme_constant_override("outline_size", 5)

func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position + Vector2(-size.x * 0.5, -LIFT)
