extends RefCounted
## (No class_name on purpose: other scripts preload this file, so it works without an editor rescan.)
## The ONE place keys are defined. Change a key here and both the behaviour and every
## on-screen hint that mentions it (via GameText / Keybinds.fmt) change together.

const BINDINGS := {
	# Player 1 - gameplay
	"p1_left": KEY_A, "p1_right": KEY_D, "p1_jump": KEY_W,
	"p1_attack": KEY_F, "p1_dash": KEY_E,
	"p1_special1": KEY_G, "p1_special2": KEY_H, "p1_ultimate": KEY_T,
	"p1_down": KEY_S,  # fast-fall; hold (or tap) with attack/special 1/special 2 for the Down variant. No alternate keys: Ctrl and Shift are modifiers, and holding them pressed Down
	"p1_support": KEY_R, "p1_support_2": KEY_U, "p1_support_3": KEY_Y,
	# Player 1 - character select
	"p1_nav_up": KEY_W, "p1_nav_down": KEY_S, "p1_nav_left": KEY_A, "p1_nav_right": KEY_D,
	"p1_select": KEY_ENTER,
	# Player 2 - gameplay
	"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_jump": KEY_UP,
	"p2_attack": KEY_KP_4, "p2_dash": KEY_KP_0,
	"p2_special1": KEY_KP_5, "p2_special2": KEY_KP_6, "p2_ultimate": KEY_KP_8,
	"p2_down": KEY_DOWN,  # fast-fall / Down variant (P2: Arrow Down). Alternates: Num 2, Num Enter (EXTRA)
	"p2_support": KEY_KP_DIVIDE, "p2_support_2": KEY_KP_MULTIPLY, "p2_support_3": KEY_KP_SUBTRACT,   # was Num 0, which is also P2 dash
	# Player 2 - character select
	"p2_nav_up": KEY_KP_8, "p2_nav_down": KEY_KP_2, "p2_nav_left": KEY_KP_4, "p2_nav_right": KEY_KP_6,
	"p2_select": KEY_KP_ENTER,
	# Character select only: PLAYER / CPU switch per side and CPU level
	"p1_cpu_toggle": KEY_Q, "p2_cpu_toggle": KEY_KP_ADD, "cpu_level": KEY_C,
	# Match / menu
	"menu_toggle": KEY_TAB,      # open fighter select from the arena
	"restart_round": KEY_F5,     # restart the round (was Y, which clashed with p1_support_3)
	"debug_hitboxes": KEY_F1,    # toggle hitbox / hurtbox overlay
	"debug_keytest": KEY_F2,     # toggle the key test overlay (shows which keys the keyboard really sends)
}

## Extra keys for an action (each value is a LIST). P2 can navigate menus without a numpad. Player 1 has no extra
## Down key: Ctrl and Shift were alternates, but they are modifiers, so holding either one held Down (fast-fall and
## Down variants on every press).
const EXTRA := {
	"p2_nav_up": [KEY_UP], "p2_nav_down": [KEY_DOWN],
	"p2_nav_left": [KEY_LEFT], "p2_nav_right": [KEY_RIGHT],
	"p2_select": [KEY_SPACE],
	"p2_down": [KEY_KP_2, KEY_KP_ENTER],
}

static func register() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_add_key(action, BINDINGS[action])
			for extra_key in EXTRA.get(action, []):
				_add_key(action, extra_key)

static func _add_key(action: String, keycode: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	InputMap.action_add_event(action, e)

## Runtime rebind (e.g. from an options screen). Hints update the next time they are built.
static func rebind(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	_add_key(action, keycode)

## Short, readable name of the key an action is CURRENTLY bound to ("R", "Tab", "Num 4").
static func key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var t: String = ev.as_text_physical_keycode() if ev.physical_keycode != 0 else ev.as_text_keycode()
			return t.replace("Kp ", "Num ")
	return "?"

## Replaces every {action_name} in text with that action's current key.
static func fmt(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\{(\\w+)\\}")
	var out := text
	for m in rx.search_all(text):
		var action := m.get_string(1)
		if InputMap.has_action(action):
			out = out.replace(m.get_string(0), key_name(action))
	return out
