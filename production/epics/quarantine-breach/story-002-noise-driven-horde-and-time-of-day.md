# Story 002: Noise-driven horde and time of day

> **Epic**: quarantine-breach
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 3`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**:
N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (MVP feature 3, Core loop, Build order), scoped to this story:*

- [ ] Actions (gunfire, movement, explosions) emit noise events with a loudness and radius
- [ ] Silenced weapons emit less noise than loud ones; a suppressor changes the radius
- [ ] Zombies are drawn toward the loudest or nearest noise, and toward visible soldiers
- [ ] Zombies move by a shared flow field (one grid pointing at the target), not individual pathfinding per zombie
- [ ] Horde size is set by a difficulty value (a data setting, not hardcoded)
- [ ] The horde stays playable at several hundred zombies on screen at 60 fps on a mid-range PC (project budget)
- [ ] Each mission has a time of day; night shortens sight range and adds more roaming zombies
- [ ] Noise rings and a horde heat map overlay can be shown (debug-level readable)
- [ ] This story proves "loud vs quiet" is a real choice: a playtest note records whether quiet play is a viable alternative to loud play

---

## Implementation Notes

- This is the riskiest part of the game: build it right after story 001, on the greybox block
- Zombies should be array data drawn in batches, not one physics node each; see the reference docs and the performance notes in `design/game-brief.md`
- If GDScript is too slow for the horde update loop, profile first, then move only that loop to C# or native code
- Godot 4.7 is past the model's knowledge: check `docs/engine-reference/godot/` before using any engine API

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: squad control
- Story 003: infection and turning
- Story 007: difficulty presets as a campaign-level choice (this story only needs the horde-size value to exist)

---

## Files

- `src/horde/flow_field.gd`
- `src/horde/horde_debug_controls.gd`
- `src/horde/horde_heat_map.gd`
- `src/horde/horde_manager.gd`
- `src/horde/noise_rings_overlay.gd`
- `src/horde/noise_system.gd`
- `src/world/time_of_day.gd`
- `src/squads/game_data.gd`
- `src/squads/soldier.gd`
- `src/squads/greybox_block.gd`
- `assets/data/noise.json`
- `assets/data/horde.json`
- `assets/data/difficulty.json`
- `assets/data/time_of_day.json`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/horde/noise_horde_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/quarantine-breach/story-001-squad-control-and-loadouts.md`
- Unlocks: `production/epics/quarantine-breach/story-003-infection-turning.md`

---

## Completion Notes
**Completed**: 2026-10-27
**Criteria**: 9/9 passing (none deferred)
**Deviations**: Advisory: zombie movement code is at/over its 2 ms frame share at 300+ moving zombies (TD-007); alerted zombies move in 8-direction streams (TD-008); dark soldier classes hard to see at night (TD-009); final horde code not re-reviewed by the engine specialist (TD-010). Out of scope: story 001 files (`game_data.gd`, `soldier.gd`, `greybox_block.gd`) edited as this story needed; Godot `.uid` companion files added. The shamble animation was built then removed for cost and moved to Later in the brief.
**Test Evidence**: waived at qa.level minimal. Retained screenshots and the loud-vs-quiet playtest note: `production/qa/evidence/story-002-noise-driven-horde-and-time-of-day/`, `production/qa/playtests/story-002-loud-vs-quiet.md`
**Reviewed by**: self, no independent review
