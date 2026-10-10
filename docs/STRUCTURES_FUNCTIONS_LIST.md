# Soul-Mon PvP - Structures and Functions List

## Overview
This document lists the key structures (classes, enums, constants) and functions in the Soul-Mon PvP codebase, explaining what they do and what they're connected to.

## Core Structures

### Classes

#### 1. Fighter (`fighter.gd`)
**Base class for all fighters**
- **What it does:** 
  - Implements core combat mechanics (movement, attacks, defense)
  - Manages hitboxes, hurtboxes, and collision detection
  - Handles hitstun, teching, wavedashing, and movement states
  - Manages visual effects, sprites, and status indicators
  - Coordinates with subsystems (input, stats, state machine, synergy, support)
- **Connected to:** 
  - InputHandler (creates one), StatsComponent (creates one), StateMachine (creates one)
  - SynergySystem (creates one), SupportSystem (creates one)
  - Various Arena2D nodes (hitbox, hurtbox) and Sprite2D nodes (visual effects)
  - All fighter archetypes inherit from this class

#### 2. Fighter Archetypes (fighter_*.gd)
**Specialized fighter classes**
- **Examples:** fighter_marshadow.gd, fighter_gholdengo.gd, fighter_blaziken.gd, etc.
- **What they do:**
  - Override _apply_archetype() to set fighter-specific stats (HP, speed, jump, etc.)
  - Override _define_moves() to define unique move sets
  - Set fighter-specific visuals (sprite sheet, effect textures, colors)
  - Inherit all core combat functionality from base Fighter class
- **Connected to:**
  - Base Fighter class (inheritance)
  - Specific asset files (sprite sheets, effect textures)
  - Unique move definitions and stats

#### 3. InputHandler (`input_handler.gd`)
**Manages input buffering and action detection**
- **What it does:**
  - Tracks button presses with frame-based buffering for forgiving inputs
  - Separates local input from potential network input (remote mode)
  - Implements hold_buffers and hold_all mechanics for hitstop and move buffering
  - Registers all gameplay actions in InputMap
  - Provides want() and consume() methods for checking and using buffered inputs
- **Connected to:**
  - Each Fighter instance (1:1 composition)
  - InputMap (registers gameplay actions)
  - Fighter's _try_actions() and poll() methods

#### 4. StatsComponent (`stats_component.gd`)
**Manages fighter statistics and status effects**
- **What it does:**
  - Tracks HP, max HP, stamina, max stamina
  - Implements stamina regeneration and exhaustion mechanics
  - Manages status effects (burn, poison, slow) as frame counters
  - Provides elemental type system with weakness/resistance/immunity calculations
  - Handles damage over time effects (burn, poison)
  - Provides speed modification based on slow status
- **Connected to:**
  - Each Fighter instance (1:1 composition)
  - Fighter's receive_hit(), take_dot(), and _check_death() methods
  - Status effect application methods (apply_burn, apply_poison, apply_slow)
  - Elemental type lookup (type_multiplier static method)

#### 5. StateMachine (`state_machine.gd`)
**Handles state transitions for fighters**
- **What it does:**
  - Calls fighter.state_<state_name>(delta) each physics frame
  - Manages enter_<state>() and exit_<state>() hooks when changing states
  - Tracks frames spent in current state
  - Untyped fighter reference to avoid circular dependencies
- **Connected to:**
  - Each Fighter instance (1:1 composition)
  - Fighter's state methods (state_idle, state_run, state_attack, etc.)
  - Fighter's enter/exit state hooks

#### 6. SynergySystem (`synergy_system.gd`)
**Manages burst gauge, burst mode, and ultimate abilities**
- **What it does:**
  - Tracks Synergy Burst gauge (0-1000) that fills through combat actions
  - Manages Burst State (READY, ACTIVE, COOLDOWN, ULTIMATE_USED)
  - Implements Burst Mode activation (temporary powered state)
  - Gates Ultimate ability behind full burst gauge during Burst Mode
  - Emits signals for gauge changes, burst state changes, and ultimate usage
  - Allows archetype-specific fill multipliers
- **Connected to:**
  - Each Fighter instance (1:1 composition)
  - Fighter's burst-related variables and traits
  - Fighter's hit connections (on_hit_connect, on_damage_dealt, on_damage_taken)
  - Fighter's burst callbacks (_on_burst_activated, etc.)
  - Fighter's ultimate readiness and usage methods

#### 7. SupportSystem (`support_system.gd`)
**Manages support Pokémon calls**
- **What it does:**
  - Tracks up to 3 support Pokémon slots with individual cooldowns
  - Manages active support effects (duration-based buffs)
  - Provides static definitions for support Pokémon (Pikachu, Eevee, Chansey, etc.)
  - Handles support effect application (instant and duration effects)
  - Tracks damage buffs from support effects
  - Emits signals for support calls, readiness, and cooldowns
- **Connected to:**
  - Each Fighter instance (1:1 composition)
  - Fighter's support-related variables and callbacks
  - Support definitions (static get_support_definition)
  - ArenaManager (for spawning support effects)

#### 8. ArenaManager (`arena_manager.gd`)
**Central game manager**
- **What it does:**
  - Builds and owns the game arena, fighters, HUD, and UI flow
  - Manages fighter selection and match initialization
  - Handles game modes (PvP, PvCPU, CPUvCPU)
  - Manages camera, sound effects, and visual juicing
  - Processes fighter signals (hits, events, deaths) for game reactions
  - Handles restarts and victory conditions
  - Loads and manages the fighter roster
- **Connected to:**
  - Two Fighter instances (p1, p2) - 1:2 composition
  - HUD (displays fighter information)
  - CharacterSelect (character selection screen)
  - AIController (for CPU fighters)
  - ArenaCamera and Sfx (visual and audio systems)
  - Fighter signals (died, got_hit, event)
  - ROSTER constant (list of available fighters)

#### 9. HUD (`hud.gd`)
**Displays fighter information and controls hint**
- **What it does:**
  - Shows two fighter HUD blocks (P1 top-left, P2 top-right)
  - Displays legible controls hint in translucent panel at bottom
  - Shows round winner banners
  - Binds to two Fighter instances to display their stats
  - Updates each frame from bound fighters' stats
- **Connected to:**
  - Two Fighter instances (via bind method)
  - FighterHUD instances (P1 and P2 blocks)
  - Banner label (round announcements)
  - Help panel (controls hint)
  - ArenaManager (added as child and updated each frame)

