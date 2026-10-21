extends CanvasLayer
## Developer balance tool. Ctrl+Shift+B opens a password prompt; type the password and press Enter to open the panel.
## The left list picks the fighters on P1's side, the right list the fighters on P2's side. Every left fighter meets
## every right fighter once (a matchup listed twice is played once). Optional: mirrors (same fighter both sides),
## sides swapped (each matchup also plays P1 and P2 exchanged), matches per matchup (1-100), and the game-second
## limit that counts a match as a timeout. Matches run at real game speed. The tool never changes Engine.time_scale:
## scaling it scales the physics delta, which teleports fighters and breaks the numbers. Fights at once (1-64) run several
## matches side by side, each in its own copy of the arena, so a batch finishes sooner without changing any match.
## Show fights (on by default) draws the copies in a grid; turn it off to only simulate, which costs less per fight.
## The panel shows the measured speed (game seconds per real second).
## Results go to user://balance/: one CSV row per match, per-move counts and damage, one row per hit, HP once per
## game second, and one report per batch. The panel shows the report.
## Keys: R run, F9 hide or show the panel (matches keep running), Esc stop (while running) or close, Enter in the password box.
## Everything is also clickable.
## The password only keeps casual key presses from opening the tool. It is not security.

const MoveCheckScript := preload("res://ui/debug/move_check.gd")
const PASSWORD := "root"
const MAX_GAME_SECONDS := 90.0       # default limit: a match with no KO by then counts as a timeout
const MIN_LIMIT_SECONDS := 10.0
const MAX_LIMIT_SECONDS := 300.0
const MAX_REPEATS := 100
const SAMPLE_EVERY := 6              # physics frames between samples (10 per game second at 60 ticks)
const EARLY_SECONDS := 5.0           # the "early" column: damage taken in the first 5 game seconds
const OUT_DIR := "user://balance"
const DEFAULT_MATCH_SECONDS := 25.0  # used for the time estimate before any match has finished
const MAX_SLOTS := 64               # fights at once (the panel shows the real-time rate; use it to pick a number)
const SLOT_SIZE := Vector2i(1280, 720)  # every fight is drawn at the game's own size, then scaled into its grid cell

enum Mode { CLOSED, PASSWORD, PANEL, RUNNING }

var arena                          # ArenaManager: owns p1, p2 and _start_match()
var mode: int = Mode.CLOSED
var typed := ""
var repeats := 2                   # matches per matchup
var max_seconds := MAX_GAME_SECONDS  # game-second limit for the next run
var swap_sides := true            # also play each matchup with P1 and P2 exchanged
var results: Array = []
var status := ""
var report_text := ""
var _abort := false
var _order_flip := false          # alternates which fighter updates first, match by match
var _run_limit := MAX_GAME_SECONDS # the limit the current run uses (set when it starts)
var slot_count := 1               # fights at once
var _panel_hidden := false        # F9: the panel is hidden, the fights stay visible
var _dim: ColorRect
var _farm: Control                # the grid of fights (parallel runs only)
var _focus: Control               # the zoom view: one fight at full game size (click a tile)
var _focus_slot := -1
var _focus_scroll: ScrollContainer
var _focus_view: TextureRect
var _focus_title: Label
var _focus_zoom_idx := 0
var _focus_zoom_label: Label
var _grid: GridContainer
var _show_btn: Button
var _hide_btn: Button
var _slots_spin: SpinBox
var _show_check: CheckBox
var _show_fights := false        # draw the fight copies (off: simulate only, rendering is skipped)
## Zoom steps for the fight view (1.0 = the largest size that fits the window).
const ZOOM_STEPS := [1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0]   # 1.0 = the largest size that fits the window
# behaviour checks (the _behaviour.csv file): the arena's inner walls (core/fighter.gd) and two thresholds
const WALL_L := 24.0
const WALL_R := 1256.0
const CORNER_EDGE := 150.0        # within this of a wall counts as cornered
const THREAT_RANGE := 160.0       # an attack by the opponent this close can hit a fighter standing still
var _render_cursor: int = 0
var draws_per_frame := MAX_SLOTS  # tile draws per frame; MAX_SLOTS = every fight every frame
var _all_live := false            # every tile is set to draw every frame (see _process)
var _slots: Array = []            # [{vp: SubViewport, tex: TextureRect}]
var _jobs: Array = []             # [P1 id, P2 id] per match, in order
var _job_results: Array = []      # result per job, same order as _jobs
var _next_job := 0
var _done_jobs := 0
var _finished_workers := 0
var _wall_sum := 0.0
var _wall_n := 0
var _root: Control
var _pw_page: PanelContainer
var _pw_field: Label
var _pw_status: Label
var _main_page: PanelContainer
var _left: Array = []              # [CheckBox, roster id] for the P1 side
var _right: Array = []             # [CheckBox, roster id] for the P2 side
var _mirrors: CheckBox
var _swap: CheckBox
var _spin: SpinBox
var _limit_spin: SpinBox
var _estimate: Label
var _run_btn: Button
var _move_check_btn: Button
var _checking := false             # the move check is running (uses the Run/Stop state)
var _stop_btn: Button
var _close_btn: Button
var _status_label: Label
var _bar: ProgressBar
var _report: RichTextLabel
var _out_label: Label

func attach(arena_node) -> void:
	arena = arena_node
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Engine.time_scale = 1.0
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	_farm = Control.new()
	_farm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_farm.mouse_filter = Control.MOUSE_FILTER_STOP
	_farm.visible = false
	var farm_bg := ColorRect.new()
	farm_bg.color = Color(0.04, 0.04, 0.06, 1.0)
	farm_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	farm_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_farm.add_child(farm_bg)
	_grid = GridContainer.new()
	_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_farm.add_child(_grid)
	_root.add_child(_farm)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	_dim = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_pw_page = _build_password_page()
	center.add_child(_pw_page)
	_main_page = _build_main_page()
	center.add_child(_main_page)
	_show_btn = Button.new()
	_show_btn.text = "Show panel  (F9)"
	_show_btn.visible = false
	_show_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_show_btn.pressed.connect(_toggle_panel)
	_root.add_child(_show_btn)
	_build_focus()
	_refresh()

# ---------------------------------------------------------------- panels

func _build_password_page() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(460, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_title("Balance tool"))
	v.add_child(_hint("Type the password, then press Enter."))
	_pw_field = Label.new()
	_pw_field.add_theme_font_size_override("font_size", 30)
	v.add_child(_pw_field)
	_pw_status = _hint("")
	v.add_child(_pw_status)
	v.add_child(_hint("[Enter] unlock    [Backspace] delete    [Esc] cancel"))
	return p

