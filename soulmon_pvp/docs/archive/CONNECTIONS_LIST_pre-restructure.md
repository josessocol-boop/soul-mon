# Soul-Mon PvP - Connections List

## Overview
This document maps the connections between different components in the Soul-Mon PvP codebase to aid in understanding the file structure and relationships.

> **Last synced with the code: 2026-10-14.** The code is the source of truth. Companion file: `STRUCTURES_FUNCTIONS_LIST.md` (what each class, constant and function does).
> **Sync changes in this revision (2026-10-14, character select redesign):** section 16 describes the new Smash-style select screen (tile grid, two preview cards, top and bottom bars). Its scene is now only the root, the shade and the background. Tab on the select screen now cancels (it was swallowed by the P2 branch of `_input()`).
>
> **Sync changes in this revision (2026-10-14, documentation audit):** no gameplay code changed. Corrected: key layout (P1 attack F, special 1 G, special 2 H, ultimate T, Down S; the Q / C keys of the 2026-10-10 playtest pass are superseded); element count is 12; sound folder has 10 files (no `ultimate.wav`); `InputHandler._input()` press capture and `hold_all` ordering in the game loop; F1 / F2 debug keys in ArenaManager; the `KeyTest` overlay; the full tools list (section 17).
>
> **Sync changes in this revision (2026-10-11, Down move art):** `Trap` plays animated strips (`trap_frames` / `trap_fps` / `trap_marker` / `trap_scale`); Down moves point at new art made by `tools/generate_down_fx.py` (`assets/fx/down_*.png`, `proj_quake.png`, `proj_quill.png`, `trap_geyser/whirlpool/pit/snare.png`); `Fighter._update_visuals()` keeps the feet planted when an attack squashes / stretches the sprite.
>
> **Previous revision (2026-10-11, Down moves reworked + input fix):** `Fighter._spawn_scheduled()` now also spawns melee shockwaves (`wave`) and indexed traps (`_spawn_trap(m, i)`); `Projectile` gained gravity / bounce / pierce / root and `Trap` gained arming delay / custom size / root / tint (new move keys, see `STRUCTURES_FUNCTIONS_LIST.md` class 13); `InputHandler._input()` feeds `poll()` through `_pending` and a Down tap latches `down_latch`; `ArenaManager` now creates the F2 key-test overlay (`input_debug.gd`) and toggles it on `debug_keytest`; `Keybinds.EXTRA` holds lists (alternate Down keys). `AIController._pick_down()` reads the Down move itself.
>
> **Previous revision (2026-10-10, aerials / fast fall / Down moves):** the aerial basic attack has its own timing and keeps its hitbox through landing (`Fighter._aerial_motion()`); Down + attack in the air is a steep spike dive; Down in the air is a fast fall and, while rising, a short hop (`Fighter.state_jump()`); `InputHandler.wants_down()` also counts Down held while the press is buffered; every roster fighter defines its own Down variants (`Fighter.variant()`); `AIController._pick_down()` lets bots use them.
>
> **Sync changes in this revision (2026-10-10, playtest fixes):** `restart_round` moved from Y to F5 and a new `debug_hitboxes` action (F1) was added; P1 attack was Q, special 1 was C (both later replaced by the keybinds in `keybinds.gd`, see the 2026-10-14 entry) and S is Down only (P2: attack Num 7, special 1 Num 3, Down Num 5 at that time); InputHandler gained `hold_all`, `down_held`, `down_at`, `fresh()` and `wants_down()`; Fighter gained Down move variants, dash cancel, wavedash glide and the nerfed tech (costs stamina); ArenaManager toggles `Fighter.debug_boxes`.
>
> **Earlier revision:** added the menu -> match flow, Keybinds/GameText, the Settings and UIManager autoloads, the AI internals (behavior-tree nodes, profiles, per-frame loop), the roster/AI-profile map and a Known Connection Hazards section; corrected the camera (ArenaCamera is the live camera, ScreenShake is unused) and the restart key.

## Core Systems & Their Connections

### 1. Fighter Class (`fighter.gd`)
**Central class that all fighter archetypes inherit from**
- **Connected to:**
  - `InputHandler` (creates and manages input for each fighter)
  - `StatsComponent` (manages HP, stamina, status effects)
  - `StateMachine` (handles state transitions like idle, attack, dash, etc.)
  - `SynergySystem` (manages burst gauge and ultimate abilities)
  - `SupportSystem` (manages support Pokémon calls)
  - `hitbox` and `hurtbox` (Area2D nodes for collision detection)
  - `move_fx` (Sprite2D for move effects)
  - Status icon sprites (burn_icon, slow_icon, poison_icon)
  - `sprite` (AnimatedSprite2D for visual representation)
  - **Phase 4:** `got_hit` signal (emits hit info to ArenaManager)
  - **Phase 4:** `event` signal (emits gameplay events: jump, dash, attack, special1, special2, ultimate, shot, trap_set)
  - **Phase 4:** `freeze_frames` (hitstop counter, pauses fighter logic)
  - **Phase 4:** `hit_confirmed` (enables cancel chains on hit; set on the ATTACKER when its melee hit connects, 2026-10-14) and `landed_hit` (set on the attacker for any hit, melee or projectile; read by the AI)

