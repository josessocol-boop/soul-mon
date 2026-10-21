## Session - latest fixes (builds 8 to 12)

- **Down preferences (build 8):** Greninja `special2_down` and Toxicroak `special1_down` set to `down_pref` 0.1. Whiff memory switched off (`WHIFF_MEMORY`): bots use a special only 1-2 times a match, so the 8-use window never fills.
- **Low-preference Downs (builds 9-10):** a Down with `down_pref` below 0.2 is never used (`_disfavored`). Greninja `special2_down` fell from 1.30 to 0.95 uses a match before this rule, and Toxicroak `special1_down` stayed at 0.83 because the fallback path ignored the preference.
- **Balance tool measurements (build 10):** each match records scene node count, object count and wall time. The report gives first, last and max node counts, so a slowdown can be traced to growth or to the machine.
- **Warnings (build 11):** `tr` renamed to `tile` in `arena/arena_manager.gd`; `size` renamed to `font_size` in `ui/fighter_hud.gd` and `ui/character_select.gd`. Ternary, integer-division and enum warnings not yet traced to lines.
- **Docs (build 12):** `STRUCTURES_FUNCTIONS_LIST.md` and `CONNECTIONS_LIST.md` regenerated from the current code. Known issues and the AI and wall sections updated.

Not verified in Godot: run the balance tool and check (1) the Greninja and Toxicroak Down traps drop to near zero, (2) the node counts stay flat, (3) the Godot warnings in the Output panel.

## Session - balance tool lag

- **Cause:** "Show fights" defaulted to on, so all 16 fight viewports (1280x720 each) redrew every frame. That is GPU work, which is why CPU and RAM stayed low while the simulation crawled.
- **Fix:** simulation-only is now the default. With fights shown, the tool asks four viewports to draw each frame in turn (UPDATE_ONCE, round-robin), so each refreshes about 15 times a second. Layout and physics are unchanged.
- **Not changed:** matches still run at real game speed (Engine.time_scale stays 1.0), so a full matrix takes hours. Speeding that up would change how the physics runs, so it is left as a decision.

Not verified in Godot: run a short matrix with the default and with "Show fights" on, and compare the time taken.

## Session - fighters stuck in walls (Alakazam vs Mewtwo)

- **Cause:** teleports (Alakazam's basic_down, Mewtwo's awakened special2) and the Vine Lash pull clamped the body's x to 32..1248. The body is a capsule of radius 14 and the walls' inner faces are at x 24 and 1256, so a clamped body sat 6 px inside a wall. Move-and-slide cannot push out an overlap, so the fighter stopped moving.
- **Fix:** `arena_x()` in `core/fighter.gd` clamps to 38..1242 (wall face plus body radius). Teleports and pulls use it, and a safety clamp after `move_and_slide()` applies it on every physics frame.
- **Constants:** `WALL_LEFT_X`, `WALL_RIGHT_X`, `BODY_RADIUS` in `fighter.gd`. If the arena walls move, update these to match `arena/arena_manager.gd`.

Not verified in Godot: teleport Alakazam and Mewtwo into each wall and check they can walk out.

## Session - AI whiff memory (from the 14,400-match run)

