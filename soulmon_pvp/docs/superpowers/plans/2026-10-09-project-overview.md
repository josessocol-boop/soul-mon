# Soul-Mon PvP Project Overview

> **For agentic workers:** This document provides a concise overview of the Soul-Mon PvP Godot fighting game project to enable quick understanding without exploring all files.

**Goal:** Provide a structured summary of the Soul-Mon PvP project architecture, systems, and conventions for efficient knowledge transfer.

**Architecture:** Modular Godot 4.7 project using behavior trees for AI, resource-based configuration for fighter profiles, and autoloads for global systems (settings, UI management). Features clear separation of concerns with fighter logic decoupled from AI control.

**Tech Stack:** Godot 4.7 (GDScript), JSON-like .tres resources for data, PNG spritesheets, ConfigFile for persistent settings.

**Spec:** This document serves as the project overview spec (no external design doc).

## Global Constraints

- Godot 4.7 (`project.godot` config/features). Older 4.x versions are not tested
- All GDScript files use `class_name` for autoload/types (except where noted in fixes)
- AI uses fair detection only (hitboxes, velocity, position, cooldowns - NO input buffer reading)
- Fighter animations follow strict 64px frame sheet format: idle(4) run(6) jump(2) dash(2) attack(4) hitstun(2) ko(3)
- Settings persist via `user://settings.cfg`
- All move data defined in `MOVE_DEFAULTS` constants with override capability per fighter

## Project Structure

### Core Systems

1. **Fighter System** (`core/fighter.gd`)
   - Base `CharacterBody2D` class for all fighters
   - Contains core combat mechanics: movement, attacks, hitboxes, stamina
   - Defines `MOVE_DEFAULTS` template for all moves
   - Archetypes subclass this and override `_apply_archetype()` and `_define_moves()`
   - Provides `get_types()` method for elemental typing system
   - Emits signals for gameplay events (jump, dash, attack, etc.) and hit detection

2. **AI System** (Behavior Tree Architecture)
   - `ai/ai_controller.gd` - Main AI driver that attaches to fighters
     - Uses behavior trees for decision making
     - Applies difficulty scaling and profile-based modifiers
     - Fair detection only (no cheating via input reading)
     - Handles combo buffering, whiff punish tracking
   - `ai/ai_behavior.gd` - Base class for all behavior tree nodes (Selector, Sequence, Condition, Action, etc.)
   - `ai/ai_profile.gd` - Resource-based configuration per fighter personality
     - Personality archetypes: aggressive, defensive, zoning, balanced, hit_and_run, tricky
     - Preferred range: close, mid, far
     - Combo chains, anti-air moves, punish moves, zoning responses, meter management
   - Individual profiles in `fighters/*/profile.tres` for each fighter

3. **Menu/Persistent Systems**
   - `Settings.gd` - Autoload singleton for persistent settings (ConfigFile at `user://settings.cfg`)
     - Stores difficulty, volume, last selected fighters
     - Provides `get_value()`/`set_value()` methods (avoiding Object method overrides)
   - `UIManager.gd` - Autoload singleton for menu stack management
     - Handles pushing/popping menus, transitions
   - Menu scenes: `ui/main_menu.tscn`, `_archive/mode_select.tscn`, `ui/options_menu.tscn`, `ui/character_select.tscn`

4. **Character Select System**
   - `ui/character_select.gd` - Full-screen, Smash-style character selection (built in code; the `.tscn` is only the root, shade and background) with:
     - A 4-column tile grid with P1 / P2 / CPU cursor badges
     - Two preview cards with animated portraits (`AnimatedPortrait.gd`), element chips, roster-relative stat bars, moves with damage / cost / cooldown, and the Down-move hint
     - Ready states for all modes (PvP, PvCPU, CPUvCPU); the same Enter key readies a side and then starts the match
     - WASD / Numpad navigation with Enter / KP_Enter selection; Tab goes back
   - `ui/animated_portrait.gd` - Reusable animated sprite component for portraits

### Fighter Archetypes (Subclasses of Fighter)

Each fighter in `fighter_*.gd` defines:
- Archetype-specific stats (hp_max, move_speed, jump_velocity, etc.)
- Elemental typing (dual-type system with attack/defense types)
- Unique move set via `_define_moves()`
- Visual elements (sprite sheet path, fx textures)
- Special mechanics via `_apply_archetype()`

Roster (8, in `Roster.ENTRIES (`roster/roster.gd`)`): Blaziken, Decidueye, Gengar, Gholdengo, Greninja, Marshadow, Scizor, Tinkaton. Prototypes kept but NOT in the roster (no AI profile, default balanced AI): Brawler, Zoner.

### Key Conventions

