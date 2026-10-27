# Story 004: Extraction mission

> **Epic**: quarantine-breach
> **Status**: In Progress
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 5`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**:
N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (MVP feature 5, Player goal & fail state), scoped to this story:*

- [ ] A mission places civilians, supply caches and an evac point on the map
- [ ] Civilians follow and can be escorted by a squad to the evac point
- [ ] Supply caches in buildings can be looted by soldiers
- [ ] Loot has weight; a heavy load slows the carrying soldier
- [ ] The evac point has a countdown timer that is shown to the player
- [ ] A mission succeeds when at least one unit reaches evac before the timer ends
- [ ] A mission fails when the squad is wiped or turned before extracting
- [ ] On success the mission reports what was extracted (soldiers, civilians, loot) and what was lost
- [ ] Mission results are passed on as data the campaign (story 007) can use

---

## Implementation Notes

- This story ties stories 001–003 together into one playable mission; run it on the greybox block until story 005 exists
- Timer length and loot weights belong in data files
- Godot 4.7 is past the model's knowledge: check `docs/engine-reference/godot/` before using any engine API

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: procedural town generation (use the greybox block)
- Story 006: call-in support
- Story 007: the campaign map, spreading infection and the shop

---

## Files

- `src/mission/civilian.gd`
- `src/mission/evac_zone.gd`
- `src/mission/mission.gd`
- `src/mission/mission_controls.gd`
- `src/mission/mission_hud.gd`
- `src/mission/mission_result.gd`
- `src/mission/supply_cache.gd`
- `src/infection/survivor.gd`
- `src/infection/infection_tracker.gd`
- `src/infection/infection_treatment.gd`
- `src/horde/horde_manager.gd`
- `src/squads/greybox_block.gd`
- `src/squads/soldier.gd`
- `src/squads/soldier_stats.gd`
- `src/squads/squad.gd`
- `src/squads/selection_controller.gd`
- `src/squads/game_data.gd`
- `assets/data/mission.json`
- `assets/data/infection.json`
- `assets/data/soldier_classes.json`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/mission/extraction_mission_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/quarantine-breach/story-003-infection-turning.md`
- Unlocks: `production/epics/quarantine-breach/story-005-procedural-suburb.md`, `production/epics/quarantine-breach/story-006-call-in-support.md`, `production/epics/quarantine-breach/story-007-region-campaign-map.md`