- **Whiff memory:** the AI records whether each use of a move connected (hits from the opponent's got_hit, so projectiles that land after the move count). A move that connects none of its last 8 uses is banned for 1.5 s, then 3 s, 4.5 s, 6 s if it keeps failing. Banned moves are removed from the usable keys and a banned Down is not picked.
- **Exempt:** ultimates, awakened moves, and persistent traps (a lingering trap can still catch someone).
- **Targets from the data:** Greninja special2_down (connects 2%, 1.25 uses a match), Toxicroak special1_down (0%, 0.84 uses), Gholdengo special2_down (11%, 0.90 uses), Gengar special2 (16%, 1.61 uses). Basics are not banned in practice: Tinkaton's basic (32%) rarely goes 8 uses without a connect.
- **Not changed:** Toxicroak special1_down never connects, which may be a trap bug rather than a bot choice. Check the trap's zone before tuning it.

Not verified in Godot: run the balance tool on the full matrix and check (1) Greninja special2_down and Toxicroak special1_down use falls, (2) Tinkaton's basic and Gengar's traps keep their use, (3) overall win rates move less than the win rates from the damage-share change.

## Session - Down choice, update order (from the 14,400-match run)

- **Down choice:** the damage-share rule is removed. It pushed Alakazam, Lucario and Mewtwo's zero-damage specials out of use (special2 use fell 2.15 -> 0.11 for Alakazam, 0.95 -> 0.24 for Lucario), and it picked Gholdengo's basic Down less. Each Down move can now set `down_pref`, the chance the bot picks it when both variants reach. Absent, the old per-kind defaults apply.
- **Preferences set from the run's hit rates:** Gholdengo basic_down 0.7 (hit 64% vs 35% for basic), Scizor special2_down 0.7 (hit 73% vs 58%), Greninja special1_down 0.7 (hit 82%), Blaziken special2_down 0.6 (hit 71%).
- **Update order:** the arena has `spawn_p2_first`, which moves P2 to the front of the physics order. The balance tool alternates it every match. The P1 mirror bias came from P1 updating first; this should now split near 50%.
- **Open:** Mewtwo's special2 fell to 3 uses in 2,200 matches. Mewtwo has no Down variant, so the Down change can't explain it. Needs an instrumented run (log why `_act("special2")` is refused).

Not verified in Godot: run the balance tool on the full matrix and check (1) Alakazam and Lucario special2 use returns to the old levels, (2) Gholdengo basic_down use rises, (3) the mirror P1 split is near 50%.

## Session - balance tool and simulation fixes (from the 1950-match round robin)

- **Win rates:** W-L-D now leaves mirrors out of the table (they were being counted as losses). win% = wins / (wins + losses); draws are excluded. Mirrors get their own line with the P1/P2 split.
- **Side bias:** "Also play with sides swapped" is on by default, so each pair plays from both sides. The mirror line reports how often P1 wins; a large gap is a simulation bias. The root cause (fighter update order) is not fixed yet.
- **Double KO:** two fighters down on the same frame (or one frame apart) is a draw, not a win for whichever death was reported last.
- **Damage over time:** burn and poison ticks emit `status_damaged` on the fighter. The balance tool logs them as events (kind `status`), counts them as damage taken, and attributes them to the fighter that applied the status. A DOT kill now has a KO event.
- **Awakenings:** Mewtwo's transform is logged as an event (kind `transform`), counted in `ults`, and written to the matches CSV as `awakens_a/awakens_b`.
- **Awakened move labels:** awakened moves are flagged and named `awaken_<move>` in hits and move starts, so their damage and starts no longer disagree.
- **Unnamed damage:** projectiles and traps carry the label of the move that fired them, so their hits are no longer listed as "other".
- **AI, Down moves:** a grounded Down sweep is now picked in proportion to how much harder it hits than the normal move (clamped 15-85%). The flat 40% left strong sweeps unused, e.g. Scizor special2_down (73% hit rate, 0.22 uses a match).

Not verified in Godot: run the balance tool on the same matrix and compare the mirror split and the Down-move usage.

## Session 2026-10-14 - modularity restructure (folders, roster registry, archive)

- Folders by role: `core/`, `fighters/<id>/`, `fighters/placeholders/`, `roster/`, `ai/` (+ `ai/bt/`), `arena/`, `ui/` (+ `ui/debug/`), `system/`, `_archive/`.
- Roster: `roster/roster.gd` (`Roster.ENTRIES`) is the single list; scene, sheet and profile paths are derived from the id. `ArenaManager.ROSTER` is now built from it.
- AI profiles moved to `fighters/<id>/profile.tres`; lookup via `Roster.profile_path()`.
- Renamed to snake_case: `AIController.gd`, `AIBehavior.gd`, `AIProfile.gd`, `ArenaCamera.gd`.
- Archived (not deleted): `screen_shake.gd`, `mode_select.gd/.tscn`, `arena_manager.tscn`, `apply_phase4.py`; `tools/legacy/` for the three generators that overwrite art; old run logs in `docs/archive/`.
- Docs: `ARCHITECTURE.md`, `MOVED_FILES.md`, `ANALYSIS.md` (new); `CONNECTIONS_LIST.md` and `STRUCTURES_FUNCTIONS_LIST.md` rewritten from the code (generated tables plus hand-written flows); old versions in `docs/archive/`; index in `docs/README.md`; the project overview and the README updated to the new folders.
- Checks run by script: all `res://` literal and `ext_resource` paths resolve (except six support icons that were already missing), autoloads and main scene resolve, `class_name` unique, roster entries resolve, no uid lost.

**Not verified:** nothing was opened in Godot 4.7. Open the project, check the Output panel for load errors, then play one match.

## Session 2026-10-14 (AI pass) - bots now attack what they can reach, on time, and punish whiffs

**Asked:** "the AIs are not working properly". Code and docs read first (AIController, bt_* nodes, AIProfile, InputHandler, the fighter's hit path, projectile.gd).

**Found (all confirmed in code):**
- **Swinging at air:** the bot attacked at 150 px; a basic attack reaches about 70 px, so most swings whiffed. Close bots also stopped at about 122 px (between reach and their approach band), where they neither moved nor attacked.
- **Cooldowns and action durations ran at physics-frame speed:** the tree ticks only at the reaction interval (0.25 s on medium), so a 3 s cooldown lasted about 45 s and a 0.3 s dash held the whole tree for about 4.5 s.
- **Combos never fired:** the combo check ran only at decisions (15 frames apart), while the windows are 8-10 frames; and `buffer_action("attack")` never matched the `"basic"` trigger.
- **Whiff punish looked at the wrong thing:** `hit_confirmed` was set on the DEFENDER in `receive_hit()`, so the attacker never knew its own hit landed.
- **Zoning response never fired:** it called `is_projectile()`, which does not exist, and looked at the bot's own hitbox.
- **Bot input expired during recovery and hitstop:** the AI decayed its own buffer every frame, skipping the hold rules a keyboard press gets.
- **`aggressiveness` from the profiles was never used.**

**Changed:**
- `AIController.gd` rewritten (same personality trees and profiles):
  - attacks are gated by `_can_use()`: melee needs the opponent within the move's own reach (`_melee_reach()` = hitbox far edge + body radius) and roughly level; projectiles need 90-600 px; traps need 420 px; plain attacks also roll against `aggressiveness`.
  - close fighters walk in until the basic attack reaches; mid and far fighters keep their spacing.
  - `decision_dt` (real seconds since the last decision) drives cooldowns and durations through `AIBehavior._get_delta()`.
  - combo follow-ups are queued the frame the trigger move connects (`_update_own_hits()`); the combo branch of the tree is gone.
  - whiff punish: when an opponent's melee move ends without `landed_hit`, the bot gets a 36-frame punish window.
  - zoning: looks for `Projectile` nodes (shooter = opponent, closer than 360 px, heading our way).
  - input buffer countdown through `InputHandler.decay_buffers()` (same hold rules as a keyboard press).
- `fighter.gd`: `hit_confirmed` is now set on the ATTACKER when its melee hit connects (`_check_hits`); the defender's line in `receive_hit()` is removed. New `landed_hit` flag (melee or projectile), reset with `hit_confirmed` at each move start.
- `projectile.gd`: a hit sets `shooter.landed_hit`.
- `input_handler.gd`: `decay_buffers()` (used by the AI; `poll()` unchanged).
- `AIBehavior.gd`: `_get_delta()` returns `ai.decision_dt`.
- `AIController.buffer_action()`: `"basic"` (used as the anti-air move by Gholdengo and Decidueye) is written as `"attack"`, the key the fighter reads. Before, that press was written under a key nothing read.

**Player-facing change to check:** `hit_confirmed` used to stay false for the attacker, so melee cancel chains (basic into special, special into special) never fired for players either. They now fire, as the docs always described. If that feels too strong, the change is the single line in `_check_hits()`.

**Not verified:** Godot is not installed here. All changed scripts pass `gdparse` (syntax only). Balance is untested. Watch: CPU vs CPU matches (both sides run the same logic), a bot against a projectile fighter (Decidueye, Gholdengo), a bot on Easy (reaction and accuracy scaling), and whether bots now get hit at a sensible rate.

---

## Session 2026-10-14 (second pass) - select screen is the mode screen, BACK goes to the menu

**Asked:** analyse the uploaded project through the docs, then: keep the select screen modular for more characters; make it look like the Smash Bros select (screenshot); BACK goes to the main menu and not to the game; switch CPU / player directly on the select screen; PLAY goes to the character select; sprite sizes must not change the height of the buttons.

**Changed:**
- `character_select.gd` rewritten (same class and signals, UI still built in code):
  - Tiles are fixed `TILE_SIZE` (180x176) and laid out in rows of `ROW_LENGTH` (5), centred, inside a scroll box of `GRID_HEIGHT` (380 px). The tile and the side panels never grow with a sprite, so sprite size no longer changes a button or tile height.
  - Each side has a `PLAYER` / `CPU` switch (`p1_cpu`, `p2_cpu`) and the panel header; `CPU LEVEL` is a button in the top bar (C cycles it, saved to Settings). The mode comes from the switches (`mode_name()`, `mode_is_cpu()`): `pvp`, `pvcpu`, `cpuvp`, `cpuvcpu`.
  - BACK (Tab) returns to the main menu when the select was opened from Play / Characters (`returns_to_menu`); it resumes the match when opened with Tab mid-match.
  - Adding a roster entry adds a tile, wraps it into the rows, and gives it bars and moves from its own script. Nothing else on the screen is per-fighter.
  - Mouse: left click on a tile = P1 cursor, right click = P2 cursor.
- `arena_manager.gd`: `open_select(..., from_menu)`; `_on_selection_cancelled()` changes to `main_menu.tscn` when `returns_to_menu`; the mode is derived with `CharacterSelect.mode_name()`; restart ids use `mode_is_cpu()`.
- `main_menu.gd`: PLAY opens the character select directly (no mode screen). `mode_select.tscn/gd` are left in the project but nothing opens them.
- `keybinds.gd`: `p1_cpu_toggle` = Q, `p2_cpu_toggle` = Num +, `cpu_level` = C (character select only; checked free against every other binding).
- `settings.gd`: `last_mode` now also stores `cpuvp` (P1 is CPU).

**Docs:** `STRUCTURES_FUNCTIONS_LIST.md` (class 23, functions 12, menu section, flow, CharacterSelect vars), `CONNECTIONS_LIST.md` (flow diagram, section 16, Settings line), `README.md` (select controls).

**Not verified:** Godot is not installed here. All changed scripts pass `gdparse` (syntax only). Test: Play -> select -> BACK returns to the main menu; Tab in a match -> BACK resumes; toggle each side to CPU and back; START in PvP / PvCPU / CPU-vs-player / CPU-vs-CPU; click tiles; add a ninth fighter to `ROSTER` and check that the grid wraps and scrolls; check that the mouse wheel scrolls the grid.

---

# Soul-Mon PvP - Session Report

**Date**: 2026-10-08
**Project**: Soul-Mon PvP Godot Fighting Game

---

## Session 2026-10-14 - character select redesign (Smash-style)

**Asked:** improve the character selection screen so it is clearer what you are about to choose, like Super Smash Bros. (screenshot of a Smash-style select attached).

**Changed:**
- `character_select.gd` rebuilt, UI in code: top bar (title, mode, CPU LEVEL), a centred 4-column tile grid with P1 / P2 / CPU badges and a gold border when both cursors share a tile, two preview cards (192 px animated portrait, name, element chips, HP / SPEED / JUMP bars relative to the roster, ATTACK / SPECIAL 1 / SPECIAL 2 / ULTIMATE with damage, hits, stamina, cooldown, Down-move hint, READY stamp and button), bottom bar (controls hint, START, BACK). Stats and moves come from the fighter scenes, instanced once and cached.
- `character_select.tscn` reduced to the root, the shade and the background (the old `MainVBox` tree is gone).
- Docs: `STRUCTURES_FUNCTIONS_LIST.md` (class 23 and the sync note), `CONNECTIONS_LIST.md` (section 16 and the sync note), `README.md` (select controls), the project-overview plan (character select bullets).

**Fixed on the way:**
- Tab (`menu_toggle`) on the select screen never ran its handler: the P2 branch of `_input()` matched first. The original script had the same bug. Tab now cancels in every mode.
- The keyboard could ready both sides but never start a match; only the START button (mouse) could. The same Enter / Num Enter key now starts once the side is ready (`_select_pressed()`, `_can_start()`). The README had claimed this already.
- Dark fighter colours (Marshadow) made the stat bars and name almost invisible: colours are lifted toward white for those (`_readable()`).
- Chip and badge text touched the edge of its box (`_pad()`); the P2 badge spilled out of its tile (now laid out by containers).
- The layout ran past the 1920x1080 viewport. Card portrait 256 -> 192 px, tile height 186 -> 176 px, READY moved from the card footer into the header, and the down-move hint shortened.

**Not changed (known):**
- The CPU LEVEL label is read-only. The old select scene had a `DiffSlider` that was never wired; the level is chosen on the mode select screen.

**Checked:** headless Godot 4.7 run against the real project (`character_select.tscn` with `ArenaManager.ROSTER`): 43 checks pass (open in each mode, cursor wrap, shared tile, ready and start per mode, Tab cancel, start ids with the `cpu_` prefix, fighter info for all 8). No script errors. Screenshots (xvfb, 1920x1080) for PvP and PvCPU reviewed.

---

## Session 2026-10-14 - documentation audit (no gameplay change)

**Asked:** analyse the game mainly through the docs and update them. The project was re-uploaded (`soulmon_pvp.zip`), so the docs were checked against that copy.

**Method:** read `CONNECTIONS_LIST.md`, `STRUCTURES_FUNCTIONS_LIST.md`, `docs/README.md`, the project-overview plan and this report; then checked them against the code: every backticked identifier (the few not found were stale fragments or file names, now corrected), every `func` in the `.gd` files against the docs (all documented except a few getters and tween helpers), the constants tables, the key bindings, the roster and move names in the Down-move guide, the settings defaults, the sound files, and the HUD / arena geometry.

**Corrected in the docs:**
- Key layout: P1 attack F, special 1 G, special 2 H, ultimate T, Down S, supports R / U / Y (from `keybinds.gd`). The Q / C letters written by the 2026-10-10 playtest pass are superseded; they are kept only as history.
- `_spawn_projectile(m, vy, dir)` and `_spawn_trap(m, index)` signatures.
- `InputHandler.clear()` runs when a fighter is hit (in `receive_hit()`), not during hitstop.
- Element count is 12 (the docs said 13).
- Sound folder has 10 files; `ultimate.wav` is missing and the event is skipped silently.
- Screen shake is `ArenaCamera` (`shake()` / `add_trauma()`); `SHAKE_SCALE` is still in `arena_manager.gd`.
- Godot version: 4.7 (`project.godot`), not 4.3+.
- Roster: 8 fighters in `ArenaManager.ROSTER`; Brawler and Zoner are prototypes outside it.
- Tools: `generate_pixel_art.py` is the authoritative art build; `generate_art.py`, `generate_roster_art.py` and `marshadow_test_art.py` must not be run on this project. The tools list in `CONNECTIONS_LIST.md` section 17 was rewritten.
- Known Issues: renumbered (9 / 10), added the missing ultimate sound and a misplaced comment in `input_handler.gd`.
- Plan doc: Godot version, roster, the steps for adding a fighter (ROSTER entry and Down variants), tunables (`const`, with `@export` only in the AI scripts), and frame-based timing.

**Added to the docs:**
- `KeyTest` (`input_debug.gd`, F2) section in `STRUCTURES_FUNCTIONS_LIST.md`.
- `InputHandler._input()` / `_pending` / `down_latch` in the InputHandler description and the game loop (`hold_all` is set before `poll()`).
- Connections for F1 / F2 in `ArenaManager`.

**Found but not changed (code, not docs):**
- `input_handler.gd`: a comment above `COMBAT_ACTIONS` describes the dash hold, which actually belongs to `hold_buffers`.
- `apply_phase4.py` in the project root is an old one-off patch script; `tools/__pycache__/` is a build cache.
- `EVENT_SOUNDS["ultimate"]` points to a file that does not exist.

**Not in this project:** the art style guide (the copy used for the Tinkaton work was an upload, and no copy is in the repo, so the docs cannot link it) and the `tools/snap_sheet.py` converter from the Tinkaton work. Neither was added back.

**Open:** playtest values from the 2026-10-10 pass have not been measured in play; the yellow / Gholdengo / starter UI notes from the first playtest list are still unresolved.

## Session 2026-10-11 - Down moves redesigned, input robustness

**Reported:** many Down moves were just the normal move with a lower hitbox ("some attacks are the same"); attacking did nothing while W and S were held ("a problem when attacking and pressing other buttons"). The project zip was a fresh copy; only its files were read.

**Found (code + docs read first):**
- All 24 Down moves existed already, but most only changed hitbox shape/position (Greninja shurikens, Decidueye arrow, Gengar ball, the three traps, every basic).
- No software rule blocks Q while W and S are held: jump / down / attack are separate InputMap actions and nothing consumes them. The likely cause is keyboard ghosting (the key never reaches the game).
- Doc/code mismatch: `input_debug.gd` (F2 key test) and its text about an "alternate Down key (Ctrl / Num Enter)" existed, but nothing created the overlay and no alternate Down key was bound.
- A press that goes down and up between two physics ticks was missed (`is_action_just_pressed` polling only).

**Changed:**
- `fighter.gd`: new optional move keys (`wave`, `proj_gravity`, `proj_bounce`, `proj_pierce`, `proj_hit_gap`, `trap_delay`, `trap_size`, `trap_step`), `WAVE_DMG_MULT`, melee shockwaves in `_run_move()` / `_spawn_scheduled()`, `_spawn_projectile(m, vy, dir)`, `_spawn_trap(m, index)`.
- `projectile.gd`: gravity, floor bounces, piercing with a per-target gap, root on hit. `trap.gd`: arming delay with telegraph, custom hit-area size + stretched sprite, root, tint.
- `fighter_<id>.gd` (all 8): all 24 Down moves redesigned (table in `STRUCTURES_FUNCTIONS_LIST.md`, "Down move guide"). Gengar's Down basic renamed "Shadow Hand" (Marshadow already has "Shadow Trip").
- `input_handler.gd`: `_input()` captures presses immediately (`_pending`); Down tap latch (`down_latch`, `DOWN_LATCH_FRAMES` = 8) so S need not be held together with W and the attack; `wants_down()` uses it (not for bots).
- `keybinds.gd`: `EXTRA` is now a list per action; alternate Down keys (P1 Ctrl / Shift, P2 Num 2 / Num Enter); new action `debug_keytest` (F2).
- `arena_manager.gd`: creates the F2 key test overlay and toggles it. `input_debug.gd`, `game_text.gd`: text updated.
- `AIController.gd`: `_pick_down()` judges the Down move itself (reach, kind, wave).
- Docs updated: `docs/STRUCTURES_FUNCTIONS_LIST.md`, `docs/CONNECTIONS_LIST.md`, `docs/README.md`, this report, `docs/superpowers/plans/2026-10-09-project-overview.md`.

**Follow-up (same day): user keybinds merged.** The user supplied a new `keybinds.gd` (P1: F attack, G / H specials, T ultimate; P2: arrows + Num 4 attack, Num 0 dash, Num 5 / 6 specials, Num 8 ultimate). It was merged with: `debug_keytest` (F2) re-added (without it `ArenaManager` would error on the missing action), `EXTRA` lists + alternate Down keys (P1 Ctrl / Shift, P2 Num 2 / Num Enter), and `p2_support_3` moved from Num 0 to Num - because Num 0 was also P2 dash. Docs' key listings updated.

**Second pass (same day):** Decidueye's Down special 1 and 2 both rooted, and Marshadow's Down special 1 was an invincible lunge like its normal special 2 - redesigned: Low Shackle Arrow is now a piercing low slowing arrow (root stays only on Underfoot Snare), Spectral Slide is now a non-invincible multi-hit drag (`hit_interval` 4, `i_frames` 0). Down move guide updated.

**Third pass (same day): Down move sprites.** The Down moves reused the normal move's effect strip (wrong size / shape for low sweeps, slides, geysers...). New generator `tools/generate_down_fx.py` produces art for all of them (21 files, listed in the Down move guide); the fighters' `*_down` dictionaries point at it. `trap.gd` gained animated strips (`trap_frames`, `trap_fps`, `trap_marker`, `trap_scale`), `fighter.gd` gained the matching defaults and keeps the feet planted when a move squashes the sprite; Down moves got crouch / stretch poses (`anim_scale`, `anim_tilt`). Gengar's Shadow Hand hitbox moved 9 px up to match its art. The character sheets are unchanged (they only have one shared attack row), so the body pose is the existing attack frames squashed or stretched. Godot imports the new PNGs the first time the project is opened.

**Fourth pass (same day): Gengar sprite sheet.** `assets/gengar_sheet.png` had ~986 dark-green chroma-key pixels on its outline and hundreds of near-identical purples. Cleaned with the new `tools/clean_sheet_palette.py` (green fringe -> outline colour; body shades, reds, whites and darks quantised separately): now 14 flat colours, red eyes / white teeth / outline preserved, same 384x448 layout (64 px frames). The original is not kept in the project; run the tool on any other sheet that shows the same problem.

**Fifth pass (same day): new Tinkaton sprite sheet.** The user supplied a full Tinkaton sheet on a green background (878x1024, 6 x 7 cells, same row order as the game: idle 4, run 6, jump 2, dash 2, attack 4, hitstun 2, ko 3 + a dropped-hammer 4th ko cell that is not used). `tools/import_green_sheet.py` keyed out the green, area-averaged each cell to a 64 px frame (feet land on the same row as the old sheet, y = 61) and reduced it to 22 flat colours; result installed as `assets/tinkaton_sheet.png` (384x448, same layout, so no code changes). The old sheet is not kept in the project. The tool works for any other green-background sheet in that layout. Tinkaton's move effects were not recoloured.

**Not verified:** Godot is not installed in the sandbox. All changed scripts pass a GDScript 4 syntax check (gdtoolkit `gdparse`), but nothing was run, so balance and feel are untested. Test each Down move on the ground with a training dummy (F1 shows hitboxes): Quake Smash waves, Coin Roll / Skimming Shuriken bounces, Gilded Geyser telegraph, Whirlpool ticks, Plunge Kick, Gengar Poison Pit row, rooting arrows / snare / trips. Then open F2 and hold W + S + Q to see whether the keyboard sends all three keys.

---

## Session 2026-10-10 - aerials, fast fall, Down moves

**Reported:** Tinkaton's (and other fighters') aerial basic attack did nothing; fast fall only made you fall faster; the Down move needed improving with ideas for every fighter.

**Cause found (code + docs read first):**
- `Fighter._run_move()` ended an aerial as soon as the fighter touched the floor after frame 2, and the aerial reused the ground basic's `on` frame. Fighters with a late hitbox (Tinkaton `on` = 10) landed before the hitbox ever existed.
- `Fighter.state_jump()` only fast-fell with NO left/right input, read the keyboard directly instead of `input.down_held`, and never touched the rising part of the jump.

**Changed:**
- `fighter.gd`: new aerial timing (`AERIAL_ON`, `AERIAL_ACTIVE`, `AERIAL_MIN_ACTIVE`, `AERIAL_LAND_LAG`, `aerial_land`, `_aerial_motion()`); Down + attack in the air = spike dive (`AERIAL_DOWN_*`, pop-up on grounded targets in `receive_hit()`); fast fall + short hop in `state_jump()` (`DOWN_CUT_SPEED`, `DOWN_CUT_STEP`, `FAST_FALL_CAP`, `_gravity(delta, cap_mult)`); `variant(base, over)` helper; sprite rotation stops at landing.
- `input_handler.gd`: `wants_down()` also counts Down held while the press is buffered.
- `fighter_<id>.gd` (all 8 roster fighters): `basic_down`, `special1_down`, `special2_down` written with `variant()`.
- `AIController.gd`: `_pick_down()` + `down_at` in `buffer_action()` so bots use Down moves.
- Docs updated: `docs/STRUCTURES_FUNCTIONS_LIST.md` (constants, aerial section, 14a, helpers, InputHandler, AI, Known Issues, "Down move guide"), `docs/CONNECTIONS_LIST.md` (18a, InputHandler, AI, flow, hazards), `docs/README.md` (controls), this report, `docs/superpowers/plans/2026-10-09-project-overview.md`.

**Not verified:** nothing could be run in Godot here (no engine in the sandbox). Test: jump + attack with Tinkaton at low height and from high up; Down + attack in the air; hold Down just after jumping; each fighter's Down moves on the ground; a CPU match.

---

## Issues Fixed This Session

### 1. Parser Error in `character_select.gd` (line 105)
- **Problem**: `Cannot infer the type of "p1_data" variable because the value doesn't have a set type`
- **Fix**: Added explicit type hints `var p1_data: Dictionary = roster[p1_index]` and `var p2_data: Dictionary = roster[p2_index]` in both `_refresh_portraits()` and `_refresh_details()` functions

### 2. Missing Input Actions in `project.godot`
- **Problem**: Character select navigation (WASD, Numpad, Tab, Enter) and menu toggle weren't defined in project.godot, causing keyboard navigation to not work
- **Fix**: Added all missing input actions:
  - `menu_toggle` (Tab)
  - `p1_nav_up/down/left/right` (W/A/S/D)
  - `p1_select` (Enter)
  - `p2_nav_up/down/left/right` (Numpad 8/2/4/6)
  - `p2_select` (KP_Enter)

---

## Previously Fixed (from earlier context)

| File | Issue | Fix |
|------|-------|-----|
| `settings.gd` | `class_name` hides autoload singleton | Removed `class_name` |
| `settings.gd` | `get()`/`set()` override Object methods | Renamed to `get_value()`/`set_value()` |
| `ui_manager.gd` | `class_name` hides autoload singleton | Removed `class_name` |
| `AIBehavior.gd` | Inner classes had `class_name` (parser error) | Removed `class_name` from all 8 inner classes |
| `arena_manager.gd` | Called `Settings.get()`/`Settings.set()` | Updated to `Settings.get_value()`/`Settings.set_value()` |

---

## Implementation Status (All Complete)

### Phase 1: AI System Redesign ✅
- `AIBehavior.gd` - Behavior tree with 8 node types (Selector, Sequence, Condition, Action, Inverter, Cooldown, Repeater, UntilFail)
- `AIProfile.gd` - Data-driven Resource class
- 8 AI profiles in `ai_profiles/*.tres` (marshadow, gholdengo, tinkaton, greninja, scizor, decidueye, blaziken, gengar)
- `AIController.gd` - Complete rewrite using behavior trees with fair detection (hitboxes, velocity, position, cooldowns - NO input reading)

### Phase 2: Menu System ✅
- `Settings.gd` - Persistent settings autoload (ConfigFile at `user://settings.cfg`)
- `UIManager.gd` - Menu stack manager autoload
- `main_menu.tscn/gd` - Play / Characters / Options / Quit
- `mode_select.tscn/gd` - PvP / PvCPU / CPUvCPU + difficulty slider
- `options_menu.tscn/gd` - Difficulty + volume sliders

### Phase 3: Character Select Overhaul ✅
- `AnimatedPortrait.gd` - Reusable animated sprite component
- `character_select.tscn/gd` - Full-screen layout with animated portraits, fighter details panel, ready states for all modes

### Phase 4: Hitstop, VFX, Audio & Cancel Chains ✅
- **Input buffer overhaul** (`input_handler.gd`) - Per-action buffer windows (attacks/specials/ultimate: 9f, movement: 6f), `clear()` on hit
- **Frame-counter statuses** (`stats_component.gd`) - burn/poison/slow as deterministic frame counters with `tick_statuses()`
- **Hitstop/freeze** (`fighter.gd`) - `freeze_frames` pauses fighter logic (states, cooldowns, regen, statuses) while input buffer stays active; `HITSTOP_SCALE` global multiplier (0 disables), `KO_HITSTOP = 12`
- **Cancel chains** (`fighter.gd`) - `_try_special_cancel()` enables basic → special1 → special2 → ultimate chains on hit confirm
- **Screen shake** (`screen_shake.gd`) - Camera2D-based shake with linear decay, controlled by `SHAKE_SCALE`
- **Hit VFX** (`hit_vfx.gd`) - Elemental particle bursts with ring/sparks/emitters; super-effective gold star burst
- **Damage numbers** (`damage_number.gd`) - Floating labels; gold "!" for super-effective, muted for resisted, red for KO
- **Audio system** (`sfx.gd`) - Positional pool player from `res://assets/audio/<name>.wav`; 11 generated placeholders
- **Arena integration** (`arena_manager.gd`) - `_build_juice()` for camera/SFX/flash setup; `_on_got_hit()` spawns VFX/numbers/sounds; `_on_fighter_event()` for gameplay sounds and ultimate flash
- **SFX generator** (`tools/generate_sfx.py`) - stdlib-only WAV generator for 11 placeholder sounds

### Integration ✅
- `arena_manager.gd` - AI attachment by mode (`cpu_` prefix), difficulty from Settings
- `fighter.gd` - Added `get_types()` method
- `project.godot` - Autoloads configured, `main_scene = "res://ui/main_menu.tscn"`

---

## Next Steps for Testing

1. Open project in Godot 4.3+
2. Run the game - main menu should launch
3. Verify:
   - Main menu buttons work (Play, Characters, Options, Quit)
   - Mode select: PvP / PvCPU / CPUvCPU buttons toggle, difficulty slider works
   - Character select: animated portraits play, fighter details show, WASD/Numpad navigation works, ready states function
   - Start match transitions to arena with correct fighters
   - AI fighters use behavior trees with distinct personalities
   - Settings persist across sessions (difficulty, volume, last fighters)
   - Direct launch of `main.tscn` still works (backward compatibility)
   - **Phase 4**: Hitstop on hits, screen shake, hit VFX, damage numbers, SFX, cancel chains work

---

## Files Modified This Session
- `character_select.gd` - Fixed type inference errors
- `project.godot` - Added missing input actions for character select navigation

## Files Modified Previously
- `settings.gd`, `ui_manager.gd`, `AIBehavior.gd`, `arena_manager.gd`
- `AIController.gd`, `AIProfile.gd`, `fighter.gd`
- `main_menu.gd/tscn`, `mode_select.gd/tscn`, `options_menu.gd/tscn`
- `character_select.gd/tscn`, `animated_portrait.gd`
- 8 AI profile .tres files in `ai_profiles/`

## Phase 4 Files Added
- `screen_shake.gd` - Camera shake system
- `hit_vfx.gd` - Elemental hit burst VFX
- `damage_number.gd` - Floating damage numbers
- `sfx.gd` - Positional audio pool player
- `tools/generate_sfx.py` - Placeholder sound generator
- `assets/audio/*.wav` - 11 generated sound effects

## CPU pass (restructured project)

**Found:**
- `fighters/blaziken/profile.tres` did not parse (a trailing `#` comment after an array). The AI then had no profile and no behaviour tree, so Blaziken never acted. Its anti-air and punish keys were also wrong (dive kick as anti-air).
- Facing: `_steer()` turned the fighter toward its movement, and the bot only re-faced when it was not retreating. A bot that backed off attacked, trapped and fired the wrong way.
- Ultimates: an ultimate needs a full stamina bar or a full gauge. Dashes cost 25 stamina and the hit-and-run and aggressive bots dash constantly, so their bars were rarely full. The roll also ran before the reach check, so most rolls were wasted.
- Coverage: some personality trees never named some keys (Gengar special1, Greninja special1 and special2, Scizor and Marshadow special2).

**Changed:**
- `fighters/blaziken/profile.tres`: fixed the parse error; anti-air is `special1` (rising Blaze Kick), punish is `special2` (dive kick).
- `fighters/blaziken, greninja, marshadow/profile.tres`: `meter_management` is `adaptive` (they were `spend`).
- `core/fighter.gd`: `facing_locked` flag. `_steer`, `enter_dash`, `_wavedash` skip facing changes while it is set.
- `ai/ai_controller.gd`:
  - `setup()` sets `facing_locked`; `_drive_movement()` faces the opponent every frame except during a move.
  - `_roll_ultimate()` returns false unless `_ultimate_ready()`; base chance 0.6, 0.75 for `save_for_ultimate`, 0.9 when the opponent is below half HP, all scaled by accuracy.
  - `_saving_stamina()`, `_stamina_full()`, `_may_dash()`: saving bots dash only from a full bar (dashes are the main drain). An earlier version also blocked specials. That was removed too, but the evidence I used for it ("ranged bots standing still") came from samples taken after a KO, so it was not a real stall.
  - `_can_connect()` holds the reach test; `_can_use()` adds the saving rule on top. The whiff punish uses `_can_connect` (`_act(..., free = true)`).
  - the personality trees now include the specials listed above, and the balanced tree gains special2 at mid range.
- `ai/ai_profile.gd`: comment on the `meter_management` values.

**Measured** (headless CPU vs CPU, 16 pairings, medium, one run; counts are small, so treat them as coarse):

| Fighter | Before: ultimate starts | After: ultimate starts | Down variants after |
|---|---|---|---|
| blaziken | 0 (profile error) | 4 | basic_down 5, special1_down 6 |
| greninja | 0 | 4 | basic_down 2, special2_down 1, special1_down 0 |
| gengar | 12 | 10 | special1_down 1, special2_down 1, basic_down 2 |
| scizor | 1 | 7 | special1_down 1, special2_down 0 |
| marshadow | 1 | 7 | special2_down 1, special1_down 2, basic_down 12 |
| gholdengo | 12 | 13 | all three Down variants used |
| tinkaton | 0 | 3 | all three Down variants used |
| decidueye | 11 | 5 | special1_down 3 |

Every fighter now starts its ultimate at least once. Some Down variants are still rare (Greninja special1_down, Scizor special2_down). Their Down choice in `_pick_down()` is a low chance when both forms reach, so a longer run or a higher chance is the next tuning step.

**Stall fixed (Gengar vs Gengar):** two bots stood in front of each other and only hopped. Each bot's tricky tree put the hop first (cooldown 1.5 s, airborne most of the time), gated its specials and dash on a stamina bar that the saving rule kept low, and let attack fire only at close range. The spacing band then held both still at about 170 px. Fix: the tricky tree now tries a close attack, then specials, dash and hop, and ends with `_walk_in()`, which keeps closing in. Re-run after the fix: Gengar basic 23 and basic_down 21 (was 8 and 2 before the fix), no stall in the trace.

**Re-run after the stall fix** (16 pairings, medium, one run): every fighter starts its ultimate (4 to 12 times). Gengar special1 10, special2 6, ultimate 10. Still zero: Greninja `special1_down` and Scizor `special2_down`. No script errors and no timeouts.

## Monitoring note (CPU tests)

- After a KO, `arena/arena_manager.gd` `_on_died()` disables physics on both fighters and the round stays over until the player restarts it (F5 or Tab). A test that keeps logging past the KO sees both fighters frozen in whatever state they were in (often mid-air or in hitstun). That is not an AI stall. Monitors must stop at `arena.over`.
- Re-fetch `arena.p1` / `arena.p2` each sample, in case the arena replaces them.
- Checked on the current build with the KO-aware monitor: 12 ranged mirrors (Gengar, Decidueye, Greninja, Gholdengo, 3 runs each) and 6 ranged cross-matchups. No pre-KO stall windows and no script errors. Both-bots-hopping-at-close-range samples: 0 to 1 per match.
- Open question: the user still reports a stall with Decidueye and Greninja in the game. The headless tests above do not show it, so the next check is to find out whether it happens before a KO banner or after one.

## Back-and-forth fix (before the banner)

- **Symptom reported:** with no ability ready, Greninja (and Decidueye) bots reverse direction every decision before any KO.
- **Cause:** `_update_movement()` backs a keep-away bot off when it is too close, but the root `_walk_in()` fallback walked it in again whenever the engagement tree had nothing to do. The two alternated as cooldowns came and went.
- **Change:** `_walk_in()` uses the same spacing band as `_update_movement()` (close in when too far, hold inside the band, keep the back-off when too close).
- **Measured** (direction reversals per bot-second, live time only, KO-aware monitor): before 0.41 (all ranged mirrors and cross-matchups), after: Decidueye 0.18 (was 0.41), Gholdengo 0.35 (was 0.40), Gengar 0.27, Greninja 0.31 (mirrors and cross-matchups).
- **Still open:** Greninja's remaining reversals partly come from its hit-and-run tree, which dashes away on purpose. Moving its preferred range to `close` would remove the spacing conflict, but its close branch has no specials, so their use would fall. Needs a decision.

## Balance tool (developer)

- New `ui/debug/balance_tool.gd`, opened with Ctrl+Shift+B and the password `root`. R runs every pairing of the roster (mirrors included) a set number of times, one match after another at a set game speed, and writes a per-match CSV and a per-fighter report to `user://balance/`.
- Per fighter: wins, KO time, damage dealt and taken, ultimates and moves started per match, direction reversals per second, longest quiet gap, idle share and timeouts.
- Test: gate (wrong then right password), a two-match batch, and the file output all pass headless with no script errors.

## Correction to the reversal numbers

The earlier reversal rates came from once-a-second log lines, which miss reversals that happen within a second. The balance tool samples ten times per game second and reports higher numbers (about 2 to 3 per second for Decidueye and Greninja in one match). The back-and-forth is therefore larger than the 0.18 to 0.41 I reported earlier. The spacing fix still reduced it, but the remaining reversal rate is the next thing to fix.

## Balance tool: speed correction and rebuilt panel

- **Finding:** `Engine.time_scale` does not speed up physics here (60 physics steps take about 1 s at x1 and at x4). It only scales the delta passed to `_physics_process`, so at x4 or x8 fighters move several times too far per step (the teleporting) and cooldowns and stamina tick too fast.
- **Consequence:** the balance tool's earlier fast runs were invalid. The Gholdengo ultimate counts (about 20 per match, and mirrors with 40+ ultimates and no KO) and the 2.7 flips/s figures came from x4 and x8 runs. Those numbers should be discarded. Headless sim runs (`cpu/sim.gd`, no time scale) are valid.
- **Change:** the tool runs only at real speed. The speed controls are gone.
- **New panel:** fighter checkboxes (All / None), mirror toggle, matches per pairing, Run / Stop / Close buttons, a progress bar with an ETA, and a monospace report. Keyboard still works: R, Esc.
- **Stop:** the match in progress is discarded, so only finished matches enter the report.
- **Test:** the password, picking, a one-match run, and Stop were all tested headless through real input events, with no script errors.

## Player side labels, and a failed fix for Greninja's back-and-forth

**Side labels (requested):**
- In the arena, each fighter now has a floating tag above its head (`P1 GENGAR`, `P2 GENGAR`), built by `ui/player_tag.gd` and attached in `arena/arena_manager.gd` (`_add_side_tag`). The tag is a top-level child of the fighter, so it does not mirror when the fighter turns, and it is freed with the match. Headless check: the tag text is correct for both sides, and it moves with the fighter. The lift (84 px) is set from the sprite size (64 px texture, scaled to about 88 px tall). I have not looked at it in a real window.
- The HUD header already said `P1 NAME` / `P2 NAME`, but it sits in the corner and does not mark the fighters.
- Balance tool: each match records `p1_label`, `p2_label` and `winner_side`. The CSV has these as its first three columns, and the report has a match list (`#n  P1 gengar  vs  P2 gengar  winner: ...  KO at ...s`). The per-fighter table still groups by Pokemon, since that is what balance needs.

**Flip metric changed.** `flips/s` now counts reversals of real horizontal motion (position change between samples), not the AI's commanded direction. The commanded value can disagree with what the player sees, so the new one is the honest measure. Numbers from before this change are not directly comparable.

**Commitment rule tried and reverted.** I added a 0.35 s hold after each turn in `_drive_movement`, so a bot could not turn back straight away. Real-speed batch (18 matches, repeats 3, real motion):

| fighter | before | with hold |
|---|---|---|
| greninja | 1.15 | 1.12 |
| gengar | 1.10 | 1.11 |
| gholdengo | 0.80 | 1.17 |
| decidueye | 0.64 | 0.70 |

Greninja and Gengar did not move. A third run on the final code (reverted, labelled output) gave Greninja 1.24, Gengar 1.23, Gholdengo 0.95, Decidueye 0.66, so run-to-run noise is about 0.1 to 0.2 flips/s with 18 matches. Treat differences smaller than that as no change. Gholdengo rose, but its sample is small and the figures are noisy. The rule was reverted, so `ai_controller.gd` is unchanged from before this turn.

**What this means.** My guess was that the reversals come in bursts faster than the rule could catch. The rule only blocks a turn within 0.35 s of the previous turn, so if reversals come about once a second, it changes nothing. This is a hypothesis, not a finding. The next step is a per-physics-frame trace of one Greninja bot (commanded direction, actual motion, state, dash/wavedash events) to see what is turning it. Not started.

## Ranged standoff: jumping and holding still (Decidueye, Gengar, Greninja)

**Symptom:** ranged bots in a mirror hopped on the spot and stood still in their spacing band, facing each other.

**Measure:** `cpu/standoff.gd`, real speed, two matches per fighter mirror. "hold" is the share of bot-frames standing with no attack and no move. "jump" is the share in the jump state. "hops" counts jump starts per match.

| fighter | before: hold / jump / hops | after: hold / jump / hops |
|---|---|---|
| gengar | 11-18% / 17-32% / 16-18 | 6-21% / 7-9% / 9 |
| decidueye | 36% / 20-23% / 37-51 | 28-41% / 4-8% / 5-16 |
| greninja | 13-23% / 11-17% / 23-40 | 19-22% / 1-7% / 6-17 |
| gholdengo | 7-10% / 1% / 4-5 | 5-24% / 1-4% / 5-8 |

**Causes found and changed:**
1. **Zoning jump dodge** (Decidueye and Greninja have `zoning_response = "jump"`). It fired on every decision while a projectile was coming, and both bots in a mirror keep firing. Now a cooled-down action (`ZONING_JUMP_COOLDOWN` 1.2 s). While it cools, the bot goes on with its own attacks.
2. **Tricky filler jump** (Gengar). The jump sat after the specials and dash, so it was the default action at mid range. Removed. The walk-in now steps forward instead.
3. **Hop at an opponent who is above** (`_update_movement`). In a mirror each hop put the other bot below the jump, which made it hop back. Now cooled down (`HOP_COOLDOWN` 1.5 s). This was not the main source, but it fed the loop.
4. **Far-zone attack fallback** (zoning tree). Decidueye's far branch had only its specials, so it waited with nothing to do. Added the basic as a fallback, gated by reach, so it only fires when the Down projectile can hit from that range. Little effect on hold (see below).

**Regression check:** ranged-only balance batch (4 fighters, all pairings, 2 repeats each, 20 matches). 0 timeouts, 0 script errors. Decidueye 3-5, Gengar 5-3, Gholdengo 3-5, Greninja 1-7 (this run uses the user's buffed Greninja file). Flips/s: Decidueye 0.72, Gengar 0.93, Gholdengo 0.89, Greninja 1.20.

**Still open:**
- Decidueye still holds about 30% of the time. Its specials sit on cooldown at long range and its attack is gated by reach and the aggressiveness roll. That is waiting, not jumping, but it reads as idle. Options: shorter far cooldowns, or a walk-in step while waiting. Not changed.
- Greninja's reversal rate (about 1.2/s) is still high. This is the back-and-forth from earlier. Not addressed this round.

## Decidueye: Down special 2 is now Hook Shot

- **Old:** Underfoot Snare, a trap at Decidueye's feet that roots whoever steps on it. It was a variant of the normal special 2 (Leaf Trap), so the two felt alike.
- **New:** Hook Shot, an arrow fired diagonally up and forward (`proj_vys` -420, speed 700, life 1.4 s, about 980 px of reach). It deals 5 damage and drags whoever it hits back toward Decidueye. It has the same 5 s cooldown and 15 stamina as the normal special 2.
- **Engine change:** a new move flag `pull` in `core/fighter.gd` `receive_hit`. A pull flips the knockback direction, so the target is pushed toward the shooter instead of away. The normal knockback is unchanged.
- **Test:** `cpu/test_hook.gd`. A pull hit gives velocity −440 (toward Decidueye). The same hit without the flag gives +440.
- **AI:** `_pick_down` gives a pull projectile a 50% chance when the opponent is 200 px or more away, and 15% when closer. In six matches (Decidueye against Decidueye, Gengar and Gholdengo) the bots started Hook Shot 0.5 times per match, up from 0.2. Low because the tree chooses special 2 itself, and the normal snare is often picked instead. Raising that would need a change to the zoning tree.
- **Not yet checked:** how the pull looks in a real window (the arrow angle and the drag), and whether the pull should also lift the target a little.

### Hook Shot redesign (after feedback that the first version did not match the request)

- **What the first version did:** fired at 31 degrees with no gravity, so at 300 px the arrow passed about 160 px above a standing opponent. It only hit a target that was jumping. On a hit the target was also kicked up 60 px, so it moved diagonally up. The arrow angle itself was correct (a trace showed it going up-right).
- **Redesign:** the arrow is fired up and forward at 45 degrees (`proj_vys` -355, `proj_speed` 355) with `proj_gravity` 900, so it arcs over and comes down about 280 px in front of Decidueye. It hooks the first opponent it lands on (`proj_r` 14). The pull uses `kb` (440, 0), so the target is dragged along the ground with no upward kick.
- **Trace (`cpu/trace_hook.gd`, opponent standing 280 px away):** the arrow peaks about 145 px up and lands on the target around 270 px out. The target is then pulled toward Decidueye at −440 px/s and comes to rest about 95 px closer. Decidueye itself does not move.
- **AI:** the pull is chosen with a 50% chance when the opponent is 150–320 px away (10% otherwise). In six Decidueye matches the bots started it 0.7 times per match.
- **Known limits:** the bot's reach test for projectiles is the same for all projectiles (90–600 px), so it can press Hook Shot at ranges where the arc lands short. Close targets under about 100 px are passed over on the rise. Neither has been tuned.
- **Not yet checked:** how the arc and the pull look in a real window.

## Hook Shot v3: Decidueye leaps, the arrow is flat

- **Feedback:** the arrow was the right idea, but Decidueye should move diagonally up and forward himself, and the arrow should not have a strange arc.
- **Move:** Decidueye leaps (`hop` -600, `lunge` 260 for 24 frames, so he carries forward through the leap). A straight arrow leaves on frame 2 (`proj_vys` 0, speed 900, life 0.6 s, so about 540 px of reach) and pulls whoever it hits toward him (`pull`, knockback 440 with no vertical component).
- **Engine change:** `core/fighter.gd` `_run_move` now applies `lunge` to projectile and trap moves as well as melee. Every other move has `lunge` 0 or is melee, so only Hook Shot is affected (checked by grep).
- **Trace (`cpu/trace_hook.gd`, target standing 280 px away):** Decidueye peaks about 80 px up and 80 px ahead, lands about 110 px forward. The arrow flies flat at foot height and hits about 270 px out. The target is pulled to about 185 px from Decidueye.
- **Batch:** Decidueye against Decidueye, Gengar and Gholdengo, two matches each. No script errors. Decidueye went 0-6 (earlier batches 1-5 and 2-4). Six matches is too few to tell, but the forward leap may leave him exposed at close range. Worth checking.

## Audio settings were never applied

- **Cause:** `system/settings.gd` saved the volumes to `settings.cfg`, but on startup it never pushed them to the audio buses. Also, the project had no audio bus layout, so the SFX and Music buses did not exist and their sliders did nothing.
- **Fix:** added `default_bus_layout.tres` (Master, SFX, Music). `_ready()` now applies the saved volumes on startup (`_apply_audio`). Sound effects play on the SFX bus (`arena/sfx.gd`).
- **Test:** one process sets master 0.5, sfx 0.3 and music 0.2. A second, fresh process reads back −6.0, −10.5 and −14.0 dB, which are the expected values.

## Character select: MAIN MENU button

- **Cause:** BACK returns to the main menu only when the screen was opened from the main menu's Characters button. When it is opened during a match (Tab), BACK returns to the match and there was no other way out.
- **Fix:** added a MAIN MENU button next to BACK, which always goes to the main menu (`main_menu_requested` signal, handled in `arena/arena_manager.gd`). BACK still behaves as before.
- **Test:** opened the select screen during a match, pressed MAIN MENU, and the scene became `ui/main_menu.tscn`. The BACK-from-Characters path also goes to the main menu (checked earlier).
- **Not checked:** the button's placement and look in a real window.

## Hook Shot v4: faster, higher leap; arrow fired diagonally down from the peak

- **Feedback:** the leap should go up faster, and the arrow should be shot diagonally down when Decidueye reaches the top of the leap, pulling the enemy.
- **Leap:** `hop` -800 (was -600), so the rise is faster and higher. It peaks about 150 px up, about frame 23, with about 110 px of forward travel (`lunge` 260 for 24 frames).
- **Arrow:** `spawn` 22, fired at the peak (vertical speed 0 at that frame, checked in the trace). Angled down at 430 vertical and 520 horizontal, so about 40 degrees below horizontal. Life 0.9 s, no gravity.
- **Hit check:** the first attempt, at 26 degrees, passed just above the target's hurtbox (a capsule 52 px tall, centred on the feet), so it missed. The steeper angle hits about 270 px out. The pull (-440 px/s toward Decidueye) moves the target to about 185 px from him.
- **Batch:** Decidueye against Decidueye, Gengar and Gholdengo, two matches each. No script errors. Decidueye 2-4.
- **Limit:** the arrow only hits targets 200 px or more away. Closer, it passes over their head.

## Hook Shot v5: flatter, quicker leap; stronger pull

- **Feedback:** the leap went too far up and too slowly, and the pull did not register.
- **Leap:** `hop` -640 (was -800), so the peak is about 95 px up instead of 150. `lunge` 420 for 18 frames (was 260 for 24), so Decidueye covers about 145 px forward in about 0.3 s instead of 110 px over 0.4 s.
- **Arrow:** `spawn` 17, which lands it near the peak for the lower leap. Angled 350 down and 520 across, about 34 degrees below horizontal. Hits the target body at about 270 px.
- **Pull:** `kb` 620 (was 440). The target now slides about 150 px toward Decidueye, from 660 to 508 in the trace, versus about 95 px before. It ends level with him.
- **Batch:** Decidueye against Decidueye, Gengar and Gholdengo, two matches each. Script errors counted in the log above.
- **Limits:** the pulled target ends level with Decidueye, so the two bodies can overlap. The arrow still does not reach targets closer than about 200 px.

## Decidueye: Down special 2 is now Vine Lash (replaces Hook Shot)

The Hook Shot sections above are superseded. Hook Shot v1-v5 was an arrow that pulled the target, and it was hard to hit at range. The user asked for a whip that pulls the enemy in front of Decidueye and stuns him there, so Decidueye can follow up with an aerial basic.

**Current values** (`fighters/decidueye/fighter_decidueye.gd`, `m["special2_down"]`, built on `m.basic` with `kind` "melee"):
- Hit box: a thin line from shoulder height (about 36 px above Decidueye's feet) to the floor about 206 px in front of him. `size` (199, 24), `off` (110, -10), `aim` 0.27 rad (about 15 degrees down). The box is a child of the fighter, so it moves with him when he hops. The sprite follows the same line.
- Timing: active frames 3-14 (`on` 3, `off_f` 14). Total 36 frames.
- Movement: `hop` -680 (he peaks about 62 px up) and `lunge` 260 for the active frames, so he moves up and forward.
- Pull: `pull` true, `kb` (600, 0). `pull_dist` 44 and `pull_hold` 60: the enemy is dragged to a point 44 px directly in front of Decidueye and held there for the whole stun (60 frames, about one second). The hold overrides the enemy's velocity, so DI and walking are blocked during the stun.
- Tech: `no_tech` true. A hit with this flag never sets `stun_air`, so the enemy cannot tech out of it.
- Cost and cooldown: 15 stamina, `cd` 4.0.
- Hang: `hang_until` 34. After a hit, Decidueye stops his rise at the peak and holds still until frame 34, then drops. The move ends at frame 36, so an aerial basic can follow.
- Sprite: `assets/fx/decidueye_vine.png`, four frames of 120x20, drawn by an inline PIL script (not kept in `tools/`). `fx_frames` 4.

**Engine changes** (`core/fighter.gd`):
- `receive_hit`: a `pull` hit drags the target toward a point `pull_dist` px (default 70) directly in front of the shooter (`pull_dest_x`, clamped to 32..1248), and holds it there for `pull_hold` frames (default 16, `pull_frames`). The slide sets `velocity.x = (dest - x) * 10` before `move_and_slide()`. Earlier versions pulled toward the shooter's body, so the target ended up beside or behind him.
- `_run_move` (melee): while a move with `hang_until` has connected and `f < hang_until`, `velocity.x` is 0 and `velocity.y` decays to 0 at 2600 px/s^2, which cancels gravity and holds the fighter in the air.
- `_hitbox_on`: `hitbox.rotation = facing * m.aim`, so a melee hit box can be angled. The sprite uses `hitbox.rotation + facing * m.fx_tilt` (default 0).

**AI changes** (`ai/ai_controller.gd`):
- `_variant_reaches` (projectile): reach is `min(PROJECTILE_MAX, proj_speed * proj_life * 0.9)`. Before this, the bot treated every projectile as reaching 600 px. Down basic (the quill spray) only travels about 243 px, so the bot kept firing it from too far away. The uploaded balance report showed Decidueye using Down basic 10.1 times per match.
- `_pick_down`: a `pull` move now gets its own check before the kind match. It chooses the Down variant with 70% chance when the opponent is 90-240 px away (times accuracy), and 10% otherwise.

**Tests (headless, `cpu/trace_fx.gd`, `cpu/trace_vine.gd`, `cpu/trace_input.gd`):**
- The enemy is pulled to about 456-459 px, which is 70-75 px in front of Decidueye at 384 px, and stays there for the stun.
- Hits at 150 and 200 px connect. The thin line misses at about 120 px, because the hop lifts Decidueye above the target before the whip is active.
- Keyboard-style input (`input.remote = false`, Down latched, special 2 buffered) starts the Down variant, with the hit box active on frames 4-14 and the sprite visible.
- An earlier wide-box version connected at all distances from 90 to 200 px, but the user asked for a precise move, so it was reverted.

**Not verified:**
- The user reports that the sprite did not appear in their build (v8-v9). In headless runs it does appear. I haven't found the cause on their side. The first question to ask is which key combination they press.
- The sprite sits about 40 game px higher than the hit box in a screenshot from the user's build (v13). The cause is unknown.
- The stun and hang have only been checked in headless traces, not in a real window.

**Balance and bot behaviour (open):**
- The last batch (after the reach cap) was stopped by the user, so there are no current numbers for Decidueye's win rate or Down basic usage.
- The standoff test (`cpu/standoff.gd`, Decidueye against Gengar, Gholdengo and Greninja) shows Decidueye holding 49% of the time, up from about 30% before the reach cap. The user also reports bots going back and forth without shooting. The cause is not yet found. Likely candidates are the walk-in band (170 px for mid-range bots, which now sits outside the quill's reach) and the arrow's cooldown.

**Update (same day):** the whip now starts at shoulder height and holds the enemy 44 px in front of Decidueye for the whole stun. The user reported that the whip went off above his head, that the enemy was not pulled in front, and that the enemy could tech out of it. Tech is blocked by `no_tech`, and the hold replaces the 16-frame slide. Close-range check: the thin line still misses at 90 and 120 px. Hits at 150 and 200 px connect and hold the enemy at about 428 px (Decidueye at 384 px).

**Update (leap, then whip at 45 degrees):** the user sent a sketch that shows the whip as a 45-degree line from the top of a leap down to the floor in front of Decidueye. The move now works like this:
- Leap: `hop` -680 and `lunge` 660 over frames 3-14. Decidueye peaks about 88 px up and about 77 px forward, at about frame 12-14.
- Whip: a 45-degree line from his hand (about 36 px above his feet, at the peak) to the floor. `size` (175, 24), `off` (76, 26), `aim` 0.785. It is active on frames 9-16 (`hit_on` 9, `hit_off` 17), so it lands near the peak. The lunge window (3-14) and the hit window are now separate keys.
- Pull and hang: as before. The enemy is held 44 px in front of him at the time of the hit, and Decidueye hangs at the peak until frame 34.
- Range: the whip connects when the enemy stands about 170-260 px from where the leap starts. Closer enemies are passed over, because the line is above their heads.
- AI: `_pick_down` chooses the pull version at 140-260 px (70%); the melee reach check already includes the lunge, so the bot counts about 267 px of reach.
- Not verified in a real window. The 45-degree whip may look different from the sketch if the sprite's hand is not where the line starts.

**Update (vine sprite and vertical pull):** the user reported that the vine started above Decidueye's hit box, and that the pull did not lift the enemy to the height of the sketch. The whip sprite was longer than its hit line, so its ends poked out. Two changes:
- `fx_fit` (new move key): the strip is scaled to the hit box's length and thickness, so the vine starts and ends where the hit box does. Only Vine Lash uses it. Other moves keep `FX_PIXEL` scale.
- `pull_dy` (new move key, -22 for Vine Lash): a pull also sets the enemy's vertical target, `pull_dest_y` = attacker's y + `pull_dy`. `pull_lift` is set when the key is present. During the hold the enemy's y velocity is driven toward that target, so he is lifted into the air in front of Decidueye. He is held about 22 px above Decidueye's origin and 44 px in front of him, so the line from his hand runs slightly down to the enemy.
- Headless check: the enemy is held at (501, 496) with Decidueye at (457, 506), for both 170 px and 200 px starts. The vine is not yet checked visually.

**Update (gravity and start point):** the user reported that the enemy floated for the whole stun, and that the vine still started above Decidueye's hit box.
- Gravity: the vertical pull now lasts `pull_lift_frames` (20 for Vine Lash), and then gravity takes over. The horizontal hold (`pull_frames`, 60 frames) continues, so the enemy is pulled up in front of Decidueye, held there briefly, and falls to the floor by about frame 56. `pull_lift` (bool) became `pull_lift_frames` (int).
- Start point: the whip now starts at chest height, 18 px above the origin (`off` (67, 35), `size` (149, 24), `aim` 0.785). The earlier start at 36 px was above his body's hurtbox, which is a capsule centred on the origin and 52 px tall, and it sat above his shoulders.
- Headless check: the enemy is lifted to about 498 px, then falls to the floor by frame 56. It connects at 170, 200 and 230 px.
- Not verified in a real window.

**Update (enemy below the player, and the AI uses the vine):** the user asked for the enemy to land slightly below Decidueye so he can follow up with an aerial, and for the AI to be fixed.
- `pull_dy` for Vine Lash is now +14 (was -22). The enemy's origin is held 14 px below Decidueye's origin, for the 20 frames of `pull_lift_frames`, and then gravity takes him down.
- AI follow-up: `_check_vine_followup` (root, priority 3). Within about 1.5 s of a vine (special 2 still cooling down), while Decidueye is airborne, the enemy is within 110 px and level or a little below, the bot presses the aerial basic (`_act("attack", 0, false)`).
- AI window: `_check_vine_window` (root, before the engagement tree). When Decidueye is grounded, the enemy is grounded at 150-250 px and level, the vine is ready and he has stamina, the bot presses special 2. The pull chance inside that window is 0.9 (was 0.7).
- Batch (Decidueye against Decidueye, Gengar and Gholdengo, 6 matches): special 2 Down (vine) went from 0.3 to 1.2 starts per match. Decidueye's win rate is still low (1-5), but the sample is small.
- Standoff (`cpu/standoff.gd`, one repeat): Decidueye's hold went from 49% to 29%. Gengar's hold is 19%.
- Not verified in a real window. The follow-up relies on the enemy staying near the pull point.

## Balance tool: pick the matchups, per-hit log, damage by move

**Why:** a 12-match batch had Decidueye win 2 and lose 10. The first version of this report said 11 losses; the match file shows 10. The tool could not say which move dealt the early damage, and it could only pair fighters from one list.

**Picker (new):**
- Two lists: P1 (left) and P2 (right). Each left fighter plays each right fighter once, and a matchup listed twice plays once. With both lists full, this is the old round robin.
- Options: mirrors, sides swapped (each matchup also plays the other way round), matches per matchup 1-100 (was 1-10), and max game seconds 10-300 (was fixed at 90).
- `_run(pairs)` keeps its signature, so `cpu/run_vs.gd` still works.

**Logs (new):**
- `balance_<stamp>_events.csv`: one row per hit, with time, attacker side and id, move, kind (melee, projectile or trap), victim, damage and the victim's HP after the hit.
- `_moves.csv`: a `dmg` column (damage the move dealt in the match).
- `_matches.csv`: a `limit_s` column.
- `_report.txt`: an `early` column (damage taken in the first 5 game seconds, per match) and a "Damage dealt per match, by move" section.

**Code changes:**
- `core/fighter.gd`: `_enter_move` stores `cur_move["_label"]` (move key plus `_down`). Melee, projectile and trap hits all carry it. The `got_hit` payload gained `attacker`, `by`, `kind` and `hp`.
- `ui/debug/balance_tool.gd`: picker rebuilt; `_on_side_hit` records each hit; `_track_moves` no longer counts the idle state before a fighter's first move. That state was the blank move row in every match.

**Checked headless:**
- Matchups from the picker: left {decidueye} against right {tinkaton, gengar} gives 2 pairs. With sides swapped it gives 4. With both lists {decidueye, gengar} and mirrors on it gives 3 (the duplicate gengar-decidueye is dropped). With mirrors off it gives 1.
- A two-match batch with sides swapped (Decidueye vs Gengar, 40 s limit): all five files written, 26 hit events, event damage equal to the per-move damage totals, no blank move rows, no script errors. Run twice; the second run came after two checkbox labels were shortened.
- In that batch, the 36 HP that Decidueye lost at 1.3 s was one hit from Gengar's ultimate. That is one match, so it is a lead to test, not a finding.

**Not checked:**
- The panel layout has not been seen on screen (headless has no window). Check that the left column fits at the usual window size.
- No full-length batch has been run through the new picker yet.

## Decidueye: stronger (HP and damage), tested on CPU batches

**Change (v23):** three values in `fighters/decidueye/fighter_decidueye.gd`, no mechanics changed.
- `hp_max` 70 to 85.
- Spirit Shackles (`special1`) damage 8 to 9.5.
- Leafy trap (`special2`) damage 10 to 13.

**Result:** Decidueye's win rate across the seven other roster fighters went from 30% to 40% in a fresh confirmation run (102/336 to 135/336). Pooled over all runs, about 29% to about 42%. Average KO time rose from 14.1 s to 15.3 s, damage dealt per match from 75 to 86, and damage taken from 65 to 73.

**Per opponent (confirmation runs, wins out of 48 for both sides):**

| Opponent | Before | After |
|---|---|---|
| Blaziken | 5 | 16 |
| Scizor | 10 | 18 |
| Gholdengo | 18 | 24 |
| Gengar | 7 | 10 |
| Marshadow | 13 | 14 |
| Tinkaton | 7 | 6 |
| Greninja | 42 | 47 |

**Method:**
- Runner: `tune/exp_run.gd` (in the scratchpad, not in the zip). It plays Decidueye against each other roster fighter, both sides, through the balance tool's `_run`, and writes a JSON summary per variant.
- Each variant is a copy of the project with one set of edits (`tune/make_variant.py`). The working copy was not touched during the sweep.
- Headless runs use `--fixed-fps 60`. That keeps the same 1/60 s step per tick but does not wait for the clock, so a match takes about a second of wall time. The check against the real-time batch matched: fixed-step base vs Gengar gave KO 13.9 s and 4 wins from 24; the earlier real-time batch gave KO about 13 s and 2 wins from 12.

**Screening (win rate, all matchups; standard error about 2.5 to 4 points, so differences under about 8 points are not reliable):**

| Variant | Matches | Win rate |
|---|---|---|
| Base (three separate runs) | 168, 336, 336 | 31%, 26%, 30% |
| HP 80 | 168 (screen), 336 | 43%, 33% |
| HP 85 | 336 | 37% |
| HP 90 | 168 | 42% |
| Shackles damage 9.5 | 168 | 35% |
| Trap damage 13 | 168 | 33% |
| Ultimate damage 8.5 | 168 | 29% |
| Basic damage 5 | 168 | 26% |
| Move speed 300 | 168 | 27% |
| HP 80 + Shackles cooldown 2.2 s | 336 | 35% |
| HP 80 + Shackles 9.5 + trap 13 | 336 | 38% |
| HP 80 + trap cooldown 4 s | 336 | 32% |
| HP 85 + Shackles 9.5 + trap 13 | 336, confirmed | 44%, then 40% |
| HP 90 + Shackles 9.5 + trap 13 | 336 | 44% |
| HP 85 + those two + Shackles cooldown 2.2 s | 336 | 44% |
| HP 85 + those two + ultimate 8.5 | 336 | 47% |
| HP 85 + those two + both cooldowns | 336 | 46% |

The chosen set is HP 85 with Shackles 9.5 and trap 13. The variants with an extra cooldown or ultimate change land at 44 to 47%, which is inside the noise of the chosen set, and the ultimate is already Decidueye's biggest damage source. So they were left out.

**Not fixed:**
- Tinkaton stays at about 6 wins from 48, and no value tried moved it. Blaziken is still only 16 from 48. These two look like a problem with how Decidueye fights them, not with its numbers. A movement or AI change is the likely fix, which was not in scope here.
- Greninja is already 47 wins from 48 for Decidueye, so the buff can't change that matchup. Greninja may be the outlier, which I have not touched.
- Human-played feel of the new numbers is untested.

**Open bug: freezes (not fixed, root cause not found):**
- About 7 of roughly 1,700 CPU matches ended with no KO in 90 game seconds. In these, neither fighter moved, went idle, or took damage, and each side started at most one move.
- Captured freezes show the fighter's state counters stopping. The physics step returns before the state tick, and in several captures one fighter's HP was already 0 without a recorded death.
- The same pattern appeared in the earlier real-time batches (before the fixed-step change), so the harness is not the cause.
- Reproduction: `tune/stall_probe.gd` runs matches until it captures a freeze. `tune/dbg/` is an instrumented copy of `fighter.gd` with markers on each step of `_physics_process`.
- The probe's "still for 3 s" check also fires on quiet moments and on KOs, so it gives false positives. A future check should use HP and the death signal, not movement alone.

## Balance pass across the roster (v24)

**Goal:** bring every roster fighter's CPU win rate toward 50% in a full round robin (each pair, both sides, all eight fighters).

**Starting point (v23, 8 repeats per side, n about 112 per fighter):** Gholdengo 73%, Marshadow 65%, Blaziken 63%, Gengar 56%, Tinkaton 53%, Decidueye 38%, Scizor 33%, Greninja 18%.

**Final values (v24, 32 repeats per side, n about 448 per fighter):**

| Fighter | Win rate | Changes from v23 |
|---|---|---|
| Blaziken | 44.9% | HP 120 to 100; Ultimate damage 26 to 24 |
| Decidueye | 45.0% | none (v23 values kept) |
| Gengar | 46.1% | none |
| Gholdengo | 56.8% | HP 115 to 100 |
| Greninja | 48.7% | HP 90 to 115; Basic 5 to 6; Spirit projectile (special1) 5 to 6; special2 projectile 9 to 11 |
| Marshadow | 57.5% | HP 90 to 82; Basic 5 to 4.5; special1 14 to 12; special2 12 to 10 |
| Scizor | 48.0% | HP 130 to 140; Basic 7 to 8; special2 14 to 16 |
| Tinkaton | 53.1% | none |

The spread went from 18% to 73% down to 45% to 58%. The average is 50%, because every match has one winner.

**Files changed:** `fighters/blaziken/fighter_blaziken.gd`, `fighters/gholdengo/fighter_gholdengo.gd`, `fighters/greninja/fighter_greninja.gd`, `fighters/marshadow/fighter_marshadow.gd`, `fighters/scizor/fighter_scizor.gd`. Nothing else changed in the project. No mechanics were touched.

**What the rounds showed:**
- Raising HP does raise win rate. Marshadow went from 57.5% to 72% when HP went 90 to 98 with everything else the same. That is why its HP went down rather than up.
- Damage cuts on Marshadow's moves moved its win rate less than HP did. Its damage was spread over basic, special1, special2 and the ultimate.
- Round-to-round noise is larger than the binomial estimate for one round. At 16 repeats, Gholdengo measured 61%, then 58%, then 50%, and the same v24 set at 32 repeats gave 53%. Read changes under about 5 points as uncertain.

**Round log (win rate, R = repeats per side):**

| Round | Edits | Result |
|---|---|---|
| Baseline (R=8) | v23 | Gholdengo 73, Marshadow 65, Blaziken 63, Gengar 56, Tinkaton 53, Decidueye 38, Scizor 33, Greninja 18 |
| r1 (R=16) | Gholdengo HP 105; Marshadow speed 320; Blaziken HP 110; Greninja HP 100, basic 6; Scizor basic 8 | Blaziken 61, Decidueye 45, Gengar 50, Gholdengo 61, Greninja 24, Marshadow 71, Scizor 38, Tinkaton 49 |
| r2 (R=16) | r1 plus Marshadow speed back to 345, Marshadow special1 12, Blaziken HP 100 and Ultimate 24, Greninja projectiles 6 and 11, Scizor special2 16 | Blaziken 48, Decidueye 48, Gengar 54, Gholdengo 58, Greninja 34, Marshadow 67, Scizor 41, Tinkaton 51 |
| r3 (R=16) | r2 plus Marshadow basic 4.5 and special2 10; Greninja HP 110; Scizor HP 140; Gholdengo HP 100 | Blaziken 53, Decidueye 46, Gengar 48, Gholdengo 50, Greninja 43, Marshadow 63, Scizor 50, Tinkaton 47 |
| r3 (R=32) | same as r3 | Blaziken 48, Decidueye 45, Gengar 50, Gholdengo 53, Greninja 40, Marshadow 63, Scizor 50, Tinkaton 52 |
| r4 (R=16) | r3 plus Marshadow HP 98 | Marshadow 72 (went up), Greninja 39, Scizor 43, Gengar 55, Tinkaton 52, Blaziken 45. Rejected: Marshadow HP is the wrong way round. |
| r5 (R=32) | r3 but Marshadow HP 82 and Greninja HP 115 | Blaziken 45, Decidueye 45, Gengar 46, Gholdengo 57, Greninja 49, Marshadow 58, Scizor 48, Tinkaton 53. **Chosen.** |

**Not fixed:**
- Three of the 1,792 round-robin matches in the final run timed out with no KO after 90 game seconds. This is the same freeze bug described above, at about 0.17% of matches. The win rates above exclude those three matches.
- Blaziken and Decidueye sit at about 45% and Marshadow and Gholdengo at about 57%. These are inside a 40 to 60 band, but not centred. Narrowing further would need more repeats than the rounds above.
- Win rate is a CPU-only measure. Human-played feel is untested, and big HP changes like Greninja's 90 to 115 change how a fight plays out, even when the numbers balance.

**Method:** `tune/run.gd` in the scratchpad (not in the zip). Each variant is a copy of the project with an edit list (`tune/mkvar.py`, `tune/edits.json`). The working project is untouched until the final values were copied in. Headless runs use `--fixed-fps 60`, as in the Decidueye tuning.

## Session 2026-10-16 - Four new fighters added to the roster
- Source: `files.zip` (fighter scripts for Alakazam, Mewtwo, Lucario, Toxicroak, and `stats_component.gd` with a PSYCHIC element) and the side-profile sheets from `tools/side_profiles.py`.
- Added `fighters/alakazam/`, `fighters/mewtwo/`, `fighters/lucario/`, `fighters/toxicroak/`, each with `fighter_<id>.gd` (from the upload), `fighter_<id>.tscn` (same as Greninja's, pointing at its own script) and `profile.tres`.
- AI profiles: Alakazam zoning, far range, jumps against zoning; Mewtwo balanced, mid range; Lucario aggressive, close, Basic -> Aura Sphere combo; Toxicroak tricky, close, Basic -> Sucker Punch combo.
- `roster/roster.gd`: four entries added to `ENTRIES` (the lines from `ROSTER_ADD_WHEN_SPRITES_READY.txt`).
- `core/stats_component.gd`: PSYCHIC added to the enum and type chart (appended, so existing values are unchanged).
- `arena/hit_vfx.gd`: a PSYCHIC hit style, so Psychic hits no longer use the Normal white burst.
- `assets/<id>_sheet.png`: the four side-profile sheets (Alakazam, Mewtwo, Lucario, Toxicroak).
- `tools/check_roster.py` added (the upload's note refers to it, but it was missing). It reports 12 fighters, 0 with problems.
- Not done: Mega Mewtwo Y is not a fighter yet (the upload's `mewtwo` script says it needs the burst system first). Done 2026-10-16, see the Mewtwo transformation session below. `tools/alakazam.py` writes `assets/alakazam_sheet.png` and would overwrite the new sheet; do not run it. The new sheets have no `.import` files yet; open the project in Godot once so it creates them.
- Not verified: Godot is not run here. Checks: `gdparse` (syntax) on every changed script, and `check_roster.py`. Test in Godot: select each new fighter, play a match, check the moves and the hit effects.

## Session 2026-10-16 (AI pass 2) - stale presses, combo follow-ups, Down-move reach

**Asked:** fix the AIs for every fighter, using the balance data.

- `_drop_stale_presses()` (every frame): an attack, special or ultimate press with no usable move is dropped, so a bot stops holding a key it cannot use.
- Combo follow-ups (`_update_own_hits`) fire only when the follow-up key is usable.
- `_melee_window()`: the near edge of the reach window applies to Down moves only. Applying it to all melee moves stalled the bots (24 of 112 Scizor matches timed out).
- Trap reach: `TRAP_LEAD` and `TRAP_MAX`. A bot plants a trap when the opponent is walking into it (`_opponent_toward()`), not just when the opponent is in range. A range-only rule halved Decidueye's trap casts.
- Greninja's hit-and-run gap-closer: `mid_hitrun_sel` is special1, special2, attack, dash.
- Tried and reverted: a slow-startup refusal, which cut Tinkaton's win rate from 54% to 28%.

**Measured** (32 repeats per side): 2 timeouts in 1,792 matches, connect rates up for most fighters, win rates between 42.6% and 55.4%. Medium difficulty.

## Session 2026-10-16 (four new fighters: balance and moves)

**Asked:** the four new fighters (Alakazam, Mewtwo, Lucario, Toxicroak) do not fit the roster. Balance them slightly, and change their moves toward the idea text if needed.

**Before (CPU vs CPU, medium, 32 matches per pair, 12 fighters):** Alakazam 26%, Lucario 82%, Mewtwo 19%, Toxicroak 35%. The other eight were 37-61%.

**Changes** (`fighters/alakazam`, `lucario`, `mewtwo`, `toxicroak`, and `mewtwo/profile.tres`):
- Alakazam: HP 80 -> 95; Psybeam 3 -> 3.5 per shot.
- Lucario: Bone Rush 3 -> 2.5 per hit, recovery 20 -> 26 frames (the three hits still land in the first 17 frames); HP 110 -> 120; Max Aura gets `push: 200`.
- Mewtwo: speed 230 -> 245; jump -680 -> -740; Psycho Cut 9 -> 12 and recovery 24 -> 22; Shadow Ball 8 -> 10, cost 15 -> 10, cooldown 3 -> 2.5 s; Disable gets `no_tech`; ultimate cooldown 10 -> 8 s; AI aggression 0.6 -> 0.85.
- Toxicroak: HP 100 -> 110; Poison Jab 5 -> 5.5; Sludge Bomb 9 -> 11; Sucker Punch 11 -> 13 and `hop: -180`.

**After:** Alakazam 40%, Lucario 50%, Mewtwo 46%, Toxicroak 46%. The other eight stayed in 38-60%. Noise is about 2.5 points.

**Rejected on the way:** Lucario's basic stun change (no effect); a Mewtwo round with HP 130 and speed 255 (win rate fell from 19% to 10%). Lucario's win rate only moved when its per-hit damage fell and its recovery grew, which makes the three-hit string punishable.

**Not verified in Godot:** these runs are headless CPU matches (`tune/run.gd`). The fighters have not been played by hand.

## Session 2026-10-16 (Mewtwo transformation: Mega Mewtwo Y)

**Asked:** make Mewtwo transform when Mega, then use the Mega sprite.

- `core/fighter.gd`: two hooks, `_ultimate_press()` and `_ultimate_locked()`. Both default to the old behaviour, so no other fighter changes. `_try_actions` and `_try_special_cancel` call them.
- `ai/ai_controller.gd`: `_ultimate_ready()` is also true when the Burst gauge is full. Before, bots pressed ultimate only during Burst or at full stamina.
- `fighters/mewtwo/fighter_mewtwo.gd`:
  - The ultimate starts Burst (`try_activate_burst`) when the gauge is full. The gauge is emptied on transform.
  - For the 12 s Burst, `_awakened_moves()` replaces `moves`. Costs are the normal cost + 25 on specials and Down specials. The basic has no stamina cost in the engine, so it is not affected. The awakened ultimate is none, so the key does nothing while transformed.
  - Awakened set: basic = Psystrike Flurry (4 hits, 3 dmg); basic_down = Psychic Wave (floor shockwave); special1 = Supernova Shadow Ball (3 piercing shots); special1_down = Singularity (trap after 1 s, pulls); special2 = Amnesia Blink (teleport, next hit x1.5); special2_down = Meteor Dive (pops grounded targets).
  - Sheet: `_use_sheet(MEGA_SHEET)` uses `assets/mega_mewtwo_y_sheet.png` (already in the project), keeping the current animation and frame. The normal sheet comes back on Burst end.
  - `burst_fill_hit = 2.0` and `burst_fill_taken = 1.5`. Without these, the gauge only reached about 400 in a typical fight, so the transform almost never happened.
- Measured (Mewtwo vs the 11 others, 32 matches per pair): win rate 45.5% before the transform, 50.9% after. Transform happens in about half of the fights.

**Deviations from the idea text:** Singularity pulls the target to a spot in front of Mewtwo, not the arena centre, because the engine's pull is relative to the shooter. Disable's dash lock is still a root stand-in.

**Not verified in Godot:** the awakened art is a sheet swap only (no extra effects). The sheet swap back on Burst end is written but was not exercised in the tests (matches ended before any Burst ran out). The roster check passes (`tools/check_roster.py`: 12 fighters, 0 with problems).

## Session 2026-10-16 (Mewtwo ULT fix: the ULT key transforms, and the HUD shows the gauge)

**Reported:** pressing ULT did not transform Mewtwo. Only the AI seemed to.

**Cause:** the transform needs a full Burst gauge, and nothing in the HUD showed it. The ULT slot showed stamina, so "MAX" meant stamina was full. Pressing ULT then fired Mewtwo's normal Shadow Ball, which looked like the ultimate but did not transform.

**Changes:**
- `fighters/mewtwo/fighter_mewtwo.gd`: the ULT key is the transform only. With a full gauge it starts Burst; otherwise it does nothing. `_ultimate_locked()` is always true, so the normal ultimate is never used. New `ult_meter()` shows the gauge ("BURST" when full) and the remaining Burst time ("AWAKE").
- `core/fighter.gd`: `ult_meter()` (default: the stamina bar, ready when full).
- `ui/fighter_hud.gd`: the ULT slot is filled from `f.ult_meter()`.
- `ai/ai_controller.gd`: `_ultimate_ready()` asks `ult_meter().ready`, so bots press ULT for Mewtwo only with a full gauge.

**Checked:** headless CPU matches, 40 Mewtwo matches: 16 transforms, no script errors. The HUD change was checked for parse errors only; it has not been looked at on screen.

**Decision:** the Shadow Ball is no longer Mewtwo's ultimate. To bring it back as a fallback, `_ultimate_press()` must return false when the gauge is not full, and `_ultimate_locked()` must return false.

## Session 2026-10-17 (attack effects: the new art is read by the fighters)

**Asked:** read the updated docs and make the assets actually be read.

**Cause:** the twelve effect PNGs in `assets/fx/` were in the project but no fighter used them. The Alakazam, Mewtwo, Lucario and Toxicroak scripts still pointed at the old art (`proj_shadowball`, `proj_wave`, `trap_snare`).

**Changes:**
- `fighters/alakazam`: Psybeam -> `proj_psybeam.png` (scale 1.8); Psywave -> `proj_psywave.png`; Future Sight -> `trap_future_sight.png` with `trap_scale` 1.5 (the 40x16 eye drawn at 60x24, the trap width).
- `fighters/mewtwo`: basic -> `mewtwo_basic.png`; Shadow Ball and its ground shot -> `proj_mewtwo_ball.png`. In the Mega form the awakened basic uses the same strip, and Supernova Shadow Ball uses `proj_mega_psystorm.png`. The normal ULT move is unreachable (the ULT key starts the transform), so it keeps `proj_wave`.
- `fighters/lucario`: basic -> `lucario_basic.png`; Aura Sphere and Aura Storm -> `proj_aura_sphere.png`; Max Aura -> `proj_max_aura.png`.
- `fighters/toxicroak`: basic -> `toxicroak_basic.png`; Sludge Bomb and Gunk Shot -> `proj_sludge.png`; Toxic Spikes -> `trap_toxic_spikes.png` (4 frames).
- `tools/generate_fighter_fx.py` added (it was missing from the upload). The three basic strips are resized to frames of about 0.7 times their hit box (48x40, 44x30, 36x22). They now draw at about 1.4 times the hit box, like the existing gengar and greninja basics. The other nine effect files are unchanged.
- Projectile scales keep roughly the size the replaced art had.
- `docs/ARCHITECTURE.md`: new "Effect strips" section (frame counts, the 2x rule for move strips, `trap_scale`).

**Checks:** `gdparse` passes on every `.gd` file; `tools/check_roster.py` reports 12 fighters and 0 problems; every effect strip width divides by its frame count; every referenced PNG has a `.import` file.

**Not verified in Godot:** the project has not been run. Test each new fighter's basic, special1 and special1_down, and Mewtwo's Burst (ULT with a full gauge, then the awakened basic and special1). Still missing, as before: six support icons (`ANALYSIS.md`).

## Session 2026-10-17 (docs pass after the effects wiring)

**Asked:** read the effects-wired upload and update the docs.

**Checked against the code:**
- Every effect strip width divides by its frame count, and every referenced PNG has a `.import` file. The sizes match the report (for example `lucario_basic` 176x30 = 4 x 44x30).
- Future Sight is one frame and has no `trap_frames`, which is correct. Toxic Spikes has `trap_frames` 4.
- The engine reads `trap_frames`, `trap_scale`, `fx_frames`, `proj_frames` and `proj_fps`.
- `check_roster.py` reports 12 fighters and 0 problems.
- Left on the old art: Mewtwo's normal ultimate and awakened Psychic Wave (`proj_wave.png`), and Singularity (`trap_geyser.png`). The report does not mention these.

**Changes to the docs:**
- `CONNECTIONS_LIST.md`: sections 8 and 9 had no rows for the four new fighters, and 20 scripts were missing from section 8. Both were regenerated from the files. The rule that reproduces all 33 existing rows is: a file's own `class_name` is not listed, and files that name no class are left out. New section 6d describes the effect-art path.
- `STRUCTURES_FUNCTIONS_LIST.md`: effect art added to the four fighter entries. Known issues list the old-art moves and the untested strips.
- `README.md`: the Art line names `tools/generate_fighter_fx.py`. The sprite pointer now names the fighter's `_apply_archetype()` (the old one named two fighters that no longer exist).
- `NOTES.txt`: rewritten for this upload.

**Not verified in Godot:** the effect strips, Mewtwo's Burst visuals and the regenerated tables were checked by reading the files only.

## Session 2026-10-17 (update everything: docs checked against the code, balance restored, Mewtwo art)

**Asked:** read the docs in this upload and update everything.

**Found and fixed:**
- **Balance pass missing from the fighter scripts.** The effects pass rebuilt the four new fighters from older numbers, so Alakazam (HP 80, basic 3.0), Lucario (HP 110, basic 3.0 over 20 frames, no Max Aura push) and Toxicroak (HP 100, basic 5.0, Sludge Bomb 9, Sucker Punch 11 with no hop) were back to pre-balance values. The 2026-10-16 balance entry says they were applied. Restored: Alakazam HP 95, basic 3.5; Lucario HP 120, basic 2.5 over 26 frames, Max Aura `push` 200; Toxicroak HP 110, basic 5.5, Sludge Bomb 11, Sucker Punch 13 with `hop` -180. The new effect art was kept. Mewtwo was already correct.
- **Mewtwo's last two old-art moves.** The awakened Psychic Wave (`basic_down`) now uses `proj_psywave.png` (it used `proj_wave.png`), and Singularity uses `trap_whirlpool.png` (4 frames, hit area 120x22, as Greninja's whirlpool). The normal ULT move still uses `proj_wave.png`; it is data only.
- **Structures list.** Five files were missing functions or constants (`ai_controller.gd`, `arena_manager.gd`, `core/fighter.gd`, `system/settings.gd`), and `ui/debug/balance_tool.gd` and `ui/player_tag.gd` had no entry. Regenerated from the code; descriptions unchanged.
- **Connections, section 7 (signals).** The line numbers were out of date, `main_menu_requested` was missing, and the balance tool's connections were not listed. Regenerated (18 signals). Sections 8 and 9 were checked: all 21 scenes match.
- **Supports are not wired.** `SupportSystem.set_supports()` is never called, so no support is selected and R, U, Y and Num / * - do nothing. The controls text in `docs/README.md` now says so, and the known issues list it.
- **Architecture doc.** `system/keybinds` now names `keybinds.gd`.
- **Historical references kept.** `tools/alakazam.py` (removed from the project), `tools/side_profiles.py` and `tools/snap_sheet.py` (not in the project) are named only in older entries. They are history, so they stay as written.
- **Project root.** Removed `docs_update_2.patch` and `mewtwo_transform.patch` (both already applied) and `test_hook.log` (a sandbox error log).

**Checked:** `tools/check_roster.py` reports 12 fighters, 0 with problems. The project imports in Godot 4.7 headless with no parse errors. Headless CPU matches with Lucario, Alakazam, Toxicroak and Mewtwo (including the Burst moves) ran with no script errors.

**Still open (needs a decision, or art):**
- Six support icons are missing (`assets/*_icon.png`). Either make the art or re-point the paths. Supports also need `set_supports()` wired to character select.
- Attack frames: 4 in `ANIMS`, 5 in the Tinkaton reference. Decide, then change both together.
- Freezes: root cause still not found (see the open bug entry above).
- `LOG_MOVE_USAGE` is still `true` in `ai/ai_controller.gd`. Set it to `false` when tuning is finished.
- The balance tool still loads in every build (`arena/arena_manager.gd`). It can be gated to debug builds if you want it out of releases.
- Nothing here has been run on screen in Godot 4.7. The effect strips, Mewtwo's Burst visuals and the HUD gauge need a playtest.

## Session 2026-10-17 (attack effects for Alakazam, Lucario, Mewtwo and Toxicroak)

**Asked:** make the attack effects that were missing for the four new fighters.

**Found:** 15 moves had no effect strip. Melee and dive moves without one fell back to the fighter's generic slash.
Missing: Alakazam (Reflect, Mind Blast, Teleport Strike, Kinesis), Lucario (Swords Dance, Low Kick, Extreme Speed),
Mewtwo (Disable, Gravity Pull, Psystrike, and the awakened Amnesia Blink and Meteor Dive), Toxicroak (Sucker Punch,
Sludge Sweep, Venom Drag).

**Done:**
- `tools/generate_attack_fx.py` writes the 15 strips to `assets/fx/` (4 frames each). Frame size is about 0.7 x the
  move's hit box, since strips are drawn at 2x on the hit box. Reflect, Gravity Pull and Amnesia Blink have their own
  frames; the rest use the shapes in `tools/pixel_effects.py`. Swords Dance has no hit box, so its frame is a fixed
  48x40 aura.
- Each move got an `fx` key (and `fx_frames: 4`) in `fighter_alakazam.gd`, `fighter_lucario.gd`, `fighter_mewtwo.gd`
  (base and awakened) and `fighter_toxicroak.gd`.

**Checks (static):** `check_roster.py` 12/12. Every `res://` path resolves except the six support icons (known). Every
move key written is read. Brackets balance.

**Not verified:** nothing was run on screen. Check the strip sizes and placement on each move, that Reflect reads as a
barrier, and that the awakened Mewtwo effects appear only during the Burst.

## Session 2026-10-17 (balance pass on the new moves, and a stronger Mega transformation)

**Asked:** test the new character moves, fix them, and make the Mewtwo to Mega transformation more impactful.

**Test:** `tools/` has no test for this, so the moves were checked statically (damage per hit and per second, frame
data, reach, knockback, cost), against the category medians of the original eight fighters. The engine was checked for
every special key the moves use: `counter`, `pull`, `no_tech`, `wave`, `teleport_distance`, `stamina_steal`,
`damage_buff` and the rest are all implemented. This is a numbers check, not a playtest.

**Correction to the earlier report:** Mewtwo's base `ultimate` (the large Shadow Ball) is not unreachable. It is the
awakened ultimate: `_awakened_moves()` uses it, so it works during the Burst.

**Number changes:**
- Mewtwo Psycho Cut (basic): damage 12 -> 8 (basics cost nothing; the basic median is 6).
- Mewtwo awakened basic: 4 hits -> 3 hits (`hit_interval` 4 -> 6), damage 3 kept.
- Mewtwo Disable (special2): damage 5 -> 8.
- Mewtwo Shadow Ball (special1): cooldown 2.5 s -> 3.0 s. Pierce is kept; check it in play.
- Mewtwo awakened Supernova: damage 8 -> 5 and pierce removed (three shots could reach 48 damage).
- Mewtwo awakened Amnesia Blink: awakening penalty +25 -> +10 (cost 24). Awakened Meteor Dive: +25 -> +12 (cost 30).
- Alakazam Mind Blast (ultimate): damage 2.5 -> 7.5 per tick (30 total), cooldown 10 s -> 8 s.
- Alakazam Psybeam (basic): damage 3.5 -> 2.5 per shot (7.5 total).
- Lucario Aura Sphere (special1): projectile life 2.0 -> 1.2 s (range about 1080 px, inside the 1360 px arena).

**Transformation (Burst into Mega Mewtwo Y):**
- Freeze 36 -> 60 frames, and Mewtwo cannot be hit during it (`TRANSFORM_INVULN`).
- Emits the `awaken` event. The arena now shakes the camera, adds trauma, flashes the screen, plays the ultimate sound
  and shows a "MEGA MEWTWO Y!" banner for 2.5 seconds.
- Burst stat buffs: speed x1.15 and damage x1.1 while awakened (the engine applies and reverts them).

**Not done:** growing the sprite and a psychic shockwave at the feet. `_update_visuals()` sets the sprite scale every
frame, so a tween would fight it; a shockwave needs a new effect strip. Both are next steps.

**Checks (static):** `check_roster.py` 12/12. Every `res://` path resolves except the six support icons (known).
Every move key written is read. Brackets balance and indentation is tabs only in the edited files.

**Not verified:** nothing was run on screen. Check the Burst transformation (banner, flash, freeze, invulnerability),
the awakened costs in play, and whether Supernova still feels strong with 5 damage per shot.

## Session 2026-10-17 (faster playtest model, move rework, ball transformation)

**Asked:** playtest the new moves at speed, rework the ones that are too strong, and make the transformation more impressive.

**Test:** Godot cannot run here, so the playtest is a model. `tools/move_stats.py` reads every move's numbers
(damage per hit, hits, frame data, reach, cost, cooldown, persistent trap ticks). `tools/playtest_model.py` plays each
fighter against a stationary dummy: it uses the highest sustained damage the stamina regeneration (20/s) can pay for,
with basics free, and reports the sustain and the time to KO. Result: before the rework the new fighters were at 0.69-1.29x the
original median; after it they are at 0.69-1.00x. The three original fighters Blaziken, Greninja and Scizor sit at 1.38x
and were not changed (outside this task).

**Engine finding:** basic attacks ignore their stamina cost and cooldown (`_try_actions`: the attack branch only checks
input). A basic's only limit is its recovery frames, so the basic reworks change `total`, not `cost` or `cd`.

**Rework:**
- Alakazam Psybeam (basic): 3 shots at 2.5 -> 2 shots at 3.0, recovery 16 -> 24 frames.
- Toxicroak Poison Jab (basic): recovery 14 -> 20 frames.
- Toxicroak Toxic Spikes: lifetime 12 s -> 8 s (24 damage per placement, was 36).
- Lucario Low Kick (basic down): recovery 18 -> 24 frames.
- Mewtwo awakened basic: recovery 24 -> 28 frames.

**Transformation (the ball):** Mewtwo fades into a ball (12 frames), the ball rises to float height (12 frames), hovers
and flashes for about a second (36 frames), flashes faster (12 frames), bursts (8 frames) and Mega Mewtwo Y comes down to
the ground (24 frames). About 1.7 s in total, with Mewtwo frozen and invulnerable throughout. `assets/fx/mega_ball.png`
(tools/generate_mega_ball.py) is a 4-frame ball with a Y on the button. The arena's awakening flash, shake, sound and banner
play when Mega is revealed.

**Checks (static):** `check_roster.py` 12/12. Unresolved `res://` paths: the six support icons (known). Every move key
written is read. Brackets balance and indentation is tabs only in the edited files.

**Not verified:** nothing was run on screen. Check the ball's size against the body (it is 48 px, the body 64 px), the
flash timing, that the fighter's dash dimming does not show during the ball, and whether the descent looks right.


## Session 2026-10-17 (balance tool: fights at once, hide the panel, no in-tool speed-up)

**Asked:** make the balance tool faster (speed-up, fights in parallel) and let the panel be hidden to watch the fights.

**Decision on speed:** no in-tool speed-up. The "Balance tool (developer)" entry in an earlier session measured that `Engine.time_scale` does not speed up physics in this build and only scales the delta passed to `_physics_process`, which invalidates the numbers. A speed-up control would therefore either break the results or refuse to run. The honest throughput option is parallel fights: physics stays at the normal step, so N fights finish in about the time of one.

**Changes:**
- `ui/debug/balance_tool.gd`: `Fights at once` (1-6). Each fight runs in its own copy of the arena (a `SubViewport` at 1280x720 with its own physics world, shown in a grid). A shared job queue feeds one worker per slot, and results are stored by job index so the files do not change order. The panel shows the measured rate (`running at X.XXx real time`) and an ETA based on the wall time of finished matches. The estimate accounts for fights at once.
- `ui/debug/balance_tool.gd`: F9 or the Hide panel button hides the panel and dim layer. A `Show panel (F9)` button stays in the top-right corner. Keys and clicks still stop or close the tool.
- `arena/arena_manager.gd`: `balance_slot` (a copy the tool runs fights in) runs only the arena geometry, camera, effects and HUD. `_setup()` returns early for it, so it starts no match and nests no tool.
- `arena/sfx.gd`: `muted`. Copies in the farm are muted; the single-fight arena keeps sound.
- `docs/CONNECTIONS_LIST.md`: section 6b describes the worker queue, the farm and the rate readout.

**Checks:** static only. Brackets balance in all three files, every member the tool uses is defined, and the farm path is the only use of the `SubViewport` API. Nothing has been run in Godot.

**Not verified in Godot:** the farm rendering and grid layout, the rate readout under load, and that six copies keep the 60 Hz step on this machine. Start with two fights at once and watch the rate.

**Not done:** a faster-than-real-time headless run. That needs a launch-time setting (for example `--fixed-fps`) and a runner script. Neither is in this zip, and neither was tested here.

## Session 2026-10-17 (balance tool: up to 16 fights at once, Show fights toggle, doc fixes)

**Asked:** the simulations allowed only 6 parallel fights; raise it, and fix what else can be fixed.

**Changes:**
- `ui/debug/balance_tool.gd`: `MAX_SLOTS` 6 -> 16 (`Fights at once`, 1-16). The grid is 4 columns at 16.
- `ui/debug/balance_tool.gd`: new `Show fights` checkbox (on by default). Off, each fight copy keeps its physics but its `SubViewport` is `UPDATE_DISABLED`, so no frames are rendered. Each fight used to render at full size every frame (`UPDATE_ALWAYS`), so with 16 fights that cost is what limits how many you can run. The matches themselves do not change. Toggling mid-run applies to the live copies.
- Docs: the 1-6 limit is now 1-16 in `CONNECTIONS_LIST.md` 6b, the balance tool entry in `STRUCTURES_FUNCTIONS_LIST.md` (constants and functions), and the balance tool header.
- Fixed a stale line in `STRUCTURES_FUNCTIONS_LIST.md`: Mewtwo's awakened Psychic Wave uses `proj_psywave.png` and Singularity uses `trap_whirlpool.png` (the code already did; the doc said `proj_wave.png` and `trap_geyser.png`).

**Not changed, on purpose:**
- Support keys still do nothing: `SupportSystem.set_supports()` is never called. Wiring it needs a decision on which supports each fighter brings, and six icon files are missing.
- `LOG_MOVE_USAGE` is still on. It prints once per freed bot, which is useful for tuning but noisy in a normal session. Turn it off for release builds.
- The freeze bug (no root cause yet) and the 4 vs 5 attack frame decision stay open.

**Not verified in Godot:** nothing was run, so the real limit is unknown. Raise `Fights at once` step by step with Show fights off, and watch the `running at X.XXx real time` readout. Below 1.00x, the machine is not keeping up with that many fights. Then check the grid with Show fights on at 4-6 fights.

## Session 2026-10-17 (balance data: the AI fixes for the new fighters, Greninja nudge)

**Asked:** balance the fighters from the 462-match CPU run (`balance_..._report.txt` and the CSVs), and fix the AIs of the four new fighters (wrong moves, moves never used).

**What the data showed** (72 matches per fighter): Toxicroak 22%, Lucario 29%, Alakazam 39%, Tinkaton 43%, Mewtwo 44%, Greninja 67%. Four AI faults explained most of it:
- **Sludge Bomb missed:** 12% of its hits. A lob was judged by `proj_speed x proj_life` (about 945 px), but it comes back down after about 390 px. Most throws landed short or long.
- **Mewtwo's transform never fired:** 0 Singularity traps and 0 awakened-only hits in 72 matches. The ULT press went through the same reach test as a projectile, and a transform has no reach. Mewtwo's ULT count is also 0 because the transform starts no move.
- **Mewtwo's Disable and Toxicroak's Toxic Spikes never used:** in the balanced tree `dash` came before `special2` in mid range, and dash is always usable, so Disable was never reached. Toxic Spikes is a persistent trap, but it was only set when the opponent walked toward it, so it was almost never cast (0.04 per match).
- **Lucario spammed its basic and rarely threw Aura Sphere:** its aggressive tree only threw specials when already in mid range, and it almost always walks in.

**Changes:**
- `ai/ai_controller.gd`: lobs use their real landing distance (`LOB_WINDOW` 60 px around `speed x 2 x rise / gravity`). A self-transform (`_self_transform()`, from the fighter's `_ultimate_locked`) needs only the full gauge, and it is not dropped as a stale press. The balanced tree tries `special1`, then `special2`, then `dash`, then `attack`. A persistent trap is set at a still opponent in its zone. Aggressive fighters throw `special1` at far range (on a 2 s cooldown) before dashing in.
- `fighters/greninja/fighter_greninja.gd`: basic 6.0 -> 5.5. It is the highest-damage basic in the data (36.6 damage per match, 9.5 uses) and the fighter at 67%.

**Checked and left alone:** Lucario's Bone Rush (2.5, recovery 26) and Max Aura push, and Toxicroak's Poison Jab, Sludge Bomb, Sucker Punch and hop, already match the 16 Oct values. Alakazam's Psybeam is 3 damage per shot with 2 shots now (16 Oct: 3.5 per shot), which looks like a deliberate change, so it is not reverted. Mewtwo's basic is 8 (was 12 then).

**Not verified in Godot, and no new matches were run.** Every change is a reasoned fix to the logged data. Re-run the same batch with the same settings as the 462-match run and compare: Toxicroak's Sludge Bomb hit rate should rise well above 12%, Mewtwo should show Disable and Psystrike starts, and some transforms should show up as trap events (Singularity). Then tune the win rates further from the new run, not from this one.


## Session 2026-10-17 (second balance batch: pooled data, Toxicroak and Alakazam HP)

Data: both old-build runs pooled (462 + 625 matches, 924 non-mirror). Both runs predate the AI fixes and the Greninja basic nudge, so they describe the old build.

- Pooled win rates: greninja 72.7, marshadow 62.3, gholdengo 61.7, gengar 57.8, blaziken 51.9, mewtwo 51.9, decidueye 51.3, scizor 49.4, tinkaton 46.8, alakazam 39.6, lucario 31.2, toxicroak 23.4.
- Per-opponent records are near-sweeps (most pairs 14-0 or 0-14). Toxicroak is 0-14 against gholdengo, greninja, lucario, scizor and tinkaton. Lucario is 0-14 against blaziken and marshadow. Alakazam is 0-14 against lucario and tinkaton. Numbers alone do not close sweeps like these.
- Toxicroak: sludge bomb (special1) hits 10% of starts (AI reach issue, addressed by the lob fix). Basic is 2595 starts at 2.3 damage per start.
- Lucario: basic is 3234 starts at 3.1 damage per start, 53% hit. Special2 lands 11%. The fallback `_act("attack")` in the defensive, zoning and balanced trees has no cooldown, which is the likely source. Not changed here.
- Alakazam: psywave (special1) hits 33% of starts. Ultimate is strong at 14.6 damage per start.
- Greninja is left alone. Its basic was already nudged 6.0 to 5.5, and this data predates that nudge.

Changes:
- Toxicroak hp_max 110 to 120.
- Balance tool MAX_SLOTS 16 to 64 (grid columns scale with sqrt, so the layout still fits).
- Alakazam hp_max 95 to 100.

Not verified: no Godot run. Re-run the batch on the current build and compare against the pooled numbers above.

## Session 2026-10-17 (third balance batch: full round robin, Toxicroak damage and Greninja special)

Data: run 4 (`balance_1792227531`) is a full round robin: 66 pairs at 64 matches each, 4,222 non-mirror matches, 2 timeouts. It ran with Toxicroak HP 120 (checked in the HP CSV), so the HP buff is included. Run 3 (`balance_1792225011`) is Gholdengo against each of the other 11 fighters (64 each, 666 matches). Its Gholdengo results match run 4, so it was not pooled.

- Run 4 win rates: greninja 68.8, gholdengo 64.1, marshadow 60.1, tinkaton 54.5, gengar 54.5, scizor 52.6, blaziken 51.4, mewtwo 50.0, decidueye 40.5, lucario 37.2, alakazam 35.4, toxicroak 30.9.
- 18 of 66 pairs are 90% or more one-sided. These are deterministic counters, so they are not a number problem.
- Toxicroak: lowest total damage (58.9k, next lowest 68.7k). Basic is 13,322 starts at 2.3 damage per start. Sludge Bomb still hits 17% (was 10%), so the reach fix helped but did not finish the job. Special1_down 0% (652 starts).
- Greninja: special1 is its largest damage source (25.2k, 8.9 per start, 64% hit).
- Lucario: basic is 15,170 starts (about 18 per match) at 3.1 damage per start. Special1 (Aura Sphere, 73% hit) is only 935 starts. Special2 11% hit.
- Decidueye: special2 (trap) 15% hit on 1,082 starts. Drops from about 51% (old builds) to 40.5%.
- Alakazam: Psybeam left at 3 per shot. The earlier changes went 3.5, 2.5, 3.0, so it is not changed here. Basic is 8,135 starts at 3.6 per start.

Changes:
- Toxicroak basic 5.5 to 6.5.
- Greninja special1 6.0 to 5.5 per shot (special1_down keeps its own 6.0).

Still needed (AI, not numbers): Lucario basic spam and rare Aura Sphere; Decidueye special2 placement; Toxicroak Sludge Bomb use; Alakazam Psywave misses. Not verified in Godot.

## Session 2026-10-17 (reworks to the weakest moves in run 4)

Source: the full round robin (run 4, 4,222 matches). Moves chosen by hit rate and damage per start, skipping traps where the hit column does not count trap ticks.

- Tinkaton basic: active frames start at 9 instead of 13, recovery 40 to 36 frames. It hit 25% of its 6,759 starts.
- Gengar special2 (poison trap): now persistent, lifetime 6 s. It hit 16% of 1,032 starts because the trap only fired if the opponent walked onto it right away.
- Decidueye special2 (leaf trap): now persistent, lifetime 6 s. It hit 15% of 1,082 starts for the same reason.
- Toxicroak special1 (Sludge Bomb): flatter arc, gravity 900 to 650, launch velocity -420 to -340. The landing point moves from about 392 to about 439 units, so the shot lands further out. It hit 17% of 301 starts.

Left alone: Alakazam Psywave (33%, bounce tuning needs in-engine tests), Future Sight and Toxic Spikes (trap columns do not show trap ticks), Lucario Aura Sphere and special2 (buff move, few starts), Mewtwo Disable (rarely started, an AI issue).

Not verified: no Godot run. Compare the same hit-rate columns in the next round robin.

## Session 2026-10-17 (sheet palettes for Alakazam, Mewtwo and Lucario; Psybeam comment)

- Sprite check (`assets/sprite_consistency_check.py`): Alakazam, Mewtwo and Lucario each had one rare colour in 72 pixels, repeated in 18 frames (run, jump, dash, attack). Those pixels are now snapped to the nearest shared-palette colour. Toxicroak, Greninja and Tinkaton already passed. The check now reports no drift for all four new sheets.
- Alakazam basic (Psybeam): the code already fires 2 shots (`spawn_count` 2, interval 4). The comment still said three shots and is now corrected. Builds before the 16 Oct change (`soulmon_pvp_effects_wired.zip` and the original upload) fire 3 shots. Latest builds fire 2.
- Not changed: the sheets' drawing itself (small figures versus the Greninja sheet) and the effect strips for Mewtwo, Lucario and Toxicroak. Those need new art or a generator pass.

Not verified in Godot.

## Session 2026-10-17 (new sprites for Alakazam, Lucario, Mewtwo and Toxicroak)

- New generator `tools/pixel_new_four.py`, drawn with the same toolkit as `pixel_characters.py` (32px native, 2x in game). It writes `assets/alakazam_sheet.png`, `lucario_sheet.png`, `mewtwo_sheet.png` and `toxicroak_sheet.png` (384x448, 64px frames, same row order).
- Colours and silhouettes follow the reference art the user sent: Alakazam yellow with brown trunks and spoons; Lucario blue with a black mask, cream chest and muzzle, red eyes; Mewtwo lavender with a purple tail and crest; Toxicroak navy with a red throat sac and yellow eyes.
- Sprites are simpler than the Greninja and Tinkaton sheets. Their animation rows follow the same poses as the other fighters.
- The earlier sheets are replaced. Palette check passes for all four.

Not verified in Godot.

## Session 2026-10-17 (sheets from the reference pictures)

- The four new sheets (Alakazam, Lucario, Mewtwo, Toxicroak) now come from the reference sheets the user sent, not from procedural drawing. `tools/import_reference_sheet.py` does the conversion: it removes the white background (only background connected to the border), area-averages each of the 6x7 cells to 64x64 (inset 6 px so grid lines stay out), and reduces each sheet to one shared 18-colour palette.
- Mewtwo: the lavender reference (first Mewtwo picture). The second Mewtwo picture (dark purple ring tail) was not used.
- Toxicroak: the navy reference with the red throat sac.
- Palette and outline checks pass.

Not verified in Godot.
- Follow-up on the same four sheets: every edge pixel is set to the sheet's darkest palette colour (`tools/unify_outline.py`), and rare colours are snapped as before. Remaining checker notes: some frames have a 2px outline where the sheet uses 1px (thickness only; outline colour is uniform). Greninja's sheet is also 2px in places.

## Session 2026-10-17 (crisper reference sheets)

- `tools/import_reference_sheet.py` now samples each frame on a 32x32 grid by majority vote over the palette (no blending), then shows it 2x nearest, the same native size as `generate_pixel_art.py`. The earlier box-filter version blurred the edges. Background removal and the shared 16-colour palette are unchanged.
- Outline colour is unified (`tools/unify_outline.py`) and rare colours are snapped. The sprites are 2px-outlined at game size, like the other sheets.

Not verified in Godot.

## Session 2026-10-17 (sheets from the user's own downscale)

- The user downscaled the four reference sheets (384x448, JPEG). `tools/clean_uploaded_sheet.py` removes the white background (only white connected to the border), maps every pixel to one shared 16-colour palette, and writes PNG. No resampling, so the pixel grid stays as the user made it.
- Mewtwo: the lavender sheet is the game sheet. The second Mewtwo sheet (dark purple tail with a white loop) is exported as `mewtwo_alt_sheet.png` and not used.

Not verified in Godot.
- Background removal follow-up: Lucario and both Mewtwo sheets use `--strict`, which removes every pure-white region (holes inside the Mewtwo ring tail and gaps between limbs). Tiny white highlights (12 px or less, such as eye glints) are kept. Alakazam and Toxicroak use the border-only mode, so their white spoons and toes stay.

## Session 2026-10-17 (clean palettes for the four reference sheets)

- `tools/palette_sheet.py` replaces the earlier palette step. Colours are clustered in CIE Lab, and each palette entry is a real pixel from the sheet rather than an average, so colours keep their saturation. Near-duplicates (dE under 7) are merged. Every 2x2 block then takes the majority palette colour, which removes the JPEG speckle. The sheet stays 2x native (384x448) with crisp blocks.
- Palette sizes: Alakazam 8 colours, Toxicroak 9, Lucario and Mewtwo 12/11 with `--strict` and `--drop-edge-white` (white halo on the silhouette edge is made transparent).
- Mewtwo alt is kept as `assets/mewtwo_alt_sheet.png` but not used.

Not verified in Godot.

## Session 2026-10-17 (Pokemon-themed effects for Alakazam, Lucario, Mewtwo and Toxicroak)

- `tools/generate_fx_four.py` draws every effect strip for the four new fighters with the size and frame count their scripts expect, so no script changes are needed except two:
  - Mewtwo's ultimate uses `proj_psystrike.png` (was `proj_wave`, which Greninja also uses).
  - Mewtwo's awakened special1 down uses `trap_psychic_field.png` (was `trap_whirlpool`, which Greninja also uses).
- Themes: Alakazam psychic waves, mind-wave columns, Future Sight eye and reflect rings; Lucario blue aura spheres, aura rings and bone strikes; Mewtwo psychic balls, psystorm and Disable locks; Toxicroak purple sludge, poison jabs, sucker-punch slashes and toxic spikes.
- Drawn on the pixel grid with no anti-aliasing. This is a first pass and has not been checked in Godot.

## Session 2026-10-17 (user's own sprite sheets)

- The four sheets for Alakazam, Lucario, Mewtwo and Toxicroak are the user's own upgraded versions (from their zip), replacing the converted and palette-cleaned sheets. The generated effects are unchanged.
- Not verified in Godot.

## Alakazam Future Sight visual (crystal swords)
- `assets/fx/trap_future_sight.png` is now a 4-frame strip (160x16, 40x16 per frame): two crossed pale-blue crystal swords with dark gem cores and a glint that moves down each blade.
- Generated by `trap_future_sight()` in `tools/generate_fx_four.py` (SPECS entry `(4, 160, 16, None)`).
- `fighters/alakazam/fighter_alakazam.gd` special1_down: added `trap_frames: 4`, `trap_fps: 8.0` (trap still 60x24 via `trap_scale 1.5`).

## Mewtwo Ground Wave (basic_down) sprite
- Added `assets/fx/down_mewtwo_basic.png` (4 frames, 192x32): a low psychic arc sweeping along the floor. Generated by `psychic_low_sweep()` in `tools/generate_fx_four.py`.
- `fighters/mewtwo/fighter_mewtwo.gd`: base and awakened `basic_down` had no `fx` key, so no swipe was drawn. Both now set `"fx": down_mewtwo_basic.png, "fx_frames": 4`.

## Mewtwo awakened Psychic Wave (basic_down) sprite
- Added `assets/fx/down_mewtwo_awakened_basic.png` (4 frames, 192x40): a taller pink-crested shockwave rolling along the floor (`psychic_big_wave()` in `tools/generate_fx_four.py`).
- Awakened `basic_down` now uses this strip instead of the base Ground Wave strip, so the two variants look distinct.

## Session 2026-10-18 (balance pass 6, fight speed, built on the 8d70015f upload)

**Asked:** apply balance changes from the 2880-match round robin (balance_1792346042), and make the simulations faster and lighter.

**Base:** this upload (`8d70015f`, identical to `e951b27f`). The Marshadow sheet in it is `assets/marshadow_sheet.png` (eb325e99, the same file as in every upload since 2026-10-10).

**Balance (data: basic_down is the biggest damage source for both top fighters):**
- Tinkaton `basic_down` dmg 12 -> 10 (2080 starts, 40% connect, about 10k total damage). Tinkaton was 64.3% win rate.
- Gholdengo `basic_down` dmg 7 -> 6 (2930 starts, 65% connect, about 12.8k total damage). Gholdengo was 62.6%.
- Alakazam Future Sight `trap_delay` 2.0 -> 1.4 (the trap almost never connected at 2.0 s).
- Alakazam, Lucario and Toxicroak HP are NOT changed: the restored values from the 2026-10-17 pass stay (80/110/100 -> 100/120/120).
- Not changed: Lucario basic spam (17.5 starts per match, an AI pacing issue); trap "connect" columns do not count trap ticks, so they are not used for decisions.

**Fight speed:**
- `core/fighter.gd`: projectile scene and trap script are `preload`ed once instead of loaded on every shot or trap.
- `ui/debug/balance_tool.gd`: fight copies render at half resolution (640x360) and are stretched to the game size with `size_2d_override`. The grid layout keeps the game's proportions.
- `ui/debug/balance_tool.gd`: each match's event and HP rows are written to the run's `_events.csv` and `_hp.csv` when the match ends (`_stream_match`), instead of being held in memory until the batch finishes. Only the early-damage totals are kept per match. Event and HP match numbers are the job number, which matches `matches.csv` unless a run is aborted.

**Not measured:** nothing was run in Godot 4.7 for these changes.

## Balance tool: frame and physics readout
- The run status now ends with "frame N ms, physics M ms" (`_perf_text()`), so a run shows whether the frame time is physics (all fights, on the main thread) or drawing.
- Diagnosis from the 2026-10-18 run: "0.50x real time" at about 4 fps is what Godot's physics-step cap gives when each frame takes about 250 ms (8 steps per frame at 60 ticks per second is about 0.53x). The readout will show which part of that frame takes the time.

## Balance tool: simulation-only copies skip their visuals
- Why: with Show fights off the copies still ran hit effects (CPU particles, damage numbers), camera shake, sound calls and the HUD's per-frame label updates on every hit and every frame. None of that affects the match.
- `arena/arena_manager.gd`: `cosmetics` flag and `set_cosmetics()`. When off, `_on_got_hit` and `_on_fighter_event` return early, and the HUD's `_process` is disabled.
- `ui/debug/balance_tool.gd`: each match sets `cosmetics` to Show fights (or on for the real arena). Toggling Show fights updates the running copies too.
- History: 1e0704f9 (2026-10-17 09:46) ran 6 fights with rendering on, which was fast enough. 90e9f8be (17:27) raised it to 64 fights with Show fights on by default. The sim is CPU-bound on the main thread, so 64 fights run at about 0.5x. More fights add lag, not throughput, beyond the point where the rate reads about 1.0x.
- Not measured in Godot. Use the readout (`frame ... ms, physics ... ms`) and the Godot profiler to confirm.

## Session 2026-10-18 (balance pass on the 12-fighter roster)

**Method:** full round robin with the balance tool's own run (`_run`), headless, 16 matches per side per matchup. That is 2,112 matches per round, with sides swapped. Each round took about 8 minutes on two cores. Decisions use win % with 352 games per fighter, so the noise is about ±5 points at 95% confidence.

**Baseline (the uploaded project):** win % ranged from 32 (Mewtwo) to 60 (Marshadow). The strongest were Marshadow, Tinkaton, Scizor and Gholdengo. The weakest were Mewtwo, Alakazam and Toxicroak.

**Changes (8 fighters, 14 values):**
- Alakazam: HP 100 to 105. Basic damage 3.0 to 3.5, and 3 shots instead of 2.
- Gengar: ultimate damage 30 to 26.
- Gholdengo: ultimate damage per shot 6.0 to 5.5 (7 shots).
- Marshadow: HP 82 to 88, move speed 345 to 330, basic damage 4.5 to 4.0.
- Mewtwo: HP 150 to 165, move speed 245 to 270, basic damage 8 to 9, Shadow Ball 10 to 11.5.
- Scizor: HP 140 to 130.
- Tinkaton: ultimate damage 42 to 36.
- Toxicroak: HP 120 to 132, basic damage 6.5 to 7.0.

**Result (round 4, win %):** Tinkaton 54.8 (was 58.8), Marshadow 54.0 (59.7), Gengar 53.4 (56.2), Lucario 52.3 (46.9), Blaziken 50.0 (50.9), Scizor 49.4 (58.8), Decidueye 49.1 (48.6), Alakazam 49.1 (35.5), Gholdengo 48.6 (57.7), Greninja 48.3 (54.5), Toxicroak 46.9 (39.5), Mewtwo 44.0 (32.4). No timeouts. The spread is now 44 to 55, down from 32 to 60.

**Still open:** Mewtwo is lowest at 44 and takes the most damage (141 per match). Its awakened basic does only about 7 damage per match, and it awakens in about two thirds of its games. The next step would be the awakened kit or the Burst gauge fill. Marshadow's speed was the main source of its edge, and it took three rounds to move it.

**Balance tool fix:** the match CSV (`_matches.csv`) wrote the format string instead of the values. It had 23 format specifiers for 26 columns. It now has 26, and the file is correct. The in-panel report was not affected.

## Balance tool: every fight drawn every frame, and a zoom view

**Why:** with Show fights on, the tool drew only four of the fight tiles each frame, so with 64 fights each tile refreshed about four times a second. The tiles looked locked, and a single fight could not be inspected closer than a tile.

**Changes (`ui/debug/balance_tool.gd`):**
- **Tile draws per frame** (new spin, default 64): every tile draws every frame. Lower it to take turns, as before, when the machine cannot keep up.
- **Click a tile to zoom in.** The fight opens at its full game size (1280x720) in a scrollable view, with its title, zoom out / fit / zoom in, and Close. Keys: + and - zoom, 0 fits, Esc closes. Ctrl + mouse wheel zooms. The zoomed copy draws every frame and returns to tile size when closed.
- **Tile labels:** each tile names its fighters and match number.
- **Less dimming:** the panel's dim layer is 45% while fights are shown (60% without).

**Trade-off:** the simulation runs on the main thread, so drawing more tiles can slow the matches. The "running at X real time" readout shows the cost. In a software-rendered test (Mesa llvmpipe, 16 fights) the rate fell from about 48 to about 30 fps. A real GPU will be much faster, but this has not been measured on your machine. Turn the draws down if the readout drops well below 1.0x.

**Checked headless under a virtual display (Xvfb, Mesa OpenGL):** the grid renders with labels, the zoom view opens and zooms (1.5x shown with scroll bars), Ctrl + wheel changes zoom, Esc closes the view without stopping the run, and the copy returns to tile size. The import reports no script errors. The on-screen result has been checked in screenshots, not on your GPU.

**Not changed:** a single fight (Fights at once = 1) still runs in the main arena behind the panel, so it is already full size and has no tile or zoom.

## Session 2026-10-19 (re-analysis with Godot in the loop)

**Asked:** reanalyse the uploaded project and update the docs.

**Done:**
- Godot 4.7.2 (official Linux build, from the uploaded packets) runs in the sandbox, headless, under Xvfb for screenshots.
- Import: no errors. Script compile (`--check-only`, every file): 48/53 pass; the 5 flagged are artifacts (autoloads are
  not loaded in check-only mode; `projectile.gd` is a one-file-check ordering artifact).
- Smoke test: every fighter pair through the arena's own `_start_match`, headless. Partial: 66 of 132 pairs complete, 0
  errors, 1 timeout. The harness waits for the arena's setup before starting a match.
- `docs/ANALYSIS.md` rewritten with the engine-verified state. Open items listed there.

**Found, not changed in this pass:**
- Several shared fixes from earlier passes are absent from this upload (hitstun fix for the attacker's `hitstun_mult`,
  buff expiry, timed counter, awakened log labels, the utility-move gate, Alakazam's Psybolt / timed Reflect / Kinesis
  pull). Listed in `docs/ANALYSIS.md`, item 1. Decide per item.
- The user's `WALL_EDGE` rule replaces the earlier corner fix; the spacing hysteresis is gone, so flips need re-measuring.
- Supports are still not assigned (R / U / Y do nothing); six support icons are still missing.

**Not verified:** on-screen feel and AI quality; the balance numbers were not re-run this pass.

## Session 2026-10-19 (missing fixes restored)

**Asked:** send the files, with the fixes.

**Restored in the code** (these were missing from `soulmon_pvp_098557.zip`):
- `core/fighter.gd`: attacker-side hitstun multiplier (applied to the stun the hit inflicts, instead of the victim's
  knockback); move buff expiry (`MOVE_BUFF_SECONDS` 4 s); timed counter (`counter_timer`, `counter_frames`).
- `ai/ai_controller.gd`: utility moves usable at any spacing.
- `fighters/alakazam/fighter_alakazam.gd`: Psybolt (speed 640, life 1.6 s, cooldown 2.5 s, cost 12); Reflect 1.2 s
  (`counter_frames` 72, cost 14); Kinesis pull (`pull_dist` 70, `pull_hold` 14, width 120, cooldown 5 s, cost 10).
  Kept: the user's Future Sight delay (1.4 s), HP, basic and ultimate.

**Not restored:** the value-weighted Down choice (`_move_value`), since the upload's `down_pref` system replaces it.
The awakened log labels were already in the upload (`current_label()`), so no change there.

**Checks:** import with no errors; `--check-only` on the three changed scripts: no errors; six fights (Alakazam and
Lucario both ways, Lucario vs Gholdengo, Alakazam vs Blaziken, Mewtwo vs Greninja, Toxicroak vs Tinkaton): no script
or input errors, one timeout (Mewtwo vs Greninja, no KO inside 40 s).

**Still open:** the full round robin is partial (66 of 132 pairs earlier); the remaining pairs have not been run on this
code. Supports are still not assigned, and six support icons are still missing.

## Session 2026-10-19 (Player 1 stuck on Down)

**Bug:** Player 1 locked into Down moves and jumped low.

**Cause:** Player 1's Down key had two alternates, Ctrl and Shift (`EXTRA` in `system/keybinds.gd`). Holding either
modifier pressed Down, so the fighter fast-fell (a low jump) and every button press became a Down variant. Ctrl and
Shift are often held, for example with Ctrl+Shift+B for the balance tool. Confirmed in the engine: holding Shift or Ctrl
made `p1_down` pressed, and releasing it cleared the action.

**Fix:** the Ctrl and Shift alternates are removed from `p1_down`. S is the only Player 1 Down key. The comments in
`system/keybinds.gd` are updated. Player 2 is unchanged (Arrow Down, Num 2, Num Enter).

**Checks:** import with no errors; key test (Shift and Ctrl no longer press `p1_down`, S still does); roster check 12/12.

**Trade-off:** a keyboard that ghosts S with W and an attack key now has no alternate Down key. If that matters, add a
letter key that is not already used by Player 1 (X is free).

## Session: Alakazam balance (hard) and projectile/trap avoidance

**Alakazam on hard was at 82.6% (roster, 6 repeats per pairing, 792 matches).** Almost all of his damage came from
Psybeam: 21 hits a match at 2.55 each (54 damage a match), and Reflect sending back about 29 damage a match.

**Changes (`fighters/alakazam/fighter_alakazam.gd`, `core/fighter.gd`):**
- Psybeam (`basic`): damage 2.8 to 2.0 per shot, shot speed 640 to 560, total frames 24 to 28.
- Mind Blast (`ultimate`): cooldown 8 s to 10 s.
- Reflect (`special2`): new move keys `counter_mult` (default 1.5) and `counter_cap` (default none) in `core/fighter.gd`.
  Reflect caps the sent-back damage at 10.

**Result (hard, full roster, 6 repeats):** Alakazam 82.6% to 61.4%. Basic damage a match 54 to 38; Reflect 29 to 23.
Greninja (71%) and Marshadow (67%) are now above Alakazam on hard; Greninja was already high before this change.

**Projectile and trap avoidance (`ai/ai_controller.gd`, `_avoid_hazards`):** bots stop walking into incoming shots,
dash through them once the reaction time has passed, and hop opponent traps on their path. Trap hits taken fell for
most fighters (Toxicroak 1.02 to 0.52 per game). Projectile hits did not fall: most shots appear within 100 px of the
bot, or the bot is in hitstun or mid-attack, so a dash cannot start in time.


## Session: roster balance on hard (2026-10-20)

**Starting point:** hard, 12 fighters, 6 repeats per pairing (792 matches). Win rates ran from 29.5% (Mewtwo) to 71.2% (Greninja). Alakazam was at 61.4%, and his Mind Blast was hard to dodge: a 900 px beam that stayed out for 46 frames, hitting four times.

**Changes (all in the project; full list in `NOTES.txt`):**
- Alakazam `ultimate` (Mind Blast): 520 px wide, active 20-44 frames after a 20-frame windup, three hits of 5 (was 900 px, four hits of 6). Total 70 frames.
- Greninja: `special1` damage 4.0 (was 5.5), cooldown 3.5 s (was 3.0); `ultimate` damage 28 (was 32).
- Marshadow: `special1` damage 10 (was 12), cooldown 3.0 s (was 2.5).
- Mewtwo: HP 190 (was 175); `basic` 78x58 box at x 42 (was 66x56 at x 38), total 20 frames (was 22); `special1` cooldown 2.5 s (was 3.0).
- Tinkaton: move speed 180 (was 165); `basic` total 28 frames (was 36).
- Gengar: HP 100 (was 90), move speed 260 (was 250).
- Scizor: HP 140 (was 130). Lucario: HP 160 (was 150). Toxicroak: HP 140 (was 132).

**Result (hard, same 792 matches):** Decidueye 60.6, Greninja 58.3, Marshadow 56.8, Gholdengo 55.3, Alakazam 53.0,
Toxicroak 52.3, Blaziken 48.5, Mewtwo 47.7, Gengar 43.2, Tinkaton 42.4, Scizor 40.9, Lucario 40.9. The spread is now
about 20 points (it was about 41). Noise is about +-4 points per fighter, so the small differences are not meaningful.

**Limits:**
- The bots do not dodge Mind Blast, so their connect rate (83%) does not show how dodgeable it is for a player. The
  narrower beam and shorter active time are the change; the dodge itself has only been checked by playing it.
- Mewtwo's gap was spread across all opponents, not one move. His basic whiffed about half the time, which is what the
  reach change targets.

## Session: move check, Vine Lash and Ground Wave fixes (2026-10-21)

**Why:** the user asked to find moves that do not work, check them by controlling the characters, change assets where a move looked wrong, and add a debug tool to the Ctrl+Shift+B panel.

**Method:** a live test (`scratchpad/chk/move_test.gd`, headless) plays each fighter's moves against a still dummy at 60, 100, 150 and 260 px and records starts, hits, damage, projectiles, traps, applied statuses and gap closing. A static audit (`scratchpad/chk/audit_moves.gd`) checks timings, textures and spawn frames.

**Findings and fixes:**
- Mewtwo `basic_down` (Ground Wave): no spawn frame, so the shockwave never spawned. Added `spawn` 6; it now makes 2 shockwaves at every distance. The audit also found a spawn-at-frame-0 case, fixed the same way.
- Decidueye `special2_down` (Vine Lash): pulled a close target but never hit it. The whip opened at frame 9, when the hop had lifted him above a close target. `hit_on` 9 -> 4. Now it hits at 60, 100, 150 and 260 px.
- Asset: `assets/fx/decidueye_vine.png` was purple spiky crowns. Redrawn as a green leafy whip, same size and frame count.
- Tool: "Move check (M)" button in the Ctrl+Shift+B panel (`ui/debug/move_check.gd`). Same test as the headless script; writes `balance/move_check_<time>.txt`.

**Result (headless, all 12 fighters, 336 tests):** 0 script errors. Every move starts. No move is without an effect at every distance (the NEVER STARTED and NO EFFECT lists are empty). The in-game check was run through the panel handler on Decidueye: 7 moves, 28 tests, all started, no dead moves.

**Limits:**
- The live test checks that a move starts and does something. It does not judge whether it looks right; the vine redraw was checked by eye on a contact sheet of all 108 move textures, and it is the only change from that review.
- The test uses a still dummy. Real opponents dodge, so a move's real use can differ.
- The pull result is only a gap check (the gap closed by 20 px or more), not a measure of where the target ended up.

