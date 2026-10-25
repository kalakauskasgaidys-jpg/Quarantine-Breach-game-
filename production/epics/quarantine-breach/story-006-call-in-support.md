# Story 006: Equipment-unlocked call-in support

> **Epic**: quarantine-breach
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 6`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**:
N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (MVP feature 6), scoped to this story:*

- [ ] Call-in abilities are defined in data (name, effect, cooldown, uses, required equipment)
- [ ] An ability is available in a mission only if the player owns its required equipment
- [ ] The MVP ships with 2–3 abilities (e.g. a barricade drop and an airstrike)
- [ ] Using an ability places its effect on the map at a chosen point, with a cooldown or limited uses
- [ ] Abilities that make noise (e.g. an airstrike) emit noise events that attract the horde (story 002)
- [ ] Adding a new ability needs only a new data entry plus its effect, not changes to the unlock system
- [ ] The player's available abilities show in the mission UI, with unavailable ones clearly marked

---

## Implementation Notes

- The unlock system is the MVP; the number of abilities is not. Build it so more abilities can be added later
- Costs and cooldowns belong in data files
- Godot 4.7 is past the model's knowledge: check `docs/engine-reference/godot/` before using any engine API

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: buying equipment in the shop (this story reads the owned-equipment list)
- Later (after the MVP): more call-in abilities and vehicle call-ins

---

## Files

- `src/support/` (call-in system, abilities)
- `assets/data/call_ins.json`
- `tests/unit/support/call_in_unlock_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/support/call_in_unlock_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/quarantine-breach/story-004-extraction-mission.md`
- Unlocks: `production/epics/quarantine-breach/story-007-region-campaign-map.md`
