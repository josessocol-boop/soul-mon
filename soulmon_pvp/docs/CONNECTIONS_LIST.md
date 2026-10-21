# Connections: how the game fits together

Rewritten for the restructured project (folders by role; see `ARCHITECTURE.md`). The flows below are written by hand. The tables are generated from the code (who names which class, which signals connect to which handler, which scene uses which script).

## 1. Startup and menus

1. `project.godot` runs `ui/main_menu.tscn`. Autoloads `Settings` (`system/settings.gd`) and `UIManager` (`system/ui_manager.gd`) are ready first.
2. Main menu buttons: PLAY, CHARACTERS, OPTIONS, QUIT. OPTIONS opens `ui/options_menu.tscn` through `UIManager.show_menu()`, which stacks it on the main menu until the stack empties (`menu_closed`).
3. PLAY and CHARACTERS both set the one-shot flag `Settings.view_mode_only` and change scene to `arena/main.tscn`. PLAY and CHARACTERS lead to the same screen.
4. The arena builds itself (see section 2). Because the flag is set, it opens the fighter-select screen (`ui/character_select.tscn`) paused, and clears the flag.
5. The select screen builds its tile grid from `Roster.entries()` (`roster/roster.gd`). Each side has a PLAYER / CPU switch and a CPU level. Keys come from `system/keybinds.gd`.
6. START emits `start_requested(p1_id, p2_id)`. `ArenaManager._on_selection_applied()` calls `_start_match()`, which spawns both fighters from `Roster.scene_path()`. CANCEL emits `cancel_requested`.

## 2. A match: scene tree

`arena/main.tscn` contains only the root and `Arena_Manager`. Everything else is created in code by `ArenaManager`:

- `Arena` (static floor, walls, ceiling as `StaticBody2D` plus textures)
- `Player_1`, `Player_2`: instances of `fighters/<id>/fighter_<id>.tscn`, which instance `core/fighter.tscn`.
- Each fighter creates its own children in `_ready()`: `HurtboxArea2D`, `HitboxArea2D`, `InputHandler`, `StatsComponent`, `StateMachine`, `SynergySystem`, `SupportSystem`, and an `AnimatedSprite2D` for the sheet.
- `ArenaCamera` (framing and shake), `Sfx` (positional sounds), the HUD (`ui/hud.tscn`, with two `FighterHUD` blocks), and the select menu (`ui/character_select.tscn`), added on demand.
- Projectiles and traps are created by the fighter during a move (`core/projectile.tscn`, `core/trap.gd`) and add themselves to the arena.

## 3. Input

1. The engine reports keys. `Keybinds` (`system/keybinds.gd`) defines every action once and registers it in `InputMap`.
2. Each fighter has an `InputHandler` (`core/input_handler.gd`). A human fills it from the keyboard. A bot sets `input_handler.remote = true` and writes into its own fighter's buffer (`ai/ai_controller.gd`), so bots and humans share one path. Remote mode skips `poll()`, so the controller calls `decay_buffers()` itself.
3. `Fighter._physics_process()` polls the handler, then runs the state machine. Buffered presses are consumed by `_try_actions()` and the move runner.
4. Hits clear the buffer (`input.clear()`), so mashing during hitstun does not fire a stale move.

## 4. Combat: one hit

1. A move's hitbox (`HitboxArea2D`) overlaps a target's `HurtboxArea2D`. `_check_hits()` runs for the attacker.
2. `target.receive_hit(attacker, dmg, kb, from_x, move)` applies the type multiplier (`StatsComponent.type_multiplier`), HP, knockback, hitstun, and the move's status (burn, slow, poison).
3. The target emits `got_hit(info)` and may die (`died`). The attacker freezes for hitstop.
4. `ArenaManager` listens to `got_hit` and spawns `HitVfx`, `DamageNumber`, plays `Sfx`, and shakes the camera.
5. The attacker fills its gauge with `synergy.on_hit_connect()`, and the target fills its own when damage is taken. `SupportSystem` is called from the fighter's support input.
6. Gameplay events (`event(kind, pos)`) drive the sound and the ultimate flash.

## 5. AI