#### 10. FighterHUD (`fighter_hud.tscn` + `fighter_hud.gd`)
**Displays individual fighter stats**
- **What it does:**
  - Shows HP bar, stamina bar, and status effect indicators
  - Displays skill slots for special moves
  - Shows fighter name and color coding
  - Updates from fighter's stats each frame
- **Connected to:**
  - HUD (instanced as P1 and P2 blocks)
  - Individual Fighter stats (HP, stamina, etc.)
  - Status effect icons (burn, slow, poison)
  - Skill slots (for special move visualization)

#### 11. Projectile (`projectile.gd` + `projectile.tscn`)
**Handles projectile behavior**
- **What it does:**
  - Moves in a straight line with configurable speed
  - Applies hit effects when colliding with fighters
  - Supports vertical velocity per shot (for spread shots)
  - Handles wall sliding to prevent getting stuck in geometry
  - Emits shot event when spawned
- **Connected to:**
  - Fighter's _spawn_projectile() method
  - ArenaManager (added as child to combat_root)
  - Fighter's move definitions (projectile kind moves)
  - SupportSystem (for support projectile effects)

#### 12. Trap (`trap.gd` + `trap.tscn`)
**Handles trap behavior**
- **What it does:**
  - Spawns at a distance from the fighter in the facing direction
  - Waits for fighters to touch it before activating
  - Applies hit effects when triggered
  - Can be configured as persistent or one-time use
  - Emits trap_set event when spawned
- **Connected to:**
  - Fighter's _spawn_trap() method
  - ArenaManager (added as child to combat_root)
  - Fighter's move definitions (trap kind moves)
  - SupportSystem (for support trap effects)

#### 13. AI System (`AIController.gd`, `AIBehavior.gd`, `AIProfile.gd`)
**Provides computer-controlled fighter behavior**
- **What it does:**
  - Implements behavior tree-based AI for fighters
  - Supports multiple difficulty levels (easy, medium, hard)
  - Can target specific fighters and adapt behavior
  - Uses AI profiles to define fighter-specific tendencies
  - Implements behaviors like aggression, spacing, and move selection
- **Connected to:**
  - ArenaManager (_attach_ai method)
  - Fighter instances (added as child when CPU-controlled)
  - Target fighter reference (set via set_target)
  - AI behavior trees and profiles

#### 14. ScreenShake (`screen_shake.gd`) - **Phase 4**
**Camera shake effect system**
- **What it does:**
  - Extends Camera2D to provide screenspace shake
  - `shake(strength: float, frames: int)` - triggers shake with linear decay over duration
  - Strength is compared against current shake; only stronger shakes override
  - `offset` is updated each physics frame with random vector scaled by remaining time fraction
- **Connected to:**
  - ArenaManager (created in _build_juice, set as current camera)
  - ArenaManager._on_got_hit() calls camera.shake() with amplitude based on damage
  - ArenaManager._on_fighter_event() shakes on ultimate

#### 15. HitVfx (`hit_vfx.gd`) - **Phase 4**
**Elemental hit burst visual effects**
- **What it does:**
  - One-shot Node2D that spawns impact ring + sparks + element-colored particle emitters
  - Static `spawn(parent: Node, info: Dictionary)` factory method
  - 13 element-specific styles (Normal, Fire, Water, Grass, Ice, Steel, Ghost, Fighting, Fairy, Bug, Dark, Poison)
  - Each style defines: colors, particle count, velocity range, gravity, size, lifetime, spread
  - Super-effective hits (mult > 1.0) add gold star burst overlay
  - KO hits (info.ko) and heavy hits boost particle counts and ring size
  - Auto-cleans up after 1.2s via timer
  - Draws expanding ring in _draw() for 0.18s
- **Connected to:**
  - ArenaManager._on_got_hit() calls HitVfx.spawn(combat_root, info)
  - Receives hit info: pos, element, dmg, mult, dir, heavy, ko, hitstop, kb

#### 16. DamageNumber (`damage_number.gd`) - **Phase 4**
**Floating damage number popups**
- **What it does:**
  - Extends Label, shows damage value with optional "!" for super-effective
  - Static `spawn(parent: Node, info: Dictionary)` factory
  - Color coding: gold for super-effective (mult > 1.0), muted grey for resisted (mult < 1.0), red for KO, white for normal
  - KO hits use larger font (34), heavy hits use 28, normal use 20
  - Tween animation: rises 44-58px over 0.65s, pops scale (back ease), fades after 0.35s, auto-frees
  - KO adds slight random rotation
- **Connected to:**
  - ArenaManager._on_got_hit() calls DamageNumber.spawn(combat_root, info)

#### 17. Sfx (`sfx.gd`) - **Phase 4**
**Positional sound effect pool player**
- **What it does:**
  - Manages pool of 12 AudioStreamPlayer2D instances
  - Loads streams from `res://assets/audio/<name>.wav` on demand (caches)
  - Missing files silently skipped (drop in real audio to replace)
  - `play(sound, pos, volume_db, pitch)` - finds free player, sets position/volume/pitch, plays
  - Max distance 4000 (heard across arena)
- **Connected to:**
  - ArenaManager (created in _build_juice)
  - ArenaManager._on_got_hit() plays hit_light/hit_heavy/hit_ko + hit_super (super-effective)
  - ArenaManager._on_fighter_event() plays EVENT_SOUNDS mapping (jump, dash, attack, special1, special2, ultimate, shot, trap_set)
  - Element pitch variation via ELEMENT_PITCH constant

### Enums

#### 1. StatsComponent.Element (`stats_component.gd`)
**Elemental types for the type effectiveness system**
- **Values:** NORMAL, FIRE, WATER, GRASS, ICE, STEEL, GHOST, FIGHTING, FAIRY, BUG, DARK, POISON
- **What it does:** Defines the elemental types used in the game's type effectiveness system
- **Connected to:**
  - Fighter's element and types variables
  - StatsComponent's type_multiplier method
  - Move definitions (element override)
  - Status effect application (burn from fire, slow from water, poison from poison)

#### 2. SynergySystem.BurstState (`synergy_system.gd`)
**States of the Synergy Burst system**
- **Values:** READY, ACTIVE, COOLDOWN, ULTIMATE_USED
- **What it does:** Tracks the current state of a fighter's burst gauge
- **Connected to:**
  - SynergySystem's state variable
  - Burst activation, end, and ultimate usage logic
  - Gauge filling and ultimate availability checks

#### 3. SupportSystem.SupportType (`support_system.gd`)
**Types of support effects**
- **Values:** ATTACK, BUFF, HEAL, UTILITY
- **What it does:** Categorizes support Pokémon by their effect type
- **Connected to:**
  - Support definitions in get_support_definition
  - Effect application logic (_apply_support_effect)
  - Active effect tracking

