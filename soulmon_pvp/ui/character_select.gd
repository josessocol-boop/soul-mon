class_name CharacterSelect
extends CanvasLayer
## Fighter select screen, laid out like the Smash Bros select:
##   - a centred grid of fighter tiles, ROW_LENGTH per row; the grid scrolls once it is taller than GRID_HEIGHT
##   - one panel per side at the bottom: PLAYER / CPU switch, READY, big portrait, stats and moves
##   - the PLAYER / CPU switch and the CPU level are on this screen, so there is no separate mode menu.
##     The mode (PvP, PvCPU, CPU vs player, CPU vs CPU) comes from the two switches.
##   - modular: a fighter added to Roster.ENTRIES (roster/roster.gd) gets a tile, wraps into the grid and gets its bars and
##     moves from its own script. Nothing else on the screen has to change.
## Built in code; the .tscn only holds the root, the shade and the background.
## Used by ArenaManager: open_select(), roster, and the signals below.

signal start_requested(p1_id: String, p2_id: String)
signal cancel_requested
signal main_menu_requested
signal mode_changed(is_pvp: bool)

const Keybinds := preload("res://system/keybinds.gd")

# Layout. Tile, grid and panel sizes are fixed, so a sprite's size never changes the height of a tile or button.
const ROW_LENGTH := 5                        # tiles per row (8 fighters = 5 + 3, centred)
const TILE_SIZE := Vector2(180, 176)
const TILE_PORTRAIT := Vector2(128, 128)     # 2x the 64 px frame (whole-number scale keeps pixels crisp)
const TILE_NAME_HEIGHT := 30
const GRID_HEIGHT := 380.0                   # the grid scrolls when it has more rows than fit here
const CARD_PORTRAIT := Vector2(192, 192)     # 3x
const CARD_HEIGHT := 400.0
const CARD_MARGIN := 16
const P1_COLOR := Color(0.25, 0.6, 1.0)
const P2_COLOR := Color(0.95, 0.35, 0.25)
const GOLD := Color(1.0, 0.85, 0.2)
const DIM_BORDER := Color(0.3, 0.3, 0.36)
const READY_COLOR := Color(0.45, 1.0, 0.55)
const STAT_FLOOR := 0.15                     # the roster's weakest stat still shows a visible bar
const STAT_KEYS := ["hp", "speed", "jump"]
const STAT_LABELS := {"hp": "HP", "speed": "SPEED", "jump": "JUMP"}
const MOVE_KEYS := ["basic", "special1", "special2", "ultimate"]
const MOVE_TITLES := {"basic": "ATTACK", "special1": "SPECIAL 1", "special2": "SPECIAL 2", "ultimate": "ULTIMATE"}
const DIFFICULTIES := ["easy", "medium", "hard"]

# Roster and selection state
var roster: Array = []
var difficulty := "medium"
var p1_index := 0
var p2_index := 1
var p1_cpu := false                          # P1 is bot-controlled
var p2_cpu := true                           # P2 is bot-controlled (default: player vs CPU)
var p1_ready := false
var p2_ready := false
var returns_to_menu := false                 # opened from the main menu: BACK goes to the main menu, not to a match

# Built UI
var _root: Control
var _mode_label: Label
var _level_btn: Button
var _scroll: ScrollContainer
var _grid: VBoxContainer
var _hint_label: Label
var _start_btn: Button
var _tiles: Array[PanelContainer] = []
var _tile_styles: Array[StyleBoxFlat] = []
var _tile_badges: Array[Dictionary] = []     # per tile: {"p1": panel, "p2": panel, "p1_label": Label, "p2_label": Label}
var _cards := {}                             # 1 / 2 -> card controls (see _make_card)
var _info := {}                              # fighter id -> cached stats (see _fighter_info)
var _grid_key := ""                          # roster ids the grid was built for

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	InputHandler.register_actions()          # the keys used here are defined in keybinds.gd
	if roster.is_empty():
		_load_roster_from_arena()
	_build_ui()