1. `ArenaManager` adds an `AIController` to each CPU side. The controller reads the fighter id from the scene file name and loads `Roster.profile_path(id)` (an `AIProfile` resource).
2. Each frame the tree (`ai/bt/*`) looks at what the fighter can see (positions, velocities, hitboxes, cooldowns) and buffers an action into its own fighter's `InputHandler`.
3. Choosing a Down variant: `_pick_down()` uses the move's `down_pref` (chance to pick the Down when both versions reach). Absent, the kind's default applies. A Down with `down_pref` below 0.2 is never used (`_disfavored()`).
4. Whiff memory (`_record_outcome`, `_banned`) is coded but switched off by `WHIFF_MEMORY`.

## 6. Menus and state

- `Settings` persists choices to `user://settings.cfg`: difficulty, volumes, last fighters, last mode.
- `Settings.view_mode_only` is a one-shot runtime flag (not saved). Set by PLAY and CHARACTERS, read and cleared by the arena at startup.
- `UIManager` owns the menu stack. Its `menu_closed` signal shows the main menu again.

## 6a. In a match

- Tab (`menu_toggle`) reopens fighter select, paused. Its START starts a new match with the picks.
- F5 (`restart_round`) restarts the same matchup.
- F1 toggles hitbox and hurtbox overlays. F2 toggles the key test (`ui/debug/input_debug.gd`).
- The arena has no ESC route back to the main menu.
- Walls: teleports and pulls go through `arena_x()` in `core/fighter.gd`, which keeps the body 38 to 1242 px, and a clamp runs after every move so the body is never left inside a wall.

The balance tool (`ui/debug/balance_tool.gd`) runs matches in parallel fight copies. Simulation only is the default. It logs matches, moves, events, HP and the scene node count per match.

## 7. Signals (generated)

| Emitter | Signal | Connected in |
|---|---|---|
| `core/fighter.gd` | `died` | `arena/arena_manager.gd:152`, `arena/arena_manager.gd:153`, `ui/debug/balance_tool.gd:679`, `ui/debug/balance_tool.gd:680` |
| `core/fighter.gd` | `got_hit` | `ai/ai_controller.gd:585`, `arena/arena_manager.gd:154`, `arena/arena_manager.gd:155`, `ui/debug/balance_tool.gd:681`, `ui/debug/balance_tool.gd:682` |
| `core/fighter.gd` | `event` | `arena/arena_manager.gd:156`, `arena/arena_manager.gd:157`, `ui/debug/balance_tool.gd:685`, `ui/debug/balance_tool.gd:686` |
| `core/fighter.gd` | `status_damaged` | `ui/debug/balance_tool.gd:683`, `ui/debug/balance_tool.gd:684` |
| `core/stats_component.gd` | `burn_ticked` | `core/fighter.gd:428` |
| `core/stats_component.gd` | `poison_ticked` | `core/fighter.gd:429` |
| `core/support_system.gd` | `support_called` | `core/fighter.gd:456` |
| `core/support_system.gd` | `support_ready` | - |
| `core/support_system.gd` | `support_cooldown` | - |
| `core/synergy_system.gd` | `burst_activated` | `core/fighter.gd:446` |
| `core/synergy_system.gd` | `burst_ended` | `core/fighter.gd:447` |
| `core/synergy_system.gd` | `ultimate_ready` | `core/fighter.gd:448` |
| `core/synergy_system.gd` | `ultimate_used` | `core/fighter.gd:449` |
| `core/synergy_system.gd` | `gauge_changed` | - |
| `system/ui_manager.gd` | `menu_changed` | - |
| `ui/character_select.gd` | `start_requested` | `arena/arena_manager.gd:60` |
| `ui/character_select.gd` | `cancel_requested` | `arena/arena_manager.gd:61` |
| `ui/character_select.gd` | `main_menu_requested` | `arena/arena_manager.gd:62` |
| `ui/character_select.gd` | `mode_changed` | `arena/arena_manager.gd:63` |

## 8. Who uses which class (generated)