func _build_main_page() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1160, 700)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)

	# left: setup
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	left.add_child(_title("Balance tool"))
	left.add_child(_hint("Every fighter on the left plays every fighter on the right. Untick to leave one out."))
	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 10)
	left.add_child(lists)
	_left = _build_side_list(lists, "P1 (left)")
	_right = _build_side_list(lists, "P2 (right)")
	_mirrors = CheckBox.new()
	_mirrors.text = "Include mirrors (same fighter both sides)"
	_mirrors.button_pressed = true
	_mirrors.toggled.connect(_on_pick_changed.unbind(1))
	left.add_child(_mirrors)
	_swap = CheckBox.new()
	_swap.text = "Also play with sides swapped"
	_swap.button_pressed = swap_sides
	_swap.toggled.connect(_on_swap_changed)
	left.add_child(_swap)
	var rrow := HBoxContainer.new()
	left.add_child(rrow)
	var rl := Label.new()
	rl.text = "Matches per matchup"
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rl)
	_spin = SpinBox.new()
	_spin.min_value = 1
	_spin.max_value = MAX_REPEATS
	_spin.step = 1
	_spin.value = repeats
	_spin.value_changed.connect(_on_repeats_changed)
	rrow.add_child(_spin)
	var lrow := HBoxContainer.new()
	left.add_child(lrow)
	var ll := Label.new()
	ll.text = "Max game seconds per match"
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow.add_child(ll)
	_limit_spin = SpinBox.new()
	_limit_spin.min_value = MIN_LIMIT_SECONDS
	_limit_spin.max_value = MAX_LIMIT_SECONDS
	_limit_spin.step = 5
	_limit_spin.value = max_seconds
	_limit_spin.value_changed.connect(_on_limit_changed)
	lrow.add_child(_limit_spin)
	var prow := HBoxContainer.new()
	left.add_child(prow)
	var pl := Label.new()
	pl.text = "Fights at once"
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(pl)
	_slots_spin = SpinBox.new()
	_slots_spin.min_value = 1
	_slots_spin.max_value = MAX_SLOTS
	_slots_spin.step = 1
	_slots_spin.value = slot_count
	_slots_spin.value_changed.connect(_on_slots_changed)
	prow.add_child(_slots_spin)
	_show_check = CheckBox.new()
	_show_check.text = "Show fights (off = simulate only)"
	_show_check.button_pressed = _show_fights
	_show_check.toggled.connect(_on_show_toggled)
	left.add_child(_show_check)
	var drow := HBoxContainer.new()
	left.add_child(drow)
	var dl := Label.new()
	dl.text = "Tile draws per frame (lower = faster matches)"
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(dl)
	var draws_spin := SpinBox.new()
	draws_spin.min_value = 1
	draws_spin.max_value = MAX_SLOTS
	draws_spin.step = 1
	draws_spin.value = draws_per_frame
	draws_spin.value_changed.connect(func(v: float): draws_per_frame = int(v))
	drow.add_child(draws_spin)
	_estimate = _hint("")
	left.add_child(_estimate)
	_run_btn = Button.new()
	_run_btn.text = "Run  (R)"
	_run_btn.pressed.connect(_run_pressed)
	left.add_child(_run_btn)
	_move_check_btn = Button.new()
	_move_check_btn.text = "Move check  (M)"
	_move_check_btn.pressed.connect(_move_check_pressed)
	left.add_child(_move_check_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "Stop  (Esc)"
	_stop_btn.pressed.connect(_stop_pressed)
	left.add_child(_stop_btn)
	_hide_btn = Button.new()
	_hide_btn.text = "Hide panel  (F9)"
	_hide_btn.pressed.connect(_toggle_panel)
	left.add_child(_hide_btn)
	_close_btn = Button.new()
	_close_btn.text = "Close  (Esc)"
	_close_btn.pressed.connect(_close)
	left.add_child(_close_btn)

	# right: progress and results
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	_status_label = Label.new()
	_status_label.text = "Ready."
	right.add_child(_status_label)
	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.show_percentage = true
	_bar.custom_minimum_size = Vector2(0, 24)
	right.add_child(_bar)
	_report = RichTextLabel.new()
	_report.bbcode_enabled = true
	_report.scroll_active = true
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report.custom_minimum_size = Vector2(790, 560)
	right.add_child(_report)
	_out_label = _hint("")
	right.add_child(_out_label)
	return p

## One side's list: a title, All / None, and a checkbox per roster fighter (all ticked to start).
func _build_side_list(parent: Control, title: String) -> Array:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(160, 0)
	parent.add_child(col)
	var lbl := Label.new()
	lbl.text = title
	col.add_child(lbl)
	var row := HBoxContainer.new()
	col.add_child(row)
	var all_btn := Button.new()
	all_btn.text = "All"
	row.add_child(all_btn)
	var none_btn := Button.new()
	none_btn.text = "None"
	row.add_child(none_btn)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(160, 250)
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var boxes: Array = []
	for e in Roster.entries():
		var cb := CheckBox.new()
		cb.text = String(e.name) if "name" in e and String(e.name) != "" else String(e.id).capitalize()
		cb.button_pressed = true
		cb.toggled.connect(_on_pick_changed.unbind(1))
		list.add_child(cb)
		boxes.append([cb, String(e.id)])
	all_btn.pressed.connect(_set_list.bind(boxes, true))
	none_btn.pressed.connect(_set_list.bind(boxes, false))
	return boxes

func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22)
	return l

