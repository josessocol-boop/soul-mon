class_name ScreenShake
extends Camera2D
## Camera shake. Strength decays linearly over the shake's duration (frames).

var amp := 0.0
var frames_left := 0
var total := 1

func shake(strength: float, frames: int) -> void:
    var current := amp * float(frames_left) / float(total) if frames_left > 0 else 0.0
    if strength >= current:
        amp = strength
        total = maxi(1, frames)
        frames_left = total

func _physics_process(_delta: float) -> void:
    if frames_left > 0:
        frames_left -= 1
        var k := float(frames_left) / float(total)
        offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp * k
    else:
        offset = Vector2.ZERO