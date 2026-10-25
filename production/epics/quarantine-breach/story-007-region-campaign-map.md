# Story 007: Region campaign map

> **Epic**: quarantine-breach
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: `Brief MVP feature 7`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**:
N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (MVP feature 7, Core loop, Player goal & fail state), scoped to this story:*

- [ ] A region map shows sectors, each with a state (clear, infected, lost) shown by color
- [ ] The player picks an infected sector to run a mission in, seeing its risk and reward first
- [ ] A mission result (story 004) updates the sector and the player's loot, soldiers and civilians
- [ ] After each mission the infection spreads to neighbouring sectors at a rate set by difficulty
- [ ] Difficulty presets set horde size and spread speed together and can be chosen at campaign start
- [ ] The player can spend loot in a shop on soldiers, gear and call-in equipment (story 006)
- [ ] The campaign is lost when the infected or lost sectors pass the difficulty's threshold
- [ ] The campaign is won when all sectors are clear (or the win rule set in the data file)
- [ ] The campaign state can be saved and loaded between missions
- [ ] The region map and its UI use the pixel-art style, with a pixel-art UI

---

## Implementation Notes

- Saving only happens between missions (no mid-mission saves, per the brief's out-of-scope list)
- Spread speed, thresholds, shop prices and presets belong in data files
- Godot 4.7 is past the model's knowledge: check `docs/engine-reference/godot/` before using any engine API

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Later (after the MVP): XP, skills and skill trees, injuries and fatigue, morale, personal traits, vehicles, weather

---

## Files

- `src/campaign/` (region map, sectors, spread, shop, save/load)
- `src/ui/` (region map and shop screens)
- `assets/data/campaign.json`, `assets/data/difficulty_presets.json`, `assets/data/shop.json`
- `tests/integration/campaign/region_map_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/campaign/region_map_test.gd` OR playtest doc
- UI: a retained screenshot of each screen touched (region map, shop) in `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/quarantine-breach/story-004-extraction-mission.md`, `production/epics/quarantine-breach/story-006-call-in-support.md`
- Unlocks: None
