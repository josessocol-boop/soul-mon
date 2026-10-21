extends Fighter
## Fire-type melee bruiser: high HP, slow, heavy, big knockback.

func _apply_archetype() -> void:
    hp_max = 150.0
    move_speed = 215.0
    jump_velocity = -760.0
    gravity_mult = 1.3
    element = StatsComponent.Element.FIRE
    sheet_path = "res://assets/brawler_sheet.png"
    fx_path = "res://assets/fire_slash.png"
    base_color = Color(0.95, 0.35, 0.15)

func _define_moves() -> Dictionary:
    return {
        # Slow, wide-arc swing, high knockback. No cooldown.
        "basic": mv({"dmg": 11.0, "size": Vector2(80, 54), "off": Vector2(44, -6),
            "on": 7, "off_f": 12, "total": 26, "kb": Vector2(560, -300), "push": 60.0}),
        # Lunging strike: moves the body forward quickly through the active frames.
        "special1": mv({"dmg": 14.0, "size": Vector2(60, 44), "off": Vector2(40, -4),
            "on": 6, "off_f": 14, "total": 24, "kb": Vector2(620, -260),
            "lunge": 780.0, "cd": 3.0, "cost": 15.0}),
        # Anti-air uppercut: tall hitbox, small hop, launches upward.
        "special2": mv({"dmg": 16.0, "size": Vector2(56, 120), "off": Vector2(26, -38),
            "on": 5, "off_f": 13, "total": 30, "kb": Vector2(180, -760),
            "hop": -420.0, "cd": 5.0, "cost": 20.0}),
        # Ultimate: huge blast in front of the fighter.
        "ultimate": mv({"dmg": 35.0, "size": Vector2(170, 110), "off": Vector2(70, -10),
            "on": 10, "off_f": 18, "total": 40, "kb": Vector2(800, -450)}),
    }