func _load_roster_from_arena() -> void:
	roster = Roster.entries()

## p_mode is one of pvp / pvcpu (P2 is CPU) / cpuvp (P1 is CPU) / cpuvcpu. from_menu = opened from the main menu.
func open_select(fighters: Array, p1_idx: int, p2_idx: int, p_mode: String = "pvp", p_difficulty: String = "medium", from_menu: bool = false) -> void:
	roster = fighters
	p1_cpu = mode_is_cpu(p_mode, 1)
	p2_cpu = mode_is_cpu(p_mode, 2)
	difficulty = p_difficulty if DIFFICULTIES.has(p_difficulty) else "medium"
	returns_to_menu = from_menu
	var last := maxi(0, roster.size() - 1)
	p1_index = clampi(p1_idx, 0, last)
	p2_index = clampi(p2_idx, 0, last)
	p1_ready = false
	p2_ready = false

	_build_ui()
	_build_grid()
	_refresh_all()
	visible = true

# ---------------------------------------------------------------- mode helpers (static, shared with ArenaManager)

## Which side is bot-controlled in a mode name.
static func mode_is_cpu(mode: String, side: int) -> bool:
	match mode:
		"cpuvcpu":
			return true
		"cpuvp":
			return side == 1
		"pvcpu":
			return side == 2
	return false

## The mode name for the two CPU flags (the inverse of mode_is_cpu).
static func mode_name(p1_is_cpu: bool, p2_is_cpu: bool) -> String:
	if p1_is_cpu and p2_is_cpu:
		return "cpuvcpu"
	if p1_is_cpu:
		return "cpuvp"
	if p2_is_cpu:
		return "pvcpu"
	return "pvp"

# ---------------------------------------------------------------- layout

func _build_ui() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)

	# Top bar: BACK (to the main menu, or to the match when opened with Tab), title, mode, CPU level
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	v.add_child(top)
	var back := _button("BACK", 26, Vector2(200, 60))
	back.pressed.connect(_on_back)
	top.add_child(back)
	# Always goes to the main menu, even when the screen was opened in the middle of a match (where BACK returns to it)
	var to_menu := _button("MAIN MENU", 22, Vector2(230, 60))
	to_menu.pressed.connect(func() -> void: main_menu_requested.emit())
	top.add_child(to_menu)
	var title := _label("SELECT FIGHTERS", 40, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_mode_label = _label("", 26, Color(0.85, 0.85, 1.0))
	top.add_child(_mode_label)
	_level_btn = _button("", 24, Vector2(330, 60))
	_level_btn.pressed.connect(_cycle_level)
	top.add_child(_level_btn)

	# Fighter grid: rows of ROW_LENGTH tiles, centred, inside a scroll box of fixed height
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, GRID_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", 14)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	# Side panels, one per side
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 28)
	v.add_child(cards)
	_cards[1] = _make_card(1)
	_cards[2] = _make_card(2)
	cards.add_child(_cards[1].panel)
	cards.add_child(_cards[2].panel)

	# Bottom bar: controls hint and START
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	v.add_child(bottom)
	_hint_label = _label("", 18, Color(0.7, 0.72, 0.8))
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_hint_label)
	_start_btn = _button("START", 34, Vector2(300, 72))
	_start_btn.pressed.connect(_on_start)
	bottom.add_child(_start_btn)

func _build_grid() -> void:
	var key := ""
	for d in roster:
		key += String(d.get("id", "")) + ","
	if key == _grid_key:
		return
	_grid_key = key
	_clear(_grid)
	_tiles.clear()
	_tile_styles.clear()
	_tile_badges.clear()
	var row: HBoxContainer = null
	for i in roster.size():
		if i % ROW_LENGTH == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 14)
			_grid.add_child(row)
		_add_tile(i, row)