### Constants

#### 1. Fighter Constants (`fighter.gd`)
**Core combat tuning values**
- **Examples:** GRAVITY_RISE, GRAVITY_FALL, JUMP_CUT, GROUND_ACCEL, AIR_ACCEL
- **What they do:** Tune core movement and combat physics
- **Connected to:** Fighter's _gravity, _steer, and movement methods

#### 2. Fighter.Anims (`fighter.gd`)
**Animation definition for fighter sprite sheets**
- **Value:** [["idle", 4, 6.0, true], ["run", 6, 12.0, true], ["jump", 2, 6.0, false], ["dash", 2, 10.0, false], ["attack", 4, 16.0, false], ["hitstun", 2, 8.0, true], ["ko", 3, 6.0, false]]
- **What it does:** Defines the animation rows in fighter sprite sheets
- **Connected to:** Fighter's _build_frames and _setup_visuals methods

#### 3. Fighter.MOVE_DEFAULTS (`fighter.gd`)
**Default move template**
- **What it does:** Provides default values for all move properties
- **Connected to:** Fighter's mv() helper method and _define_moves defaults

#### 4. StatsComponent Constants (`stats_component.gd`)
**Status effect and type system constants**
- **Examples:** BURN_DAMAGE, BURN_TICKS, POISON_DAMAGE, POISON_TICKS, SLOW_FACTOR
- **What they do:** Tune status effect duration and strength
- **Connected to:** Status effect application and ticking methods

#### 5. SynergySystem Constants (`synergy_system.gd`)
**Burst system tuning values**
- **Examples:** GAUGE_MAX, GAUGE_FILL_ON_HIT, BURST_DURATION, BURST_COOLDOWN
- **What they do:** Tune burst gauge fill rates, duration, and cooldowns
- **Connected to:** Gauge filling, burst activation, and ultimate logic

#### 6. SupportSystem Constants (`support_system.gd`)
**Support system tuning values**
- **Examples:** MAX_SUPPORTS, BASE_COOLDOWN
- **What they do:** Tune support slot count and base cooldown times
- **Connected to:** Support initialization and cooldown tracking

#### 7. ArenaManager Constants (`arena_manager.gd`)
**Game world and tuning constants**
- **Examples:** FLOOR_TOP, SHAKE_SCALE, ELEMENT_PITCH, EVENT_SOUNDS, ROSTER
- **What they do:** Define game world boundaries, audio mapping, and available fighters
- **Connected to:** Arena building, audio system, hit reactions, and fighter selection

#### 8. InputHandler Constants (`input_handler.gd`)
**Input buffering constants**
- **Examples:** BUFFER_WINDOWS, COMBAT_ACTIONS
- **What they do:** Define input buffer durations for different actions
- **Connected to:** Input polling and buffer management

#### 9. Phase 4 Juice Constants - **Phase 4**
**Screen shake, VFX, and audio tuning**

**Fighter (`fighter.gd`):**
- `HITSTOP_SCALE := 1.0` - Global hitstop multiplier (0 = disabled)
- `KO_HITSTOP := 12` - Extra hitstop frames on killing blow
- `BUFFER_TAIL := 8` - Combat presses held until last N frames of move

**ArenaManager (`arena_manager.gd`):**
- `SHAKE_SCALE := 1.0` - Global screen shake multiplier (0 = disabled)
- `ELEMENT_PITCH := {GHOST: 0.85, STEEL: 1.25, FAIRY: 1.4, FIRE: 0.95, DARK: 0.8, POISON: 0.9}` - Hit sound pitch per element
- `EVENT_SOUNDS := {"jump": "jump", "dash": "dash", "attack": "swing", "special1": "swing_special", "special2": "swing_special", "ultimate": "ultimate", "shot": "shot", "trap_set": "trap_set"}` - Gameplay event to sound file mapping

**StatsComponent (`stats_component.gd`):**
- `FPS := 60` - Frame rate for deterministic status effect tick timing

**ScreenShake (`screen_shake.gd`):**
- Shake decays linearly: `offset = random_vector * amp * (frames_left / total)`

**HitVfx (`hit_vfx.gd`):**
- `STYLE` dictionary - 13 element-specific particle configurations (color, count, velocity, gravity, size, lifetime, spread)
- Ring animation: 0.18s duration, expands from 40% to 100% of `ring_size`

**DamageNumber (`damage_number.gd`):**
- Font sizes: KO=34, heavy=28, normal=20
- Animation: rise 44-58px over 0.65s, scale pop 1.2x (0.12s back-ease), fade after 0.35s, auto-free at 1.2s

**Sfx (`sfx.gd`):**
- `POOL := 12` - AudioStreamPlayer2D pool size
- `max_distance = 4000.0` - Heard across arena

- **What they do:** Tune visual/audio feedback for hits, movement, and combat events
- **Connected to:** ArenaManager._on_got_hit(), _on_fighter_event(), Fighter hitstop/cancel logic

## Key Functions

### Fighter Class Functions

#### 1. Fighter._apply_archetype() 
- **What it does:** Sets fighter-specific stats (HP, speed, jump, etc.) - overridden by archetypes
- **Connected to:** Fighter._ready() calls this during initialization

#### 2. Fighter._define_moves()
- **What it does:** Defines the fighter's move set - overridden by archetypes
- **Connected to:** Fighter._ready() uses this to set up moves

#### 3. Fighter.configure(p_prefix: String, face: int)
- **What it sets:** Sets up fighter prefix ("p1"/"p2") and facing direction (1/-1)
- **Connected to:** ArenaManager._start_match() calls this when spawning fighters

#### 4. Fighter._ready()
- **What it does:** Initializes the fighter: applies archetype, sets up collision shapes, creates subsystems, binds signals
- **Connected to:** Godot engine calls this when the node enters the scene tree

#### 5. Fighter._physics_process(delta: float)
- **What it does:** Main game loop for fighters: processes input, updates state machine, handles hitstop, ticks stats, updates visuals
- **Connected to:** Godot engine calls this each physics frame

#### 6. Fighter._try_actions() -> bool
- **What it does:** Checks for buffered inputs and attempts to change state to perform actions
- **Connected to:** Fighter state methods call this to check for action inputs

#### 7. Fighter.receive_hit(attacker: Fighter, damage: float, kb: Vector2, from_x: float, move_data: Dictionary) -> bool
- **What it does:** Applies damage to the fighter, handles hitstop, status effects, knockback, and hit confirmation
- **Connected to:** Fighter's _check_hits() method calls this on overlapping hitboxes