| File | Uses classes |
|---|---|
| `ai/ai_behavior.gd` | AIController |
| `ai/ai_controller.gd` | AIBehavior, AIProfile, Action, Condition, Cooldown, Fighter, InputHandler, Projectile, Roster, Selector, Sequence, Trap |
| `ai/bt/bt_action.gd` | AIBehavior, AIController |
| `ai/bt/bt_condition.gd` | AIBehavior, AIController |
| `ai/bt/bt_cooldown.gd` | AIBehavior, AIController |
| `ai/bt/bt_inverter.gd` | AIBehavior, AIController |
| `ai/bt/bt_repeater.gd` | AIBehavior, AIController |
| `ai/bt/bt_selector.gd` | AIBehavior, AIController |
| `ai/bt/bt_sequence.gd` | AIBehavior, AIController |
| `ai/bt/bt_until_fail.gd` | AIBehavior, AIController |
| `arena/arena_manager.gd` | AIController, ArenaCamera, CharacterSelect, DamageNumber, Fighter, HitVfx, InputHandler, Roster, Sfx, StatsComponent |
| `arena/hit_vfx.gd` | Fighter, StatsComponent |
| `core/fighter.gd` | InputHandler, StateMachine, StatsComponent, SupportSystem, SynergySystem |
| `core/input_handler.gd` | Fighter |
| `core/projectile.gd` | Fighter |
| `core/state_machine.gd` | Fighter |
| `core/stats_component.gd` | Fighter |
| `core/support_system.gd` | StatsComponent |
| `core/trap.gd` | Fighter |
| `fighters/alakazam/fighter_alakazam.gd` | Fighter, StatsComponent |
| `fighters/blaziken/fighter_blaziken.gd` | Fighter, StatsComponent |
| `fighters/decidueye/fighter_decidueye.gd` | Fighter, StatsComponent |
| `fighters/gengar/fighter_gengar.gd` | Fighter, StatsComponent |
| `fighters/gholdengo/fighter_gholdengo.gd` | Fighter, StatsComponent |
| `fighters/greninja/fighter_greninja.gd` | Fighter, StatsComponent |
| `fighters/lucario/fighter_lucario.gd` | Fighter, StatsComponent |
| `fighters/marshadow/fighter_marshadow.gd` | Fighter, StatsComponent |
| `fighters/mewtwo/fighter_mewtwo.gd` | Fighter, StatsComponent, SynergySystem |
| `fighters/placeholders/fighter_brawler.gd` | Fighter, StatsComponent |
| `fighters/placeholders/fighter_zoner.gd` | Fighter, StatsComponent |
| `fighters/scizor/fighter_scizor.gd` | Fighter, StatsComponent |
| `fighters/tinkaton/fighter_tinkaton.gd` | Fighter, StatsComponent |
| `fighters/toxicroak/fighter_toxicroak.gd` | Fighter, StatsComponent |
| `roster/roster.gd` | Fighter |
| `ui/character_select.gd` | AnimatedPortrait, Fighter, HitVfx, InputHandler, Roster, StatsComponent |
| `ui/debug/balance_tool.gd` | AIController, MoveCheck, Roster |
| `ui/debug/move_check.gd` | Fighter, Projectile, Roster, Trap |
| `ui/fighter_hud.gd` | Fighter, StatsComponent |
| `ui/hud.gd` | Fighter |

## 9. Scenes and what they instance (generated)

