# Architecture and folder layout

This is the current layout. `CONNECTIONS_LIST.md` describes how the systems talk to each other, and
`STRUCTURES_FUNCTIONS_LIST.md` lists every file, class, signal and function. Pre-restructure versions of
both are in `docs/archive/`; `MOVED_FILES.md` maps old file names to new.

## Folders

| Folder | What lives there | Depends on |
|---|---|---|
| `core/` | The fighter model: `fighter.gd` (base, `fighter.tscn`), `stats_component`, `state_machine`, `input_handler`, `synergy_system`, `support_system`, `projectile`, `trap` | nothing outside `core/` (and `system/keybinds.gd`) |
| `fighters/<id>/` | One folder per playable fighter: `fighter_<id>.gd` (extends Fighter), `fighter_<id>.tscn`, `profile.tres` (AI). Data and tuning only. | `core/`, `ai/` (profile class) |
| `fighters/placeholders/` | Style-test fighters (brawler, zoner). Not in the roster. | `core/` |
| `roster/roster.gd` | **The roster.** The only list of playable fighters, and the path rules for each one. | nothing |
| `ai/` | Bot controller, behaviour-tree base (`ai_behavior`), profile resource (`ai_profile`), and `ai/bt/` tree nodes | `core/` (writes into the normal input buffer) |
| `arena/` | The match scene (`main.tscn`, `arena_manager`), camera, hit VFX, damage numbers, sound | `core/`, `ui/`, `ai/`, `roster/` |
| `ui/` | HUD, fighter HUD, skill slot, character select, main menu, options, animated portrait | `system/`, `roster/`, `core/` (read-only) |
| `ui/debug/` | Developer overlays (key test) | `system/` |
| `system/` | Autoloads (`settings.gd`, `ui_manager.gd`), key bindings (`keybinds.gd`), text (`game_text.gd`) | nothing |
| `assets/` | Sheets (`<id>_sheet.png`, 64 px frames), effects, audio, icons | — |
| `tools/` | Art and audio generators (see `docs/README.md`). `tools/legacy/` must not be run. | — |
| `_archive/` | Unused code kept for reference (`screen_shake.gd`, `mode_select.*`, `arena_manager.tscn`, `apply_phase4.py`). Not loaded by the game. | — |
| `docs/` | Documentation. `docs/archive/` holds old run logs. | — |

Dependency direction: `system` and `roster` are at the bottom; `core` and `ai` sit on them; `fighters`
build on `core`; `arena` and `ui` sit on top. `core/` should never import from `arena/` or `ui/`.

## Autoloads

- `Settings` (`system/settings.gd`): persistent choices (`user://settings.cfg`).
- `UIManager` (`system/ui_manager.gd`): the menu stack.

## Naming rules

- Fighter id: lowercase, no spaces (`gengar`). Used for the folder, the scene, the script, the sheet and the profile.
- Scene and script: `fighter_<id>.tscn` / `fighter_<id>.gd`. `AIController` reads the id from the scene filename,
  so keep this name.
- Sheet: `assets/<id>_sheet.png`. Profile: `fighters/<id>/profile.tres`.
- New files: snake_case. Keep the `class_name` in PascalCase.

## How to add things

**A fighter.** (1) Create `fighters/<id>/` with `fighter_<id>.gd` (extends Fighter, override
`_apply_archetype()` and `_define_moves()`), `fighter_<id>.tscn` (instance of `core/fighter.tscn`
with the script attached) and `profile.tres` (copy an existing profile). (2) Add one line to
`Roster.ENTRIES` in `roster/roster.gd`. (3) Put the sheet at `assets/<id>_sheet.png`. (4) Run `python3 tools/check_roster.py`; it fails until every listed fighter has its folder, scene, profile and a sheet of at least 384x448. Nothing else
needs editing: the arena, character select and AI all read the roster.

**A move.** Add it in the fighter's `_define_moves()`. Move keys are listed in `core/fighter.gd`
(`MOVE_DEFAULTS`).

**A fighter's ultimate or Burst behaviour.** Override `_ultimate_press()` (return true if the fighter took the press), `_ultimate_locked()` and `ult_meter()` (what the HUD ULT slot shows, and whether the AI may press it) in the fighter script. To change moves or sheet during Burst, override `_on_burst_activated` and `_on_burst_ended` and call `super`. `fighters/mewtwo/fighter_mewtwo.gd` is the example.

**A support.** Add an entry in `core/support_system.gd`. Check that its icon exists in `assets/`
(six currently do not, see `ANALYSIS.md`).

**A menu.** Put the scene and script in `ui/`, and open it through `UIManager.show_menu()`.

## Frame sheet format

Each `assets/<id>_sheet.png` holds 64 px frames, one row per animation, in this order:
idle (4), run (6), jump (2), dash (2), attack (4), hitstun (2), ko (3). The count of each row is
defined in `fighter.gd` (`ANIMS`). Attack is 4 frames today; a 5-frame attack needs `ANIMS` and the
attack timing constant changed together.

A sheet can be swapped at runtime with the same layout: `_use_sheet(path)` in `fighter_mewtwo.gd` loads a sheet and keeps the current animation and frame. Mewtwo's Mega form uses `assets/mega_mewtwo_y_sheet.png`.

## Effect strips

Move effects (`fx`, `proj_tex`, `trap_tex`) are PNG strips with the frames side by side, full height. The frame count is `fx_frames`, `proj_frames` or `trap_frames`, and the strip width must divide evenly by it (`tools/generate_fighter_fx.py` writes the Pokémon-themed set). Move strips (`fx`) draw at 2x (`FX_PIXEL` in `core/fighter.gd`), so a frame about 0.7 times the hit box gives an effect about 1.4 times the hit box, the same as the existing basics. Projectiles draw at `proj_scale` with no 2x. A trap's art is stretched to `trap_size` unless `trap_scale` is set.
