class_name Roster
extends RefCounted
## THE roster: the one place that lists playable fighters.
##
## To add a fighter:
##   1. Create fighters/<id>/ with fighter_<id>.gd (extends Fighter), fighter_<id>.tscn and profile.tres.
##   2. Add one entry to ENTRIES below.
##   3. Put the 64 px frame sheet at assets/<id>_sheet.png (layout: docs/ARCHITECTURE.md).
## Scene, sheet and AI profile paths are derived from the id, so nothing else needs editing.
## Placeholders (fighters/placeholders/) are deliberately NOT listed.

const ENTRIES := [
	{"id": "gholdengo", "name": "Gholdengo", "color": Color(0.8, 0.8, 0.6)},
	{"id": "marshadow", "name": "Marshadow", "color": Color(0.2, 0.2, 0.2)},
	{"id": "tinkaton", "name": "Tinkaton", "color": Color(0.95, 0.55, 0.75)},
	{"id": "greninja", "name": "Greninja", "color": Color(0.25, 0.5, 0.9)},
	{"id": "scizor", "name": "Scizor", "color": Color(0.85, 0.2, 0.25)},
	{"id": "decidueye", "name": "Decidueye", "color": Color(0.35, 0.55, 0.35)},
	{"id": "blaziken", "name": "Blaziken", "color": Color(0.9, 0.35, 0.2)},
	{"id": "gengar", "name": "Gengar", "color": Color(0.45, 0.25, 0.6)},
	{"id": "alakazam", "name": "Alakazam", "color": Color(0.95, 0.8, 0.3)},
	{"id": "mewtwo", "name": "Mewtwo", "color": Color(0.7, 0.55, 0.9)},
	{"id": "lucario", "name": "Lucario", "color": Color(0.3, 0.55, 0.9)},
	{"id": "toxicroak", "name": "Toxicroak", "color": Color(0.45, 0.2, 0.6)},
]

## Full entries (id, name, color, scene, sheet) in roster order. Dictionaries are built fresh each call.
static func entries() -> Array:
	var out: Array = []
	for e in ENTRIES:
		out.append({
			"id": e.id,
			"name": e.name,
			"color": e.color,
			"scene": scene_path(e.id),
			"sheet": sheet_path(e.id),
		})
	return out

static func scene_path(fighter_id: String) -> String:
	return "res://fighters/%s/fighter_%s.tscn" % [fighter_id, fighter_id]

static func script_path(fighter_id: String) -> String:
	return "res://fighters/%s/fighter_%s.gd" % [fighter_id, fighter_id]

static func sheet_path(fighter_id: String) -> String:
	return "res://assets/%s_sheet.png" % fighter_id

static func profile_path(fighter_id: String) -> String:
	return "res://fighters/%s/profile.tres" % fighter_id

static func index_of(fighter_id: String, fallback: int = 0) -> int:
	for i in ENTRIES.size():
		if ENTRIES[i].id == fighter_id:
			return i
	return fallback
