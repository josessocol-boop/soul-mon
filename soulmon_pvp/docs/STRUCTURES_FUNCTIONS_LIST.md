# Structures and functions

Generated from the code on the restructured project. The descriptions are the first doc comment in each file.
To regenerate, use the scan in `docs/ARCHITECTURE.md` (names, signals, constants, functions). Hand-written reasoning lives in `CONNECTIONS_LIST.md`.

## Files and classes

### Fighter model (core/)

#### `core/fighter.gd`
- class `Fighter`, extends `CharacterBody2D`
- Base fighter. Archetypes subclass this and override _apply_archetype()
- signals: `died`, `got_hit`, `event`, `status_damaged`
- constants: `WALL_LEFT_X`, `WALL_RIGHT_X`, `BODY_RADIUS`, `GRAVITY_RISE`, `GRAVITY_FALL`, `JUMP_CUT`, `GROUND_ACCEL`, `AIR_ACCEL`, `ATTACK_STAMINA_GAIN`, `HITSTUN_FRAMES`, `HITSTOP_SCALE`, `KO_HITSTOP`, `AERIAL_ATTACK_PUSH`, `AERIAL_HOP`, `AERIAL_KB_Y`, `AERIAL_ANGLE`, `AERIAL_ON`, `AERIAL_ACTIVE`, `AERIAL_MIN_ACTIVE`, `AERIAL_LAND_LAG`, `AERIAL_DOWN_PUSH`, `AERIAL_DOWN_HOP`, `AERIAL_DOWN_ANGLE`, `AERIAL_DOWN_KB_Y`, `AERIAL_DOWN_POP_Y`, `AERIAL_DOWN_MIN_ACTIVE`, `AERIAL_DOWN_LAND_LAG`, `DOWN_CUT_SPEED`, `DOWN_CUT_STEP`, `FAST_FALL_CAP`, `DI_INFLUENCE`, `TECH_PRESS_FRAMES`, `TECH_COST`, `TECH_WINDOW`, `TECH_IFRAMES`, `TECH_RECOVERY`, `TECH_COOLDOWN`, `WAVE_DMG_MULT`, `COYOTE_FRAMES`, `DOWN_VARIANT_KEYS` ...
- functions: `arena_x`, `get_types`, `_apply_archetype`, `_define_moves`, `_define_moves_default`, `_derive_down_variant`, `_ultimate_press`, `_ultimate_locked`, `ult_meter`, `_move_data`, `mv`, `variant`, `configure`, `_ready`, `_physics_process`, `cooldown_ratio`, `_gravity`, `_steer`, `_try_actions`, `_restore_hurtbox`, `_hitbox_off`, `_check_hits`, `receive_hit`, `_hitstop_frames`, `_apply_status`, `take_dot`, `_check_death`, `_on_burst_activated`, `_on_burst_ended`, `_on_ultimate_ready`, `_on_ultimate_used`, `_on_support_called`, `_enter_move`, `_move_animation_profile`, `_run_move`, `_aerial_motion`, `_try_special_cancel`, `_finish_move`, `_move_dive`, `_spawn_scheduled`, `current_label`, `_labelled`, `_spawn_projectile`, `_spawn_trap`, `_end_move`, `state_idle`, `state_run`, `state_jump`, `_wavedash`, `enter_dash`, `state_dash`, `exit_dash`, `enter_attack`, `state_attack`, `exit_attack`, `enter_special1`, `state_special1`, `exit_special1`, `enter_special2`, `state_special2` ...

#### `core/input_handler.gd`
- class `InputHandler`, extends `Node`
- Separated from the Fighter so a NetworkManager can later feed remote input
- constants: `BUFFER_WINDOWS`, `COMBAT_ACTIONS`, `DOWN_LATCH_FRAMES`
- functions: `_input`, `poll`, `decay_buffers`, `want`, `fresh`, `wants_down`, `consume`, `clear`, `register_actions`

#### `core/projectile.gd`
- class `Projectile`, extends `Node2D`
- Data-driven projectile. All numbers come from the casting move's dictionary
- constants: `WORLD_GRACE_FRAMES`
- functions: `setup`, `_ready`, `_physics_process`

#### `core/state_machine.gd`
- class `StateMachine`, extends `Node`
- Calls fighter.state_<name>(delta) each tick, plus optional
- functions: `start`, `change`, `tick`, `_hook`

#### `core/stats_component.gd`
- class `StatsComponent`, extends `Node`
- signals: `burn_ticked`, `poison_ticked`
- constants: `DASH_COST`, `REGEN_PER_SEC`, `RECOVER_AT`, `BURN_DAMAGE`, `BURN_TICKS`, `POISON_DAMAGE`, `POISON_TICKS`, `SLOW_FACTOR`, `SLOW_TIME`, `SUPER`, `RESIST`, `IMMUNE`, `FPS`
- functions: `_ready`, `tick`, `can_spend`, `spend`, `gain_stamina`, `tick_statuses`, `apply_burn`, `apply_poison`, `apply_slow`, `burning`, `poisoned`, `slowed`, `get_speed`, `clear_statuses`, `type_multiplier`

