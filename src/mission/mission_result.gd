class_name MissionResult
extends RefCounted
## Plain outcome of one extraction mission (design/game-brief.md MVP feature 5),
## handed to the campaign (story 007) through [signal Mission.mission_finished].
## Every unit is counted exactly once: extracted, lost or left behind.

## Why a mission ended.
enum Reason { ALL_AT_EVAC, SQUAD_LOST, TIMER_EXPIRED }

## True if at least one unit (soldier or civilian) was extracted.
var success: bool = false
## What ended the mission, see [enum Reason].
var reason: Reason = Reason.ALL_AT_EVAC
## Soldiers that left the map alive.
var soldiers_extracted: int = 0
## Soldiers killed or turned into zombies.
var soldiers_lost: int = 0
## Soldiers still on the map when the mission ended.
var soldiers_left_behind: int = 0
## Civilians that left the map alive.
var civilians_extracted: int = 0
## Civilians killed or turned into zombies.
var civilians_lost: int = 0
## Civilians still on the map when the mission ended.
var civilians_left_behind: int = 0
## Total weight of the loot carried out by extracted soldiers.
var loot_weight: float = 0.0
## Total value of the loot carried out by extracted soldiers.
var loot_value: float = 0.0
## Mission seconds from deploy to the end.
var time_taken: float = 0.0


## Short text for the results panel.
func summary_text() -> String:
	var title := "MISSION COMPLETE" if success else "MISSION FAILED"
	var cause: String = ["All soldiers reached the evac", "No soldiers left on the map", "The timer ran out"][reason]
	return "%s (%s)\n\nSoldiers: %d extracted, %d lost, %d left behind\nCivilians: %d extracted, %d lost, %d left behind\nLoot: %.0f kg, value %.0f\nTime: %.1f s" % [
			title, cause, soldiers_extracted, soldiers_lost, soldiers_left_behind,
			civilians_extracted, civilians_lost, civilians_left_behind, loot_weight, loot_value, time_taken]
