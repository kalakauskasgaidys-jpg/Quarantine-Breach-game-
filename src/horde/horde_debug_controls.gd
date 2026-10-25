class_name HordeDebugControls
extends Node
## Keyboard input for the story 002 debug tools. Holds no logic: it only reports
## which toggle was pressed. Keys: N noise rings, H horde heat map, T day/night.
## Uses physical keys so the bindings do not depend on keyboard layout.

## Emitted when the noise-ring overlay key is pressed.
signal noise_rings_toggled
## Emitted when the horde heat-map key is pressed.
signal heat_map_toggled
## Emitted when the day/night test key is pressed.
signal time_of_day_toggled


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_N:
			noise_rings_toggled.emit()
		KEY_H:
			heat_map_toggled.emit()
		KEY_T:
			time_of_day_toggled.emit()
