extends CanvasLayer
## F2 key test. Shows which game actions the engine currently sees as pressed, plus a log of the last raw key
## events. If a key never shows up here while other keys are held, the KEYBOARD is not sending it (ghosting /
## limited rollover) - no game code can fix that, so use an alternate Down key (Ctrl or Shift for P1, Num 2 or
## Num Enter for P2), or tap Down just before / after the attack (a Down tap counts for a few frames).

const Keybinds := preload("res://system/keybinds.gd")
const GAME_ACTIONS := ["left", "right", "jump", "down", "attack", "dash", "special1", "special2", "ultimate"]
const LOG_LINES := 10

var _label: Label
var _log := PackedStringArray()

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.position = Vector2(20, 120)
	bg.size = Vector2(980, 380)
	add_child(bg)
	_label = Label.new()
	_label.position = Vector2(34, 130)
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or event.echo:
		return
	var key_event := event as InputEventKey
	var code: String = key_event.as_text_physical_keycode() if key_event.physical_keycode != 0 else key_event.as_text_keycode()
	_log.append(("PRESS    " if key_event.pressed else "release  ") + code)
	while _log.size() > LOG_LINES:
		_log.remove_at(0)

func _process(_delta: float) -> void:
	if not visible:
		return
	var t := "KEY TEST  (F2 closes)\n"
	t += "Hold a combo (e.g. W + S + Q). A key missing below is NOT reaching the game:\n"
	t += "that is the keyboard (ghosting), not the code. Alternate Down keys: Ctrl / Shift (P1), Num 2 / Num Enter (P2).\n"
	t += "Down also counts if you TAP it a few frames before or after the attack.\n\n"
	for p in ["p1", "p2"]:
		var held := PackedStringArray()
		for a in GAME_ACTIONS:
			var action: String = p + "_" + a
			if InputMap.has_action(action) and Input.is_action_pressed(action):
				held.append("%s[%s]" % [a, Keybinds.key_name(action)])
		t += "%s pressed: %s\n" % [p.to_upper(), ", ".join(held) if held.size() > 0 else "-"]
	t += "\nLast key events:\n" + "\n".join(_log)
	_label.text = t