func _add_tile(i: int, row: HBoxContainer) -> void:
	var data: Dictionary = roster[i]
	var col: Color = data.get("color", Color(0.5, 0.5, 0.5))
	var style := _box(Color(0.06, 0.07, 0.1, 0.95), DIM_BORDER, 2)

	var tile := PanelContainer.new()
	tile.clip_contents = true
	tile.custom_minimum_size = TILE_SIZE
	tile.add_theme_stylebox_override("panel", style)
	tile.gui_input.connect(_on_tile_input.bind(i))
	row.add_child(tile)          # in the tree before the portrait below, so its timer can start

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)

	var art_bg := PanelContainer.new()
	art_bg.custom_minimum_size = TILE_PORTRAIT
	art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_bg.add_theme_stylebox_override("panel", _box(Color(col.r, col.g, col.b, 0.28), Color(0, 0, 0, 0), 0))
	v.add_child(art_bg)
	var portrait := AnimatedPortrait.new()
	portrait.custom_minimum_size = TILE_PORTRAIT
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_bg.add_child(portrait)
	portrait.set_fighter(data)

	var name_bar := PanelContainer.new()
	name_bar.custom_minimum_size = Vector2(0, TILE_NAME_HEIGHT)
	name_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_bar.add_theme_stylebox_override("panel", _pad(_box(col.darkened(0.35), Color(0, 0, 0, 0), 0, 0), 4, 3))
	v.add_child(name_bar)
	var name_lbl := _label(String(data.get("name", "?")).to_upper(), 18, Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_bar.add_child(name_lbl)

	# Cursor badges sit in the tile's top corners (P1 left, P2 right) and show only while a player is on it.
	var corners := MarginContainer.new()
	corners.set_anchors_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		corners.add_theme_constant_override("margin_" + side, 6)
	tile.add_child(corners)
	var badge_row := HBoxContainer.new()
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corners.add_child(badge_row)
	var b1 := _badge(P1_COLOR)
	badge_row.add_child(b1.panel)
	badge_row.add_child(_spacer())
	var b2 := _badge(P2_COLOR)
	badge_row.add_child(b2.panel)

	_tiles.append(tile)
	_tile_styles.append(style)
	_tile_badges.append({"p1": b1.panel, "p1_label": b1.label, "p2": b2.panel, "p2_label": b2.label})

func _badge(col: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _pad(_box(col, Color(0, 0, 0, 0), 0, 4), 6, 2))
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var lbl := _label("", 16, Color.WHITE)
	panel.add_child(lbl)
	return {"panel": panel, "label": lbl}

func _make_card(n: int) -> Dictionary:
	var accent := _side_color(n)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.09, 0.94), accent, 6, 6, true))

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, CARD_MARGIN)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	# Header: PLAYER / CPU switch, side title, READY stamp, READY button
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var toggle := _button("PLAYER", 20, Vector2(160, 44))
	toggle.pressed.connect(_toggle_side.bind(n))
	head.add_child(toggle)
	var title := _label("", 26, accent)
	head.add_child(title)
	head.add_child(_spacer())
	var stamp := _label("READY!", 30, READY_COLOR)
	stamp.visible = false
	head.add_child(stamp)
	var ready_btn := _button("READY", 22, Vector2(180, 44))
	ready_btn.pressed.connect(_on_p1_ready if n == 1 else _on_p2_ready)
	head.add_child(ready_btn)

	# Body: big portrait + name on the left, details on the right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var backdrop := PanelContainer.new()
	backdrop.custom_minimum_size = CARD_PORTRAIT
	left.add_child(backdrop)
	var portrait := AnimatedPortrait.new()
	portrait.custom_minimum_size = CARD_PORTRAIT
	backdrop.add_child(portrait)
	var fighter_name := _label("", 34, Color.WHITE)
	fighter_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(fighter_name)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var types := HBoxContainer.new()
	types.add_theme_constant_override("separation", 8)
	right.add_child(types)

	right.add_child(_label("STATS", 20, GOLD))
	var stat_bars := {}
	var stat_values := {}
	for k in STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		right.add_child(row)
		var key_lbl := _label(STAT_LABELS[k], 20, Color(0.85, 0.85, 0.9))
		key_lbl.custom_minimum_size = Vector2(110, 0)
		row.add_child(key_lbl)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 20)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var val_lbl := _label("", 20, Color.WHITE)
		val_lbl.custom_minimum_size = Vector2(110, 0)
		row.add_child(val_lbl)
		stat_bars[k] = bar
		stat_values[k] = val_lbl

	right.add_child(_label("MOVES", 20, GOLD))
	var moves := GridContainer.new()
	moves.columns = 3
	moves.add_theme_constant_override("h_separation", 22)
	moves.add_theme_constant_override("v_separation", 6)
	right.add_child(moves)

	return {"panel": panel, "toggle": toggle, "title": title, "stamp": stamp, "ready_btn": ready_btn,
		"portrait": portrait, "backdrop": backdrop, "fighter_name": fighter_name, "types": types,
		"stat_bars": stat_bars, "stat_values": stat_values, "moves": moves, "shown": ""}

