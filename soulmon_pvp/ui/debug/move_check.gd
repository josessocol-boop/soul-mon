class_name MoveCheck
extends RefCounted
## Move check for the Ctrl+Shift+B panel ("Move check" button, or M).
## Each chosen fighter (P1, no AI) performs each of its moves at four distances against a still dummy (P2).
## Per test it reports: whether the move started, hits and damage, what it spawned (projectiles, traps),
## the status and flags it applied, and how far the gap closed. Summary lists moves that never start and
## moves with no visible effect at any distance.
## Keep the logic in step with scratchpad/chk/move_test.gd (the headless version of the same test).

const DISTANCES := [60.0, 100.0, 150.0, 260.0]
const SETTLE_FRAMES := 120       # wait this long at most for both fighters to land
const TEST_FRAMES := 150         # frames watched per test
const STAND_X := 380.0
const STAND_Y := 580.0

## Runs the check. `arena` is the ArenaManager (owns p1, p2, _start_match). `tree` drives the frames.
## `should_stop` returns true when the player pressed Stop. `on_progress` gets a status string.
## Returns { "rows": Array of Dictionary, "lines": Array of String (the report), "stopped": bool }.
func run(arena, tree: SceneTree, ids: Array, should_stop: Callable, on_progress: Callable) -> Dictionary:
	var rows: Array = []
	var stopped := false
	var tests: Array = []                       # [fighter id, move key] pairs, in order
	for id in ids:
		for key in _move_keys(tree, id):
			tests.append([id, key])
	var total := tests.size() * DISTANCES.size()
	var done := 0
	for pair in tests:
		var id: String = pair[0]
		var key: String = pair[1]
		for dx in DISTANCES:
			if should_stop.call():
				stopped = true
				break
			on_progress.call("Move check %d / %d  (%s %s, %d px)" % [done + 1, total, id, key, int(dx)])
			var r: Dictionary = await _test(arena, tree, id, key, dx)
			rows.append(r)
			done += 1
		if stopped:
			break
	return {"rows": rows, "lines": _report_lines(rows), "stopped": stopped}

# ---------------------------------------------------------------- one test

func _test(arena, tree: SceneTree, a_id: String, key: String, dx: float) -> Dictionary:
	var base: String = key.replace("_down", "")
	var down: bool = key.ends_with("_down")
	arena._start_match(a_id, "marshadow" if a_id != "marshadow" else "gholdengo")
	await tree.physics_frame
	await tree.physics_frame
	var a: Fighter = arena.p1
	var b: Fighter = arena.p2
	a.position = Vector2(STAND_X, STAND_Y)
	b.position = Vector2(STAND_X + dx, STAND_Y)
	# a basic started in the air is the aerial dive, not the ground move: wait until both are on the floor
	var settle := 0
	while settle < SETTLE_FRAMES and not (a.is_on_floor() and b.is_on_floor()):
		await tree.physics_frame
		settle += 1
	for _i in 4:
		await tree.physics_frame
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO
	var hits := {"n": 0, "by": {}}
	var on_hit := func(info): hits.n += 1; hits.by[String(info.get("by", ""))] = true
	b.got_hit.connect(on_hit)
	a.stats.stamina = a.stats.max_stamina
	for c in a.cooldowns.keys():
		a.cooldowns[c] = 0.0
	var serial0 := a.move_serial
	a.down_next = down
	a.sm.change("attack" if base == "basic" else base)
	var seen_proj := {}
	var seen_trap := {}
	var flags := {"counter": false, "teleport": false, "buff": false, "invuln": false, "root": false,
		"poison": false, "burn": false, "slow": false}
	var gap0: float = absf(b.global_position.x - a.global_position.x)
	var gap_min: float = gap0
	var b_hp0: float = b.stats.hp
	var started := false
	for _i in TEST_FRAMES:
		await tree.physics_frame
		if a.move_serial != serial0:
			started = true
		if a.counter_active: flags.counter = true
		if a.move_teleported: flags.teleport = true
		if a.move_buff_timer > 0.0 or a.next_damage_buff != 1.0: flags.buff = true
		if a.invincible: flags.invuln = true
		if b.rooted_time > 0.0: flags.root = true
		if b.stats.poisoned(): flags.poison = true
		if b.stats.burning(): flags.burn = true
		if b.stats.slowed(): flags.slow = true
		gap_min = minf(gap_min, absf(b.global_position.x - a.global_position.x))
		var parent := a.get_parent()
		if parent:
			for n in parent.get_children():
				if n is Projectile and n.shooter == a:
					seen_proj[n.get_instance_id()] = true
				if n is Trap and n.owner_fighter == a:
					seen_trap[n.get_instance_id()] = true
	b.got_hit.disconnect(on_hit)
	var closed: float = gap0 - gap_min
	# the pull flag only counts for a move that really has a pull; a lunge closes the gap by itself
	var has_pull: bool = bool(a.moves.get(key, {}).get("pull", false))
	var fx: Array = []
	for k in flags.keys():
		if flags[k]:
			fx.append(k)
	if has_pull and closed >= 20.0:
		fx.append("pull")
	return {
		"fighter": a_id, "key": key, "dx": dx, "started": started,
		"hits": int(hits.n), "dmg": b_hp0 - b.stats.hp, "by": hits.by.keys(),
		"proj": seen_proj.size(), "trap": seen_trap.size(), "fx": fx, "closed": closed,
	}

# ---------------------------------------------------------------- report

func _move_keys(tree: SceneTree, id: String) -> Array:
	var entry = null
	for e in Roster.entries():
		if e.id == id:
			entry = e
	if entry == null:
		return []
	var probe = load(entry.scene).instantiate()
	tree.root.add_child(probe)
	var keys: Array = []
	for k in probe.moves.keys():
		if not String(k).begins_with("awaken_"):
			keys.append(String(k))
	probe.queue_free()
	keys.sort()
	return keys

func _report_lines(rows: Array) -> Array:
	var lines: Array = []
	var by_move := {}
	for r in rows:
		var name := "%s %s" % [r.fighter, r.key]
		if not by_move.has(name):
			by_move[name] = []
		by_move[name].append(r)
	lines.append("MOVE CHECK  (%d moves, %d tests, distances %s px)" % [by_move.size(), rows.size(),
		", ".join(DISTANCES.map(func(d): return str(int(d))))])
	lines.append("")
	for name in by_move.keys():
		var parts: Array = []
		for r in by_move[name]:
			var fx: String = " ".join(r.fx)
			parts.append("%d: h%d %.1fdmg p%d t%d%s" % [int(r.dx), r.hits, r.dmg, r.proj, r.trap,
				"" if fx == "" else " [" + fx + "]"])
		var started := true
		for r in by_move[name]:
			started = started and r.started
		lines.append("%-28s %s%s" % [name, "" if started else "NEVER STARTED  ", " | ".join(parts)])
	var never: Array = []
	var silent: Array = []
	for name in by_move.keys():
		var any_started := false
		var any_effect := false
		for r in by_move[name]:
			any_started = any_started or r.started
			any_effect = any_effect or r.hits > 0 or r.proj > 0 or r.trap > 0 or not r.fx.is_empty() or r.closed >= 20.0
		if not any_started:
			never.append(name)
		elif not any_effect:
			silent.append(name)
	lines.append("")
	lines.append("NEVER STARTED: " + (", ".join(never) if not never.is_empty() else "none"))
	lines.append("NO EFFECT AT ANY DISTANCE: " + (", ".join(silent) if not silent.is_empty() else "none"))
	return lines