func _hint(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.modulate = Color(1, 1, 1, 0.7)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _refresh() -> void:
	_root.visible = mode != Mode.CLOSED
	var on_panel := mode == Mode.PANEL or mode == Mode.RUNNING
	var hidden := _panel_hidden and on_panel
	_pw_page.visible = mode == Mode.PASSWORD
	_main_page.visible = on_panel and not hidden
	_dim.visible = not hidden
	_dim.color = Color(0.0, 0.0, 0.0, 0.45 if _farm.visible else 0.6)
	_show_btn.visible = hidden
	_farm.visible = _slots.size() > 0 and _show_fights
	if _focus_slot >= 0 and not _farm.visible:
		_close_focus()
	if mode == Mode.PASSWORD:
		_pw_field.text = "Password: " + "*".repeat(typed.length())
		_pw_status.text = status
	if mode == Mode.PANEL or mode == Mode.RUNNING:
		var running := mode == Mode.RUNNING
		_run_btn.disabled = running or _selected_pairs().is_empty()
		_move_check_btn.disabled = running or _picked(_left).is_empty()
		_stop_btn.disabled = not running
		_close_btn.disabled = running
		for pair in _left + _right:
			pair[0].disabled = running
		_mirrors.disabled = running
		_swap.disabled = running
		_spin.editable = not running
		_limit_spin.editable = not running
		_slots_spin.editable = not running
		_status_label.text = status
		if report_text != "":
			_report.text = "[code]" + report_text + "[/code]"
		elif not running:
			_report.text = "Results appear here after a run.\n\nEach matchup plays the chosen number of matches. A match ends at a KO or after %.0f game seconds." % max_seconds
		_out_label.text = "Output folder: " + ProjectSettings.globalize_path(OUT_DIR)
		_refresh_estimate()

func _refresh_estimate() -> void:
	var pairs := _selected_pairs()
	if pairs.is_empty():
		_estimate.text = "Pick at least one fighter on each side."
		return
	var count := pairs.size() * repeats
	var per_match := DEFAULT_MATCH_SECONDS
	if not results.is_empty():
		var sum := 0.0
		for r in results:
			sum += float(r["secs"])
		per_match = sum / float(results.size())
	var workers := clampi(slot_count, 1, maxi(1, count))
	var minutes := float(count) * per_match / float(workers) / 60.0
	_estimate.text = "%d matchups, %d matches. Estimate about %.0f min at real speed, %d at once." % [pairs.size(), count, minutes, workers]

# ---------------------------------------------------------------- picking

func _picked(boxes: Array) -> Array:
	var out: Array = []
	for pair in boxes:
		if pair[0].button_pressed:
			out.append(pair[1])
	return out

## The matchups for the current picks, as [P1 id, P2 id]. Each left fighter meets each right fighter once.
## A matchup that appears twice (both fighters ticked on both sides) plays once, with the left-list fighter as P1.
## With "sides swapped" each matchup also plays the other way round, so P1 bias cancels out.
func _selected_pairs() -> Array:
	var out: Array = []
	var seen := {}
	var lefts: Array = _picked(_left)
	var rights: Array = _picked(_right)
	for a in lefts:
		for b in rights:
			var sa: String = String(a)
			var sb: String = String(b)
			if sa == sb and not _mirrors.button_pressed:
				continue
			var key: String = (sa if sa <= sb else sb) + "|" + (sb if sa <= sb else sa)
			if seen.has(key):
				continue
			seen[key] = true
			out.append([sa, sb])
			if swap_sides and sa != sb:
				out.append([sb, sa])
	return out

func _set_list(boxes: Array, on: bool) -> void:
	for pair in boxes:
		pair[0].button_pressed = on
	_refresh()

func _on_pick_changed() -> void:
	_refresh()

func _on_repeats_changed(v: float) -> void:
	repeats = int(v)
	_refresh()

func _on_limit_changed(v: float) -> void:
	max_seconds = v
	_refresh()

func _on_swap_changed(on: bool) -> void:
	swap_sides = on
	_refresh()

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _focus_slot >= 0 and event is InputEventKey and event.pressed and not event.echo:
		var used := true
		match event.keycode:
			KEY_ESCAPE:
				_close_focus()
			KEY_EQUAL, KEY_KP_ADD:
				_zoom_focus(1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_focus(-1)
			KEY_0, KEY_KP_0:
				_fit_focus()
			_:
				used = false
		if used:
			get_viewport().set_input_as_handled()
			return
	if mode == Mode.CLOSED:
		if event.keycode == KEY_B and event.ctrl_pressed and event.shift_pressed:
			_open_password()
			get_viewport().set_input_as_handled()
		return
	match mode:
		Mode.PASSWORD:
			get_viewport().set_input_as_handled()
			_key_password(event)
		Mode.PANEL, Mode.RUNNING:
			if event.keycode == KEY_F9:
				get_viewport().set_input_as_handled()
				_toggle_panel()
			elif event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				if mode == Mode.RUNNING:
					_stop_pressed()
				else:
					_close()
			elif event.keycode == KEY_R and mode == Mode.PANEL:
				get_viewport().set_input_as_handled()
				_run_pressed()
			elif event.keycode == KEY_M and mode == Mode.PANEL:
				get_viewport().set_input_as_handled()
				_move_check_pressed()
			elif get_viewport().gui_get_focus_owner() == null:
				# keep arena keys (Tab, F5...) away while no control has focus; typing in the spin boxes still works
				get_viewport().set_input_as_handled()

func _key_password(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			_close()
			return
		KEY_ENTER, KEY_KP_ENTER:
			if typed == PASSWORD:
				typed = ""
				mode = Mode.PANEL
				status = "Ready."
			else:
				typed = ""
				status = "Wrong password."
		KEY_BACKSPACE:
			typed = typed.left(typed.length() - 1)
		_:
			if event.unicode > 0 and typed.length() < 24:
				typed += char(event.unicode)
	_refresh()

func _open_password() -> void:
	mode = Mode.PASSWORD
	typed = ""
	status = ""
	get_tree().paused = true
	_refresh()

func _close() -> void:
	mode = Mode.CLOSED
	_abort = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	_refresh()

func _stop_pressed() -> void:
	if mode == Mode.RUNNING:
		_abort = true
		status = "Stopping: the current match is discarded..."
		_refresh()

func _run_pressed() -> void:
	if mode != Mode.PANEL:
		return
	_run(_selected_pairs())

## Move check: every ticked fighter on the left performs each of its moves against a dummy (see ui/debug/move_check.gd).
## It restarts the arena match as it goes; the panel's Stop button ends it between tests.
func _move_check_pressed() -> void:
	if mode != Mode.PANEL or not is_instance_valid(arena):
		return
	var ids := _picked(_left)
	if ids.is_empty():
		status = "Tick at least one fighter on the left side first."
		_refresh()
		return
	mode = Mode.RUNNING
	_checking = true
	_abort = false
	report_text = ""
	status = "Move check starting..."
	get_tree().paused = false
	_refresh()
	var check = MoveCheckScript.new()
	var out: Dictionary = await check.run(arena, get_tree(), ids,
		func() -> bool: return _abort,
		func(text: String) -> void:
			status = text
			_refresh())
	get_tree().paused = true
	_checking = false
	mode = Mode.PANEL
	_abort = false
	report_text = "\n".join(out.lines)
	var where := _write_check_file(out.lines)
	status = ("Move check stopped early. " if out.stopped else "Move check finished. ") + "File: " + where
	print("[BalanceTool] ", status)
	_refresh()

func _write_check_file(lines: Array) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path := OUT_DIR + "/move_check_%d.txt" % Time.get_unix_time_from_system()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "(could not write file)"
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return ProjectSettings.globalize_path(path)

# ---------------------------------------------------------------- runs

## Plays every [P1 id, P2 id] pair `repeats` times, in order. cpu/ batch scripts call this directly.
func _run(pairs: Array) -> void:
	if mode == Mode.RUNNING or pairs.is_empty():
		return
	if not is_instance_valid(arena) and slot_count <= 1:
		return
	mode = Mode.RUNNING
	_abort = false
	_run_limit = max_seconds
	results = []
	report_text = ""
	_jobs = []
	for pr in pairs:
		for r in repeats:
			_jobs.append(pr)
	var total := _jobs.size()
	_job_results = []
	_job_results.resize(total)
	_next_job = 0
	_done_jobs = 0
	_finished_workers = 0
	_wall_sum = 0.0
	_wall_n = 0
	_bar.value = 0
	get_tree().paused = false
	var workers := clampi(slot_count, 1, total)
	var wall0 := Time.get_ticks_msec()
	var frames0 := Engine.get_physics_frames()
	_open_streams()
	var hosts: Array = [arena] if workers == 1 else _farm_open(workers)
	for h in hosts:
		_worker(h)
	while _finished_workers < hosts.size():
		_bar.value = 100.0 * float(_done_jobs) / float(total)
		status = _progress_text(total, workers, _rate(wall0, frames0)) + "   " + _perf_text()
		_refresh_live()
		await get_tree().process_frame
	_farm_close()
	_close_streams()
	results = []
	for x in _job_results:
		if x != null:
			results.append(x)
	_bar.value = 100.0 * float(results.size()) / float(total)
	get_tree().paused = true
	mode = Mode.PANEL
	_abort = false
	report_text = _build_report()
	var where := _write_files()
	status = "Finished %d of %d matches (%d at once). Files: %s" % [results.size(), total, workers, where]
	print("[BalanceTool] ", status)
	_refresh()

## One fight slot: takes jobs from the shared queue until none are left or the run is stopped.
func _worker(host) -> void:
	await _wait_host_ready(host)
	while not _abort and _next_job < _jobs.size():
		var j := _next_job
		_next_job += 1
		var pr: Array = _jobs[j]
		var t0 := Time.get_ticks_msec()
		var res: Dictionary = await _play(pr[0], pr[1], host, j + 1)
		if res.get("aborted", false):
			break
		var wall := float(Time.get_ticks_msec() - t0) / 1000.0
		res["wall_s"] = wall
		_wall_sum += wall
		_wall_n += 1
		_job_results[j] = res
		_done_jobs += 1
	_finished_workers += 1

## A farm copy starts its own setup a frame after it is added; wait for its HUD before the first fight.
func _wait_host_ready(host) -> void:
	var guard := 0
	while not is_instance_valid(host.hud) and guard < 600:
		await get_tree().process_frame
		guard += 1

## Where the frame time goes. If physics is most of the frame, the fights are CPU-bound on the main thread (physics and
## scripts for every fight); if the frame is much longer than physics, drawing is the cost.
func _perf_text() -> String:
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return "frame %.0f ms, physics %.0f ms" % [frame_ms, phys_ms]

func _progress_text(total: int, workers: int, rate: float) -> String:
	var txt := "%d of %d done   %d fight%s at once" % [_done_jobs, total, workers, "" if workers == 1 else "s"]
	if rate > 0.0:
		txt += "   running at %.2fx real time" % rate
	if _wall_n > 0:
		var eta := _wall_sum / float(_wall_n) * float(total - _done_jobs) / float(workers) / 60.0
		txt += "   ETA about %.0f min" % eta
	return txt

## Game seconds per real second since the run started (1.00x is real time). Shows whether the machine keeps up.
func _rate(wall0: int, frames0: int) -> float:
	var dw := float(Time.get_ticks_msec() - wall0) / 1000.0
	if dw < 1.0:
		return 0.0
	return float(Engine.get_physics_frames() - frames0) / float(Engine.physics_ticks_per_second) / dw

## Builds one fight copy per slot: a SubViewport at the game's own size with its own physics world,
## shown in a grid through a TextureRect. Returns the arena copies (their setup runs a frame later).
func _farm_open(n: int) -> Array:
	_farm_close()
	_grid.columns = int(ceil(sqrt(float(n))))
	_all_live = false
	var hosts: Array = []
	for i in n:
		var sv := SubViewport.new()
		# drawn at half resolution and stretched to the game size: a thumbnail needs no more, and a quarter of the pixels is
		# a large saving across many fights at once. The arena layout stays at the game's own size.
		sv.size_2d_override = SLOT_SIZE
		sv.size_2d_override_stretch = true
		sv.size = SLOT_SIZE / 2
		sv.disable_3d = true
		sv.render_target_update_mode = _render_mode()
		add_child(sv)
		var scene: Node = load("res://arena/main.tscn").instantiate()
		var mgr = scene.find_child("Arena_Manager", true, false)
		mgr.balance_slot = true
		sv.add_child(scene)
		var tile := Control.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(160, 90)
		tile.clip_contents = true
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.tooltip_text = "Click to zoom in on this fight"
		tile.gui_input.connect(_on_tile_input.bind(i))
		var tex_rect := TextureRect.new()
		tex_rect.texture = sv.get_texture()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tex_rect)
		var tag := Label.new()
		tag.position = Vector2(6, 4)
		tag.add_theme_font_size_override("font_size", 14)
		tag.add_theme_color_override("font_color", Color(1, 1, 1))
		tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		tag.add_theme_constant_override("shadow_offset_x", 1)
		tag.add_theme_constant_override("shadow_offset_y", 1)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tag)
		_grid.add_child(tile)
		_slots.append({"vp": sv, "tex": tex_rect, "tile": tile, "tag": tag, "title": "", "mgr": mgr})
		hosts.append(mgr)
	_farm.visible = _show_fights
	return hosts

## Fight copies are drawn only while "Show fights" is on. Off, their physics still runs (the matches are the same),
## but no frames are rendered, which is most of the cost of a fight on screen.
func _render_mode() -> int:
	# Viewports are never left on UPDATE_ALWAYS: _process() asks a few of them to draw each frame.
	return SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	if not _show_fights or _slots.is_empty():
		return
	var n := _slots.size()
	var live := draws_per_frame >= n
	if live != _all_live:
		_all_live = live
		for sl in _slots:
			sl["vp"].render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	if not live:
		# a slow machine: the tiles take turns, draws_per_frame of them each frame
		for i in draws_per_frame:
			var sl: Dictionary = _slots[_render_cursor % n]
			sl["vp"].render_target_update_mode = SubViewport.UPDATE_ONCE
			_render_cursor += 1
	if _focus_slot >= 0:
		_slots[_focus_slot]["vp"].render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _on_show_toggled(on: bool) -> void:
	_show_fights = on
	_all_live = false
	if not on:
		_close_focus()
	for sl in _slots:
		if is_instance_valid(sl["mgr"]):
			sl["mgr"].set_cosmetics(on)
		sl["vp"].render_target_update_mode = _render_mode()
	_refresh()

## Builds the zoom view: one fight at full game size with zoom controls. It is the top layer of the tool.
func _build_focus() -> void:
	_focus = Control.new()
	_focus.set_anchors_preset(Control.PRESET_FULL_RECT)
	_focus.mouse_filter = Control.MOUSE_FILTER_STOP
	_focus.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_focus.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12.0
	col.offset_top = 10.0
	col.offset_right = -12.0
	col.offset_bottom = -10.0
	col.add_theme_constant_override("separation", 6)
	_focus.add_child(col)
	var bar := HBoxContainer.new()
	col.add_child(bar)
	_focus_title = Label.new()
	_focus_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_focus_title.add_theme_font_size_override("font_size", 20)
	bar.add_child(_focus_title)
	var zoom_out := Button.new()
	zoom_out.text = "-  zoom out"
	zoom_out.pressed.connect(_zoom_focus.bind(-1))
	bar.add_child(zoom_out)
	_focus_zoom_label = Label.new()
	_focus_zoom_label.custom_minimum_size = Vector2(70, 0)
	_focus_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_focus_zoom_label)
	var zoom_in := Button.new()
	zoom_in.text = "+  zoom in"
	zoom_in.pressed.connect(_zoom_focus.bind(1))
	bar.add_child(zoom_in)
	var fit := Button.new()
	fit.text = "Fit"
	fit.pressed.connect(_fit_focus)
	bar.add_child(fit)
	var close := Button.new()
	close.text = "Close  (Esc)"
	close.pressed.connect(_close_focus)
	bar.add_child(close)
	col.add_child(_hint("Keys: + and - zoom, 0 fits the window, Esc closes. Ctrl + mouse wheel also zooms. Drag the scroll bars to look around."))
	_focus_scroll = ScrollContainer.new()
	_focus_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_focus_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_focus_scroll.gui_input.connect(_on_focus_input)
	_focus_scroll.resized.connect(_layout_focus)
	col.add_child(_focus_scroll)
	_focus_view = TextureRect.new()
	_focus_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_focus_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_focus_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_scroll.add_child(_focus_view)
	_root.add_child(_focus)

