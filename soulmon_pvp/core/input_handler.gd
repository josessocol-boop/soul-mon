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
## Set by the Fighter during hitstop: NO buffer decays, but new presses are still recorded.
var hold_all := false
## Set by the Fighter during a dash so combat presses survive until the dash can be cancelled.
const COMBAT_ACTIONS := ["attack", "special1", "special2", "ultimate"]
## Tapping Down (S) counts as holding it for this many frames after the press, so the Down move does not need
## S + attack (+ W ...) held together: tap S then press the button, or the button then S. Keyboards that cannot
## send three keys at once (ghosting) are the usual reason a held combo does nothing.
const DOWN_LATCH_FRAMES := 8
var move_x := 0.0
## Down (S) is held: fast-fall, and the "directional" variant of whatever move is pressed with it.
var down_held := false
## Frames left in which a Down TAP still counts as "Down held" for a button pressed next to it (see DOWN_LATCH_FRAMES).
var down_latch := 0
## Per action: was Down held at the moment that action was pressed? (so S+attack picks the down variant)
var down_at := {}
var jump_held := false
## Presses seen by _input() since the last poll(): a key that goes down AND up between two physics ticks (a very
## fast tap, or a busy frame) is still counted. Polling is_action_just_pressed() alone can miss those.
var _pending := {}
var buffer := {"jump": 0, "dash": 0, "attack": 0, "special1": 0, "special2": 0, "ultimate": 0, "support": 0, "support_2": 0, "support_3": 0}

## Records every key-down the moment the engine delivers it (before the next physics tick).
func _input(event: InputEvent) -> void:
    if remote or not (event is InputEventKey) or event.echo or not event.pressed:
        return
    if event.is_action_pressed(prefix + "_down"):
        down_latch = DOWN_LATCH_FRAMES
    for a in buffer.keys():
        if event.is_action_pressed(prefix + "_" + a):
            _pending[a] = true

func poll() -> void:
    if remote:
        return
    move_x = Input.get_axis(prefix + "_left", prefix + "_right")
    jump_held = Input.is_action_pressed(prefix + "_jump")
    down_held = Input.is_action_pressed(prefix + "_down")
    if down_held:
        down_latch = DOWN_LATCH_FRAMES
    elif not hold_all and down_latch > 0:
        down_latch -= 1
    var down_now := down_held or down_latch > 0
    for a in buffer.keys():
        if _pending.has(a) or Input.is_action_just_pressed(prefix + "_" + a):
            buffer[a] = BUFFER_WINDOWS[a]
            down_at[a] = down_now
        elif hold_all and buffer[a] > 0:
            pass  # hitstop: freeze the countdown so presses made during the freeze survive it
        elif hold_buffers and a in COMBAT_ACTIONS and buffer[a] > 0:
            pass  # keep the press alive until the current move's recovery ends
        else:
            buffer[a] = max(0, buffer[a] - 1)
    _pending.clear()

## Buffer countdown for remote (AI) input. Same hold rules as poll(): nothing decays during hitstop, and combat
## presses are held through a long move, so a bot's press survives recovery the way a player's does.
func decay_buffers() -> void:
    for a in buffer.keys():
        if hold_all and buffer[a] > 0:
            continue
        if hold_buffers and a in COMBAT_ACTIONS and buffer[a] > 0:
            continue
        buffer[a] = max(0, buffer[a] - 1)

func want(action: String) -> bool:
    return enabled and buffer[action] > 0

## True only if the press is at most `frames` old (used where a stale buffered press must not count, e.g. tech).
func fresh(action: String, frames: int) -> bool:
    return enabled and buffer[action] >= BUFFER_WINDOWS[action] - frames + 1

## True if the buffered press of `action` was made while Down was held (directional variant), OR Down is
## held right now while that press is still buffered (so tapping Down a moment after the button still counts).
func wants_down(action: String) -> bool:
    return bool(down_at.get(action, false)) or (not remote and (down_held or down_latch > 0) and int(buffer.get(action, 0)) > 0)

func consume(action: String) -> void:
    buffer[action] = 0

## Drop every buffered input (called when hit, so mashing during hitstun
## doesn't fire a surprise move the instant you recover).
func clear() -> void:
    for a in buffer.keys():
        buffer[a] = 0

static func register_actions() -> void:
    preload("res://system/keybinds.gd").register()   # all keys are defined in keybinds.gd
