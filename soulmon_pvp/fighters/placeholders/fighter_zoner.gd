extends Fighter
## Water-type ranged fighter: fragile, fast, high jump, projectile + trap.

func _apply_archetype() -> void:
    hp_max = 85.0
    move_speed = 320.0
    jump_velocity = -880.0
    gravity_mult = 1.0
    element = StatsComponent.Element.WATER
    sheet_path = "res://assets/zoner_sheet.png"
    fx_path = "res://assets/water_splash.png"
    base_color = Color(0.25, 0.6, 1.0)

func _define_moves() -> Dictionary:
    return {
        # Fast, low-damage jab.
        "basic": mv({"dmg": 4.0, "size": Vector2(38, 28), "off": Vector2(30, -4),
            "on": 2, "off_f": 5, "total": 9, "kb": Vector2(180, -100)}),
        # Horizontal water bolt.
        "special1": mv({"kind": "projectile", "dmg": 7.0, "spawn": 6, "total": 16,
            "proj_speed": 560.0, "kb": Vector2(260, -140), "cd": 3.0, "cost": 10.0}),
        # Ground trap placed ahead; lasts 3 s, springs once on an enemy.
        "special2": mv({"kind": "trap", "dmg": 12.0, "spawn": 8, "total": 20,
            "kb": Vector2(150, -520), "cd": 5.0, "cost": 15.0}),
        # Tidal burst: big, high-damage hitbox.
        "ultimate": mv({"dmg": 28.0, "size": Vector2(220, 90), "off": Vector2(80, -6),
            "on": 8, "off_f": 18, "total": 34, "kb": Vector2(700, -300)}),
    }