## A tile was clicked: zoom in on that fight.
func _on_tile_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_open_focus(i)

## Shows one fight at its full game size. Its copy draws every frame while it is open.
func _open_focus(i: int) -> void:
	if i < 0 or i >= _slots.size():
		return
	_close_focus()
	var sl: Dictionary = _slots[i]
	_focus_slot = i
	sl["vp"].size = SLOT_SIZE
	sl["vp"].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_focus_view.texture = sl["vp"].get_texture()
	_focus_title.text = String(sl["title"])
	_focus_zoom_idx = 0
	_focus.visible = true
	_layout_focus()

func _close_focus() -> void:
	if _focus_slot < 0:
		return
	if _focus_slot < _slots.size():
		_slots[_focus_slot]["vp"].size = SLOT_SIZE / 2
	_focus_slot = -1
	_focus_view.texture = null
	_focus.visible = false
	_all_live = false   # the tile draw policy is applied again next frame

func _zoom_focus(step: int) -> void:
	_focus_zoom_idx = clampi(_focus_zoom_idx + step, 0, ZOOM_STEPS.size() - 1)
	_layout_focus()

func _fit_focus() -> void:
	_focus_zoom_idx = 0
	_layout_focus()

## Sizes the fight so that "fit" fills the view, then multiplies by the zoom step. Bigger than the view = scroll bars.
func _layout_focus() -> void:
	if _focus_slot < 0 or _focus_scroll.size.x <= 0.0:
		return
	var area := _focus_scroll.size
	var fit := minf(area.x / float(SLOT_SIZE.x), area.y / float(SLOT_SIZE.y))
	var z: float = ZOOM_STEPS[_focus_zoom_idx]
	var sz := Vector2(SLOT_SIZE) * fit * z
	_focus_view.custom_minimum_size = sz
	_focus_view.size = sz
	_focus_zoom_label.text = "fit" if _focus_zoom_idx == 0 else "%.2fx" % z

func _on_focus_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_focus(1)
			_focus_scroll.accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_focus(-1)
			_focus_scroll.accept_event()

## Names the fight in its tile and in the zoom view.
func _tag_slot(host, a: String, b: String, mid: int) -> void:
	for sl in _slots:
		if sl["mgr"] == host:
			sl["title"] = "%s vs %s   (match %d)" % [a.capitalize(), b.capitalize(), mid]
			sl["tag"].text = "%s vs %s   #%d" % [a.capitalize(), b.capitalize(), mid]
			return

func _farm_close() -> void:
	_close_focus()
	for sl in _slots:
		sl["tile"].queue_free()
		sl["vp"].queue_free()
	_slots.clear()
	if is_instance_valid(_farm):
		_farm.visible = false

