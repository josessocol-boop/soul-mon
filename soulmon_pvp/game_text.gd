extends RefCounted

const Keybinds := preload("res://keybinds.gd")
## Player-facing strings live here as constants. {action_name} placeholders are filled from the
## real input bindings (see Keybinds), so a hint can never disagree with the actual key.

const HELP_P1 := "P1 (left):   {p1_left} / {p1_right} move  -  {p1_jump} jump  -  {p1_attack} attack  -  {p1_dash} dash  -  {p1_special1} / {p1_special2} specials  -  {p1_ultimate} ultimate"
const HELP_P2 := "P2 (right):   {p2_left} / {p2_right} move  -  {p2_jump} jump  -  {p2_attack} attack  -  {p2_dash} dash  -  {p2_special1} / {p2_special2} specials  -  {p2_ultimate} ultimate"
const HELP_FOOTER := "{menu_toggle}: choose fighters        {restart_round}: restart round"
const WIN_BANNER := "{winner} WINS!  ({restart_round} to restart)"

const MODE_PVP := "MODE: PLAYER vs PLAYER"
const MODE_PVCPU := "MODE: PLAYER vs CPU   -   pick the CPU fighter with {p2_nav_left} / {p2_nav_right}"
const MODE_CPUVCPU := "MODE: CPU vs CPU   -   {p1_nav_left} / {p1_nav_right} and {p2_nav_left} / {p2_nav_right} pick the fighters"

static func mode_hint(mode: String) -> String:
	match mode:
		"pvcpu": return Keybinds.fmt(MODE_PVCPU)
		"cpuvcpu": return Keybinds.fmt(MODE_CPUVCPU)
		_: return MODE_PVP

static func controls_help() -> String:
	return Keybinds.fmt(HELP_P1 + "\n" + HELP_P2 + "\n" + HELP_FOOTER)

static func win_banner(winner_name: String) -> String:
	return Keybinds.fmt(WIN_BANNER).replace("{winner}", winner_name)
