class_name Sfx
extends Node2D
## Tiny positional sound player. Streams are looked up by name in
## res://assets/audio/<name>.wav; missing files are silently skipped, so
## dropping in real audio is just replacing the files.

const DIR := "res://assets/audio/"
const POOL := 12

var cache := {}
var players: Array = []

func _ready() -> void:
    for i in POOL:
        var p := AudioStreamPlayer2D.new()
        p.bus = &"SFX"
        p.max_distance = 4000.0
        add_child(p)
        players.append(p)

var muted := false

func play(sound: String, pos: Vector2 = Vector2(640, 360), volume_db: float = 0.0, pitch: float = 1.0) -> void:
    if muted or sound == "":
        return
    if not cache.has(sound):
        var path := DIR + sound + ".wav"
        cache[sound] = load(path) if ResourceLoader.exists(path) else null
    var stream = cache[sound]
    if stream == null:
        return
    var chosen: AudioStreamPlayer2D = players[0]
    for p in players:
        if not p.playing:
            chosen = p
            break
    chosen.stream = stream
    chosen.global_position = pos
    chosen.volume_db = volume_db
    chosen.pitch_scale = pitch
    chosen.play()