func _toggle_panel() -> void:
	_panel_hidden = not _panel_hidden
	_refresh()

func _on_slots_changed(v: float) -> void:
	slot_count = int(v)
	_refresh_estimate()

func _ai_of(f):
	for c in f.get_children():
		if c is AIController:
			return c
	return null

## One match, measured. Returns the outcome and per-side counters, or {"aborted": true} if stopped midway.
func _play(a: String, b: String, host, mid: int = 0) -> Dictionary:
	var wall_start := Time.get_ticks_msec()
	host.spawn_p2_first = _order_flip
	_tag_slot(host, a, b, mid)
	_order_flip = not _order_flip
	# a simulation-only copy skips its visuals; the real arena (not a copy) always shows them
	if host.has_method("set_cosmetics"):
		host.set_cosmetics(_show_fights or not host.balance_slot)
	host._start_match("cpu_" + a, "cpu_" + b)
	await get_tree().process_frame
	var p1 = host.p1
	var p2 = host.p2
	var tps := float(Engine.physics_ticks_per_second)
	var start := Engine.get_physics_frames()
	var st := {"done": false, "loser": "", "taken": {"p1": 0.0, "p2": 0.0},
		"quiet_max": 0.0, "last_start_t": 0.0, "last_total": 0, "hp_log": [], "hp_sec": -1,
		"events": [], "draw": false, "done_frame": -1, "awakens": {"p1": 0, "p2": 0},
		"a": a, "b": b, "p1": p1, "p2": p2, "start": start, "tps": tps}
	var side := {
		"p1": {"f": p1, "ai": _ai_of(p1), "last_x": p1.global_position.x, "last_dir": 0.0, "flips": 0, "idle": 0, "samples": 0},
		"p2": {"f": p2, "ai": _ai_of(p2), "last_x": p2.global_position.x, "last_dir": 0.0, "flips": 0, "idle": 0, "samples": 0},
	}
	st["side"] = side
	for k in ["p1", "p2"]:
		side[k]["serial"] = -1
		side[k]["label"] = ""
		side[k]["hit"] = false
		side[k]["moves"] = {}
		side[k]["corner"] = 0
		side[k]["still"] = 0
		side[k]["threat_idle"] = 0
		side[k]["hits"] = 0
		side[k]["dmg"] = 0.0
		side[k]["idle_hits"] = 0
		side[k]["idle_dmg"] = 0.0
		side[k]["walk_hits"] = 0
		side[k]["walk_dmg"] = 0.0
		side[k]["attacks"] = []
		side[k]["idle_melee"] = 0
		side[k]["idle_melee_visible"] = 0
		side[k]["idle_proj"] = 0
	p1.died.connect(_on_side_died.bind(st, "p1"))
	p2.died.connect(_on_side_died.bind(st, "p2"))
	p1.got_hit.connect(_on_side_hit.bind(st, "p1"))
	p2.got_hit.connect(_on_side_hit.bind(st, "p2"))
	p1.status_damaged.connect(_on_side_status.bind(st, "p1"))
	p2.status_damaged.connect(_on_side_status.bind(st, "p2"))
	p1.event.connect(_on_side_event.bind(st, "p1"))
	p2.event.connect(_on_side_event.bind(st, "p2"))

	var n := 0
	while not st.done and not _abort and (Engine.get_physics_frames() - start) / tps < _run_limit:
		await get_tree().physics_frame
		n += 1
		_track_moves(side)
		if n % SAMPLE_EVERY == 0:
			_sample(st, side, (Engine.get_physics_frames() - start) / tps)
			if n % (SAMPLE_EVERY * 10) == 0:
				_refresh_live()
	for k in ["p1", "p2"]:
		_finish_use(side[k])
	if _abort and not st.done:
		return {"aborted": true}
	var secs := (Engine.get_physics_frames() - start) / tps
	_stream_match(mid, st)
	var early_p1: float = _early_taken(st.events, "P1")
	var early_p2: float = _early_taken(st.events, "P2")

	var usage_a: Dictionary = _usage(side["p1"]["ai"])
	var usage_b: Dictionary = _usage(side["p2"]["ai"])
	var winner := ""
	var winner_side := ""
	if st.draw:
		winner_side = "DRAW"
	elif st.done:
		winner = b if st.loser == "p1" else a
		winner_side = "P2" if st.loser == "p1" else "P1"
	return {
		"a": a, "b": b, "winner": winner, "winner_side": winner_side,
		"p1_label": "P1 " + a, "p2_label": "P2 " + b,
		"timed_out": not st.done,
		"ko_s": secs if st.done else -1.0, "secs": secs, "limit_s": _run_limit,
		"taken_a": st.taken["p1"], "taken_b": st.taken["p2"],
		"usage_a": usage_a, "usage_b": usage_b,
		"flips_a": side["p1"]["flips"], "flips_b": side["p2"]["flips"],
		"idle_a": _share(side["p1"]), "idle_b": _share(side["p2"]),
		"quiet_s": st.quiet_max,
		"moves_a": side["p1"]["moves"], "moves_b": side["p2"]["moves"],
		"dealt_a": _dealt_by_move(st.events, "P1"), "dealt_b": _dealt_by_move(st.events, "P2"),
		"early_p1": early_p1, "early_p2": early_p2,
		"draw": bool(st.draw), "awakens_a": int(st.awakens.p1), "awakens_b": int(st.awakens.p2),
		"beh": {"p1": _beh(side["p1"]), "p2": _beh(side["p2"])},
	"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	"wall_s": float(Time.get_ticks_msec() - wall_start) / 1000.0,
	}

func _attacking(f) -> bool:
	var c := String(f.sm.current)
	return c == "attack" or c == "ultimate" or c.begins_with("special")

## Behaviour shares for one side: fractions of samples (corner, still, threat_idle) and hit counts.
func _beh(s: Dictionary) -> Dictionary:
	var n := float(maxi(1, s["samples"]))
	return {"corner": s["corner"] / n, "still": s["still"] / n, "threat_idle": s["threat_idle"] / n,
		"hits": s["hits"], "idle_hits": s["idle_hits"], "walk_hits": s["walk_hits"],
		"dmg": s["dmg"], "idle_dmg": s["idle_dmg"], "walk_dmg": s["walk_dmg"],
		"atk": _atk_counts(s["attacks"]),
		"idle_melee": s["idle_melee"], "idle_melee_visible": s["idle_melee_visible"], "idle_proj": s["idle_proj"]}

## Attacks this side started, split by the opponent's state at the start (idle / moving / busy) and by distance.
func _atk_counts(list: Array) -> Dictionary:
	var c := {"n": 0, "hit": 0, "idle_n": 0, "idle_hit": 0, "move_n": 0, "move_hit": 0, "busy_n": 0, "busy_hit": 0,
		"near_n": 0, "near_hit": 0, "mid_n": 0, "mid_hit": 0, "far_n": 0, "far_hit": 0}
	for a in list:
		var h := 1 if a["hit"] else 0
		c["n"] += 1
		c["hit"] += h
		var opp := String(a["opp"])
		var band := "busy"
		if opp == "idle":
			band = "idle"
		elif opp == "run" or opp == "jump" or opp == "dash":
			band = "move"
		c[band + "_n"] += 1
		c[band + "_hit"] += h
		var d := float(a["dist"])
		var reach := "far"
		if d < 90.0:
			reach = "near"
		elif d < 160.0:
			reach = "mid"
		c[reach + "_n"] += 1
		c[reach + "_hit"] += h
	return c

func _refresh_live() -> void:
	# keeps the panel responsive during a long match without redrawing every frame
	_status_label.text = status

func _usage(ai) -> Dictionary:
	return ai.usage.duplicate() if ai != null else {}

func _share(s: Dictionary) -> float:
	return float(s["idle"]) / float(maxi(1, s["samples"]))

