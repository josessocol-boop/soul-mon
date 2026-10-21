# Soul-Mon PvP - documentation index

**Rule for every change:** update the docs with it. Balance changes go in `NOTES.txt` (changelog), `docs/SESSION_REPORT.md` (the measured result), and `docs/ANALYSIS.md` or `docs/STRUCTURES_FUNCTIONS_LIST.md` when the known issues or names change.

Start here:
- `ARCHITECTURE.md`: folder layout, dependency rules, how to add a fighter, move, support or menu.
- `MOVED_FILES.md`: where each old file went after the restructure.
- `ANALYSIS.md`: what was found, what was archived, what is still missing or unverified.
- `CONNECTIONS_LIST.md`: how the game fits together (menus, match, input, combat, AI), with generated
  tables of signals, class use and scenes.
- `STRUCTURES_FUNCTIONS_LIST.md`: every file and class with its signals, constants and functions, plus the
  move dictionary, key bindings and roster. Generated from the code.
- `SESSION_REPORT.md`: change log per session.
- `archive/`: old run logs.

---

# Soul-Mon PvP - Visuals & UI Polish build
Open in Godot 4.7 (project.godot is set to 4.7; let it import the PNGs on first open), press F5 to run.
Default matchup: Marshadow (P1/left) vs Gholdengo (P2/right).

P1: A/D move, W jump, F attack, E dash, G special 1, H special 2, T ultimate (Mewtwo: transforms when the Burst gauge is full; the gauge shows in the ULT slot), R/U/Y supports (not wired yet: no support is selected, see STRUCTURES_FUNCTIONS_LIST.md), S = Down (hold or tap S + attack/special = Down move; in the air S = fast fall / short hop). Player 1 has no alternate Down key (Ctrl and Shift were removed: they held Down when pressed).
P2: Left/Right arrows move, Up jump, Down = Down (same uses as S), Num 4 attack, Num 0 dash, Num 5 special 1, Num 6 special 2, Num 8 ultimate, Num / * - supports (not wired yet, as above). Alternate Down keys: Num 2 or Num Enter

Down and air moves:
- Attack in the air = diagonal dive attack; its hitbox is on from the 2nd frame and stays on through the landing (then a short landing lag).
- Down + attack in the air = steep spike dive (spikes airborne targets, pops grounded ones up).
- Hold Down while falling = fast fall (works while steering left/right); hold Down right after jumping = short hop.
- Hold Down + attack / special 1 / special 2 on the ground = that fighter's own Down move (list in `docs/STRUCTURES_FUNCTIONS_LIST.md`, "Down move guide"). Every Down move is a genuinely different attack (trips, shockwaves, skipping projectiles, delayed geysers, a teleporting slash, rooting arrows, ...), not just a lower swing. You do not have to HOLD Down: tapping it up to ~8 frames before or after the button still counts. The CPU uses Down moves too.
- If an attack does nothing while you hold W + S (or other combos), the keyboard may be unable to send that many keys at once (ghosting). Press F2 in a match to open the key test and see what actually arrives; use the alternate Down keys

Play goes straight to fighter select (Smash-style: a tile grid, then one panel per side). Each side has a PLAYER / CPU switch: P1 = Q, P2 = Num + (or click the button); CPU LEVEL = C (easy / medium / hard). P1 moves with WASD and readies with Enter; P2 moves with the numpad 8/4/2/6 (or the arrow keys) and readies with Num Enter. Once a side is ready, the same key again starts the match (START also works with the mouse). Left click a tile = P1 cursor, right click = P2 cursor. BACK (or Tab) returns to the main menu when you came from Play; in a match, Tab opens the select and BACK resumes the match. F5 restarts the selected matchup.