#### `core/support_system.gd`
- class `SupportSystem`, extends `Node`
- Manages Support Pokémon calls - assist attacks, buffs, and utility.
- signals: `support_called`, `support_ready`, `support_cooldown`
- constants: `MAX_SUPPORTS`, `BASE_COOLDOWN`
- functions: `get_support_definition`, `_ready`, `set_player`, `set_supports`, `_process`, `try_call_support`, `_apply_support_effect`, `_apply_instant_effect`, `_apply_duration_effect`, `_remove_effect`, `get_damage_multiplier`, `get_cooldown_remaining`, `is_support_ready`, `reset`

#### `core/synergy_system.gd`
- class `SynergySystem`, extends `Node`
- Manages Synergy Burst gauge, Burst Mode activation, and One-Time Ultimate gating.
- signals: `burst_activated`, `burst_ended`, `ultimate_ready`, `ultimate_used`, `gauge_changed`
- constants: `GAUGE_MAX`, `GAUGE_FILL_ON_HIT`, `GAUGE_FILL_ON_DEALT`, `GAUGE_FILL_ON_TAKEN`, `GAUGE_FILL_PASSIVE`, `BURST_DURATION`, `BURST_COOLDOWN`, `ULTIMATE_COST`
- functions: `_ready`, `set_player`, `set_archetype_traits`, `_process`, `_fill_gauge`, `on_hit_connect`, `on_damage_dealt`, `on_damage_taken`, `try_activate_burst`, `_end_burst`, `try_use_ultimate`, `get_burst_time_remaining`, `get_cooldown_remaining`, `is_burst_active`, `is_ultimate_available`, `reset`

#### `core/trap.gd`
- class `Trap`, extends `Node2D`
- Static ground hazard. By default lasts 3 s and springs once on an enemy.
- functions: `setup`, `_ready`, `_set_visual_size`, `_set_frame`, `_physics_process`

### Fighters (fighters/)

#### `fighters/alakazam/fighter_alakazam.gd`
- no class_name, extends `Fighter`
- Alakazam (Psychic): tricky zoner. Psybeam bursts, a bouncing Psywave, Future Sight traps, Reflect stance.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/blaziken/fighter_blaziken.gd`
- no class_name, extends `Fighter`
- Blaziken (Fire/Fighting): aggressive aerial fighter. High jump; rising kick and dive kick.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/decidueye/fighter_decidueye.gd`
- no class_name, extends `Fighter`
- Decidueye (Grass/Ghost): long-range zoner. Low HP, screen-crossing arrows, leafy trap.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/gengar/fighter_gengar.gd`
- no class_name, extends `Fighter`
- Gengar (Ghost/Poison): tricky evasive zoner. Floaty jumps, shadow balls, poison trap.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/gholdengo/fighter_gholdengo.gd`
- no class_name, extends `Fighter`
- Gholdengo (Steel/Ghost): mid-range zoner. Surfboard swings and gold-coin projectiles.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/greninja/fighter_greninja.gd`
- no class_name, extends `Fighter`
- Greninja (Water/Dark): high-mobility zoner. Huge jump, fast fall, water blades and shurikens.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/lucario/fighter_lucario.gd`
- no class_name, extends `Fighter`
- Lucario (Fighting/Steel): combo rushdown. Bone Rush strings, aura projectiles, Swords Dance, Extreme Speed.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/marshadow/fighter_marshadow.gd`
- no class_name, extends `Fighter`
- Marshadow (Ghost/Fighting): fast close-range assassin. Extended shadow dash (more i-frames, sinks into the floor).
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/mewtwo/fighter_mewtwo.gd`
- no class_name, extends `Fighter`
- Mewtwo (Psychic): balanced boss. Ultimate = Mega Mewtwo Y Awakening, and only that: the ULT key starts Burst
- constants: `AWAKEN_COST`, `AWAKEN_FRAMES`, `BALL_TEX`, `BALL_BODY`, `BALL_FLOAT`, `MEGA_SHEET`
- functions: `_apply_archetype`, `_define_moves`, `_awakened_moves`, `_awakened_cost`, `_ultimate_press`, `_ultimate_locked`, `ult_meter`, `_on_burst_activated`, `_physics_process`, `_start_awaken`, `_tick_awaken`, `_awaken_reveal`, `_end_awaken`, `_smooth`, `_on_burst_ended`, `_use_sheet`