func _sample(st: Dictionary, side: Dictionary, t: float) -> void:
	var total := 0
	for k in ["p1", "p2"]:
		var s: Dictionary = side[k]
		var ai = s["ai"]
		if ai == null:
			continue
		for v in ai.usage.values():
			total += int(v)
		# Count reversals of real horizontal motion (what the player sees), not the commanded direction.
		var x: float = s["f"].global_position.x
		var moved: float = x - float(s["last_x"])
		s["last_x"] = x
		var dir := 0.0
		if absf(moved) > 0.5:
			dir = signf(moved)
		if dir != 0.0:
			if s["last_dir"] != 0.0 and dir != s["last_dir"]:
				s["flips"] += 1
			s["last_dir"] = dir
		s["samples"] += 1
		if String(s["f"].sm.current) == "idle":
			s["idle"] += 1
		var cur := String(s["f"].sm.current)
		var opp = side["p2" if k == "p1" else "p1"]["f"]
		if x < WALL_L + CORNER_EDGE or x > WALL_R - CORNER_EDGE:
			s["corner"] += 1
		if (cur == "idle" or cur == "run") and absf(moved) < 0.5:
			s["still"] += 1
		if cur == "idle" and _attacking(opp) and s["f"].global_position.distance_to(opp.global_position) < THREAT_RANGE:
			s["threat_idle"] += 1
	var sec := int(t)
	if sec != int(st.hp_sec):
		st.hp_sec = sec
		st.hp_log.append([t, float(side["p1"]["f"].stats.hp), float(side["p2"]["f"].stats.hp)])
	if total > st.last_total:
		# at least one bot started a move since the last sample: the gap just ended counts as quiet time
		st.quiet_max = maxf(st.quiet_max, t - st.last_start_t)
		st.last_start_t = t
		st.last_total = total

## Per move, per fighter: [starts, hits, shot_hits, connects]. "connects" counts uses that hit at least once. "hits" is melee or trap contact, "shot_hits" is projectiles
## this move fired that hit something. The idle state before a fighter's first move has no key and is not counted.
func _track_moves(side: Dictionary) -> void:
	for k in ["p1", "p2"]:
		var s: Dictionary = side[k]
		var f = s["f"]
		if not is_instance_valid(f):
			continue
		var serial: int = int(f.move_serial)
		if serial != int(s["serial"]):
			_finish_use(s)
			s["serial"] = serial
			var label: String = String(f.cur_move.get("_label", String(f.cur_key) + ("_down" if bool(f.cur_down) else "")))
			s["label"] = label
			if label != "":
				# one record per attack: what the opponent was doing and how far away it was when the attack started
				var opp_f = side["p2" if k == "p1" else "p1"]["f"]
				s["attacks"].append({"label": label, "opp": String(opp_f.sm.current), "f": Engine.get_physics_frames(),
					"dist": f.global_position.distance_to(opp_f.global_position), "hit": false})
			s["hit"] = false
			s["use_hit"] = false
			if label != "":
				_bump(s["moves"], label, 0)
		if bool(f.landed_hit) and not bool(s["hit"]) and String(s["label"]) != "":
			s["hit"] = true
			s["use_hit"] = true
			_bump(s["moves"], String(s["label"]), 1)
			_mark_attack(s, String(s["label"]))
		# shots this fighter fired that hit something: credited to the move that fired them
		while f.shot_hit_keys.size() > 0:
			var sk: String = String(f.shot_hit_keys.pop_front())
			if sk != "":
				_bump(s["moves"], sk, 2)
				_mark_attack(s, sk)
				if sk == String(s["label"]):
					s["use_hit"] = true

## Marks the latest attack with this label as having connected.
func _mark_attack(s: Dictionary, label: String) -> void:
	var list: Array = s["attacks"]
	for i in range(list.size() - 1, -1, -1):
		if String(list[i]["label"]) == label:
			list[i]["hit"] = true
			return

## Counts the current use as connected if it hit at least once. Called when the use ends.
func _finish_use(s: Dictionary) -> void:
	if String(s.get("label", "")) != "" and bool(s.get("use_hit", false)):
		_bump(s["moves"], String(s["label"]), 3)
	s["use_hit"] = false

func _bump(moves: Dictionary, key: String, col: int) -> void:
	var rec: Array = moves.get(key, [0, 0, 0, 0])
	rec[col] = int(rec[col]) + 1
	moves[key] = rec

func _on_side_died(_f, st: Dictionary, who: String) -> void:
	var now := Engine.get_physics_frames()
	if st.done:
		# both fighters down on the same frame (or one frame apart): a draw, not a win for whoever died last
		if st.loser != who and now - int(st.done_frame) <= 1:
			st.draw = true
		return
	st.done = true
	st.loser = who
	st.done_frame = now

## Damage over time (burn, poison) on one side. It counts as damage taken and as an event, so a DOT kill has one.
func _on_side_status(info: Dictionary, st: Dictionary, who: String) -> void:
	var dmg := float(info.get("dmg", 0.0))
	st.taken[who] = float(st.taken[who]) + dmg
	var t := (Engine.get_physics_frames() - int(st.start)) / float(st.tps)
	var att = info.get("attacker")
	var by_p1: bool = att == st.p1
	st.events.append({
		"t": t,
		"attacker_side": ("P1" if by_p1 else "P2") if att != null else "",
		"attacker": (st.a if by_p1 else st.b) if att != null else "",
		"move": String(info.get("by", "")),
		"kind": "status",
		"victim_side": "P1" if who == "p1" else "P2",
		"victim": st.a if who == "p1" else st.b,
		"dmg": dmg,
		"hp": float(info.get("hp", 0.0)),
		"ko": bool(info.get("ko", false)),
	})

## The awakening (Mewtwo's transform). Logged as an ultimate use and as an event, so it shows in the counts.
func _on_side_event(kind: String, _pos: Vector2, st: Dictionary, who: String) -> void:
	if kind != "awaken":
		return
	st.awakens[who] = int(st.awakens[who]) + 1
	var t := (Engine.get_physics_frames() - int(st.start)) / float(st.tps)
	st.events.append({
		"t": t, "attacker_side": "P1" if who == "p1" else "P2",
		"attacker": st.a if who == "p1" else st.b, "move": "awaken", "kind": "transform",
		"victim_side": "", "victim": "", "dmg": 0.0, "hp": 0.0, "ko": false,
	})

## Every hit that lands on one side. `who` is the side that was hit; the attacker is the other side.
func _on_side_hit(info: Dictionary, st: Dictionary, who: String) -> void:
	var dmg := float(info.get("dmg", 0.0))
	st.taken[who] = float(st.taken[who]) + dmg
	var sd: Dictionary = st.side[who]
	var victim = st.p1 if who == "p1" else st.p2
	var vs := String(victim.sm.current)   # got_hit fires before the victim changes to hitstun, so this is what it was doing
	sd["hits"] += 1
	sd["dmg"] += dmg
	if vs == "idle":
		sd["idle_hits"] += 1
		sd["idle_dmg"] += dmg
		var kind := String(info.get("kind", ""))
		if kind == "melee":
			# how long the attack was on screen before it landed: 12 frames is 0.2 s, a clear warning
			sd["idle_melee"] += 1
			var att_list: Array = st.side["p2" if who == "p1" else "p1"]["attacks"]
			var started := -1
			for a in range(att_list.size() - 1, -1, -1):
				if String(att_list[a]["label"]) == String(info.get("by", "")):
					started = int(att_list[a]["f"])
					break
			if started >= 0 and Engine.get_physics_frames() - started >= 12:
				sd["idle_melee_visible"] += 1
		elif kind == "projectile":
			sd["idle_proj"] += 1
	elif vs == "run":
		sd["walk_hits"] += 1
		sd["walk_dmg"] += dmg
	var by_p1: bool = info.get("attacker") == st.p1
	var t := (Engine.get_physics_frames() - int(st.start)) / float(st.tps)
	st.events.append({
		"t": t,
		"attacker_side": "P1" if by_p1 else "P2",
		"attacker": st.a if by_p1 else st.b,
		"move": String(info.get("by", "")),
		"kind": String(info.get("kind", "")),
		"victim_side": "P1" if who == "p1" else "P2",
		"victim": st.a if who == "p1" else st.b,
		"dmg": dmg,
		"hp": float(info.get("hp", 0.0)),
		"ko": bool(info.get("ko", false)),
	})

