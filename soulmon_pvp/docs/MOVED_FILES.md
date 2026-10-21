# Moved files (restructure)

The project used to keep ~80 scripts and scenes in one flat folder. They now live in folders by role
(see `ARCHITECTURE.md`). Godot resolves scripts by `class_name` and by `.uid`, so the moves are safe;
every `res://` path inside the project was rewritten to match. Old names are listed here so that
older notes and the docs in `CONNECTIONS_LIST.md` / `STRUCTURES_FUNCTIONS_LIST.md` can be mapped.

Renamed to snake_case (names only; class names are unchanged): `AIController.gd` -> `ai_controller.gd`,
`AIBehavior.gd` -> `ai_behavior.gd`, `AIProfile.gd` -> `ai_profile.gd`, `ArenaCamera.gd` -> `arena_camera.gd`.

Edited by hand (not just moved):
- `ArenaManager.ROSTER` (const list) -> `Roster.ENTRIES` in `roster/roster.gd`; the arena now has `var ROSTER = Roster.entries()`.
- `ai_profiles/<id>.tres` -> `fighters/<id>/profile.tres`; the AI looks it up with `Roster.profile_path(id)`.
- `CharacterSelect` no longer reads the arena's constants; its fallback is `Roster.entries()`.

## Full map

| Old path (before) | New path (now) |
|---|---|
| `AIBehavior.gd` | `ai/ai_behavior.gd` |
| `AIController.gd` | `ai/ai_controller.gd` |
| `AIProfile.gd` | `ai/ai_profile.gd` |
| `ArenaCamera.gd` | `arena/arena_camera.gd` |
| `ai_profiles/blaziken.tres` | `fighters/blaziken/profile.tres` |
| `ai_profiles/decidueye.tres` | `fighters/decidueye/profile.tres` |
| `ai_profiles/gengar.tres` | `fighters/gengar/profile.tres` |
| `ai_profiles/gholdengo.tres` | `fighters/gholdengo/profile.tres` |
| `ai_profiles/greninja.tres` | `fighters/greninja/profile.tres` |
| `ai_profiles/marshadow.tres` | `fighters/marshadow/profile.tres` |
| `ai_profiles/scizor.tres` | `fighters/scizor/profile.tres` |
| `ai_profiles/tinkaton.tres` | `fighters/tinkaton/profile.tres` |
| `animated_portrait.gd` | `ui/animated_portrait.gd` |
| `apply_phase4.py` | `_archive/apply_phase4.py` |
| `arena_manager.gd` | `arena/arena_manager.gd` |
| `arena_manager.tscn` | `_archive/arena_manager.tscn` |
| `bt_action.gd` | `ai/bt/bt_action.gd` |
| `bt_condition.gd` | `ai/bt/bt_condition.gd` |
| `bt_cooldown.gd` | `ai/bt/bt_cooldown.gd` |
| `bt_inverter.gd` | `ai/bt/bt_inverter.gd` |
| `bt_repeater.gd` | `ai/bt/bt_repeater.gd` |
| `bt_selector.gd` | `ai/bt/bt_selector.gd` |
| `bt_sequence.gd` | `ai/bt/bt_sequence.gd` |
| `bt_until_fail.gd` | `ai/bt/bt_until_fail.gd` |
| `character_select.gd` | `ui/character_select.gd` |
| `character_select.tscn` | `ui/character_select.tscn` |
| `damage_number.gd` | `arena/damage_number.gd` |
| `docs/error.txt` | `docs/archive/error.txt` |
| `docs/output.txt` | `docs/archive/output.txt` |
| `docs/report.txt` | `docs/archive/report.txt` |
| `fighter.gd` | `core/fighter.gd` |
| `fighter.tscn` | `core/fighter.tscn` |
| `fighter_blaziken.gd` | `fighters/blaziken/fighter_blaziken.gd` |
| `fighter_blaziken.tscn` | `fighters/blaziken/fighter_blaziken.tscn` |
| `fighter_brawler.gd` | `fighters/placeholders/fighter_brawler.gd` |
| `fighter_brawler.tscn` | `fighters/placeholders/fighter_brawler.tscn` |
| `fighter_decidueye.gd` | `fighters/decidueye/fighter_decidueye.gd` |
| `fighter_decidueye.tscn` | `fighters/decidueye/fighter_decidueye.tscn` |
| `fighter_gengar.gd` | `fighters/gengar/fighter_gengar.gd` |
| `fighter_gengar.tscn` | `fighters/gengar/fighter_gengar.tscn` |
| `fighter_gholdengo.gd` | `fighters/gholdengo/fighter_gholdengo.gd` |
| `fighter_gholdengo.tscn` | `fighters/gholdengo/fighter_gholdengo.tscn` |
| `fighter_greninja.gd` | `fighters/greninja/fighter_greninja.gd` |
| `fighter_greninja.tscn` | `fighters/greninja/fighter_greninja.tscn` |
| `fighter_hud.gd` | `ui/fighter_hud.gd` |
| `fighter_hud.tscn` | `ui/fighter_hud.tscn` |
| `fighter_marshadow.gd` | `fighters/marshadow/fighter_marshadow.gd` |
| `fighter_marshadow.tscn` | `fighters/marshadow/fighter_marshadow.tscn` |
| `fighter_scizor.gd` | `fighters/scizor/fighter_scizor.gd` |
| `fighter_scizor.tscn` | `fighters/scizor/fighter_scizor.tscn` |
| `fighter_tinkaton.gd` | `fighters/tinkaton/fighter_tinkaton.gd` |
| `fighter_tinkaton.tscn` | `fighters/tinkaton/fighter_tinkaton.tscn` |
| `fighter_zoner.gd` | `fighters/placeholders/fighter_zoner.gd` |
| `fighter_zoner.tscn` | `fighters/placeholders/fighter_zoner.tscn` |
| `game_text.gd` | `system/game_text.gd` |
| `hit_vfx.gd` | `arena/hit_vfx.gd` |
| `hud.gd` | `ui/hud.gd` |
| `hud.tscn` | `ui/hud.tscn` |
| `input_debug.gd` | `ui/debug/input_debug.gd` |
| `input_handler.gd` | `core/input_handler.gd` |
| `keybinds.gd` | `system/keybinds.gd` |
| `main.tscn` | `arena/main.tscn` |
| `main_menu.gd` | `ui/main_menu.gd` |
| `main_menu.tscn` | `ui/main_menu.tscn` |
| `mode_select.gd` | `_archive/mode_select.gd` |
| `mode_select.tscn` | `_archive/mode_select.tscn` |
| `options_menu.gd` | `ui/options_menu.gd` |
| `options_menu.tscn` | `ui/options_menu.tscn` |
| `projectile.gd` | `core/projectile.gd` |
| `projectile.tscn` | `core/projectile.tscn` |
| `screen_shake.gd` | `_archive/screen_shake.gd` |
| `settings.gd` | `system/settings.gd` |
| `sfx.gd` | `arena/sfx.gd` |
| `skill_slot.gd` | `ui/skill_slot.gd` |
| `state_machine.gd` | `core/state_machine.gd` |
| `stats_component.gd` | `core/stats_component.gd` |
| `support_system.gd` | `core/support_system.gd` |
| `synergy_system.gd` | `core/synergy_system.gd` |
| `tools/generate_art.py` | `tools/legacy/generate_art.py` |
| `tools/generate_roster_art.py` | `tools/legacy/generate_roster_art.py` |
| `tools/marshadow_test_art.py` | `tools/legacy/marshadow_test_art.py` |
| `trap.gd` | `core/trap.gd` |
| `ui_manager.gd` | `system/ui_manager.gd` |
