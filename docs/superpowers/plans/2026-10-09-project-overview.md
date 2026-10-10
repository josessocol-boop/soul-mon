# Soul-Mon PvP Project Overview

> **For agentic workers:** This document provides a concise overview of the Soul-Mon PvP Godot fighting game project to enable quick understanding without exploring all files.

**Goal:** Provide a structured summary of the Soul-Mon PvP project architecture, systems, and conventions for efficient knowledge transfer.

**Architecture:** Modular Godot 4.3+ project using behavior trees for AI, resource-based configuration for fighter profiles, and autoloads for global systems (settings, UI management). Features clear separation of concerns with fighter logic decoupled from AI control.

**Tech Stack:** Godot 4.3+ (GDScript), JSON-like .tres resources for data, PNG spritesheets, ConfigFile for persistent settings.

**Spec:** This document serves as the project overview spec (no external design doc).

## Global Constraints

- Godot 4.3+ required
- All GDScript files use `class_name` for autoload/types (except where noted in fixes)
- AI uses fair detection only (hitboxes, velocity, position, cooldowns - NO input buffer reading)
- Fighter animations follow strict 64px frame sheet format: idle(4) run(6) jump(2) dash(2) attack(4) hitstun(2) ko(3)
- Settings persist via `user://settings.cfg`
- All move data defined in `MOVE_DEFAULTS` constants with override capability per fighter

## Project Structure

### Core Systems

1. **Fighter System** (`fighter.gd`)
   - Base `CharacterBody2D` class for all fighters
   - Contains core combat mechanics: movement, attacks, hitboxes, stamina
   - Defines `MOVE_DEFAULTS` template for all moves
   - Archetypes subclass this and override `_apply_archetype()` and `_define_moves()`
   - Provides `get_types()` method for elemental typing system
   - Emits signals for gameplay events (jump, dash, attack, etc.) and hit detection

2. **AI System** (Behavior Tree Architecture)
   - `AIController.gd` - Main AI driver that attaches to fighters
     - Uses behavior trees for decision making
     - Applies difficulty scaling and profile-based modifiers
     - Fair detection only (no cheating via input reading)
     - Handles combo buffering, whiff punish tracking
   - `AIBehavior.gd` - Base class for all behavior tree nodes (Selector, Sequence, Condition, Action, etc.)
   - `AIProfile.gd` - Resource-based configuration per fighter personality
     - Personality archetypes: aggressive, defensive, zoning, balanced, hit_and_run, tricky
     - Preferred range: close, mid, far
     - Combo chains, anti-air moves, punish moves, zoning responses, meter management
   - Individual profiles in `ai_profiles/*.tres` for each fighter

3. **Menu/Persistent Systems**
   - `Settings.gd` - Autoload singleton for persistent settings (ConfigFile at `user://settings.cfg`)
     - Stores difficulty, volume, last selected fighters
     - Provides `get_value()`/`set_value()` methods (avoiding Object method overrides)
   - `UIManager.gd` - Autoload singleton for menu stack management
     - Handles pushing/popping menus, transitions
   - Menu scenes: `main_menu.tscn`, `mode_select.tscn`, `options_menu.tscn`, `character_select.tscn`

4. **Character Select System**
   - `character_select.gd` - Full-screen character selection with:
     - Animated portraits (`AnimatedPortrait.gd`)
     - Fighter details panel
     - Ready states for all modes (PvP, PvCPU, CPUvCPU)
     - WASD/Numpad navigation with Enter/KP_Enter selection
   - `animated_portrait.gd` - Reusable animated sprite component for portraits

### Fighter Archetypes (Subclasses of Fighter)

Each fighter in `fighter_*.gd` defines:
- Archetype-specific stats (hp_max, move_speed, jump_velocity, etc.)
- Elemental typing (dual-type system with attack/defense types)
- Unique move set via `_define_moves()`
- Visual elements (sprite sheet path, fx textures)
- Special mechanics via `_apply_archetype()`

Current roster: Blaziken, Brawler, Decidueye, Gengar, Gholdengo, Greninja, Marshadow, Scizor, Tinkaton, Zoner

### Key Conventions

1. **Constants Naming**: ALL_CAPS with underscores for configuration values
2. **Signals**: Used for loose coupling (gameplay events, hit detection)
3. **Node Access**: Fighters access child nodes via `get_node()` in `_ready()` or setup functions
4. **Resource Loading**: `preload()` for constants, `load()` for dynamic resources
5. **Delta Time**: Use `_get_physics_process_delta_time()` for frame-rate independent logic
6. **Export Variables**: `@export` for tunable parameters in inspector
7. **Doc Comments**: Detailed comments explaining constants and systems

### Important Files to Modify

- **Adding New Fighter**: 
  1. Create `fighter_<name>.gd` inheriting from Fighter
  2. Create `fighter_<name>.tscn` scene
  3. Create AI profile in `ai_profiles/<name>.tres`
  4. Add sprite sheet to `assets/` (following 64px frame format)
  5. Update character select roster if needed

- **Modifying AI Behavior**:
  1. Adjust AI profile `.tres` file for personality/tendencies
  2. Create new AIBehavior node types in `AIBehavior.gd` if needed
  3. Modify `AIController.gd` for core AI logic changes

- **Changing Game Mechanics**:
  1. Modify `fighter.gd` for core combat changes
  2. Adjust `MOVE_DEFAULTS` for baseline move properties
  3. Update constants at top of `fighter.gd` for global values

### Recent Fixes & Maintenance Notes

- **Parser Error Fixes**: Added explicit type hints to resolve `Cannot infer type` errors
- **Input Actions**: Missing actions added to `project.godot` for character select/navigation
- **Method Renaming**: `Settings.get()`/`set()` renamed to `get_value()`/`set_value()` to avoid Object method overrides
- **class_name Removal**: Removed from autoloads and inner classes to prevent parser conflicts

### Extension Points

1. **New Moves**: Add to fighter's `_define_moves()` overriding `MOVE_DEFAULTS` values
2. **New AI Behaviors**: Extend `AIBehavior.gd` with new node types
3. **New Menu Options**: Add to `UIManager.gd` and create corresponding tscn/gd files
4. **New Settings**: Add to `Settings.gd` with default values and persistence
5. **Visual Effects**: Modify hit/vfx systems in `fighter.gd` or create new VFX nodes

### Testing Approach

1. Launch via `main_menu.tscn` (default) or `main.tscn` for backward compatibility
2. Verify menu navigation works in all menus
3. Test character selection and ready states
4. Confirm AI fighters exhibit distinct personalities based on profiles
5. Check settings persist between sessions
6. Validate hitbox visualization when `DEBUG_HITBOXES := true`
7. Use godot in headless mode to check for additional errors