#### 8. Fighter._check_hits()
- **What it does:** Checks the fighter's hitbox for overlaps with enemy hurtboxes and processes hits
- **Connected to:** Fighter's _run_move() calls this during melee moves

#### 9. Fighter._run_move(delta: float)
- **What it does:** General move runner that handles movement, hit detection, and move completion for most move kinds
- **Connected to:** Fighter state methods for attack, special1, special2, ultimate call this

#### 10. Fighter._enter_move(key: String)
- **What it does:** Sets up variables for a new move (current move, hit tracking, visuals, etc.)
- **Connected to:** Fighter's enter_*_state methods call this

#### 11. Fighter._finish_move()
- **What it does:** Transitions back to idle or jump state after a move completes
- **Connected to:** Fighter._run_move() calls this when a move finishes

#### 12. Fighter._spawn_projectile(m: Dictionary, vy: float)
- **What it does:** Spawns a projectile based on move data and vertical velocity
- **Connected to:** Fighter._spawn_scheduled() calls this for projectile moves

#### 13. Fighter._spawn_trap(m: Dictionary)
- **What it does:** Spawns a trap based on move data
- **Connected to:** Fighter._spawn_scheduled() calls this for trap moves

#### 14. Fighter._wavedash()
- **What it does:** Performs a wavedash (air dodge into horizontal burst with i-frames)
- **Connected to:** Fighter.state_jump() calls this when dash is pressed during jump

#### 15. Fighter.state_*_methods (state_idle, state_run, state_jump, state_dash, etc.)
- **What they do:** Handle logic for each fighter state (movement, actions, state transitions)
- **Connected to:** StateMachine.tick() calls the appropriate state method each frame

#### 16. Fighter.enter_*_methods (enter_attack, enter_special1, etc.)
- **What they do:** Set up when entering a move state (calls _enter_move)
- **Connected to:** StateMachine's enter_<state>() hook calls these

#### 17. Fighter.exit_*_methods (exit_attack, exit_special1, etc.)
- **What they do:** Clean up when exiting a move state (calls _end_move)
- **Connected to:** StateMachine's exit_<state>() hook calls these

#### 18. Fighter._setup_visuals()
- **What it does:** Sets up the fighter's sprite, effects, and status icons
- **Connected to:** Fighter._ready() calls this during initialization

#### 19. Fighter._update_visuals()
- **What it does:** Updates the fighter's visual appearance each frame (sprite, effects, icons, etc.)
- **Connected to:** Fighter._physics_process() calls this each frame

#### 20. Fighter.event.emit(kind: String, pos: Vector2)
- **What it does:** Emits gameplay events for sound/VFX hooks (jump, dash, attack, special1, special2, ultimate, shot, trap_set)
- **Connected to:** Various fighter methods call this during actions, ArenaManager receives it for audio/VFX

#### 21. Fighter.got_hit.emit(info: Dictionary)
- **What it does:** Emits when the fighter gets hit (contains hit details)
- **Connected to:** Fighter.receive_hit() calls this, ArenaManager receives it for hit reactions

#### 22. Fighter.died.emit(fighter)
- **What it does:** Emits when the fighter dies
- **Connected to:** Fighter._check_death() calls this, ArenaManager receives it for victory handling

#### 23. Fighter._try_special_cancel() -> bool - **Phase 4**
- **What it does:** Checks for buffered special/ultimate inputs on hit confirm; enables cancel chains (basic → special1 → special2 → ultimate). Priority: ultimate (if full stamina) > special2 > special1. Consumes input and stamina, changes state.
- **Connected to:** Fighter._run_move() calls this when hit_confirmed and move is in active frames (on >= frame)

#### 24. Fighter._hitstop_frames(dmg: float, m: Dictionary) -> int - **Phase 4**
- **What it does:** Calculates hitstop frames based on damage: 3f (<6 dmg), 4f (6-10), 5f (10-18), 6f (18-30), 7f (30+). Multi-hit moves (hit_interval > 0) capped at 2f. Scaled by HITSTOP_SCALE. KO hits use KO_HITSTOP (12).
- **Connected to:** Fighter.receive_hit() calls this to set freeze_frames on both attacker and defender

#### 25. Fighter._end_move() - **Phase 4 (updated)**
- **What it does:** Resets move state (hit_confirmed = false, move_spawned = 0, move_teleported = false), emits event for the move kind, transitions via _finish_move()
- **Connected to:** Fighter exit_*_state hooks call this

### InputHandler Functions

#### 1. InputHandler.poll()
- **What it does:** Updates input state each frame (gets axis values, checks button presses, manages buffers)
- **Connected to:** Fighter._physics_process() calls this each frame

#### 2. InputHandler.want(action: String) -> bool
- **What it does:** Checks if an action is currently buffered and available
- **Connected to:** Fighter._try_actions() calls this to check for inputs

#### 3. InputHandler.consume(action: String)
- **What it does:** Consumes (clears) a buffered action input
- **Connected to:** Fighter._try_actions() calls this after using an input

#### 4. InputHandler.clear()
- **What it does:** Clears all buffered inputs
- **Connected to:** Fighter.receive_hit() calls this during hitstop to prevent surprise moves

#### 5. InputHandler.register_actions()
- **What it does:** Registers all gameplay actions in the InputMap
- **Connected to:** ArenaManager._setup() calls this during initialization

### StatsComponent Functions

#### 1. StatsComponent.tick(delta: float)
- **What it does:** Regenerates stamina over time
- **Connected to:** Fighter._physics_process() calls this each frame (when not in hitstop)

#### 2. StatsComponent.can_spend(cost: float) -> bool
- **What it does:** Checks if the fighter has enough stamina to spend
- **Connected to:** Fighter._try_actions() calls this before attempting actions

#### 3. StatsComponent.spend(cost: float)
- **What it does:** Spends stamina and sets exhausted flag if empty
- **Connected to:** Fighter methods call this when performing actions that cost stamina

#### 4. StatsComponent.gain_stamina(amount: float)
- **What it does:** Adds stamina (capped at max)
- **Connected to:** Fighter.receive_hit() calls this on basic attack hits

#### 5. StatsComponent.tick_statuses()
- **What it does:** Updates status effect timers and emits tick signals for burn/poison
- **Connected to:** Fighter._physics_process() calls this each frame (when not in hitstop)

#### 6. StatsComponent.apply_burn(), apply_poison(), apply_slow()
- **What they do:** Apply the respective status effects
- **Connected to:** Fighter._apply_status() calls these based on element and move data

#### 7. StatsComponent.burning(), poisoned(), slowed() -> bool
- **What they do:** Check if the respective status is active
- **Connected to:** Fighter._update_visuals() calls these to update visual indicators