| Scene | Root and main nodes | External resources |
|---|---|---|
| `arena/main.tscn` | Main_Game_Root:Node2D, Arena_Manager:Node | `arena/arena_manager.gd` |
| `core/fighter.tscn` | Fighter:CharacterBody2D, AnimatedSprite2D:AnimatedSprite2D | `core/fighter.gd` |
| `core/projectile.tscn` | Projectile:Node2D | `core/projectile.gd` |
| `fighters/alakazam/fighter_alakazam.tscn` | Fighter_Alakazam | `core/fighter.tscn`, `fighters/alakazam/fighter_alakazam.gd` |
| `fighters/blaziken/fighter_blaziken.tscn` | Fighter_Blaziken | `core/fighter.tscn`, `fighters/blaziken/fighter_blaziken.gd` |
| `fighters/decidueye/fighter_decidueye.tscn` | Fighter_Decidueye | `core/fighter.tscn`, `fighters/decidueye/fighter_decidueye.gd` |
| `fighters/gengar/fighter_gengar.tscn` | Fighter_Gengar | `core/fighter.tscn`, `fighters/gengar/fighter_gengar.gd` |
| `fighters/gholdengo/fighter_gholdengo.tscn` | Fighter_Gholdengo | `core/fighter.tscn`, `fighters/gholdengo/fighter_gholdengo.gd` |
| `fighters/greninja/fighter_greninja.tscn` | Fighter_Greninja | `core/fighter.tscn`, `fighters/greninja/fighter_greninja.gd` |
| `fighters/lucario/fighter_lucario.tscn` | Fighter_Lucario | `core/fighter.tscn`, `fighters/lucario/fighter_lucario.gd` |
| `fighters/marshadow/fighter_marshadow.tscn` | Fighter_Marshadow | `core/fighter.tscn`, `fighters/marshadow/fighter_marshadow.gd` |
| `fighters/mewtwo/fighter_mewtwo.tscn` | Fighter_Mewtwo | `core/fighter.tscn`, `fighters/mewtwo/fighter_mewtwo.gd` |
| `fighters/placeholders/fighter_brawler.tscn` | Fighter_Brawler | `core/fighter.tscn`, `fighters/placeholders/fighter_brawler.gd` |
| `fighters/placeholders/fighter_zoner.tscn` | Fighter_Zoner | `core/fighter.tscn`, `fighters/placeholders/fighter_zoner.gd` |
| `fighters/scizor/fighter_scizor.tscn` | Fighter_Scizor | `core/fighter.tscn`, `fighters/scizor/fighter_scizor.gd` |
| `fighters/tinkaton/fighter_tinkaton.tscn` | Fighter_Tinkaton | `core/fighter.tscn`, `fighters/tinkaton/fighter_tinkaton.gd` |
| `fighters/toxicroak/fighter_toxicroak.tscn` | Fighter_Toxicroak | `core/fighter.tscn`, `fighters/toxicroak/fighter_toxicroak.gd` |
| `ui/character_select.tscn` | CharacterSelect:CanvasLayer, BackgroundShade:ColorRect, BackgroundArt:TextureRect | `ui/character_select.gd`, `assets/background.png` |
| `ui/fighter_hud.tscn` | FighterHUD:MarginContainer, VBox:VBoxContainer, Header:HBoxContainer, NameLabel:Label, StateLabel:Label, BurnBadge:Label, PoisonBadge:Label, SlowBadge:Label, HPLabel:Label, HPBar:ProgressBar | `ui/fighter_hud.gd`, `ui/skill_slot.gd` |
| `ui/hud.tscn` | HUD:CanvasLayer, Root:Control, P1, P2, Banner:Label, HelpPanel:PanelContainer, Help:Label | `ui/hud.gd`, `ui/fighter_hud.tscn` |
| `ui/main_menu.tscn` | MainMenu:CanvasLayer, Background:TextureRect, VBoxContainer:VBoxContainer, Title:Label, PlayButton:Button, CharactersButton:Button, OptionsButton:Button, QuitButton:Button | `ui/main_menu.gd`, `assets/background.png` |
| `ui/options_menu.tscn` | OptionsMenu:CanvasLayer, Background:TextureRect, VBoxContainer:VBoxContainer, Title:Label, DifficultyContainer:HBoxContainer, DifficultyLabel:Label, DifficultySlider:HSlider, HSeparator:HSeparator, MasterContainer:HBoxContainer, MasterLabel:Label | `ui/options_menu.gd`, `assets/background.png` |

## 10. Autoloads and shared data

| Name | File | Used by |
|---|---|---|
| `Settings` | `system/settings.gd` | options, character select, arena, main menu |
| `UIManager` | `system/ui_manager.gd` | main menu, options, arena |
| `Keybinds` (preloaded, no autoload) | `system/keybinds.gd` | input, HUD hints, character select, key test |
| `GameText` (preloaded) | `system/game_text.gd` | menus and HUD text |
| `Roster` | `roster/roster.gd` | arena, character select, AI, fighter scenes |

## 11. Known connection hazards (current)

- `ArenaManager` assumes exactly two fighters (`p1`, `p2`). The balance tool can move P2 to the front of the physics order with `spawn_p2_first`.
- `AIController` finds its profile by the scene file name, so `fighter_<id>.tscn` must keep that name.
- Projectile spawning assumes the flat arena (floor, ceiling, two walls).
- Mode selection happens on the character select screen. `ModeSelect` is archived in `_archive/`.
- Keyboard ghosting (W + S + attack held together) is a keyboard limitation. The F2 key test shows it.
- Wall constants `WALL_LEFT_X`, `WALL_RIGHT_X` and `BODY_RADIUS` in `core/fighter.gd` must match the walls in `arena/arena_manager.gd`.