### 2. Fighter Archetypes (fighter_*.gd files)
**Each fighter extends the base Fighter class**
- **Files:** fighter_marshadow.gd, fighter_gholdengo.gd, fighter_blaziken.gd, etc.
- **Connected to:**
  - Base `Fighter` class (inheritance)
  - Specific sprite sheets (sheet_path)
  - Specific effect textures (fx_path)
  - Unique move definitions (_define_moves overrides)
  - Archetype-specific stats (_apply_archetype overrides)

### 3. InputHandler (`input_handler.gd`)
**Manages input buffering and action detection**
- **Connected to:**
  - Each `Fighter` instance (creates one per fighter)
  - InputMap (registers gameplay actions through `Keybinds.register()`; all keys are defined in `keybinds.gd`)
  - Fighter's `_try_actions()` method (consumes buffered inputs)
  - Fighter's `poll()` method (called each frame to update input state)
- **Phase 4:** Per-action buffer windows (`BUFFER_WINDOWS`: attacks/specials/ultimate=9f, movement=6f)
- **Phase 4:** `clear()` method (called on hit to prevent mashing surprises)
- **Phase 4:** `hold_buffers` / `COMBAT_ACTIONS` (keeps combat presses alive during move recovery; the Fighter also sets it during the first part of a dash)
- **Hitstop fix:** `hold_all` (set by `Fighter._physics_process()` BEFORE `poll()` while `freeze_frames > 0`) stops every buffer from counting down during hitstop; new presses are still recorded
- **Down variants:** `down_held` (Down/S state; drives the fast fall / short hop in `Fighter.state_jump()` and Down variants) and `down_at[action]` (was Down held when that press was made). `wants_down(action)` is true if Down was held at the press OR is held now while the press is still buffered. `Fighter._try_actions()` / `_try_special_cancel()` read it to pick the `<move>_down` data; `AIController.buffer_action()` writes `down_at` for bots
- **Tech:** `fresh(action, frames)` tells `state_hitstun()` whether the dash press is recent enough to tech

### 4. StatsComponent (`stats_component.gd`)
**Manages fighter statistics: HP, stamina, status effects, elemental affinities**
- **Connected to:**
  - Each `Fighter` instance (creates one per fighter)
  - Fighter's `receive_hit()` method (applies damage and status effects)
  - Fighter's `take_dot()` method (handles damage over time)
  - Fighter's `_check_death()` method (checks if HP <= 0)
  - Status effect application methods (apply_burn, apply_poison, apply_slow)
  - Elemental type system (type_multiplier static method)
- **Phase 4:** Frame-counter statuses (`burn_left`, `poison_left`, `slow_left`, `burn_phase`, `poison_phase`)
- **Phase 4:** `tick_statuses()` method (called by Fighter each un-frozen physics frame)
- **Phase 4:** `FPS = 60` constant for deterministic frame-based duration

### 5. StateMachine (`state_machine.gd`)
**Handles state transitions for fighters**
- **Connected to:**
  - Each `Fighter` instance (creates one per fighter)
  - Fighter's state methods (state_idle, state_run, state_jump, etc.)
  - Fighter's enter/exit state hooks (enter_attack, exit_attack, etc.)
  - Fighter's `_physics_process` method (calls tick each frame)

### 6. SynergySystem (`synergy_system.gd`)
**Manages burst gauge, burst mode, and ultimate abilities**
- **Connected to:**
  - Each `Fighter` instance (creates one per fighter)
  - Fighter's burst-related variables (burst_fill_hit, burst_fill_dealt, etc.)
  - Fighter's hit connections (on_hit_connect, on_damage_dealt, on_damage_taken)
  - Fighter's burst callbacks (_on_burst_activated, _on_burst_ended, etc.)
  - Fighter's ultimate readiness checks (is_ultimate_available, try_use_ultimate)

### 7. SupportSystem (`support_system.gd`)
**Manages support Pokémon calls**
- **Connected to:**
  - Each `Fighter` instance (creates one per fighter)
  - Fighter's support-related variables (cooldowns, support_called signal)
  - Fighter's support callbacks (_on_support_called)
  - Support definitions (static get_support_definition method)
  - ArenaManager (for spawning support effects)