# ---------------------------------------------------------------- refresh

func _refresh_all() -> void:
	if roster.is_empty() or _root == null:
		return
	_mode_label.text = _mode_text()
	_level_btn.text = "CPU LEVEL: " + difficulty.to_upper()
	_refresh_tiles()
	_refresh_card(1)
	_refresh_card(2)
	_refresh_start_button()
	_hint_label.text = Keybinds.fmt(
		"P1: {p1_nav_left}{p1_nav_right}{p1_nav_up}{p1_nav_down} move, {p1_select} ready, {p1_cpu_toggle} player / CPU   |   "
		+ "P2: arrows or {p2_nav_left}{p2_nav_right}{p2_nav_up}{p2_nav_down} move, {p2_select} ready, {p2_cpu_toggle} player / CPU   |   "
		+ "{cpu_level} CPU level   |   {menu_toggle} back\n"
		+ "Down move: hold {p1_down} (P1) or {p2_down} (P2) + attack or a special. A quick tap works too. Clicks: left = P1 cursor, right = P2 cursor.")

func _mode_text() -> String:
	return "%s VS %s" % ["CPU" if p1_cpu else "PLAYER", "CPU" if p2_cpu else "PLAYER"]

func _refresh_tiles() -> void:
	for i in _tiles.size():
		var p1_here := i == p1_index
		var p2_here := i == p2_index
		var st: StyleBoxFlat = _tile_styles[i]
		if p1_here and p2_here:
			st.border_color = GOLD
		elif p1_here:
			st.border_color = P1_COLOR
		elif p2_here:
			st.border_color = P2_COLOR
		else:
			st.border_color = DIM_BORDER
		st.set_border_width_all(4 if (p1_here or p2_here) else 2)
		_tiles[i].modulate = Color.WHITE if (p1_here or p2_here) else Color(0.78, 0.78, 0.84)
		var badges: Dictionary = _tile_badges[i]
		badges.p1_label.text = _side_tag(1)
		badges.p2_label.text = _side_tag(2)
		badges.p1.visible = p1_here
		badges.p2.visible = p2_here