#### 8. StatsComponent.get_speed() -> float
- **What it does:** Gets current speed modified by slow status
- **Connected to:** Fighter._steer() uses this for movement speed calculation

#### 9. StatsComponent.clear_statuses()
- **What it does:** Clears all status effects
- **Connected to:** Fighter._check_death() and ArenaManager._on_died() call this on fighter death

#### 10. StatsComponent.type_multiplier(attacker: int, defenders: Array) -> float (static)
- **What it does:** Calculates type effectiveness multiplier based on attacker element and defender types
- **Connected to:** Fighter.receive_hit() calls this to calculate damage multiplier

### StateMachine Functions

#### 1. StateMachine.start(f: Node, initial: String)
- **What it does:** Initializes the state machine with a fighter and starting state
- **Connected to:** Fighter._ready() calls this to set up the state machine

#### 2. StateMachine.change(next: String)
- **What it does:** Changes to a new state (calls exit_<current> and enter_<next> hooks)
- **Connected to:** Fighter state methods call this to transition states

#### 3. StateMachine.tick(delta: float)
- **What it does:** Increments frame counter and calls the fighter's current state method
- **Connected to:** Fighter._physics_process() calls this each frame

#### 4. StateMachine._hook(prefix: String)
- **What it does:** Calls enter_<state> or exit_<state> method on the fighter if it exists
- **Connected to:** StateMachine.start() and StateMachine.change() call this

### SynergySystem Functions

#### 1. SynergySystem.set_player(pid: int)
- **What it does:** Sets which player this system belongs to (for signaling)
- **Connected to:** Fighter._ready() calls this during initialization

#### 2. SynergySystem.set_archetype_traits(traits: Dictionary)
- **What it does:** Sets archetype-specific burst fill multipliers
- **Connected to:** Fighter._ready() calls this during initialization

#### 3. SynergySystem._process(delta: float)
- **What it does:** Updates burst and cooldown timers each frame
- **Connected to:** Godot engine calls this each frame (process_mode = ALWAYS)

#### 4. SynergySystem._fill_gauge(amount: float)
- **What it does:** Adds amount to the burst gauge (with clamping) and emits gauge_changed signal
- **Connected to:** Various on_* methods call this to fill the gauge

#### 5. SynergySystem.on_hit_connect(is_counter: bool = false)
- **What it does:** Fills burst gauge when a move connects (more on counter hits)
- **Connected to:** Fighter._check_hits() calls this when a hit connects

#### 6. SynergySystem.on_damage_dealt(amount: float)
- **What it does:** Fills burst gauge based on damage dealt
- **Connected to:** Fighter.receive_hit() calls this after applying damage

#### 7. SynergySystem.on_damage_taken(amount: float)
- **What it does:** Fills burst gauge based on damage taken
- **Connected to:** Fighter.receive_hit() calls this after taking damage

#### 8. SynergySystem.try_activate_burst() -> bool
- **What it does:** Attempts to activate Burst Mode if ready and gauge is full
- **Connected to:** Fighter methods call this to check for burst activation

#### 9. SynergySystem._end_burst()
- **What it does:** Ends Burst Mode and sets appropriate cooldown state
- **Connected to:** SynergySystem._process() calls this when burst timer expires

#### 10. SynergySystem.try_use_ultimate() -> bool
- **What it does:** Attempts to use the ultimate ability if in Burst Mode and gauge is full
- **Connected to:** Fighter._try_actions() calls this for ultimate input

#### 11. SynergySystem._end_burst() (continued)
- **What it does:** Ends burst early after ultimate use and sets ULTIMATE_USED state
- **Connected to:** SynergySystem.try_use_ultimate() calls this after using ultimate

#### 12. SynergySystem.get_burst_time_remaining() -> float
- **What it does:** Gets remaining time in current Burst Mode
- **Connected to:** Fighter UI might use this for burst timer display

#### 13. SynergySystem.get_cooldown_remaining() -> float
- **What it does:** Gets remaining time before burst gauge can refill again
- **Connected to:** Fighter UI might use this for burst cooldown display

#### 14. SynergySystem.is_burst_active() -> bool
- **What it does:** Checks if Burst Mode is currently active
- **Connected to:** Fighter methods check this for burst armor and passive heal

#### 15. SynergySystem.is_ultimate_available() -> bool
- **What it does:** Checks if the ultimate can be used right now
- **Connected to:** Fighter._try_actions() calls this for ultimate input

#### 16. SynergySystem.reset()
- **What it does:** Resets the burst system to initial state
- **Connected to:** ArenaManager._start_match() might call this for new matches

### SupportSystem Functions

#### 1. SupportSystem.set_player(pid: int)
- **What it does:** Sets which player this system belongs to (for signaling)
- **Connected to:** Fighter._ready() calls this during initialization

#### 2. SupportSystem.set_supports(support_ids: Array)
- **What it does:** Sets which support Pokémon are available in each slot
- **Connected to:** CharacterSelect or save data would call this to set up supports

#### 3. SupportSystem._process(delta: float)
- **What it does:** Updates cooldown timers and active effects each frame
- **Connected to:** Godot engine calls this each frame (process_mode = ALWAYS)

#### 4. SupportSystem.try_call_support(slot: int) -> bool
- **What it does:** Attempts to call a support from the specified slot
- **Connected to:** Fighter._try_actions() calls this for support input

#### 5. SupportSystem._apply_support_effect(effect: Dictionary)
- **What it does:** Applies a support effect (instant or duration)
- **Connected to:** SupportSystem.try_call_support() calls this after verifying the call

#### 6. SupportSystem._apply_instant_effect(effect: Dictionary)
- **What it does:** Applies an instant support effect (like a projectile or melee hit)
- **Connected to:** SupportSystem._apply_support_effect() calls this for instant effects

#### 7. SupportSystem._apply_duration_effect(effect: Dictionary)
- **What it does:** Applies a duration-based support effect (like a damage buff)
- **Connected to:** SupportSystem._apply_support_effect() calls this for duration effects

#### 8. SupportSystem._remove_effect(effect: Dictionary)
- **What it does:** Removes an active duration effect when its timer expires
- **Connected to:** SupportSystem._process() calls this when effect timers reach zero

#### 9. SupportSystem.get_damage_multiplier() -> float
- **What it does:** Gets the combined damage multiplier from active damage buff effects
- **Connected to:** Fighter damage calculation might use this

#### 10. SupportSystem.get_cooldown_remaining(slot: int) -> float
- **What it does:** Gets remaining cooldown for a specific support slot
- **Connected to:** Fighter UI might use this for support cooldown display