### 8. ArenaManager (`arena_manager.gd`)
**Central game manager that owns the arena, fighters, HUD, and game flow**
- **Connected to:**
  - Two `Fighter` instances (p1, p2)
  - `HUD` (displays fighter information)
  - `CharacterSelect` (character selection screen)
  - `AIController` (for CPU fighters)
  - `ArenaCamera` (dynamic camera following fighters)
  - `Sfx` (sound effects manager) - **Phase 4**
  - `ArenaCamera` shake (`shake()` / `add_trauma()`) - the live screen shake; `ScreenShake` (`screen_shake.gd`) is legacy and never instantiated
  - `GameText` (win banner text) and `Keybinds` (actions `menu_toggle`, `restart_round`, `debug_hitboxes`, `debug_keytest`)
  - `KeyTest` (`input_debug.gd`, F2 overlay): created in `_setup()`, shown or hidden in `_unhandled_input()`
  - `Settings` (`last_mode`, `difficulty`, `view_mode_only`)
  - `ColorRect` flash layer - **Phase 4**
  - Fighter signals (died, got_hit, event) - **Phase 4: got_hit, event added**
  - ROSTER constant (list of available fighters)
  - Settings access (for difficulty and view mode)
- **Phase 4:** `_build_juice()` - creates ArenaCamera (made current), Sfx, flash layer
- **Phase 4:** `_on_got_hit(info)` - spawns HitVfx, DamageNumber, plays SFX, triggers screen shake
- **Phase 4:** `_on_fighter_event(kind, pos)` - plays event sounds, ultimate screen flash

### 9. HUD (`hud.gd`)
**Displays fighter information and controls hint**
- **Connected to:**
  - Two `Fighter` instances (bound via bind() method)
  - Fighter HUD components (`fighter_hud.tscn` instances for P1/P2)
  - Banner label (for round announcements)
  - Help panel (controls hint, text built by `GameText.controls_help()` from the live key bindings; `refresh_help()` rebuilds it)
  - ArenaManager (added as child and updated each frame)

### 10. FighterHUD (`fighter_hud.tscn` with `fighter_hud.gd`)
**Displays individual fighter stats (HP, stamina, etc.)**
- **Connected to:**
  - HUD (instanced as P1 and P2 blocks)
  - Individual Fighter stats (HP, stamina, etc. via update_from method)
  - Status effect icons (burn, slow, poison)
  - Skill slots (for special moves)

### 11. Projectile System (`projectile.gd` + `projectile.tscn`)
**Handles projectile spawning and behavior**
- **Connected to:**
  - Fighter's `_spawn_projectile()` method
  - ArenaManager (added as child to combat_root)
  - Fighter's move definitions (projectile kind moves, and melee moves with `wave: true`, which spawn one shot each way via `_spawn_projectile(m, vy, dir)`)
  - SupportSystem (for support projectile effects)
  - Target Fighter: `receive_hit()`, and `rooted_time` when the move has `root`
- **Phase 4:** Emits `event("shot", pos)` on spawn

### 12. Trap System (`trap.gd` (no scene: `Fighter._spawn_trap()` creates it with `load("res://trap.gd").new()`))
**Handles trap spawning and behavior**
- **Connected to:**
  - Fighter's `_spawn_trap()` method
  - ArenaManager (added as child to combat_root)
  - Fighter's move definitions (trap kind moves; `spawn_count` > 1 + `trap_step` lays several traps in a row via `_spawn_trap(m, index)`)
  - SupportSystem (for support trap effects)
  - Target Fighter: `receive_hit()`, and `rooted_time` when the move has `root`
- **Phase 4:** Emits `event("trap_set", pos)` on spawn

### 13. AI System (`AIController.gd`, `AIBehavior.gd`, `AIProfile.gd`)
**Provides computer-controlled fighter behavior**
- **Connected to:**
  - ArenaManager (_attach_ai method)
  - Fighter instances (added as child when CPU-controlled)
  - Target fighter reference (set via set_target)
  - AI behavior trees and profiles

### 14. Screen Shake & Visual Effects (**Phase 4**)
**Handles screen shake, hit flashes, and visual juicing**
- **ArenaCamera (`ArenaCamera.gd`) - the live camera and shake:**
  - Extends Camera2D, created by `ArenaManager._build_juice()` and made current
  - `set_targets(p1, p2)` (called from `_start_match`) -> follows the midpoint, zooms 2.4 (close) to 1.6 (far), stays inside `ARENA_RECT`
  - `shake(strength, frames)` - linear-decay shake; `add_trauma(amount)` - squared-trauma shake that decays over time
  - Connected to: ArenaManager (`camera` variable; `_on_got_hit`, `_on_fighter_event`)