func _refresh_card(n: int) -> void:
	var card: Dictionary = _cards[n]
	var idx := p1_index if n == 1 else p2_index
	var data: Dictionary = roster[idx]
	var info := _fighter_info(data)
	var col: Color = data.get("color", Color.WHITE)
	var cpu := _is_cpu_side(n)
	var accent := _side_color(n)

	var toggle: Button = card.toggle
	toggle.text = "CPU" if cpu else "PLAYER"
	var title: Label = card.title
	title.text = _side_title(n)
	title.add_theme_color_override("font_color", accent)
	var stamp: Label = card.stamp
	stamp.visible = _is_ready(n) and not cpu
	var ready_btn: Button = card.ready_btn
	ready_btn.visible = not cpu
	ready_btn.text = "WAITING..." if _is_ready(n) else "READY"
	ready_btn.disabled = _is_ready(n)

	# Animate the portrait whenever the cursor lands on a different fighter
	var portrait: AnimatedPortrait = card.portrait
	if card.shown != data.id:
		card.shown = data.id
		portrait.set_fighter(data)
		_punch(portrait)
	(card.backdrop as PanelContainer).add_theme_stylebox_override("panel", _box(Color(col.r, col.g, col.b, 0.3), Color(0, 0, 0, 0), 0))

	var fname: Label = card.fighter_name
	fname.text = String(data.get("name", "?")).to_upper()
	fname.add_theme_color_override("font_color", _readable(col))

	_fill_types(card.types, info.types)

	for k in STAT_KEYS:
		var bar: ProgressBar = card.stat_bars[k]
		var raw: float = float(info[k])
		bar.value = _stat_fill(k, raw)
		bar.add_theme_stylebox_override("fill", _box(_readable(col), Color(0, 0, 0, 0), 0, 3))
		bar.add_theme_stylebox_override("background", _box(Color(0.15, 0.16, 0.2), Color(0, 0, 0, 0), 0, 3))
		(card.stat_values[k] as Label).text = str(roundi(raw))

	_fill_moves(card.moves, info.moves)

func _refresh_start_button() -> void:
	var can_start := _can_start()
	_start_btn.disabled = not can_start
	_start_btn.text = "START" if can_start else "WAITING..."

func _fill_types(box: HBoxContainer, types: Array) -> void:
	_clear(box)
	var names: Array = StatsComponent.Element.keys()
	for t in types:
		var el := int(t)
		var col: Color = HitVfx.STYLE.get(el, {}).get("c", Color(0.6, 0.6, 0.6))
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _pad(_box(col, Color(0, 0, 0, 0), 0, 6), 9, 3))
		var text := String(names[el]).capitalize() if el >= 0 and el < names.size() else "?"
		var txt_col := Color(0.08, 0.08, 0.1) if col.get_luminance() > 0.5 else Color.WHITE
		chip.add_child(_label(text, 18, txt_col))
		box.add_child(chip)

func _fill_moves(grid: GridContainer, moves: Array) -> void:
	_clear(grid)
	for m in moves:
		grid.add_child(_label(MOVE_TITLES.get(m.key, String(m.key).to_upper()), 19, GOLD))
		var dmg_text := "%d DMG" % roundi(float(m.dmg))
		if int(m.hits) > 1:
			dmg_text += "  x%d" % int(m.hits)
		grid.add_child(_label(dmg_text, 19, Color.WHITE))
		grid.add_child(_label(_move_detail(m), 17, Color(0.72, 0.74, 0.82)))

func _move_detail(m: Dictionary) -> String:
	if m.key == "ultimate":
		return "needs full gauge or full stamina"
	var parts: Array[String] = []
	if float(m.cost) > 0.0:
		parts.append("%d stamina" % roundi(float(m.cost)))
	if float(m.cd) > 0.0:
		parts.append("%ss cooldown" % str(snappedf(float(m.cd), 0.1)))
	if parts.is_empty():
		return "no cost" if m.key != "basic" else "gains stamina on hit"
	return " - ".join(parts)

func _side_color(n: int) -> Color:
	return P1_COLOR if n == 1 else P2_COLOR

func _side_title(n: int) -> String:
	return ("CPU %d" if _is_cpu_side(n) else "PLAYER %d") % n

func _side_tag(n: int) -> String:
	return ("CPU %d" if _is_cpu_side(n) else "P%d") % n

func _is_cpu_side(n: int) -> bool:
	return p1_cpu if n == 1 else p2_cpu

## A CPU side is always ready; a player side is ready after its READY press.
func _is_ready(n: int) -> bool:
	return _is_cpu_side(n) or (p1_ready if n == 1 else p2_ready)

# ---------------------------------------------------------------- fighter data

## Fighters are only instantiated for display here (never added to the tree), so their _ready() --
## which normally applies the archetype -- never runs. Apply it by hand so hp/speed/types are real.
func _data_instance(data: Dictionary) -> Fighter:
	var scene = load(data.scene)
	if scene == null:
		return null
	var inst = scene.instantiate()
	if not (inst is Fighter):
		if inst:
			inst.free()
		return null
	inst._apply_archetype()
	if inst.types.is_empty():
		inst.types = [inst.element]
	return inst