1. **Constants Naming**: ALL_CAPS with underscores for configuration values
2. **Signals**: Used for loose coupling (gameplay events, hit detection)
3. **Node Access**: Fighters access child nodes via `get_node()` in `_ready()` or setup functions
4. **Resource Loading**: `preload()` for constants, `load()` for dynamic resources
5. **Delta Time**: gameplay runs in physics frames (60 fps); use the `delta` passed to `_physics_process()` and the state methods. Move and status timers count frames, not seconds
6. **Tunables**: `const` values at the top of each script (`core/fighter.gd`, `core/stats_component.gd`, `core/synergy_system.gd`, ...). `@export` is only used by `ai/ai_controller.gd` and `ai/ai_profile.gd`
7. **Doc Comments**: Detailed comments explaining constants and systems

### Important Files to Modify

- **Adding New Fighter**: 
  1. Create `fighter_<name>.gd` inheriting from Fighter
  2. Create `fighter_<name>.tscn` scene
  3. Create AI profile in `fighters/<name>/profile.tres` and add the id to `roster/roster.gd`
  4. Add sprite sheet to `assets/` (following 64px frame format)
  5. Add an entry to `Roster.ENTRIES (`roster/roster.gd`)` (`id`, `name`, `scene`, `sheet`, `color`); character select reads that list
  6. Define `basic_down`, `special1_down` and `special2_down` at the end of `_define_moves()` with `variant(m.<key>, {...})` (or let `_derive_down_variant()` build them)

- **Modifying AI Behavior**:
  1. Adjust AI profile `.tres` file for personality/tendencies
  2. Create new AIBehavior node types in `ai/ai_behavior.gd` if needed
  3. Modify `ai/ai_controller.gd` for core AI logic changes

- **Changing Keys or On-screen Key Hints**:
  1. Change the key in `system/keybinds.gd` (`BINDINGS`, and `EXTRA` for alternate keys). `system/game_text.gd` and the HUD read the key back, so the hints update themselves

- **Changing Game Mechanics**:
  1. Modify `core/fighter.gd` for core combat changes
  2. Adjust `MOVE_DEFAULTS` for baseline move properties
  3. Update constants at top of `core/fighter.gd` for global values
  4. Keep `docs/STRUCTURES_FUNCTIONS_LIST.md` and `docs/CONNECTIONS_LIST.md` in step with the change (add a sync note at the top of each)

### Recent Fixes & Maintenance Notes

- **Parser Error Fixes**: Added explicit type hints to resolve `Cannot infer type` errors
- **Input Actions**: Missing actions added to `project.godot` for character select/navigation
- **Method Renaming**: `Settings.get()`/`set()` renamed to `get_value()`/`set_value()` to avoid Object method overrides
- **Aerials / Down moves (2026-10-10)**: the aerial basic has its own timing and keeps its hitbox through landing; Down + attack in the air is a spike dive; Down in the air is a fast fall / short hop; each roster fighter defines `basic_down` / `special1_down` / `special2_down` with `Fighter.variant()`; bots use them (`AIController._pick_down()`)
- **Down moves reworked / input (2026-10-11)**: every Down move is a different attack (new optional move keys: `wave`, `proj_gravity`, `proj_bounce`, `proj_pierce`, `trap_delay`, `trap_size`, `trap_step`, `root` from projectiles/traps); input presses are captured by `InputHandler._input()`, a Down tap latches for 8 frames, alternate Down keys (P1 Ctrl/Shift, P2 Num Enter/Num .) and the F2 key test (`ui/debug/input_debug.gd`) were added
- **Down move art (2026-10-11)**: `tools/generate_down_fx.py` generates `assets/fx/down_*.png`, `proj_quake`, `proj_quill` and four animated trap strips; traps support `trap_frames` / `trap_fps` / `trap_marker` / `trap_scale`
- **class_name Removal**: Removed from autoloads and inner classes to prevent parser conflicts

### Extension Points

1. **New Moves**: Add to fighter's `_define_moves()` overriding `MOVE_DEFAULTS` values; add a Down variant as `m["<key>_down"] = variant(m.<key>, {...})` (keys: basic, special1, special2). Make it a different attack, not just a lower hitbox: `kind` may change (melee -> projectile / trap / dive) and the optional keys above give trips, shockwaves, bouncing / piercing shots, delayed traps
2. **New AI Behaviors**: Extend `ai/ai_behavior.gd` with new node types
3. **New Menu Options**: Add to `UIManager.gd` and create corresponding tscn/gd files
4. **New Settings**: Add to `Settings.gd` with default values and persistence
5. **Visual Effects**: Modify hit/vfx systems in `core/fighter.gd` or create new VFX nodes

### Testing Approach

1. Launch via `ui/main_menu.tscn` (default) or `arena/main.tscn` for backward compatibility
2. Verify menu navigation works in all menus
3. Test character selection and ready states
4. Confirm AI fighters exhibit distinct personalities based on profiles
5. Check settings persist between sessions
6. Validate hitbox visualization with F1 (`Fighter.debug_boxes`) and the keyboard with F2 (key test)
7. Try each fighter's three Down moves (hold or tap Down + attack / special 1 / special 2)
7. Use godot in headless mode to check for additional errors