- **ScreenShake (`screen_shake.gd`) - LEGACY, unused:** an older Camera2D with only the timed `shake()`; nothing creates it any more
- **HitVfx (`hit_vfx.gd`):**
  - One-shot elemental burst: ring + sparks + particle emitter
  - `spawn(parent, info)` - static factory from Fighter.got_hit info
  - Element-specific styles (12 elements: Normal, Fire, Water, Grass, Ice, Steel, Ghost, Fighting, Fairy, Bug, Dark, Poison)
  - Super-effective: gold star burst overlay
  - Connected to: ArenaManager._on_got_hit() spawns in combat_root
- **DamageNumber (`damage_number.gd`):**
  - Floating damage popup Label
  - Gold "!" for super-effective, muted for resisted, red for KO
  - Tween animation: rise, scale pop, fade out
  - Connected to: ArenaManager._on_got_hit() spawns in combat_root

### 15. Audio System (`sfx.gd`) (**Phase 4**)
**Manages sound effects**
- **Connected to:**
  - ArenaManager (sfx instance)
  - Fighter hit reactions (via _on_got_hit and _on_fighter_event)
  - Event sounds mapping (EVENT_SOUNDS constant: jump, dash, attack, special1, special2, ultimate, shot, trap_set)
  - Element-based pitch variation (ELEMENT_PITCH constant)
  - Audio pool (12 AudioStreamPlayer2D instances)
  - Loads from `res://assets/audio/<name>.wav` (missing files silently skipped; 10 files exist, `ultimate` has none yet)