## Damage each move of one side dealt in a match: move label -> total. Hits with no label (a counter) go to "other".
func _dealt_by_move(events: Array, attacker_side: String) -> Dictionary:
	var out := {}
	for e in events:
		if e["attacker_side"] != attacker_side:
			continue
		var k: String = e["move"] if e["move"] != "" else "other"
		out[k] = float(out.get(k, 0.0)) + float(e["dmg"])
	return out

## Damage one side took in the first EARLY_SECONDS of a match.
func _early_taken(events: Array, victim_side: String) -> float:
	var total := 0.0
	for e in events:
		if e["victim_side"] == victim_side and float(e["t"]) <= EARLY_SECONDS:
			total += float(e["dmg"])
	return total

# ---------------------------------------------------------------- reports

func _build_report() -> String:
	var per := {}   # id -> stats, from matches between two different fighters only
	var mirror := {"p1": 0, "p2": 0, "draw": 0}
	for r in results:
		if r["a"] == r["b"]:
			# mirrors only tell us about side bias: who won as P1 and who as P2
			if r["winner_side"] == "P1":
				mirror.p1 += 1
			elif r["winner_side"] == "P2":
				mirror.p2 += 1
			else:
				mirror.draw += 1
			continue
		_add_side(per, r["a"], r, true)
		_add_side(per, r["b"], r, false)
	var ids := per.keys()
	ids.sort()
	var lines := PackedStringArray()
	lines.append("%-10s %-11s %-6s %-6s %-7s %-7s %-7s %-6s %-7s %-8s %-7s %-6s %-4s" % [
		"fighter", "W-L-D", "win%", "KO s", "dealt", "taken", "early", "ults", "starts", "flips/s", "quiet s", "idle", "t/o"])
	for id in ids:
		var s: Dictionary = per[id]
		var m := float(maxi(1, s.matches))
		var decided: int = int(s.wins) + int(s.losses)
		var ko := float(s.ko_sum) / float(maxi(1, s.ko_count))
		var flips_per_s := float(s.flips) / maxf(0.001, float(s.secs))
		lines.append("%-10s %-11s %-6s %-6s %-7.0f %-7.0f %-7.0f %-6.1f %-7.1f %-8.2f %-7.1f %-6s %-4d" % [
			id, "%d-%d-%d" % [s.wins, s.losses, s.draws],
			("%.1f%%" % (100.0 * float(s.wins) / float(decided))) if decided > 0 else "-",
			"%.1f" % ko if s.ko_count > 0 else "-", s.dealt / m, s.taken / m, s.early / m,
			float(s.ults) / m, float(s.starts) / m, flips_per_s, s.quiet_sum / m,
			"%.0f%%" % (100.0 * s.idle_sum / m), s.timeouts])
	lines.append("")
	lines.append("Moves started per match:")
	for id in ids:
		var s: Dictionary = per[id]
		var mix := []
		for k in s.moves.keys():
			mix.append([k, float(s.moves[k]) / float(maxi(1, s.matches))])
		mix.sort_custom(func(x, y): return x[1] > y[1])
		var parts := PackedStringArray()
		for item in mix:
			parts.append("%s %.1f" % [item[0], item[1]])
		lines.append("  %-10s %s" % [id, ", ".join(parts)])
	lines.append("")
	lines.append("Damage dealt per match, by move:")
	for id in ids:
		var s: Dictionary = per[id]
		var m := float(maxi(1, s.matches))
		var dmix := []
		for k in s.dealt_moves.keys():
			dmix.append([k, float(s.dealt_moves[k]) / m])
		dmix.sort_custom(func(x, y): return x[1] > y[1])
		var dparts := PackedStringArray()
		for item in dmix:
			dparts.append("%s %.0f" % [item[0], item[1]])
		lines.append("  %-10s %s" % [id, ", ".join(dparts)])
	lines.append("")
	lines.append("Matches, in the order they ran (P1 is the left fighter, P2 the right):")
	for i in results.size():
		var r: Dictionary = results[i]
		var result := "KO at %.1fs" % float(r["ko_s"]) if not r["timed_out"] else "no KO (timed out)"
		var won := "winner: %s %s" % [r["winner_side"], r["winner"]] if r["winner"] != "" else ("draw (both down together)" if r["winner_side"] == "DRAW" else "no winner")
		lines.append("  #%-3d %-17s vs %-17s  %-30s %s" % [i + 1, r["p1_label"], r["p2_label"], won, result])
	lines.append("")
	lines.append("Mirrors (same fighter both sides, not in the table): P1 won %d, P2 won %d, draws %d." % [mirror.p1, mirror.p2, mirror.draw])
	lines.append("Update order alternates by match (P1 updates first in half of them), so this split should now be near 50%.")
	var mirror_total: int = int(mirror.p1) + int(mirror.p2)
	if mirror_total > 0:
		var p1_share := 100.0 * float(mirror.p1) / float(mirror_total)
		lines.append("P1 wins %.0f%% of decided mirrors. Far from 50%% means the sim favours one side. Sides are swapped in the table, which cancels it there." % p1_share)
	lines.append("")
	if results.size() > 0:
		var nodes_first := int(results[0].get("nodes", 0))
		var nodes_last := int(results[results.size() - 1].get("nodes", 0))
		var nodes_max := 0
		for r in results:
			nodes_max = maxi(nodes_max, int(r.get("nodes", 0)))
		lines.append("Scene nodes after a match: first %d, last %d, max %d (a steady run keeps these flat)." % [nodes_first, nodes_last, nodes_max])
	lines.append("How to read it: win% = wins / (wins + losses). Draws are not in it. KO s and dealt/taken show power and speed.")
	lines.append("W-L-D: wins, losses, draws. A draw is two fighters going down on the same frame (or one frame apart).")
	lines.append("early is damage taken in the first %.0f game seconds, per match. Damage by move counts each hit a move dealt; damage over time is listed under burn or poison." % EARLY_SECONDS)
	lines.append("ults counts ultimate uses and awakenings (Mewtwo's transform). starts counts moves started by the bot.")
	lines.append("flips/s counts direction reversals per second (high = back-and-forth).")
	lines.append("quiet s is the longest gap with no move started by either bot (high = standing still).")
	lines.append("t/o counts matches with no KO inside %.0f game seconds." % _run_limit)
	return "\n".join(lines)

