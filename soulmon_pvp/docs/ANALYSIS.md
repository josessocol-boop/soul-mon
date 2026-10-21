# Current state analysis (2026-10-19)

Based on `soulmon_pvp_098557.zip`. The previous analysis (2026-10-16) is kept in `docs/archive/` history; this one replaces
it. Godot 4.7.2 (official Linux build) now runs in the analysis sandbox, headless, so the checks below are engine checks,
not text checks. Visual checks are limited to the headless screenshot of the main menu (a virtual display; no sound).

## What the engine verified (this pass)

- **Import:** `godot --headless --import` completes with no errors (340+ assets processed).
- **Script compile:** every `.gd` file (53, excluding `_archive/`) was checked with `--check-only`. 48 pass. The 5
  flagged are not real errors:
  - `arena_manager.gd`, `character_select.gd`, `main_menu.gd`, `options_menu.gd`: "Identifier not found: Settings". The
    check-only mode does not load autoloads, and `Settings` is an autoload (`project.godot` `[autoload]`). They run in
    the game, and the arena runs in the smoke test below.
  - `projectile.gd`: a `.tscn` ordering artifact of checking one file on its own. The file exists, and projectiles fire
    in the smoke test.
- **Smoke test (full round robin, 12 fighters, every pair, headless, `arena/main.tscn` with the arena's own
  `_start_match`):** see the result table below. The test harness waits for the arena's own setup before starting
  matches (starting one early produced nil-HUD errors that were the harness's fault, not the game's).

### Smoke test results (partial: 66 of 132 pairs, headless, engine)

The run covers the first 66 ordered pairs, so early fighters appear in more matches than late ones. The win rates
below are **not yet a fair comparison** (games per fighter differ). The remaining 66 pairs were started separately;
their results will be added as a follow-up.

| Fighter | W | L | Win % (partial) |
|---|---|---|---|
| marshadow | 5 | 1 | 83 |
| alakazam | 11 | 5 | 69 |
| lucario | 4 | 2 | 67 |
| tinkaton | 4 | 2 | 67 |
| blaziken | 8 | 8 | 50 |
| decidueye | 8 | 8 | 50 |
| mewtwo | 3 | 3 | 50 |
| scizor | 3 | 3 | 50 |
| greninja | 7 | 9 | 44 |
| toxicroak | 2 | 4 | 33 |
| gengar | 5 | 11 | 31 |
| gholdengo | 5 | 11 | 31 |

Of the 66 matches: 1 timed out (no KO within 90 game seconds). Median fight length 18.1 s. No script or input errors
in any match.

## Open issues

0. **Alakazam pass (2026-10-20).** Alakazam on hard went from 82.6% to 61.4% win rate over the full roster (792 matches, 6 repeats per pairing). Psybeam (`basic`) is now 2.0 damage per shot, 560 px/s, 28 frames total (it was 2.8, 640, 24: about 21 hits a match). Reflect caps its returned damage at 10 (new move key `counter_cap`; a heavy hit used to come back for about 30). Mind Blast cooldown is 10 s. Item 1 below lists the values from the earlier pass.
   Then a roster pass on the same hard setting (see `SESSION_REPORT.md`, "roster balance on hard"): the spread went from 29.5-71.2% to 40.9-60.6%, with Alakazam's Mind Blast narrowed.
   Bots now stop walking into incoming shots, hop opponent traps on their path, and dash out of traps they are standing in: trap hits taken fell for most fighters (Toxicroak 1.02 to 0.52 a game). Projectile hits did not fall. An instant, always-taken dodge gave the same numbers, so the reaction time is not the limit: most shots appear within 100 px of the bot, or land while it is in hitstun or mid-attack. Fixing that would take spacing changes, which were not made.
1. **Shared fixes restored (2026-10-19, this pass).** The following were missing from the upload and are now in the code, checked
   by Godot (compile, and six fights with no errors):
   - `core/fighter.gd`: the attacker's `hitstun_mult` now lengthens the stun its own hit inflicts (it was read by the
     victim, so it did nothing for the attacker); the damage and hitstun buff from a move expires after
     `MOVE_BUFF_SECONDS` (4 s) if no hit uses it; a timed counter (`counter_frames`).
   - `ai/ai_controller.gd`: utility moves (buff, counter, blink) are usable at any spacing.
   - `fighters/alakazam/fighter_alakazam.gd`: Psybolt (fast straight shot), Reflect for 1.2 s (`counter_frames` 72,
     cost 14), Kinesis as a pull (cost 10, cooldown 5). Your Future Sight delay (1.4 s) and your HP, basic and ultimate
     values are kept.
   Not restored: the value-weighted Down choice (`_move_value`); your `down_pref` system replaces it.
2. **Wall handling replaced.** The corner fix (`_wall_behind`, `CORNER_MARGIN`) is replaced by the user's `WALL_EDGE` rule
   (`_pinned_against_wall`). The hysteresis that stopped spacing flips is also gone. Flip rates should be re-measured.
3. **Six support icons are still missing** (`pikachu`, `eevee`, `chansey`, `ditto`, `snorlax`, `gardevoir`). Nothing reads
   them at runtime, so they do not crash. Supports are still not assigned to fighters (`set_supports()` is never
   called), so R / U / Y do nothing.
4. **The balance tool ships in every build.** `arena_manager.gd` loads it unless `balance_slot` is set.
5. **Move logging is on.** `LOG_MOVE_USAGE := true` in `ai/ai_controller.gd`.
6. **The stalemate risk.** The smoke test includes timeouts (no KO inside the time limit). Check the table for matchups
   that end in timeouts; those are candidates for the AI or the numbers.

## Balance state (from the user's notes, round 7)

Mewtwo was the lowest win rate at round 4 (44%) and was given HP, speed and damage changes in rounds 5–7. Re-check
with the balance tool. Element changes (Lucario basic to STEEL, Toxicroak basic to FIGHTING) and the immunity rule
(x0.8) are in the notes and the code.

## Verification status

| Check | Method | Result |
|---|---|---|
| Import | Godot `--import` headless | pass |
| Script compile | Godot `--check-only` per file | 48/53 pass; 5 are artifacts (see above) |
| Main menu renders | Godot headless under Xvfb, screenshot | pass (`main_menu.png`) |
| Every pair runs a match | Godot headless smoke test | 66 of 132 pairs done, 0 errors, 1 timeout; rest running |
| Balance numbers | balance tool CSVs | round 7 notes; not re-run in this pass |
| On-screen feel, AI quality | not measured | open |