### 16. Character Select System (`character_select.gd` + `character_select.tscn`) - **redesigned 2026-10-14, flow changed the same day**
**Smash-style fighter select screen, and the place where the mode is chosen.** The `.tscn` holds only the root `CanvasLayer` (script), `BackgroundShade` and `BackgroundArt`; the whole UI is built in code.
- **Screen layout:** top bar (BACK, title, mode label "PLAYER VS CPU" etc., `CPU LEVEL` button) -> a centred grid of fixed-size tiles in rows of `ROW_LENGTH` (5), inside a scroll box of `GRID_HEIGHT` (380 px) (one tile per `ROSTER` entry, cursor badges P1 / P2 / CPU, gold border when both cursors share a tile) -> two fixed-height side panels (P1 left in blue, P2 right in red; each has a PLAYER / CPU switch, READY and the preview) -> bottom bar (controls hint from `Keybinds.fmt`, START).
- **Mode:** each side's PLAYER / CPU switch (button, or `p1_cpu_toggle` = Q, `p2_cpu_toggle` = Num +). `mode_name(p1_cpu, p2_cpu)` gives the mode string that `ArenaManager` and `Settings.last_mode` use. The mode select scene (`mode_select.tscn`) is no longer in the flow.
- **Card contents:** 192 px animated portrait and name, element chips (`HitVfx.STYLE` colours, `StatsComponent.Element` names), STATS bars (HP / SPEED / JUMP, roster-relative), MOVES grid (ATTACK / SPECIAL 1 / SPECIAL 2 / ULTIMATE with damage, `xN` hits, stamina cost, cooldown), READY stamp and READY button in the panel header.
- **Connected to:**
  - ArenaManager (instanced and managed via signals; `open_select(ROSTER, ..., from_menu)` from Play / Characters through `_setup()` and from Tab in a match; `select_menu.visible` is checked in `_unhandled_input`; `returns_to_menu` decides whether BACK goes to the main menu or resumes the match)
  - ROSTER data (from ArenaManager; the fighter's `id`, `name`, `scene`, `sheet`, `color`). Adding a roster entry is enough: the tile, its row, its stat bars and its move list are generated.
  - Selection signals (`start_requested` -> `ArenaManager._on_selection_applied`, `cancel_requested` -> `_on_selection_cancelled`, `mode_changed` -> `_on_mode_changed`)
  - Fighter scenes, read once for stats and moves: `_data_instance()` loads `ROSTER[i].scene`, calls `_apply_archetype()` by hand (the scene is never added to the tree) and frees it after `_fighter_info()` has read `hp_max`, `move_speed`, `jump_velocity`, `get_types()` and `_define_moves()`
  - `AnimatedPortrait` (one per tile and one per panel), `HitVfx.STYLE` (element chip colours), `StatsComponent.Element` (chip names), `Keybinds.fmt()` (key labels in the hints), `InputHandler.register_actions()` (on `_ready`)
  - Input: `p1_nav_*` / `p1_select`, `p2_nav_*` / `p2_select`, `p1_cpu_toggle`, `p2_cpu_toggle`, `cpu_level` (C), and `menu_toggle` (Tab = BACK; checked before the P2 branch). Enter / Num Enter go through `_select_pressed()`: the first press readies the side, the next press starts once `_can_start()` allows it. Left / right mouse click on a tile places P1 / P2's cursor.
  - `Settings` (`_on_start` saves `last_p1_fighter`, `last_p2_fighter`, `last_mode` and `difficulty`; `_cycle_level` saves the difficulty at once)

### 17. Tools Directory (`tools/`, not used by the running game)
**Asset and audio generators, importers and previews.** Run from the project root with Python 3 (Pillow, and numpy where noted). None of them is loaded by the game; they only write files into `assets/`.
- **Authoritative art build:** `generate_pixel_art.py` writes all pixel-art assets: the 8 roster sheets (from `pixel_characters.py`), per-move effect strips, projectiles, traps, status icons, arena tiles and background, and `fx_table.gd` (fighter id + move key -> art). **`fx_table.gd` is not in this project**: the generator writes it into the project root, but nothing in the game loads it, so the move `fx` keys in `fighter_*.gd` are what the game uses. Shared helpers: `pixel_core.py` (cel shading, outline, sheet builder) and `pixel_effects.py` (effect shapes, projectiles, traps, icons, arena art).
- **Down-move effects:** `generate_down_fx.py` writes `assets/fx/down_*.png`, `proj_quake.png`, `proj_quill.png` and the animated trap strips (`trap_geyser/whirlpool/pit/snare.png`). Uses `pixel_effects.py`.
- **Placeholder sounds:** `generate_sfx.py` (stdlib only) writes `assets/audio/*.wav`.
- **Legacy generators (do NOT run on this project):** `generate_art.py` (effects and arena art; `--sheets` also overwrites every `assets/*_sheet.png`), `generate_roster_art.py` (roster sheets) and `marshadow_test_art.py` (Marshadow test sheet). They overwrite art that is already in use.
- **Sheet importers / cleanup (numpy):** `import_green_sheet.py` turns a green-background 6 x 7 sheet into a 384 x 448 game sheet (used for `tinkaton_sheet.png`); `clean_sheet_palette.py` removes green fringes and reduces a sheet to a small flat palette (used on `gengar_sheet.png` on 2026-10-11).
- **Previews:** `preview_chars.py` and `preview_fx.py` write contact sheets for review; they write only to the path you give them.
- **Other files:** `tools/__pycache__/` is a Python build cache (safe to delete). The project root also has `apply_phase4.py`, a one-off patch script from Phase 4 that is not used at runtime.
- **Connected to:** `assets/*_sheet.png`, `assets/fx/*`, `assets/audio/*`, `assets/icon_*`, `assets/background.png`. Changing an output name requires changing the game code that loads it (for example `Fighter.sheet_path`, `ArenaManager.ROSTER`, `fighter_*.gd` move `fx` keys).

### 18a. Down move variants, aerials, fast fall (`fighter.gd`, `input_handler.gd`, `AIController.gd`, `fighter_*.gd`) - **reworked**
- **Flow:** `InputHandler._input()` notes the press the instant it arrives (`_pending`, and `down_latch` on a Down press) -> `InputHandler.poll()` records `down_at[action]` (Down held OR tapped within `DOWN_LATCH_FRAMES`) -> `Fighter._try_actions()` / `_try_special_cancel()` call `_move_data(key, wants_down)` to check cost/cooldown, set `down_next`, then `sm.change(key)` -> `_enter_move(key)` reads `down_next` and copies `moves[key + "_down"]` into `cur_move`.
- **Move toolkit:** the Down moves use optional move keys (`wave`, `proj_gravity`, `proj_bounce`, `proj_pierce`, `trap_delay`, `trap_size`, `trap_step`, `root`, `teleport_distance`, `i_frames`, `hit_interval`, `kind` swaps such as melee -> projectile / trap / dive) handled by `Fighter._enter_move()`, `_run_move()`, `_spawn_scheduled()`, `Projectile` and `Trap`.
- **Data source:** each roster fighter defines `basic_down`, `special1_down`, `special2_down` at the end of its `_define_moves()` with `variant(m.<key>, {...})` (the normal move with a few values overridden); any key a fighter does not define (Brawler, Zoner) is built by `_derive_down_variant()` in `_ready()`. Ultimate has no variant. The per-fighter list is in `STRUCTURES_FUNCTIONS_LIST.md` ("Down move guide").
- **Shared with the normal move:** state name, `cur_key`, cooldown slot, animation profile and cancel chains.
- **In the air:** Down + attack = spike dive (`_enter_move()` keeps `want_down` for the aerial and does NOT use `basic_down`); Down + special uses the `special*_down` data; Down alone = fast fall (falling) or short hop (rising) in `state_jump()`.
- **Aerial attack flow:** `_enter_move()` (own timing: hitbox on at `AERIAL_ON`) -> `_run_move()` -> `_aerial_motion()` (dive, record `aerial_land`, hold the hitbox `AERIAL_MIN_ACTIVE` frames, landing lag) -> `_finish_move()`; `_update_visuals()` rotates the sprite until landing; `receive_hit()` turns the spike into a pop-up on a grounded target.
- **AI:** `AIController.buffer_action()` sets `input_handler.down_at[action]` from `_pick_down()` (situational, random, scaled by difficulty `accuracy`), so bots use Down variants too.

### 18. Keybinds and GameText (`keybinds.gd`, `game_text.gd`) - **new**
**One place for keys, one place for on-screen text** (both `extends RefCounted`, no `class_name`, loaded with `preload`)
- **Keybinds** is connected to:
  - `InputHandler.register_actions()` -> `Keybinds.register()` (adds every missing action to the `InputMap`)
  - `GameText` (`Keybinds.fmt()` fills `{action_name}` placeholders with the real current key)
  - Anything that wants a runtime rebind (`rebind()`) or a key label (`key_name()`)
- **GameText** is connected to:
  - HUD (`controls_help()` for the controls hint)
  - CharacterSelect (`mode_hint(mode)` for the mode label)
  - ArenaManager (`win_banner(name)` for the round-over banner)
- Result: change a key in `keybinds.gd` and the behaviour **and** every hint change together.

### 19. Autoloads: Settings and UIManager (`project.godot` [autoload]) - **new**
- **Settings** (`settings.gd`) - persistent `ConfigFile` at `user://settings.cfg`
  - Read by: ModeSelect (initial difficulty), OptionsMenu (sliders), CharacterSelect (saves last fighters/mode), ArenaManager (`last_mode`, `difficulty`, `view_mode_only`)
  - Written by: ModeSelect (Continue), OptionsMenu (sliders), CharacterSelect (`_on_start`)
  - `view_mode_only` is a one-shot runtime flag: set by MainMenu "Characters" and ModeSelect "Continue", cleared by ArenaManager when it opens character select
- **UIManager** (`ui_manager.gd`) - menu stack
  - Used by: MainMenu (`show_menu` for Mode Select and Options), ModeSelect (`go_back`, `clear_stack`), OptionsMenu (`go_back`)
  - Menus are instanced on the scene root, on top of whatever scene is current (the main menu stays underneath until the stack is cleared and the scene is changed)

### 20. Menu scenes (`main_menu`, `mode_select`, `options_menu`) - **new**
- **MainMenu** (`main_scene`) -> UIManager (Play, Options), Settings + `main.tscn` (Characters)
- **ModeSelect** -> Settings, UIManager, `main.tscn`; emits `mode_selected(mode, difficulty)` (no listener at the moment)
- **OptionsMenu** -> Settings, UIManager
- **AnimatedPortrait** -> CharacterSelect (portrait per player); **SkillSlot** -> FighterHUD (special-move indicators)

### 21. AI internals (`AIController.gd`, `bt_*.gd`, `AIProfile.gd`, `ai_profiles/*.tres`) - **rewritten 2026-10-14 (AI pass)**
- **AIController** is added as a child of a CPU fighter by `ArenaManager._attach_ai()`; `setup()` finds the fighter's `InputHandler` (switched to `remote = true`)
- **Profile lookup:** `_load_profile()` takes the fighter id from the scene file name and loads `res://ai_profiles/<id>.tres` (an `AIProfile` resource); no file (Brawler, Zoner) -> default balanced profile
- **Tree:** `_build_behavior_tree()` builds the nodes in code; priority: anti-air > whiff punish > zoning response > personality engagement tree. Attack actions are gated by `_can_use()` (reach, height, projectile range), so the bot only presses what can connect
- **Per frame:** `_update_whiff_tracking()`, `_update_own_hits()` (combo follow-ups queued the frame the move connects), `_drive_movement()` (`input_handler.decay_buffers()`, facing); at each decision: `decision_dt` = real time since the last decision, `_update_movement()`, `behavior_tree.tick(self)`
- **Timing:** `bt_*` nodes count cooldowns and durations with `decision_dt` (`AIBehavior._get_delta`), not physics frames, because the tree only ticks at the reaction interval
- **Output path:** `Action` nodes call `AIController.buffer_action()`, which writes into the fighter's `InputHandler.buffer` (and `down_at` through `_pick_down()`) - the same buffer a human fills, so the Fighter code is identical for bots and players. Buffer countdown for bots is `InputHandler.decay_buffers()`, with the same hold rules as a keyboard press (hitstop, long moves)
- **Information it reads:** the opponent's position, velocity, state, `cur_move` and `landed_hit`; its own `landed_hit` / `cur_key`; `Projectile` nodes in the arena (`shooter`, `dir`). Never the opponent's input buffer
- **Difficulty:** `ArenaManager` passes the `Settings` difficulty; `_apply_difficulty()` sets `reaction_time = BASE_REACTION_TIME[difficulty] * (1 + profile.reaction_bonus)` (easy 0.4 s, medium 0.25 s, hard 0.15 s), `accuracy` from `DIFFICULTY_MULTIPLIERS` (0.5 / 0.7 / 0.85) and `aggressiveness = profile.aggressiveness * multiplier` (0.7 / 1.0 / 1.2, now used by plain attacks)

### 22. Roster map - **new**
- `ArenaManager.ROSTER` (8): gholdengo, marshadow, tinkaton, greninja, scizor, decidueye, blaziken, gengar -> each entry points to `fighter_<id>.tscn` (script `fighter_<id>.gd`), `assets/<id>_sheet.png` and `ai_profiles/<id>.tres`
- Not in ROSTER: `fighter_brawler` and `fighter_zoner` (kept in the project, no AI profile)
- CharacterSelect reads the roster passed by `open_select()` (or `ArenaManager.ROSTER` through `get_script_constant_map()`)

## Data Flow Summary

### 1. Initialization:
- ArenaManager loads and sets up the game scene
- Creates two Fighter instances based on selection
- Each Fighter creates its own InputHandler, StatsComponent, StateMachine, SynergySystem, SupportSystem
- ArenaManager binds fighters to HUD and sets up camera
- **Phase 4:** ArenaManager._build_juice() creates ArenaCamera (camera), Sfx, flash layer

### 2. Game Loop (per frame):
- `InputHandler._input()` records each key press as it arrives (`_pending`, `down_latch`)
- Fighter's _physics_process:
  - First sets `input.hold_all = freeze_frames > 0`, then calls `input.poll()` (the order matters: hitstop must not eat buffered presses)
  - If `freeze_frames > 0`: decrement, update visuals, return early (hitstop - **Phase 4**)
  - Else: stats.tick(delta), stats.tick_statuses() (**Phase 4**)
  - StateMachine.tick calls appropriate state_* method
- Fighter state methods handle movement, actions, and state transitions
- Fighters check for hits, apply damage, manage status effects
- SynergySystem and SupportSystem update their timers and gauges
- HUD updates from fighter stats each frame
- ArenaManager handles hit reactions, screen shake, audio, and visual effects

### 3. Action Flow (when player presses buttons):
- InputHandler buffers the press (per-action windows - **Phase 4**)
- Fighter's _try_actions checks for buffered inputs and changes state
- StateMachine calls enter_* method for new state
- Fighter's _enter_move sets up move-specific variables
  - **Aerial / Down:** `_enter_move()` turns an airborne basic into the aerial dive (spike dive with Down) and picks `<key>_down` data on the ground when `down_next` was set
  - **Phase 4:** Emits `event("jump"/"dash"/"attack"/etc., pos)`
- StateMachine calls _run_move each frame during the move
- _run_move handles hit detection, movement, and move completion
  - **Aerial:** melee moves marked `is_aerial` are moved by `_aerial_motion()`, which keeps the hitbox alive through the landing
  - **Phase 4:** On hit: `hit_confirmed = true`, `freeze_frames = hitstop`
  - **Phase 4:** Cancel chains: if hit_confirmed and move on active frames, `_try_special_cancel()` checks for buffered special/ultimate
- On hit: receive_hit applies damage/status, emits got_hit signal
- **Phase 4:** ArenaManager._on_got_hit() spawns HitVfx, DamageNumber, plays SFX, shakes the ArenaCamera
- Fighter's SynergySystem and SupportSystem update based on hits/dealt damage
- HUD updates to reflect new stats

## Menu and Match Flow - **new**

```
main_menu.tscn (main_scene)
 ├─ Play ────────► Settings.set_view_mode_only(true) ─► change_scene_to_file(main.tscn)
 ├─ Characters ──► (same as Play)
 ├─ Options ─────► UIManager.show_menu(options_menu.tscn) ─► Settings sliders
 └─ Quit

main.tscn ─► ArenaManager._setup()
 ├─ InputHandler.register_actions() ─► Keybinds.register()
 ├─ _build_arena() + _build_juice() (ArenaCamera, Sfx, flash) + HUD + CharacterSelect (hidden)
 ├─ Settings.view_mode_only? ─ yes ─► clear flag, CharacterSelect.open_select(..., from_menu = true) with the tree paused
 │                              └ no  ─► _start_match(_current_match_ids())
 ├─ CharacterSelect.start_requested(p1_id, p2_id) ─► _on_selection_applied() ─► _start_match()
 │    (ids carry a "cpu_" prefix for bot sides; _start_match strips it and sets current_mode = CharacterSelect.mode_name())
 └─ CharacterSelect.cancel_requested ─► _on_selection_cancelled()
      from_menu: hide, unpause, change_scene_to_file(main_menu.tscn)
      otherwise: hide and resume the match

In a match:  Tab (menu_toggle) ─► CharacterSelect.open_select (paused, from_menu = false)
             F5  (restart_round) ─► _start_match(_current_match_ids())
             F1  (debug_hitboxes) ─► toggles static Fighter.debug_boxes (every Fighter redraws its hitbox/hurtbox overlay)
             F2  (debug_keytest) ─► toggles the key test overlay (input_debug.gd): shows which keys the keyboard really sends
```

## Key Connection Points

- **Keybinds → InputMap:** defines every action once; `GameText` and the HUD/CharacterSelect hints read it back through `Keybinds.fmt()`
- **Settings ↔ OptionsMenu / CharacterSelect / ArenaManager:** persistent choices and the one-shot `view_mode_only` flag
- **UIManager ↔ MainMenu / ModeSelect / OptionsMenu:** menu stack on the scene root
- **ArenaManager ↔ ArenaCamera:** 1:1 (`set_targets`, `shake`, `add_trauma`)
- **ArenaManager ↔ AIController:** 0..2 (one per CPU fighter); **AIController → InputHandler (remote):** writes the same buffer a human fills
- **AIController ↔ AIProfile:** 1:1, loaded from `ai_profiles/<id>.tres`
- **Fighter ↔ InputHandler:** 1:1 composition (each fighter has its own input handler)
- **Fighter ↔ StatsComponent:** 1:1 composition (stats management)
- **Fighter ↔ StateMachine:** 1:1 composition (state management)
- **Fighter ↔ SynergySystem:** 1:1 composition (burst gauge management)
- **Fighter ↔ SupportSystem:** 1:1 composition (support call management)
- **Fighter ↔ ArenaManager:** Many:1 (arena manages fighter lifecycle and interactions)
- **Fighter ↔ HUD:** Many:1 (HUD displays multiple fighters)
- **ArenaManager ↔ HUD:** 1:1 (arena owns and updates HUD)
- **ArenaManager ↔ Fighter:** 1:2 (arena manages exactly two fighters in combat)
- **Fighter ↔ Projectile/Trap:** 1:Many (fighters can spawn multiple projectiles/traps)
- **Fighter ↔ AIController:** 0:1 (only for CPU-controlled fighters)
- **Phase 4:** **Fighter → ArenaManager:** `got_hit(info)` signal with hit details (pos, element, dmg, mult, dir, heavy, ko, hitstop, kb)
- **Phase 4:** **Fighter → ArenaManager:** `event(kind, pos)` signal for gameplay sounds/VFX
- **Phase 4:** **ArenaManager → ArenaCamera/Sfx/HitVfx/DamageNumber:** Owns and triggers all juice systems
- **Phase 4:** **StatsComponent → Fighter:** `tick_statuses()` called during un-frozen physics frames
- **Phase 4:** **InputHandler → Fighter:** `clear()` called on hit to reset buffers

## Known Connection Hazards (as of 2026-10-14) - **new**
Observations from reading the code; none of these have been changed in this documentation pass.
- ~~`Y` was bound to two actions~~ - **fixed:** `restart_round` is now F5.
- ~~**Aerial attacks wrote into the shared move dictionary.**~~ (already fixed: `_enter_move()` uses `.duplicate()`) Old description: `Fighter._enter_move()` sets `cur_move = moves[key]` and then edits `cur_move.kb` / `cur_move.is_aerial`, so after the first airborne basic attack the grounded basic attack keeps the aerial knockback. (Details in `STRUCTURES_FUNCTIONS_LIST.md`, Known Issues.)
- **Dead links:** `ScreenShake` is never created; `ModeSelect.mode_selected` and `UIManager.menu_changed` have no listeners (state travels through `Settings`).
- **Keyboard ghosting (not a code bug):** W + S + attack held together can fail on keyboards that cannot report three keys at once. The F2 key test shows it; mitigations are the Down tap latch and the alternate Down keys (Ctrl / Shift for P1, Num 2 / Num Enter for P2). Num 2 and Num Enter (P2's alternate Down keys) are also `p2_nav_down` / `p2_select`, which only matter in the menus. P2 support 3 moved from Num 0 (same as P2 dash) to Num -.
- **Flat arena:** projectile spawn points and the world check (`Projectile` frees itself when its centre is inside any `StaticBody2D`) assume only the floor, ceiling and two walls exist; add platforms with that in mind.
- ~~**Aerial attacks were cancelled by landing before their hitbox existed**~~ **fixed** (2026-10-10): the aerial no longer uses the ground move's `on` frame and landing now only ends it after `AERIAL_MIN_ACTIVE` frames plus `AERIAL_LAND_LAG`.
- **Fast fall used to read the keyboard directly and only worked with no left/right input:** now it uses `input.down_held` (works for bots/remote input) and no longer requires neutral steering.
