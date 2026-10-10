class_name InputHandler
extends Node
## Separated from the Fighter so a NetworkManager can later feed remote input
## by setting `remote = true` and writing move_x / jump_held / buffer directly.

## Per-action buffer windows (frames). Attacks/specials get a wider window so
## cancel chains (basic -> special) and mashed follow-ups feel forgiving.
const BUFFER_WINDOWS := {"jump": 6, "dash": 6, "attack": 9, "special1": 9, "special2": 9, "ultimate": 9, "support": 6, "support_2": 6, "support_3": 6}

var prefix := "p1"
var remote := false
var enabled := true
## Set by the Fighter while a long move is playing: combat presses made during
## the move are held (not decayed) so they fire the instant the move ends.
var hold_buffers := false
const COMBAT_ACTIONS := ["attack", "special1", "special2", "ultimate"]
var move_x := 0.0
var jump_held := false
var buffer := {"jump": 0, "dash": 0, "attack": 0, "special1": 0, "special2": 0, "ultimate": 0, "support": 0, "support_2": 0, "support_3": 0}

func poll() -> void:
    if remote:
        return
    move_x = Input.get_axis(prefix + "_left", prefix + "_right")
    jump_held = Input.is_action_pressed(prefix + "_jump")
    for a in buffer.keys():
        if Input.is_action_just_pressed(prefix + "_" + a):
            buffer[a] = BUFFER_WINDOWS[a]
        elif hold_buffers and a in COMBAT_ACTIONS and buffer[a] > 0:
            pass  # keep the press alive until the current move's recovery ends
        else:
            buffer[a] = max(0, buffer[a] - 1)

func want(action: String) -> bool:
    return enabled and buffer[action] > 0

func consume(action: String) -> void:
    buffer[action] = 0

## Drop every buffered input (called when hit, so mashing during hitstun
## doesn't fire a surprise move the instant you recover).
func clear() -> void:
    for a in buffer.keys():
        buffer[a] = 0

static func register_actions() -> void:
    preload("res://keybinds.gd").register()   # all keys are defined in keybinds.gd
