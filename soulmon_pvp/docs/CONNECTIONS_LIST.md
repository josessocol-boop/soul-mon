# Soul-Mon PvP - Connections List

## Overview
This document maps the connections between different components in the Soul-Mon PvP codebase to aid in understanding the file structure and relationships.

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
  - **Phase 4:** `hit_confirmed` (enables cancel chains on hit)

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
  - InputMap (registers gameplay actions)
  - Fighter's `_try_actions()` method (consumes buffered inputs)
  - Fighter's `poll()` method (called each frame to update input state)
- **Phase 4:** Per-action buffer windows (`BUFFER_WINDOWS`: attacks/specials/ultimate=9f, movement=6f)
- **Phase 4:** `clear()` method (called on hit to prevent mashing surprises)
- **Phase 4:** `hold_buffers` / `COMBAT_ACTIONS` (keeps combat presses alive during move recovery)

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
  - `ScreenShake` (camera shake) - **Phase 4**
  - `ColorRect` flash layer - **Phase 4**
  - Fighter signals (died, got_hit, event) - **Phase 4: got_hit, event added**
  - ROSTER constant (list of available fighters)
  - Settings access (for difficulty and view mode)
- **Phase 4:** `_build_juice()` - creates ScreenShake, Sfx, flash layer
- **Phase 4:** `_on_got_hit(info)` - spawns HitVfx, DamageNumber, plays SFX, triggers screen shake
- **Phase 4:** `_on_fighter_event(kind, pos)` - plays event sounds, ultimate screen flash

### 9. HUD (`hud.gd`)
**Displays fighter information and controls hint**
- **Connected to:**
  - Two `Fighter` instances (bound via bind() method)
  - Fighter HUD components (`fighter_hud.tscn` instances for P1/P2)
  - Banner label (for round announcements)
  - Help panel (controls hint)
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
  - Fighter's move definitions (projectile kind moves)
  - SupportSystem (for support projectile effects)
- **Phase 4:** Emits `event("shot", pos)` on spawn

### 12. Trap System (`trap.gd` + `trap.tscn`)
**Handles trap spawning and behavior**
- **Connected to:**
  - Fighter's `_spawn_trap()` method
  - ArenaManager (added as child to combat_root)
  - Fighter's move definitions (trap kind moves)
  - SupportSystem (for support trap effects)
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
- **ScreenShake (`screen_shake.gd`):**
  - Extends Camera2D, added as current camera by ArenaManager
  - `shake(strength, frames)` - linear decay shake
  - Connected to: ArenaManager (camera variable)
- **HitVfx (`hit_vfx.gd`):**
  - One-shot elemental burst: ring + sparks + particle emitter
  - `spawn(parent, info)` - static factory from Fighter.got_hit info
  - Element-specific styles (13 elements: Normal, Fire, Water, Grass, Ice, Steel, Ghost, Fighting, Fairy, Bug, Dark, Poison)
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
  - Loads from `res://assets/audio/<name>.wav` (missing files silently skipped)

### 16. Character Select System (`character_select.gd` + `character_select.tscn`)
**Handles fighter selection screen**
- **Connected to:**
  - ArenaManager (instanced and managed via signals)
  - ROSTER data (from ArenaManager)
  - Selection signals (start_requested, cancel_requested, mode_changed)
  - Navigation and selection input handling

### 17. Tools Directory
**Art and effect generation scripts**
- **Connected to:**
  - Asset creation (generate_art.py, generate_roster_art.py, generate_sfx.py)
  - README mentions these tools generate placeholder art/audio
  - Not directly connected to runtime game code

## Data Flow Summary

### 1. Initialization:
- ArenaManager loads and sets up the game scene
- Creates two Fighter instances based on selection
- Each Fighter creates its own InputHandler, StatsComponent, StateMachine, SynergySystem, SupportSystem
- ArenaManager binds fighters to HUD and sets up camera
- **Phase 4:** ArenaManager._build_juice() creates ScreenShake (camera), Sfx, flash layer

### 2. Game Loop (per frame):
- Each Fighter's InputHandler polls for input
- Fighter's _physics_process:
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
  - **Phase 4:** Emits `event("jump"/"dash"/"attack"/etc., pos)`
- StateMachine calls _run_move each frame during the move
- _run_move handles hit detection, movement, and move completion
  - **Phase 4:** On hit: `hit_confirmed = true`, `freeze_frames = hitstop`
  - **Phase 4:** Cancel chains: if hit_confirmed and move on active frames, `_try_special_cancel()` checks for buffered special/ultimate
- On hit: receive_hit applies damage/status, emits got_hit signal
- **Phase 4:** ArenaManager._on_got_hit() spawns HitVfx, DamageNumber, plays SFX, triggers ScreenShake
- Fighter's SynergySystem and SupportSystem update based on hits/dealt damage
- HUD updates to reflect new stats

## Key Connection Points

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
- **Phase 4:** **ArenaManager → ScreenShake/Sfx/HitVfx/DamageNumber:** Owns and triggers all juice systems
- **Phase 4:** **StatsComponent → Fighter:** `tick_statuses()` called during un-frozen physics frames
- **Phase 4:** **InputHandler → Fighter:** `clear()` called on hit to reset buffers