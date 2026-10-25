# Story 003: Infection turning

> **Epic**: quarantine-breach
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

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

- `src/infection/` (infection state, turning, treatment)
- `assets/data/infection.json`
- `tests/unit/infection/infection_turning_test.gd`

---

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