#### 11. SupportSystem.is_support_ready(slot: int) -> bool
- **What it does:** Checks if a support in a specific slot is ready to be used
- **Connected to:** Fighter._try_actions() calls this for support input

#### 12. SupportSystem.reset()
- **What it does:** Resets all supports to ready state and clears active effects
- **Connected to:** ArenaManager._start_match() might call this for new matches

### ArenaManager Functions

#### 1. ArenaManager._setup()
- **What it does:** Sets up the game: registers input handlers, builds arena and juice, instantiates HUD and character select
- **Connected to:** Godot engine calls this via call_deferred() from _ready()

#### 2. ArenaManager._build_arena(root: Node)
- **What it does:** Builds the game arena with background, floor, walls, and colliders
- **Connected to:** ArenaManager._setup() calls this

#### 3. ArenaManager._build_juice(root: Node)
- **What it does:** Sets up camera, sound effects, and visual juicing (flash effect)
- **Connected to:** ArenaManager._setup() calls this

#### 4. ArenaManager._start_match(p1_id: String, p2_id: String)
- **What it does:** Starts a new match with the specified fighters (handles CPU prefixes)
- **Connected to:** ArenaManager._setup() and _on_selection_applied() call this

#### 5. ArenaManager._fighter_data(fighter_id: String) -> Dictionary
- **What it does:** Looks up fighter data in the ROSTER constant
- **Connected to:** Various ArenaManager methods call this to get fighter info

#### 6. ArenaManager._roster_index(fighter_id: String) -> int
- **What it does:** Gets the index of a fighter in the ROSTER constant
- **Connected to:** ArenaManager._setup() and _start_match() call this for character select

#### 7. ArenaManager._attach_ai(fighter: Fighter, target: Fighter, difficulty: String)
- **What it does:** Attaches an AI controller to a fighter for CPU control
- **Connected to:** ArenaManager._start_match() calls this for CPU fighters

#### 8. ArenaManager._on_died(loser: Fighter)
- **What it does:** Handles a fighter dying (shows winner banner, pauses fighters)
- **Connected to:** Fighter.died signal connects to this

#### 9. ArenaManager._on_got_hit(info: Dictionary)
- **What it does:** Handles a fighter getting hit (screen shake, audio, VFX, damage numbers)
- **Connected to:** Fighter.got_hit signal connects to this

#### 10. ArenaManager._on_fighter_event(kind: String, pos: Vector2)
- **What it does:** Handles fighter events (jump, dash, attack, etc.) for audio feedback
- **Connected to:** Fighter.event signal connects to this

#### 11. ArenaManager._on_selection_applied(p1_id: String, p2_id: String)
- **What it does:** Handles when character selection is confirmed (starts the match)
- **Connected to:** CharacterSelect.start_requested signal connects to this

#### 12. ArenaManager._on_selection_cancelled()
- **What it does:** Handles when character selection is cancelled (hides select menu)
- **Connected to:** CharacterSelect.cancel_requested signal connects to this

#### 13. ArenaManager._on_mode_changed(is_pvp: bool)
- **What it does:** Handles when the game mode checkbox is toggled
- **Connected to:** CharacterSelect.mode_changed signal connects to this

#### 14. ArenaManager._unhandled_input(event: InputEvent)
- **What it does:** Handles unhandled input (Tab for character select, R for restart)
- **Connected to:** Godot engine calls this for unhandled input events

### HUD Functions

#### 1. HUD._ready()
- **What it does:** Initializes the HUD (sets up help panel styling)
- **Connected to:** Godot engine calls this when the node enters the scene tree

#### 2. HUD._style_help()
- **What it does:** Styles the help panel (controls hint) with outline and background
- **Connected to:** HUD._ready() calls this

#### 3. HUD.bind(a: Fighter, b: Fighter, name1: String, name2: String)
- **What it does:** Binds two fighters to the HUD for display
- **Connected to:** ArenaManager._start_match() calls this after spawning fighters

#### 4. HUD.show_banner(text: String)
- **What it does:** Shows a banner message (for round winners)
- **Connected to:** ArenaManager._on_died() calls this to show winner banner

#### 5. HUD._process(_delta: float)
- **What it does:** Updates each frame from bound fighters' stats
- **Connected to:** Godot engine calls this each frame

#### 6. HUD.fighter_hud.tscn (P1 and P2 blocks)
- **What it does:** Displays individual fighter stats (HP, stamina, status, skills)
- **Connected to:** HUD.bind() sets up these instances, FighterHUD.update_from() updates them

### FighterHUD Functions (in fighter_hud.tscn)

#### 1. FighterHUD.setup(name: String, is_p2: Boolean, color: Color)
- **What it does:** Initializes the fighter HUD with name, side indicator, and color
- **Connected to:** HUD.bind() calls this on instantiation

#### 2. FighterHUD.update_from(fighter: Fighter)
- **What it does:** Updates the HUD display from a fighter's current stats
- **Connected to:** HUD._process() calls this each frame for each bound fighter

### ScreenShake Functions (`screen_shake.gd`) - **Phase 4**

#### 1. ScreenShake.shake(strength: float, frames: int)
- **What it does:** Triggers a screen shake. Only overrides current shake if new strength >= current effective strength. Sets amp, total frames, and frames_left.
- **Connected to:** ArenaManager._on_got_hit() (damage-based), ArenaManager._on_fighter_event() (ultimate)

#### 2. ScreenShake._physics_process(_delta: float)
- **What it does:** Updates offset each frame: random vector * amp * (frames_left/total). Decays linearly to zero.
- **Connected to:** Godot engine calls this each physics frame

### HitVfx Functions (`hit_vfx.gd`) - **Phase 4**

#### 1. HitVfx.spawn(parent: Node, info: Dictionary) (static)
- **What it does:** Factory method - creates HitVfx instance, positions at info.pos, adds to parent, calls burst()
- **Connected to:** ArenaManager._on_got_hit() calls this for every hit

#### 2. HitVfx.burst(info: Dictionary)
- **What it does:** Spawns ring + element-specific particle emitters + super-effective gold burst if mult > 1.0. Sets up 1.2s auto-free timer.
- **Connected to:** HitVfx.spawn() calls this immediately

#### 3. HitVfx._emitter(count, c1, c2, vmin, vmax, grav, smin, smax, life, spread, dir)
- **What it does:** Creates and configures a CPUParticles2D with given parameters for particles/sparks/ring
- **Connected to:** HitVfx.burst() calls this 2-3 times per hit

#### 4. HitVfx._process(delta: float)
- **What it does:** Increments ring_t, queues redraw for ring animation
- **Connected to:** Godot engine calls each frame

