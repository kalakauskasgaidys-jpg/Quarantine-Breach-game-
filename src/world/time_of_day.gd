class_name TimeOfDay
extends Node
## A mission's time of day, 'day' or 'night' (design/game-brief.md MVP feature 3).
## Night shortens soldier sight and adds roaming zombies (multipliers read by the
## mission) and darkens the lighting. Settings come from time_of_day.json.
##
## Usage: var time := TimeOfDay.new(); time.setup(data.time_of_day["modes"], env, sun);
## time.set_mode("night").

## Emitted after the lighting changed to [param mode_id].
signal time_of_day_changed(mode_id: String)

## Current mode id, 'day' or 'night'.
var mode_id: String = ""
## Current display name for the HUD.
var display_name: String = ""
## Multiplies every soldier's sight range.
var sight_range_multiplier: float = 1.0
## Multiplies zombie sight range.
var zombie_sight_multiplier: float = 1.0
## Multiplies the difficulty's roaming zombie count.
var roaming_multiplier: float = 1.0

var _modes: Dictionary = {}
var _environment: Environment
var _sun: DirectionalLight3D


## Supplies the validated "modes" block and the lighting to drive.
func setup(modes: Dictionary, environment: Environment, sun: DirectionalLight3D) -> void:
	_modes = modes
	_environment = environment
	_sun = sun


## Largest roaming multiplier of any mode: sizes the horde's capacity.
func max_roaming_multiplier() -> float:
	var largest := 0.0
	for id: String in _modes:
		largest = maxf(largest, _modes[id]["roaming_multiplier"])
	return largest


## Applies mode [param id] (a key of the modes block) and emits [signal time_of_day_changed].
func set_mode(id: String) -> void:
	var mode: Dictionary = _modes[id]
	mode_id = id
	display_name = mode["display_name"]
	sight_range_multiplier = mode["sight_range_multiplier"]
	zombie_sight_multiplier = mode["zombie_sight_multiplier"]
	roaming_multiplier = mode["roaming_multiplier"]
	_environment.ambient_light_color = GameData.color_from(mode["ambient_color"])
	_environment.ambient_light_energy = mode["ambient_energy"]
	_environment.background_color = GameData.color_from(mode["background_color"])
	_sun.light_energy = mode["sun_energy"]
	time_of_day_changed.emit(id)


## Switches between 'day' and 'night' (debug test key).
func toggle() -> void:
	set_mode("day" if mode_id == "night" else "night")
