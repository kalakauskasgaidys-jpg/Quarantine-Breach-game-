# Story 005: Procedural suburb

> **Epic**: quarantine-breach
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 1`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**:
N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (MVP feature 1, Art & audio direction), scoped to this story:*

- [ ] A generator builds a small-town suburb map from a seed: streets, house lots, yards and a main street
- [ ] The same seed always produces the same map
- [ ] Buildings are placed on lots without overlapping streets or each other, and every building has a reachable door
- [ ] Generated maps are fully connected: soldiers, civilians and the evac point can all be reached from the start area
- [ ] Enterable buildings have an interior shown as icons for loot and occupants, and zombies and fights can happen inside
- [ ] Supply caches, civilians and the evac point from story 004 are placed by the generator
- [ ] The generator replaces the greybox block used by earlier stories
- [ ] The map renders in the 3D-as-pixel look at a top-down 3/4 camera, with the muted palette
- [ ] Map generation completes within a few seconds on a mid-range PC

---

## Implementation Notes

- Only the small-town suburb type is in the MVP; dense city, farmland and industrial towns come later
- Generation settings (map size, house density) belong in data files
- The pixel look: render the 3D scene to a low-resolution target and scale it up without smoothing; check that the camera snaps to the pixel grid to limit shimmer
- Godot 4.7 is past the model's knowledge: check `docs/engine-reference/godot/` before using any engine API

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Later (after the MVP): dense city blocks, rural farmland and industrial towns, the 360° camera, weather and light damage details

---

## Files

- `src/world/town_generator.gd` and related scripts
- `assets/data/town_generation.json`
- `tests/unit/mapgen/suburb_generator_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/mapgen/suburb_generator_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)
- The look is also checked: a retained screenshot of a generated suburb in `production/qa/evidence/` (see `.claude/docs/run-and-observe.md`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/quarantine-breach/story-004-extraction-mission.md`
- Unlocks: None
