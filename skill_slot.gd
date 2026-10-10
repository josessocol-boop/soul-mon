extends Control
## Compact square ability slot. Fills bottom-up as the ability recharges;
## lights up (bright border) when ready. Layout size comes from the container.

var title := "S1"
var ratio := 1.0
var text := ""
var lit := true
var accent := Color(0.4, 0.9, 0.6)

func set_state(p_ratio: float, p_text: String, p_lit: bool) -> void:
    ratio = p_ratio
    text = p_text
    lit = p_lit
    queue_redraw()

func _draw() -> void:
    var r := Rect2(Vector2.ZERO, size)
    draw_rect(r, Color(0.07, 0.08, 0.11, 0.9))
    var h := size.y * clampf(ratio, 0.0, 1.0)
    draw_rect(Rect2(0, size.y - h, size.x, h), Color(accent, 0.75 if lit else 0.3))
    draw_rect(r, accent if lit else Color(0.35, 0.37, 0.45), false, 2.0)
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(5, 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
    if text != "":
        draw_string(font, Vector2(0, size.y - 8), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color.WHITE)
