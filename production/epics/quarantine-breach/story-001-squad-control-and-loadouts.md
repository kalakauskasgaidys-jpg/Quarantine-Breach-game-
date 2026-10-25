# Story 001: Squad control and loadouts

> **Epic**: quarantine-breach
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 2`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**:
N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (MVP feature 2, Player goal & fail state), scoped to this story:*

- [ ] The player can select a squad (click, drag-box, number key) and order it to move; units path around buildings and obstacles
- [ ] The player controls 2–3 squads at once, each shown with a squad number and selection ring
- [ ] Squads can attack zombies in range with the equipped weapon
- [ ] Line of sight limits what each squad sees; unexplored map is black and previously seen map is grey (fog of war)
- [ ] Each soldier has one class (rifleman, medic, engineer, scout, heavy) that sets base stats
- [ ] Gear slots (primary weapon, sidearm, suppressor, armor, grenades, medkit) can be chosen before a mission and change the soldier's stats and noise
- [ ] Squad control works on a greybox block with placeholder shapes (no final art needed)
- [ ] A squad wiped out removes control of those units (feeds the mission fail state)

---

## Implementation Notes

- Build this first as the greybox: one block, one squad, placeholder meshes; later stories add the horde and the town
- Keep unit data (class stats, gear modifiers) in external data files, not hardcoded (project coding standards)
- Keep selection and order input separate from unit logic so the game logic can be tested without the UI
- Godot 4.7 is past the model's knowledge: check `docs/engine-reference/godot/` before using any engine API

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: noise, zombies and day/night
- Story 003: infection and turning
- Story 004: civilians, loot, the evac timer and win/fail
- Story 005: procedural town generation
- Story 006: call-in support
- Story 007: the region campaign map and the shop

---

## Files

- `src/squads/camera_rig.gd`
- `src/squads/fog_of_war.gd`
- `src/squads/fog_overlay.gd`
- `src/squads/game_data.gd`
- `src/squads/greybox_block.gd`
- `src/squads/greybox_block.tscn`
- `src/squads/loadout_panel.gd`
- `src/squads/selection_controller.gd`
- `src/squads/soldier.gd`
- `src/squads/soldier_loadout.gd`
- `src/squads/soldier_stats.gd`
- `src/squads/squad.gd`
- `src/squads/target_dummy.gd`
- `assets/data/soldier_classes.json`
- `assets/data/gear.json`
- `assets/data/squad_greybox.json`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/squads/squad_control_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/quarantine-breach/story-002-noise-driven-horde-and-time-of-day.md`

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 8/8 passing (none deferred)
**Deviations**: Advisory: `retarget_interval` (0.25) and presentation sizes are hardcoded in `soldier.gd`; engine-review warnings left open (unvalidated camera config sub-keys, more than 3 squads would overrun the 3 spawn markers, non-mesh node in the `obstacles` group crashes fog, same-point shot logs an error, number keys depend on keyboard layout). Out of scope: Godot `.uid` companion files. `squad_greybox.json` was added beyond the planned data files.
**Test Evidence**: waived at qa.level minimal. Retained screenshots: `production/qa/evidence/story-001-squad-control-and-loadouts/` (stamp: all files unchanged)
**Reviewed by**: self, no independent review