UI:      hud.tscn -> fighter_hud.tscn (MarginContainer/VBox/HBox), skill_slot.gd
Sprites: assets/*_sheet.png, 64px frames, one row per animation:
         idle(4) run(6) jump(2) dash(2) attack(4) hitstun(2) ko(3)
         To swap in real art, keep that layout (or edit Fighter.ANIMS) and change
         sheet_path in that fighter's _apply_archetype() (fighters/<id>/fighter_<id>.gd).
Art:     tools/generate_pixel_art.py is the authoritative build for the character sheets, effects, icons and arena art (needs Pillow). The move effects of Alakazam, Mewtwo, Lucario and Toxicroak come from tools/generate_fighter_fx.py (also needs Pillow). Do NOT run tools/generate_art.py, tools/generate_roster_art.py or tools/marshadow_test_art.py on this project: they overwrite art that is already in use. Down-move effects (assets/fx/down_*.png, proj_quake/proj_quill, trap_geyser/whirlpool/pit/snare) come from tools/generate_down_fx.py.
Import:  tools/import_green_sheet.py turns a green-background sheet (6 x 7 cells) into a game sheet (used for tinkaton_sheet.png).
Cleanup: tools/clean_sheet_palette.py removes green fringes and reduces a sheet to a flat palette (used on gengar_sheet.png).
Debug:   press F1 in a match to toggle the hitbox (yellow) / hurtbox (cyan) overlay; F2 toggles the key test (which keys the keyboard really sends).

## Phase 4 - Hitstop, VFX, Audio & Cancel Chains
- **Per-action input buffers** (input_handler.gd): wider windows for attacks/specials/ultimate (9f) vs movement (6f); `clear()` on hit prevents mashing surprises.
- **Frame-counter statuses** (stats_component.gd): burn/poison/slow now tick deterministically in physics frames (freeze during hitstop).
- **Hitstop/hit freeze** (fighter.gd): `freeze_frames` pauses the fighter (state, cooldowns, regen, statuses) while input buffer keeps listening; scale via `HITSTOP_SCALE` (0 disables), KO hits use `KO_HITSTOP = 12`.
- **Cancel chains**: on hit confirm, buffered special/ultimate can interrupt recovery (basic → special1 → special2 → ultimate) via `_try_special_cancel()`.
- **Screen shake** (`arena/arena_camera.gd`): `shake()` for a timed linear-decay shake and `add_trauma()` for a decaying trauma shake; scaled by `SHAKE_SCALE` in arena_manager.gd. `_archive/screen_shake.gd` is legacy and unused.
- **Hit VFX** (hit_vfx.gd): Elemental particle bursts with ring, sparks, and element-colored emitters; super-effective shows gold star burst.
- **Damage numbers** (damage_number.gd): Floating labels; gold "!" for super-effective, muted for resisted, red for KO.
- **Audio system** (sfx.gd): Positional pool player loading from `res://assets/audio/<name>.wav`; 10 generated placeholders (hit_light/heavy/ko/super, swing/special, dash, jump, shot, trap_set). There is no `ultimate.wav` yet, so the ultimate sound is skipped. Run `python3 tools/generate_sfx.py` to regenerate.
- **Arena integration** (arena_manager.gd): `_build_juice()` sets up camera/shake/flash/SFX; `_on_got_hit()` spawns VFX/numbers/plays sounds; `_on_fighter_event()` handles gameplay event sounds and ultimate screen flash.

## Phase 3 - roster, types, and HUD text fix
- Roster (8): Gholdengo, Marshadow, Tinkaton, Greninja, Scizor, Decidueye, Blaziken, Gengar
  (fighter_<name>.gd/.tscn, each inherits Fighter). Default match: Marshadow (P1) vs Gholdengo (P2).
- Moves are plain dictionaries (see MOVE_DEFAULTS in fighter.gd). Kinds: melee, projectile
  (multi-shot via spawn_count/spawn_interval/proj_vys), trap, dive. Other keys: hit_interval
  (multi-hit), i_frames, stun (hitstun frames), element override, apply (status).
- Per-fighter dash (dash_speed/frames, iframe_frames, dash_cost, dash_sink), fall_mult, max_fall.
- Dual typing: `types = [A, B]`. types[0] is the attack type; incoming damage is flattened to
  x1.2 / x1.0 / x0.8 (any immunity x0.8). Statuses: Fire=burn, Water=slow, Poison=poison
  (override per move with "apply").
- Controls hint is now a translucent PanelContainer with white outlined text (hud.gd).
- tools/generate_art.py (legacy) writes effects/arena art only; its --sheets option (off by default) also overwrites assets/*_sheet.png. See the Art line above for the current build.