func _add_side(per: Dictionary, id: String, r: Dictionary, is_a: bool) -> void:
	if not per.has(id):
		per[id] = {"matches": 0, "wins": 0, "losses": 0, "draws": 0, "dealt": 0.0, "taken": 0.0, "early": 0.0,
			"ko_sum": 0.0, "ko_count": 0, "ults": 0, "starts": 0, "flips": 0, "secs": 0.0, "quiet_sum": 0.0,
			"idle_sum": 0.0, "timeouts": 0, "moves": {}, "dealt_moves": {}}
	var s: Dictionary = per[id]
	var usage: Dictionary = r["usage_a"] if is_a else r["usage_b"]
	var taken: float = float(r["taken_a"]) if is_a else float(r["taken_b"])
	var dealt: float = float(r["taken_b"]) if is_a else float(r["taken_a"])
	var idle: float = float(r["idle_a"]) if is_a else float(r["idle_b"])
	var flips: int = int(r["flips_a"]) if is_a else int(r["flips_b"])
	var dealt_moves: Dictionary = r["dealt_a"] if is_a else r["dealt_b"]
	s.matches += 1
	if r["winner"] == id:
		s.wins += 1
	elif r["winner"] == "":
		s.draws += 1
	else:
		s.losses += 1
	s.dealt += dealt
	s.taken += taken
	s.early += float(r["early_p1"]) if is_a else float(r["early_p2"])
	if not r["timed_out"]:
		s.ko_sum += float(r["ko_s"])
		s.ko_count += 1
	else:
		s.timeouts += 1
	# ultimate uses plus awakenings (Mewtwo's transform never starts as a move, so it was missing before)
	s.ults += int(usage.get("ultimate", 0)) + int(r["awakens_a"] if is_a else r["awakens_b"])
	var starts := 0
	for k in usage.keys():
		starts += int(usage[k])
		s.moves[k] = int(s.moves.get(k, 0)) + int(usage[k])
	for k in dealt_moves.keys():
		s.dealt_moves[k] = float(s.dealt_moves.get(k, 0.0)) + float(dealt_moves[k])
	s.starts += starts
	s.flips += flips
	s.secs += float(r["secs"])
	s.quiet_sum += float(r["quiet_s"])
	s.idle_sum += idle

## Files of the current run. Event and HP rows are written as each match finishes, so memory does not grow with the batch.
var _ev_file: FileAccess
var _hp_file: FileAccess
var _run_base := ""

func _open_streams() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_run_base = "%s/balance_%s" % [OUT_DIR, str(int(Time.get_unix_time_from_system()))]
	_ev_file = FileAccess.open(_run_base + "_events.csv", FileAccess.WRITE)
	if _ev_file:
		_ev_file.store_line("match,p1,p2,t,attacker_side,attacker,move,kind,victim_side,victim,dmg,victim_hp_after,ko")
	_hp_file = FileAccess.open(_run_base + "_hp.csv", FileAccess.WRITE)
	if _hp_file:
		_hp_file.store_line("match,p1,p2,t,p1_hp,p2_hp")

func _close_streams() -> void:
	if _ev_file:
		_ev_file.close()
	if _hp_file:
		_hp_file.close()
	_ev_file = null
	_hp_file = null

## One match's event and HP rows, written now. `mid` is the job number (1-based), which matches the match number in matches.csv.
func _stream_match(mid: int, st: Dictionary) -> void:
	var p1_label := "P1 " + String(st.a)
	var p2_label := "P2 " + String(st.b)
	if _ev_file:
		for e in st.events:
			_ev_file.store_line("%d,%s,%s,%.2f,%s,%s,%s,%s,%s,%s,%.1f,%.1f,%s" % [
				mid, p1_label, p2_label, float(e["t"]), e["attacker_side"], e["attacker"],
				e["move"] if e["move"] != "" else "other", e["kind"], e["victim_side"], e["victim"],
				float(e["dmg"]), float(e["hp"]), str(e["ko"])])
	if _hp_file:
		for row in st.hp_log:
			_hp_file.store_line("%d,%s,%s,%.1f,%.1f,%.1f" % [mid, p1_label, p2_label, float(row[0]), float(row[1]), float(row[2])])

func _write_files() -> String:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var base := _run_base
	var f := FileAccess.open(base + "_matches.csv", FileAccess.WRITE)
	if f:
		f.store_line("p1,p2,winner_side,a,b,winner,timed_out,ko_s,secs,taken_a,taken_b,starts_a,starts_b,ults_a,ults_b,flips_a,flips_b,idle_a,idle_b,quiet_s,limit_s,awakens_a,awakens_b,nodes,objects,wall_s")
		for r in results:
			f.store_line("%s,%s,%s,%s,%s,%s,%s,%.1f,%.1f,%.0f,%.0f,%d,%d,%d,%d,%d,%d,%.2f,%.2f,%.1f,%.0f,%d,%d,%d,%d,%.1f" % [
				r["p1_label"], r["p2_label"], r["winner_side"], r["a"], r["b"], r["winner"], str(r["timed_out"]), float(r["ko_s"]), float(r["secs"]),
				float(r["taken_a"]), float(r["taken_b"]),
				_sum(r["usage_a"]), _sum(r["usage_b"]), int(r["usage_a"].get("ultimate", 0)), int(r["usage_b"].get("ultimate", 0)),
				int(r["flips_a"]), int(r["flips_b"]), float(r["idle_a"]), float(r["idle_b"]), float(r["quiet_s"]), float(r["limit_s"]), int(r["awakens_a"]), int(r["awakens_b"]), int(r["nodes"]), int(r["objects"]), float(r["wall_s"])])
		f.close()
	var mf := FileAccess.open(base + "_moves.csv", FileAccess.WRITE)
	if mf:
		mf.store_line("match,p1,p2,side,fighter,move,starts,hits,shot_hits,dmg,connects")
		for i in results.size():
			var r: Dictionary = results[i]
			for sd in [["P1", "a", "moves_a", "dealt_a"], ["P2", "b", "moves_b", "dealt_b"]]:
				var moves: Dictionary = r[sd[2]]
				var dealt: Dictionary = r[sd[3]]
				var keys: Array = moves.keys()
				for dk in dealt.keys():
					if not keys.has(dk):
						keys.append(dk)
				for mk in keys:
					var rec: Array = moves.get(mk, [0, 0, 0, 0])
					mf.store_line("%d,%s,%s,%s,%s,%s,%d,%d,%d,%.0f,%d" % [i + 1, r["p1_label"], r["p2_label"], sd[0], r[sd[1]], mk,
						int(rec[0]), int(rec[1]), int(rec[2]), float(dealt.get(mk, 0.0)), int(rec[3])])
		mf.close()
	var bf := FileAccess.open(base + "_behaviour.csv", FileAccess.WRITE)
	if bf:
		bf.store_line("match,p1,p2,side,fighter,corner_share,still_share,threat_idle_share,hits_taken,idle_hits_taken,walk_hits_taken,dmg_taken,idle_dmg_taken,walk_dmg_taken,attacks,attacks_hit,vs_idle_attacks,vs_idle_hit,vs_moving_attacks,vs_moving_hit,vs_busy_attacks,vs_busy_hit,near_attacks,near_hit,mid_attacks,mid_hit,far_attacks,far_hit,idle_melee_hits,idle_melee_visible_hits,idle_projectile_hits")
		for i in results.size():
			var r: Dictionary = results[i]
			for sd in [["P1", "a", "p1"], ["P2", "b", "p2"]]:
				var bh: Dictionary = r["beh"][sd[2]]
				var ac: Dictionary = bh.atk
				bf.store_line("%d,%s,%s,%s,%s,%.3f,%.3f,%.3f,%d,%d,%d,%.1f,%.1f,%.1f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [i + 1, r["p1_label"], r["p2_label"], sd[0], r[sd[1]],
					float(bh.corner), float(bh.still), float(bh.threat_idle),
					int(bh.hits), int(bh.idle_hits), int(bh.walk_hits), float(bh.dmg), float(bh.idle_dmg), float(bh.walk_dmg),
					int(ac.n), int(ac.hit), int(ac.idle_n), int(ac.idle_hit), int(ac.move_n), int(ac.move_hit), int(ac.busy_n), int(ac.busy_hit),
					int(ac.near_n), int(ac.near_hit), int(ac.mid_n), int(ac.mid_hit), int(ac.far_n), int(ac.far_hit),
					int(bh.idle_melee), int(bh.idle_melee_visible), int(bh.idle_proj)])
		bf.close()
	var rep := FileAccess.open(base + "_report.txt", FileAccess.WRITE)
	if rep:
		rep.store_string(report_text + "\n")
		rep.close()
	return ProjectSettings.globalize_path(OUT_DIR)

func _sum(usage: Dictionary) -> int:
	var t := 0
	for v in usage.values():
		t += int(v)
	return t