#### `fighters/placeholders/fighter_brawler.gd`
- no class_name, extends `Fighter`
- Fire-type melee bruiser: high HP, slow, heavy, big knockback.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/placeholders/fighter_zoner.gd`
- no class_name, extends `Fighter`
- Water-type ranged fighter: fragile, fast, high jump, projectile + trap.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/scizor/fighter_scizor.gd`
- no class_name, extends `Fighter`
- Scizor (Bug/Steel): rushdown brawler. Heavy gravity, fast cheap dashes, bullet-punch flurry.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/tinkaton/fighter_tinkaton.gd`
- no class_name, extends `Fighter`
- Tinkaton (Fairy/Steel): the heavy brawler. Very slow, huge hammer swings, big knockback and hitstun.
- functions: `_apply_archetype`, `_define_moves`

#### `fighters/toxicroak/fighter_toxicroak.gd`
- no class_name, extends `Fighter`
- Toxicroak (Poison/Fighting): evasive assassin. Poison jabs, Toxic Spikes, Sucker Punch, Venom Drag.
- functions: `_apply_archetype`, `_define_moves`

### Roster (roster/)

#### `roster/roster.gd`
- class `Roster`, extends `RefCounted`
- THE roster: the one place that lists playable fighters.
- constants: `ENTRIES`
- functions: `entries`, `scene_path`, `script_path`, `sheet_path`, `profile_path`, `index_of`

### AI (ai/)

#### `ai/ai_behavior.gd`
- class `AIBehavior`, extends `RefCounted`
- Base class for behavior tree nodes. All nodes return Status enum.
- functions: `tick`, `_reset`, `_get_delta`

#### `ai/ai_controller.gd`
- class `AIController`, extends `Node`
- AI controller: a behaviour tree (fighters/<id>/profile.tres plus the personality trees below) that drives a fighter
- constants: `DIFFICULTY_MULTIPLIERS`, `BASE_REACTION_TIME`, `BODY_RADIUS`, `FAR_RANGE`, `WHIFF_WINDOW`, `HOP_COOLDOWN`, `ZONING_JUMP_COOLDOWN`, `ZONING_SIGHT`, `PROJECTILE_MIN`, `PROJECTILE_MAX`, `TRAP_MAX`, `LOB_WINDOW`, `TRAP_LEAD`, `ATTACK_KEYS`, `MELEE_KINDS`, `LOG_MOVE_USAGE`, `RECENT_USES`, `WHIFF_MEMORY`, `WHIFF_BAN_FRAMES`
- functions: `setup`, `_load_profile`, `_apply_difficulty`, `_build_behavior_tree`, `_build_engagement_tree`, `_build_aggressive_tree`, `_build_defensive_tree`, `_build_zoning_tree`, `_build_hit_and_run_tree`, `_build_tricky_tree`, `_build_balanced_tree`, `_always_true`, `_check_vine_followup`, `_check_vine_window`, `_walk_in`, `_has_opponent`, `_horizontal_gap`, `_melee_window`, `_opponent_toward`, `_melee_reach`, `_in_range`, `_variant_reaches`, `_usable_keys`, `_disfavored`, `_can_use`, `_can_connect`, `_self_transform`, `_ultimate_ready`, `_saving_stamina`, `_stamina_full`, `_may_dash`, `_roll_ultimate`, `_check_anti_air`, `_check_whiff_punish`, `_check_zoning_response`, `_get_zoning_action`, `set_target`, `_on_opponent_hit`, `_physics_process`, `_update_movement`, `_drop_stale_presses`, `_drive_movement`, `_update_whiff_tracking`, `_update_own_hits`, `_track_outcomes`, `_record_outcome`, `_banned`, `_pick_down`, `_tally_moves`, `_exit_tree`, `buffer_action`, `_cond`, `_act`, `_cd`, `_seq`

#### `ai/ai_profile.gd`
- class `AIProfile`, extends `Resource`
- Data-driven AI configuration per fighter. Loaded from fighters/<fighter_id>/profile.tres (see roster/roster.gd)

#### `ai/bt/bt_action.gd`
- class `Action`, extends `AIBehavior`
- Buffers an input action for the fighter. duration 0 = instant SUCCESS.
- functions: `tick`, `_reset`

#### `ai/bt/bt_condition.gd`
- class `Condition`, extends `AIBehavior`
- Evaluates a check (Callable returning bool).
- functions: `tick`

#### `ai/bt/bt_cooldown.gd`
- class `Cooldown`, extends `AIBehavior`
- Child only evaluated when the cooldown is ready.
- functions: `tick`, `_reset`

#### `ai/bt/bt_inverter.gd`
- class `Inverter`, extends `AIBehavior`
- functions: `tick`

#### `ai/bt/bt_repeater.gd`
- class `Repeater`, extends `AIBehavior`
- functions: `tick`, `_reset`

#### `ai/bt/bt_selector.gd`
- class `Selector`, extends `AIBehavior`
- Tries children left-to-right, returns first SUCCESS or RUNNING.
- functions: `tick`

#### `ai/bt/bt_sequence.gd`
- class `Sequence`, extends `AIBehavior`
- Runs children in order. FAILURE if any child fails, SUCCESS if all succeed.
- functions: `tick`, `_reset`

#### `ai/bt/bt_until_fail.gd`
- class `UntilFail`, extends `AIBehavior`
- functions: `tick`

### Arena (arena/)

#### `arena/arena_camera.gd`
- class `ArenaCamera`, extends `Camera2D`
- Tracks both fighters, adapts framing to their distance, and shakes on impact.
- constants: `ZOOM_MIN`, `ZOOM_MAX`, `ZOOM_DISTANCE`, `ZOOM_SMOOTHING`, `POSITION_SMOOTHING`, `TRAUMA_DECAY`, `TRAUMA_SHAKE_MULT`, `MAX_TRAUMA`, `ARENA_RECT`
- functions: `set_targets`, `shake`, `add_trauma`, `_physics_process`, `_process`

#### `arena/arena_manager.gd`
- no class_name, extends `Node`
- Builds the arena, owns the selected matchup, HUD, and win/menu flow.
- constants: `FLOOR_TOP`, `SHAKE_SCALE`, `ELEMENT_PITCH`, `EVENT_SOUNDS`
- functions: `_ready`, `_setup`, `_setup_balance_slot`, `_current_match_ids`, `_fighter_data`, `_roster_index`, `_start_match`, `_attach_ai`, `_on_selection_applied`, `_on_main_menu_requested`, `_on_selection_cancelled`, `_on_mode_changed`, `_collider`, `_tile`, `_build_arena`, `_add_side_tag`, `_on_died`, `_build_juice`, `_on_got_hit`, `_on_fighter_event`, `_unhandled_input`

#### `arena/damage_number.gd`
- class `DamageNumber`, extends `Label`
- Floating damage popup. Gold for super-effective hits, muted for resisted hits.
- functions: `spawn`, `_damage_color`

#### `arena/hit_vfx.gd`
- class `HitVfx`, extends `Node2D`
- One-shot elemental hit burst: impact ring + sparks + an element-flavoured
- constants: `E`, `STYLE`
- functions: `spawn`, `burst`, `_emitter`, `_process`, `_draw`

#### `arena/sfx.gd`
- class `Sfx`, extends `Node2D`
- Tiny positional sound player. Streams are looked up by name in
- constants: `DIR`, `POOL`
- functions: `_ready`, `play`

### UI (ui/)

#### `ui/animated_portrait.gd`
- class `AnimatedPortrait`, extends `TextureRect`
- Animated portrait using fighter's sprite sheet idle animation.
- functions: `_ready`, `_setup_animation`, `_on_frame_advance`, `set_fighter`, `stop`, `start`

#### `ui/character_select.gd`
- class `CharacterSelect`, extends `CanvasLayer`
- Fighter select screen, laid out like the Smash Bros select:
- signals: `start_requested`, `cancel_requested`, `main_menu_requested`, `mode_changed`
- constants: `Keybinds`, `ROW_LENGTH`, `TILE_SIZE`, `TILE_PORTRAIT`, `TILE_NAME_HEIGHT`, `GRID_HEIGHT`, `CARD_PORTRAIT`, `CARD_HEIGHT`, `CARD_MARGIN`, `P1_COLOR`, `P2_COLOR`, `GOLD`, `DIM_BORDER`, `READY_COLOR`, `STAT_FLOOR`, `STAT_KEYS`, `STAT_LABELS`, `MOVE_KEYS`, `MOVE_TITLES`, `DIFFICULTIES`
- functions: `_ready`, `_load_roster_from_arena`, `open_select`, `mode_is_cpu`, `mode_name`, `_build_ui`, `_build_grid`, `_add_tile`, `_badge`, `_make_card`, `_refresh_all`, `_mode_text`, `_refresh_tiles`, `_refresh_card`, `_refresh_start_button`, `_fill_types`, `_fill_moves`, `_move_detail`, `_side_color`, `_side_title`, `_side_tag`, `_is_cpu_side`, `_is_ready`, `_data_instance`, `_fighter_info`, `_hit_count`, `_stat_fill`, `_on_p1_ready`, `_on_p2_ready`, `_toggle_side`, `_cycle_level`, `_on_start`, `_on_back`, `_select_pressed`, `_can_start`, `_step`, `_move_cursor`, `_place_cursor`, `_scroll_to`, `_on_tile_input`, `_input`, `_label`, `_button`, `_readable`, `_pad`, `_spacer`, `_box`, `_clear`, `_punch`

#### `ui/debug/balance_tool.gd`
- no class_name, extends `CanvasLayer`
- Developer balance tool. Ctrl+Shift+B opens a password prompt; type the password and press Enter to open the panel.
- constants: `PASSWORD`, `MAX_GAME_SECONDS`, `MIN_LIMIT_SECONDS`, `MAX_LIMIT_SECONDS`, `MAX_REPEATS`, `SAMPLE_EVERY`, `EARLY_SECONDS`, `OUT_DIR`, `DEFAULT_MATCH_SECONDS`, `MAX_SLOTS`, `SLOT_SIZE`, `RENDER_SLOTS_PER_FRAME`
- functions: `attach`, `_build_password_page`, `_build_main_page`, `_build_side_list`, `_title`, `_hint`, `_refresh`, `_refresh_estimate`, `_picked`, `_selected_pairs`, `_set_list`, `_on_pick_changed`, `_on_repeats_changed`, `_on_limit_changed`, `_on_swap_changed`, `_input`, `_key_password`, `_open_password`, `_close`, `_stop_pressed`, `_run_pressed`, `_run`, `_worker`, `_wait_host_ready`, `_progress_text`, `_rate`, `_farm_open`, `_render_mode`, `_process`, `_on_show_toggled`, `_farm_close`, `_toggle_panel`, `_on_slots_changed`, `_ai_of`, `_play`, `_refresh_live`, `_usage`, `_share`, `_sample`, `_track_moves`, `_finish_use`, `_bump`, `_on_side_died`, `_on_side_status`, `_on_side_event`, `_on_side_hit`, `_dealt_by_move`, `_early_taken`, `_build_report`, `_add_side`, `_write_files`, `_sum`

#### `ui/debug/input_debug.gd`
- no class_name, extends `CanvasLayer`
- F2 key test. Shows which game actions the engine currently sees as pressed, plus a log of the last raw key
- constants: `Keybinds`, `GAME_ACTIONS`, `LOG_LINES`
- functions: `_ready`, `_input`, `_process`

#### `ui/fighter_hud.gd`
- no class_name, extends `MarginContainer`
- One player's HUD block. Layout is entirely container-driven; this script
- functions: `_text`, `_style_bar`, `_reverse`, `setup`, `update_from`

#### `ui/hud.gd`
- no class_name, extends `CanvasLayer`
- Container-driven HUD: P1 block anchored top-left, P2 mirrored top-right,
- constants: `GameText`
- functions: `_ready`, `refresh_help`, `_style_help`, `bind`, `show_banner`, `_process`

#### `ui/main_menu.gd`
- no class_name, extends `CanvasLayer`
- functions: `_ready`, `_on_play`, `_on_characters`, `_change_to_arena`, `_on_options`, `_on_quit`

#### `ui/options_menu.gd`
- no class_name, extends `CanvasLayer`
- functions: `_ready`, `_on_difficulty_changed`, `_on_master_changed`, `_on_sfx_changed`, `_on_music_changed`, `_on_back`

#### `ui/player_tag.gd`
- no class_name, extends `Label`
- Floating tag above a fighter, such as "P1 · GENGAR", so you can tell which player is which
- constants: `LIFT`
- functions: `setup`, `_process`

#### `ui/skill_slot.gd`
- no class_name, extends `Control`
- Compact square ability slot. Fills bottom-up as the ability recharges;
- functions: `set_state`, `_draw`

### System (system/)

#### `system/game_text.gd`
- no class_name, extends `RefCounted`
- Player-facing strings live here as constants. {action_name} placeholders are filled from the
- constants: `Keybinds`, `HELP_P1`, `HELP_P2`, `HELP_FOOTER`, `WIN_BANNER`, `MODE_PVP`, `MODE_PVCPU`, `MODE_CPUVCPU`
- functions: `mode_hint`, `controls_help`, `win_banner`

#### `system/keybinds.gd`
- no class_name, extends `RefCounted`
- (No class_name on purpose: other scripts preload this file, so it works without an editor rescan.)
- constants: `BINDINGS`, `EXTRA`
- functions: `register`, `_add_key`, `rebind`, `key_name`, `fmt`

#### `system/settings.gd`
- no class_name, extends `Node`
- Persistent settings singleton. Saves to user://settings.cfg
- constants: `SETTINGS_PATH`
- functions: `_ready`, `_apply_audio`, `_set_bus`, `load_settings`, `save_settings`, `_defaults`, `get_value`, `set_value`, `get_difficulty`, `set_difficulty`, `get_master_volume`, `set_master_volume`, `get_sfx_volume`, `set_sfx_volume`, `get_music_volume`, `set_music_volume`, `get_last_p1_fighter`, `set_last_p1_fighter`, `get_last_p2_fighter`, `set_last_p2_fighter`, `get_last_mode`, `set_last_mode`, `set_view_mode_only`, `get_view_mode_only`, `clear_view_mode_only`

#### `system/ui_manager.gd`
- no class_name, extends `Node`
- Menu stack manager autoload. Handles showing/hiding menus with a navigation stack.
- signals: `menu_changed`
- functions: `show_menu`, `go_back`, `clear_stack`, `get_current_menu`

## Signals

| File | Signal | Parameters |
|---|---|---|
| `core/fighter.gd` | `died` | fighter |
| `core/fighter.gd` | `got_hit` | info: Dictionary |
| `core/fighter.gd` | `event` | kind: String, pos: Vector2 |
| `core/fighter.gd` | `status_damaged` | info: Dictionary |
| `core/stats_component.gd` | `burn_ticked` | amount: float |
| `core/stats_component.gd` | `poison_ticked` | amount: float |
| `core/support_system.gd` | `support_called` | player_id: int, support_id: String |
| `core/support_system.gd` | `support_ready` | player_id: int, slot: int |
| `core/support_system.gd` | `support_cooldown` | player_id: int, slot: int, time: float |
| `core/synergy_system.gd` | `burst_activated` | player_id: int |
| `core/synergy_system.gd` | `burst_ended` | player_id: int |
| `core/synergy_system.gd` | `ultimate_ready` | player_id: int |
| `core/synergy_system.gd` | `ultimate_used` | player_id: int |
| `core/synergy_system.gd` | `gauge_changed` | player_id: int, value: float, max_value: float |
| `system/ui_manager.gd` | `menu_changed` | menu_name: String |
| `ui/character_select.gd` | `start_requested` | p1_id: String, p2_id: String |
| `ui/character_select.gd` | `cancel_requested` | - |
| `ui/character_select.gd` | `main_menu_requested` | - |
| `ui/character_select.gd` | `mode_changed` | is_pvp: bool |

## Fighter move dictionary (`MOVE_DEFAULTS` in `core/fighter.gd`)

Every move is a dictionary built from these defaults. A fighter overrides only what it needs in `_define_moves()`.

| Key | Default |
|---|---|
| `kind` | `"melee"` |
| `dmg` | `8.0` |
| `size` | `Vector2(44` |
| `off` | `Vector2(34` |
| `on` | `4` |
| `total` | `16` |
| `kb` | `Vector2(380` |
| `push` | `0.0` |
| `lunge` | `0.0` |
| `hop` | `0.0` |
| `cd` | `0.0` |
| `cost` | `0.0` |
| `spawn` | `0` |
| `proj_speed` | `0.0` |
| `spawn_count` | `1` |
| `spawn_interval` | `1` |
| `hit_interval` | `0` |
| `i_frames` | `0` |
| `teleport_distance` | `0.0` |
| `counter` | `false` |
| `counter_frames` | `0` (seconds the counter stays armed: frames / 60) |
| `counter_mult` | `1.5` (not in the defaults; damage multiplier of the reflected hit) |
| `counter_cap` | no cap (not in the defaults; most damage the reflected hit can send back) |
| `stamina_steal` | `0.0` |
| `self_damage` | `0.0` |
| `damage_buff` | `1.0` |
| `hitstun_mult` | `1.0` |
| `root` | `0.0` |
| `trap_lifetime` | `3.0` |
| `trap_persistent` | `false` |
| `trap_tick` | `0.0` |
| `track_y` | `false` |
| `projectile_block` | `false` |
| `anim_rate` | `1.0` |
| `anim_tilt` | `0.0` |
| `anim_scale` | `Vector2.ONE` |
| `fx_tint` | `Color.WHITE` |
| `fx` | `""` |
| `fx_frames` | `4` |
| `fx_loop` | `false` |
| `fx_cast` | `""` |
| `fx_cast_frames` | `4` |
| `fx_cast_off` | `Vector2(26` |
| `proj_frames` | `1` |
| `proj_fps` | `14.0` |
| `element` | `-1` |
| `apply` | `"auto"` |
| `stun` | `18` |
| `proj_vys` | `[]` |
| `proj_off` | `Vector2(30` |
| `proj_tex` | `"res://assets/water_orb.png"` |
| `proj_scale` | `1.0` |
| `proj_r` | `10.0` |
| `proj_life` | `3.0` |
| `proj_spin` | `0.0` |
| `trap_tex` | `"res://assets/trap.png"` |
| `trap_dist` | `90.0` |
| `dive_start` | `0` |
| `dive_dx` | `380.0` |
| `dive_speed` | `1050.0` |
| `wave` | `false` |
| `proj_gravity` | `0.0` |
| `proj_bounce` | `0` |
| `proj_pierce` | `false` |
| `proj_hit_gap` | `0.45` |
| `trap_delay` | `0.0` |
| `trap_size` | `Vector2(60` |
| `trap_step` | `0.0` |
| `trap_frames` | `1` |
| `trap_marker` | `false` |
| `trap_fps` | `8.0` |
| `trap_scale` | `1.0` |

## Key bindings (`system/keybinds.gd`)

| Action | Key |
|---|---|
| `p1_left` | `KEY_A` |
| `p1_right` | `KEY_D` |
| `p1_jump` | `KEY_W` |
| `p1_attack` | `KEY_F` |
| `p1_dash` | `KEY_E` |
| `p1_special1` | `KEY_G` |
| `p1_special2` | `KEY_H` |
| `p1_ultimate` | `KEY_T` |
| `p1_down` | `KEY_S` |
| `p1_support` | `KEY_R` |
| `p1_support_2` | `KEY_U` |
| `p1_support_3` | `KEY_Y` |
| `p1_nav_up` | `KEY_W` |
| `p1_nav_down` | `KEY_S` |
| `p1_nav_left` | `KEY_A` |
| `p1_nav_right` | `KEY_D` |
| `p1_select` | `KEY_ENTER` |
| `p2_left` | `KEY_LEFT` |
| `p2_right` | `KEY_RIGHT` |
| `p2_jump` | `KEY_UP` |
| `p2_attack` | `KEY_KP_4` |
| `p2_dash` | `KEY_KP_0` |
| `p2_special1` | `KEY_KP_5` |
| `p2_special2` | `KEY_KP_6` |
| `p2_ultimate` | `KEY_KP_8` |
| `p2_down` | `KEY_DOWN` |
| `p2_support` | `KEY_KP_DIVIDE` |
| `p2_support_2` | `KEY_KP_MULTIPLY` |
| `p2_support_3` | `KEY_KP_SUBTRACT` |
| `p2_nav_up` | `KEY_KP_8` |
| `p2_nav_down` | `KEY_KP_2` |
| `p2_nav_left` | `KEY_KP_4` |
| `p2_nav_right` | `KEY_KP_6` |
| `p2_select` | `KEY_KP_ENTER` |
| `p1_cpu_toggle` | `KEY_Q` |
| `p2_cpu_toggle` | `KEY_KP_ADD` |
| `cpu_level` | `KEY_C` |
| `menu_toggle` | `KEY_TAB` |
| `restart_round` | `KEY_F5` |
| `debug_hitboxes` | `KEY_F1` |
| `debug_keytest` | `KEY_F2` |

## Roster (`roster/roster.gd`)

| id | name |
|---|---|
| `gholdengo` | Gholdengo |
| `marshadow` | Marshadow |
| `tinkaton` | Tinkaton |
| `greninja` | Greninja |
| `scizor` | Scizor |
| `decidueye` | Decidueye |
| `blaziken` | Blaziken |
| `gengar` | Gengar |
| `alakazam` | Alakazam |
| `mewtwo` | Mewtwo |
| `lucario` | Lucario |
| `toxicroak` | Toxicroak |

## Tuning constants: key values

Read these from the file named; the values here are the current ones at the time of generation.

**core/stats_component.gd**

| Constant | Value |
|---|---|
| `DASH_COST` | `25.0` |
| `REGEN_PER_SEC` | `20.0` |
| `RECOVER_AT` | `25.0` |
| `BURN_DAMAGE` | `2.0` |
| `BURN_TICKS` | `3` |
| `POISON_DAMAGE` | `2.0` |
| `POISON_TICKS` | `4` |
| `SLOW_FACTOR` | `0.75` |
| `SLOW_TIME` | `3.0` |

**core/synergy_system.gd**

| Constant | Value |
|---|---|
| `GAUGE_MAX` | `1000.0` |
| `BURST_DURATION` | `12.0` |
| `BURST_COOLDOWN` | `30.0` |
| `ULTIMATE_COST` | `1000.0` |

**core/support_system.gd**

| Constant | Value |
|---|---|
| `MAX_SUPPORTS` | `3` |
| `BASE_COOLDOWN` | `20.0` |

**core/fighter.gd**

| Constant | Value |
|---|---|
| `GRAVITY_RISE` | `2200.0` |
| `GRAVITY_FALL` | `3200.0` |
| `JUMP_CUT` | `-220.0` |
| `GROUND_ACCEL` | `4000.0` |
| `AIR_ACCEL` | `2600.0` |
| `HITSTUN_FRAMES` | `18` |
| `HITSTOP_SCALE` | `1.0` |
| `KO_HITSTOP` | `12` |
| `TECH_COOLDOWN` | `2.0` |
| `COYOTE_FRAMES` | `6` |

## Known issues (current)

- Six support icons are referenced but missing from `assets/` (`core/support_system.gd`).
- Attack has 4 frames in `ANIMS` (`core/fighter.gd`). The Tinkaton reference has 5, so the row and the timing constant need changing together.
- Mewtwo `special2` (Disable) is almost never used by the bots (0 a match in the latest runs). Cause not found. Alakazam `special2` (Reflect) is used about 3 times a match on hard (since 2026-10-20 its returned damage is capped at 10).
- Bots do not dodge Alakazam's Mind Blast (ultimate), so its connect rate against bots (83%) does not show how dodgeable it is for a player. Checked by playing only.
- Projectile hits on the bots do not respond to dodging: most shots are first seen within 100 px of the bot, or land while it is in hitstun or mid-attack, when no dash can start (see the 2026-10-20 addendum).
- Toxicroak `special1_down` (Toxic Spikes) has never connected in any balance run. Its Down preference is 0.1 and Down variants with a low preference are never used, so the bot no longer picks it. The trap itself is unverified.
- Whiff memory (`WHIFF_MEMORY` in `ai/ai_controller.gd`) is off. Bots use a special only 1-2 times in a ~15 s match, so the 8-use window never fills.
- Decidueye `special2_down` (Vine Lash) pulled a target standing close (60-100 px) without ever hitting it. The cause is inferred from the hitbox geometry (the whip opens at frame 9, when the hop has lifted him above a close target). Fixed by opening the whip at frame 4. In the headless run over all 12 fighters, no move is dead.
- The move check sets the `pull` flag only for a move that has a `pull` key. A lunge that closes the gap no longer counts as a pull.
- Balance tool: "Show fights" draws four fight views per frame (`RENDER_SLOTS_PER_FRAME`), so fights refresh at the game frame rate divided by 4. Matches run at real game speed.
- Godot reports integer-division, enum-cast and ternary-type warnings on reload. Not all source lines are identified.
- Not verified in Godot 4.7 since the latest changes (see `SESSION_REPORT.md`).

## Addendum 2026-10-21 (names added since the last sync)
- `ui/debug/move_check.gd` (new, `class_name MoveCheck`): `DISTANCES` (60, 100, 150, 260 px), `SETTLE_FRAMES` (120), `TEST_FRAMES` (150), `STAND_X`, `STAND_Y`. Functions: `run(arena, tree, ids, should_stop, on_progress)` (returns `rows`, `lines`, `stopped`), `_test` (one move at one distance), `_move_keys`, `_report_lines`.
- `ui/debug/balance_tool.gd`: `MoveCheckScript` (preload), `_move_check_btn`, `_checking`, `_move_check_pressed()` (the "Move check (M)" button and the M key), `_write_check_file()` (writes `balance/move_check_<unix time>.txt`).
- `fighters/mewtwo/fighter_mewtwo.gd`: `basic_down` now has `spawn` 6 (its shockwave never spawned before).
- `fighters/decidueye/fighter_decidueye.gd`: `special2_down` `hit_on` 9 -> 4 (the whip opens while the hop is still low).

## Addendum 2026-10-20 (names added since the last sync)
- `ai/ai_controller.gd`: `PROJ_LOOK` (360 px), `PROJ_LANE_HIGH` (64 px above the feet), `PROJ_LANE_LOW` (12 px below), `PROJ_DODGE_CHANCE` (0.85), `TRAP_AVOID_CHANCE` (0.85), `TRAP_HOP_DIST` (110 px). Variables: `_proj_seen`, `_proj_dodge`, `_trap_avoid`, `_hazard_move`, `_hazard_frames`. Functions: `_avoid_hazards` (every physics frame, after `_try_dodge`: stops walking toward an incoming opponent shot, dashes through it once the reaction time has passed, hops an opponent trap on the bot's path, and dashes out of one it is standing in), `_prune_hazards`. `_drive_movement` uses `_hazard_move` while `_hazard_frames` is above 0.
- `core/fighter.gd`: `counter_mult` (default 1.5) and `counter_cap` (default no cap), read from the move keys `counter_mult` and `counter_cap` when a counter move starts. An armed counter returns `min(damage * counter_mult, counter_cap)`.
- `fighters/alakazam/fighter_alakazam.gd` (values, not names): `basic` dmg 2.0, `proj_speed` 560, `total` 28; `special2` `counter_cap` 10; `ultimate` `cd` 10.

## Addendum 2026-10-19 (names added since the last sync)

- `ai/ai_controller.gd`: `WALL_EDGE` (150 px: a keep-away bot steps in instead of backing into a wall), `DODGE_CHANCE`
  (0.7), `DODGE_MARGIN` (10 px), `WHIFF_MEMORY` (false; the whiff-ban system is present but off), `RECENT_USES`,
  `WHIFF_BAN_FRAMES`. Functions: `_pinned_against_wall`, `_melee_threat_now`, `_try_dodge`, `_disfavored`,
  `_on_opponent_hit`.
- `ui/debug/balance_tool.gd`: `ZOOM_STEPS`, `CORNER_EDGE`, `THREAT_RANGE` (the zoom view and the tile labels).
- `core/fighter.gd`: `WALL_LEFT_X`, `WALL_RIGHT_X` (the arena's inner wall faces), `enter_ultimate` / `state_ultimate` /
  `exit_ultimate`, `state_hitstun`, `exit_special2`, `PROJECTILE_SCENE`, `TRAP_SCRIPT`, `BUFFER_TAIL`.
- Not in this upload (see `docs/ANALYSIS.md`): timed counter, move buff expiry, awakened log labels.

