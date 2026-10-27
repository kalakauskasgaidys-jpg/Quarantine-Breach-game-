class_name InfectionControls
extends Node
## Keyboard input for story 003. Holds no logic: it reports which key was pressed
## together with the currently selected squads. Keys: E treat the nearest infected
## friendly (antidote or medic), I infect the selected soldier (debug).
## Uses physical keys so the bindings do not depend on keyboard layout.

## Emitted when the treat key is pressed.
signal treat_requested(squads: Array[Squad])
## Emitted when the debug infect key is pressed.
signal infect_requested(squads: Array[Squad])

var _selected: Array[Squad] = []


## Follows the selection of [param controller].
func setup(controller: SelectionController) -> void:
	controller.selection_changed.connect(_on_selection_changed)


func _on_selection_changed(selected: Array[Squad]) -> void:
	_selected = selected.duplicate()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_E:
			treat_requested.emit(_selected)
		KEY_I:
			infect_requested.emit(_selected)