## Stats and moves for one roster entry, read once from its fighter script and cached by id.
func _fighter_info(data: Dictionary) -> Dictionary:
	var id := String(data.get("id", ""))
	if _info.has(id):
		return _info[id]
	var info := {"types": [], "hp": 0.0, "speed": 0.0, "jump": 0.0, "moves": []}
	var inst := _data_instance(data)
	if inst != null:
		info.types = inst.get_types()
		info.hp = float(inst.hp_max)
		info.speed = float(inst.move_speed)
		info.jump = absf(float(inst.jump_velocity))
		var defs: Dictionary = inst._define_moves()
		var fallback: Dictionary = inst._define_moves_default()
		for key in MOVE_KEYS:
			var m: Dictionary = defs.get(key, fallback.get(key, {}))
			if m.is_empty():
				continue
			info.moves.append({"key": key, "dmg": float(m.get("dmg", 0.0)), "hits": _hit_count(m),
				"cost": float(m.get("cost", 0.0)), "cd": float(m.get("cd", 0.0))})
		inst.free()
	_info[id] = info
	return info

## Multi-hit moves: per-hit damage x number of hits, so the number reflects real damage.
func _hit_count(m: Dictionary) -> int:
	if int(m.get("hit_interval", 0)) > 0:
		return maxi(1, (int(m.get("off_f", 0)) - int(m.get("on", 0))) / int(m.hit_interval) + 1)
	if String(m.get("kind", "melee")) == "projectile":
		return maxi(1, int(m.get("spawn_count", 1)))
	return 1

## Bar fill for a stat, relative to the whole roster (weakest = STAT_FLOOR, strongest = full).
func _stat_fill(key: String, value: float) -> float:
	var lo := INF
	var hi := -INF
	for d in roster:
		var v := float(_fighter_info(d)[key])
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if hi <= lo:
		return 1.0
	return lerpf(STAT_FLOOR, 1.0, clampf((value - lo) / (hi - lo), 0.0, 1.0))

# ---------------------------------------------------------------- selection

func _on_p1_ready() -> void:
	if p1_cpu:
		return
	p1_ready = true
	_refresh_all()

func _on_p2_ready() -> void:
	if p2_cpu:
		return
	p2_ready = true
	_refresh_all()

## The PLAYER / CPU switch of one side. Changing it resets that side's READY.
func _toggle_side(n: int) -> void:
	if n == 1:
		p1_cpu = not p1_cpu
		p1_ready = false
	else:
		p2_cpu = not p2_cpu
		p2_ready = false
	mode_changed.emit(not (p1_cpu or p2_cpu))
	_refresh_all()

func _cycle_level() -> void:
	var i := DIFFICULTIES.find(difficulty)
	difficulty = DIFFICULTIES[(i + 1) % DIFFICULTIES.size()]
	if Settings:
		Settings.set_difficulty(difficulty)
	_refresh_all()

func _on_start() -> void:
	if roster.is_empty() or not _can_start():
		return
	var p1_id: String = roster[p1_index].id
	var p2_id: String = roster[p2_index].id
	if p1_cpu:
		p1_id = "cpu_" + p1_id
	if p2_cpu:
		p2_id = "cpu_" + p2_id

	# Save last selections
	if Settings:
		Settings.set_last_p1_fighter(roster[p1_index].id)
		Settings.set_last_p2_fighter(roster[p2_index].id)
		Settings.set_last_mode(mode_name(p1_cpu, p2_cpu))
		Settings.set_difficulty(difficulty)

	start_requested.emit(p1_id, p2_id)
	visible = false
	get_tree().paused = false

func _on_back() -> void:
	cancel_requested.emit()
	visible = false
	get_tree().paused = false

