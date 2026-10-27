# Story 003: Infection turning

> **Epic**: quarantine-breach
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 4`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**:
N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (MVP feature 4, Player goal & fail state), scoped to this story:*

- [ ] A bite from a zombie marks a soldier or civilian as infected
- [ ] An infected unit turns into a zombie after a delay set in a data file
- [ ] A turned unit joins the horde and attacks nearby survivors
- [ ] An infected unit shows a visible countdown until it turns
- [ ] An antidote item, used by any soldier, stops the turning if used before the countdown ends
- [ ] A medic can treat an infected unit as well (the medic class's special ability)
- [ ] A turned soldier is removed from the player's squad and counted as lost
- [ ] A turned civilian is counted as lost for the mission result

---

## Implementation Notes

- Keep the turning delay and treatment rules in data files so difficulty can tune them later
- Turned units should reuse the horde system from story 002 rather than a separate zombie type
- Godot 4.7 is past the model's knowledge: check `docs/engine-reference/godot/` before using any engine API

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: civilians as an extraction objective
- Later (after the MVP): injuries, fatigue, morale and a memorial for the fallen

---

## Files

- `src/infection/infectable.gd`
- `src/infection/infection_controls.gd`
- `src/infection/infection_countdown.gd`
- `src/infection/infection_tracker.gd`
- `src/infection/infection_treatment.gd`
- `src/infection/placeholder_civilian.gd`
- `src/infection/survivor.gd`
- `src/squads/soldier.gd`
- `src/squads/soldier_stats.gd`
- `src/squads/game_data.gd`
- `src/squads/greybox_block.gd`
- `src/horde/horde_manager.gd`
- `assets/data/infection.json`
- `assets/data/gear.json`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/infection/infection_turning_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/quarantine-breach/story-002-noise-driven-horde-and-time-of-day.md`
- Unlocks: `production/epics/quarantine-breach/story-004-extraction-mission.md`

---

## Completion Notes
**Completed**: 2026-10-27
**Criteria**: 8/8 passing (none deferred)
**Deviations**: Advisory: light-grey placeholder civilians resemble the white medic body (TD-011); one presentation value hardcoded in `placeholder_civilian.gd` (TD-012). The placeholder civilians are deliberately minimal and are replaced by story 004. Out of scope: story 001/002 files edited for hooks (`soldier.gd`, `soldier_stats.gd`, `game_data.gd`, `greybox_block.gd`, `horde_manager.gd`, `gear.json`); Godot `.uid` files added. Design decisions made during the story: zombies ignore infected units, the countdown pauses during a medic treatment, medics may treat themselves, civilians are hidden by fog.
**Test Evidence**: waived at qa.level minimal. Retained screenshots: `production/qa/evidence/story-003-infection-turning/`
**Reviewed by**: self, no independent review