#### 5. HitVfx._draw()
- **What it does:** Draws expanding ring (arc) for 0.18s, fading out
- **Connected to:** Godot engine calls when redraw queued

### DamageNumber Functions (`damage_number.gd`) - **Phase 4**

#### 1. DamageNumber.spawn(parent: Node, info: Dictionary) (static)
- **What it does:** Factory - creates Label, sets text/color/outline/size from info (dmg, mult, heavy, ko), positions, adds tweens for rise/pop/fade, auto-frees
- **Connected to:** ArenaManager._on_got_hit() calls this for every hit

#### 2. DamageNumber._damage_color(mult: float, ko: bool) -> Color (static)
- **What it does:** Returns color: KO=red, super-effective=gold, resisted=muted grey, normal=white
- **Connected to:** DamageNumber.spawn() calls this

### Sfx Functions (`sfx.gd`) - **Phase 4**

#### 1. Sfx._ready()
- **What it does:** Creates pool of 12 AudioStreamPlayer2D instances, sets max_distance=4000
- **Connected to:** Godot engine calls on node enter tree

#### 2. Sfx.play(sound: String, pos: Vector2, volume_db: float, pitch: float)
- **What it does:** Loads/caches stream from assets/audio/<name>.wav, finds free player, sets pos/volume/pitch, plays. Missing files silently skipped.
- **Connected to:** ArenaManager._on_got_hit() (hit sounds), ArenaManager._on_fighter_event() (gameplay sounds)

## Signal Connections

### Fighter Signals
- **died(fighter)** → ArenaManager._on_died()
- **got_hit(info: Dictionary)** → ArenaManager._on_got_hit()
- **event(kind: String, pos: Vector2)** → ArenaManager._on_fighter_event()

### SynergySystem Signals
- **burst_activated(player_id: int)** → Fighter._on_burst_activated()
- **burst_ended(player_id: int)** → Fighter._on_burst_ended()
- **ultimate_ready(player_id: int)** → Fighter._on_ultimate_ready()
- **ultimate_used(player_id: int)** → Fighter._on_ultimate_used()
- **gauge_changed(player_id: int, value: float, max_value: float)** → (Possibly UI or debug)

### SupportSystem Signals
- **support_called(player_id: int, support_id: String)** → Fighter._on_support_called()
- **support_ready(player_id: int, slot: int)** → (Possibly UI for support readiness)
- **support_cooldown(player_id: int, slot: int, time: float)** → (Possibly UI for support cooldown)

### CharacterSelect Signals (connected to ArenaManager)
- **start_requested(p1_id: String, p2_id: String)** → ArenaManager._on_selection_applied()
- **cancel_requested** → ArenaManager._on_selection_cancelled()
- **mode_changed(is_pvp: bool)** → ArenaManager._on_mode_changed()

## Data Structures and Containers

### 1. Fighter Variables
- **var input: InputHandler** - Composition: Fighter owns its input handler
- **var stats: StatsComponent** - Composition: Fighter owns its stats component
- **var sm: StateMachine** - Composition: Fighter owns its state machine
- **var synergy: SynergySystem** - Composition: Fighter owns its synergy system
- **var support: SupportSystem** - Composition: Fighter owns its support system
- **var hitbox: Area2D, hurtbox: Area2D** - Nodes for collision detection
- **var move_fx: Sprite2D** - Node for move effects
- **var burn_icon, slow_icon, poison_icon: Sprite2D** - Nodes for status indicators
- **var sprite: AnimatedSprite2D** - Node for visual representation
- **var hit_targets: Array, hit_counts: Dictionary** - Tracks hit confirmation for move canceling
- **var cooldowns: Dictionary** - Tracks special move cooldowns
- **var cur_move: Dictionary, cur_key: String** - Tracks current move being executed
- **var move_inv: Boolean, move_iframes_left: int** - Tracks move invincibility frames
- **var rooted_time: float** - Tracks time rooted from moves
- **var tech_cd: float, tech_since_land: int** - Tracks tech cooldown and window
- **var wavedash_left: int** - Tracks wavedash glide frames
- **var air_dashed: Boolean** - Tracks if air dash used this jump
- **var stun_air: Boolean** - Tracks if launched into air during hitstun
- **var di_input: float** - Stores directional influence input during hitstun
- **var next_damage_buff: float, next_hitstun_mult: float** - Tracks pending buffs from synergy/support
- **var freeze_frames: int** - Tracks hitstop freeze frames
- **var hit_confirmed: Boolean** - Tracks if current move has connected (for canceling)
- **var projectile_block: Boolean** - Tracks if fighter is blocking projectiles
- **var counter_active: Boolean** - Tests if counter window is active
- **var move_spawned: int, move_teleported: bool** - Tracks if move has spawned projectiles/teleported
- **var dive_active: Boolean, dive_end: int** - Tracks dive move state

### 2. StatsComponent Variables
- **var max_hp := 100.0, hp := 100.0** - Health points
- **var max_stamina := 100.0, stamina := 100.0** - Stamina points
- **var base_speed := 260.0** - Base movement speed
- **var element: Element = Element.NORMAL** - Primary (attack) type
- **var types: Array = []** - All types (1 or 2) used when defending
- **var exhausted := false** - Stamina exhaustion flag
- **var burn_left := 0, burn_phase := 0** - Burn status effect timers
- **var poison_left := 0, poison_phase := 0** - Poison status effect timers
- **var slow_left := 0** - Slow status effect timer

### 3. InputHandler Variables
- **var prefix := "p1"** - Input prefix ("p1_" or "p2_")
- **var remote := false** - Whether input is coming from network (future feature)
- **var enabled := true** - Whether input processing is enabled
- **var hold_buffers := false** - Whether to hold input buffers during move recovery
- **var hold_all := false** - Whether to hold all input buffers (during hitstop)
- **var move_x := 0.0** - Horizontal axis value (-1 to 1)
- **var jump_held := false** - Whether jump button is currently held
- **var buffer := {"jump": 0, "dash": 0, "attack": 0, "special1": 0, "special2": 0, "ultimate": 0, "support": 0, "support_2": 0, "support_3": 0}** - Input buffer frames for each action

### 4. SynergySystem Variables
- **var player_id: int = 1** - Which player this system belongs to
- **var gauge: float = 0.0** - Current burst gauge value (0-1000)
- **var state: BurstState = BurstState.READY** - Current burst state
- **var burst_timer: float = 0.0** - Time remaining in current burst
- **var cooldown_timer: float = 0.0** - Time remaining before gauge can refill
- **var ultimate_used_this_burst: bool = false** - Whether ultimate used in current burst
- **var passive_fill_enabled: bool = true** - Whether passive gauge fill is enabled
- **var fill_multiplier_hit := 1.0, fill_multiplier_dealt := 1.0, fill_multiplier_taken := 1.0, fill_multiplier_passive := 1.0** - Archetype-specific fill multipliers