## Enter / Num Enter: ready this side. Once it is ready, the same key starts the match when it can begin.
func _select_pressed(n: int) -> void:
	if not _is_ready(n):
		if n == 1:
			_on_p1_ready()
		else:
			_on_p2_ready()
	elif _can_start():
		_on_start()

func _can_start() -> bool:
	return _is_ready(1) and _is_ready(2)

# ---------------------------------------------------------------- cursors

## Next roster index for a move. dy moves one row (ROW_LENGTH tiles); a short last row is clamped to its last tile.
func _step(index: int, dx: int, dy: int) -> int:
	var count := roster.size()
	if dy != 0:
		var target := index + dy * ROW_LENGTH
		if dy > 0 and target >= count and index / ROW_LENGTH < (count - 1) / ROW_LENGTH:
			target = count - 1
		if target < 0 or target >= count:
			return index
		return target
	return wrapi(index + dx, 0, count)

func _move_cursor(n: int, dx: int, dy: int) -> void:
	if n == 1:
		p1_index = _step(p1_index, dx, dy)
		p1_ready = false
		_scroll_to(p1_index)
	else:
		p2_index = _step(p2_index, dx, dy)
		p2_ready = false
		_scroll_to(p2_index)
	_refresh_all()

func _place_cursor(n: int, i: int) -> void:
	if i < 0 or i >= roster.size():
		return
	if n == 1:
		p1_index = i
		p1_ready = false
	else:
		p2_index = i
		p2_ready = false
	_scroll_to(i)
	_refresh_all()

func _scroll_to(i: int) -> void:
	if _scroll and i >= 0 and i < _tiles.size():
		_scroll.ensure_control_visible.call_deferred(_tiles[i])

func _on_tile_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_place_cursor(1, i)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_place_cursor(2, i)

func _input(event: InputEvent) -> void:
	if not visible or roster.is_empty():
		return
	# Checked first so the P2 keys below never swallow it
	if event.is_action_pressed("menu_toggle"):
		_on_back()
	elif event.is_action_pressed("cpu_level"):
		_cycle_level()
	elif event.is_action_pressed("p1_cpu_toggle"):
		_toggle_side(1)
	elif event.is_action_pressed("p2_cpu_toggle"):
		_toggle_side(2)
	elif event.is_action_pressed("p1_select"):
		_select_pressed(1)
	elif event.is_action_pressed("p2_select"):
		_select_pressed(2)
	elif event.is_action_pressed("p1_nav_left"):
		_move_cursor(1, -1, 0)
	elif event.is_action_pressed("p1_nav_right"):
		_move_cursor(1, 1, 0)
	elif event.is_action_pressed("p1_nav_up"):
		_move_cursor(1, 0, -1)
	elif event.is_action_pressed("p1_nav_down"):
		_move_cursor(1, 0, 1)
	elif event.is_action_pressed("p2_nav_left"):
		_move_cursor(2, -1, 0)
	elif event.is_action_pressed("p2_nav_right"):
		_move_cursor(2, 1, 0)
	elif event.is_action_pressed("p2_nav_up"):
		_move_cursor(2, 0, -1)
	elif event.is_action_pressed("p2_nav_down"):
		_move_cursor(2, 0, 1)
	else:
		return
	get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- small helpers

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, font_size: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # Enter must only mean "ready", never press a focused button
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = min_size
	return b

## Fighter colours can be near-black (Marshadow), so anything drawn in them is lifted toward white first.
func _readable(col: Color) -> Color:
	return col.lerp(Color.WHITE, 0.35)

## Inner padding for a flat box (chips, badges, name bars), so text does not touch the edge.
func _pad(sb: StyleBoxFlat, h: int, v: int) -> StyleBoxFlat:
	sb.content_margin_left = h
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v
	return sb

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _box(bg: Color, border: Color, width: int = 0, radius: int = 6, top_only: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	if top_only:
		sb.border_width_top = width
	else:
		sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb

func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

## Quick scale pop when the shown fighter changes, so the new choice is obvious.
func _punch(c: Control) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.16).from(Vector2(1.06, 1.06)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
