class_name CivilianShelter
extends Node3D
## A civilian hiding inside a building (design/game-brief.md MVP feature 5). While
## sheltering there is no unit on the map, so zombies cannot see or bite it; only this
## marker exists, shown once the building has been explored. [Mission] replaces the
## shelter with a [Civilian] at [member door] when a soldier comes close.

## Where the civilian steps out, beside the building.
var door: Vector3
## The building's footprint (world x, z); the marker shows once any of it was explored.
var area: Rect2


## Places the marker at [param spot] (x, z). Call before adding to the tree.
func setup(spot: Vector2, p_door: Vector2, p_area: Rect2, color: Color) -> void:
	position = Vector3(spot.x, 0.0, spot.y)
	door = Vector3(p_door.x, 0.0, p_door.y)
	area = p_area
	visible = false
	var label := Label3D.new()
	label.text = "!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.015
	label.font_size = 64
	label.outline_size = 12
	label.modulate = color
	label.position.y = 3.6
	add_child(label)