### 5. SupportSystem Variables
- **var player_id: int = 1** - Which player this system belongs to
- **var selected_supports: Array = []** - Array of support IDs (max 3)
- **var cooldowns: Dictionary = {}** - Cooldown timers for each support slot
- **var active_effects: Array = []** - Currently active duration-based support effects

### 6. ArenaManager Variables
- **var p1: Fighter, var p2: Fighter** - The two fighters in the current match
- **var hud** - The HUD instance
- **var select_menu** - The character select menu instance
- **var combat_root: Node2D** - Root node for all combat objects (fighters, projectiles, etc.)
- **var over: Boolean** - Whether the match is over
- **var camera: ArenaCamera** - The dynamic camera
- **var sfx: Sfx** - The sound effects manager
- **var flash: ColorRect** - The full-screen flash effect
- **var selected_p1 = "marshadow", var selected_p2 = "gholdengo"** - Currently selected fighters
- **var cpu_mode := false** - Whether CPU mode is enabled (from character select)
- **var current_mode: String = "pvp"** - Current game mode ("pvp", "pvcpu", "cpuvcpu")
- **var p1_difficulty: String = "medium", var p2_difficulty: String = "medium"** - AI difficulty settings
- **const ROSTER := [...]** - List of available fighters with their scenes, sheets, and colors

### 7. HUD Variables
- **@onready var root: Control = $Root** - Root container node
- **@onready var p1_hud = $Root/P1** - P1 fighter HUD block
- **@onready var p2_hud = $Root/P2** - P2 fighter HUD block
- **@onready var banner: Label = $Root/Banner** - Banner label for round announcements
- **@onready var help_panel: PanelContainer = $Root/HelpPanel** - Panel containing controls hint
- **@onready var help: Label = $Root/HelpPanel/Help** - Label for controls hint text
- **var f1: Fighter, var f2: Fighter** - The two bound fighters

### 8. FighterHUD Variables (in fighter_hud.tscn)
- **Various nodes for HP bar, stamina bar, skill slots, status icons, name label, etc.**

### 9. ScreenShake Variables (`screen_shake.gd`) - **Phase 4**
- **var amp := 0.0** - Current shake amplitude
- **var frames_left := 0** - Remaining frames in current shake
- **var total := 1** - Total frames for current shake (for decay calculation)

### 10. HitVfx Variables (`hit_vfx.gd`) - **Phase 4**
- **var ring_t := 0.0** - Ring animation timer
- **var ring_color := Color.WHITE** - Ring color (from element style)
- **var ring_size := 26.0** - Base ring size (scaled by hit severity)
- **const STYLE** - 13-element particle style dictionary

### 11. DamageNumber Variables (`damage_number.gd`) - **Phase 4**
- Uses Label properties (text, modulate, position, scale, rotation) via tweens

### 12. Sfx Variables (`sfx.gd`) - **Phase 4**
- **var cache := {}** - Loaded AudioStream cache (name -> stream)
- **var players: Array** - Pool of 12 AudioStreamPlayer2D instances
- **const DIR := "res://assets/audio/"** - Sound file directory
- **const POOL := 12** - Pool size

## Summary of Key Relationships

### Composition Relationships (1:1)
- Fighter ↔ InputHandler
- Fighter ↔ StatsComponent  
- Fighter ↔ StateMachine
- Fighter ↔ SynergySystem
- Fighter ↔ SupportSystem

### Management Relationships (1:Many or Many:1)
- ArenaManager ↔ Fighters (1:2)
- ArenaManager ↔ HUD (1:1)
- ArenaManager ↔ CharacterSelect (1:1)
- ArenaManager ↔ ArenaCamera (1:1)
- ArenaManager ↔ Sfx (1:1)
- ArenaManager ↔ ScreenShake (1:1) - **Phase 4**
- ArenaManager ↔ HitVfx (1:Many, spawned per hit) - **Phase 4**
- ArenaManager ↔ DamageNumber (1:Many, spawned per hit) - **Phase 4**
- ArenaManager ↔ Flash ColorRect (1:1) - **Phase 4**
- Fighter ↔ Projectiles/Trap (1:Many)
- Fighter ↔ Status Effect Icons (1:3)
- Fighter ↔ Move Effect Sprite (1:1)

### Signal Connections
- Fighter.died → ArenaManager._on_died()
- Fighter.got_hit → ArenaManager._on_got_hit()
- Fighter.event → ArenaManager._on_fighter_event()
- SynergySystem.burst_activated → Fighter._on_burst_activated()
- SynergySystem.burst_ended → Fighter._on_burst_ended()
- SynergySystem.ultimate_ready → Fighter._on_ultimate_ready()
- SynergySystem.ultimate_used → Fighter._on_ultimate_used()
- SupportSystem.support_called → Fighter._on_support_called()
- CharacterSelect.start_requested → ArenaManager._on_selection_applied()
- CharacterSelect.cancel_requested → ArenaManager._on_selection_cancelled()
- CharacterSelect.mode_changed → ArenaManager._on_mode_changed()

### Inheritance Relationships
- Fighter_* → Fighter (all fighter archetypes inherit from base Fighter class)
- StateMachine → Node (Godot base class)
- SynergySystem → Node (Godot base class)
- SupportSystem → Node (Godot base class)
- InputHandler → Node (Godot base class)
- Fighter → CharacterBody2D (Godot physics body)
- HUD → CanvasLayer (Godot UI layer)
- FighterHUD → Various Control nodes (Godot UI elements)
- Projectile/Area2D → Node2D/Area2D (Godot physics nodes)
- AIController/AIBehavior/AIProfile → Node (Godot base class)
- ScreenShake → Camera2D (Godot camera) - **Phase 4**
- HitVfx → Node2D (Godot 2D node) - **Phase 4**
- DamageNumber → Label (Godot UI) - **Phase 4**
- Sfx → Node2D (Godot 2D node) - **Phase 4**

This structure shows a clean, modular design where each fighter is a self-contained unit with its own subsystems for input, stats, state management, synergy, and support, all coordinated by the central ArenaManager which handles the game flow, arena, and cross-fighter interactions. **Phase 4** adds comprehensive visual/audio feedback (hitstop, screen shake, elemental VFX, damage numbers, positional audio) and cancel chains for deeper combat mechanics.