class_name SupplyCache
extends Node3D
## A supply cache beside a building (design/game-brief.md MVP feature 5): a coloured
## box with a label showing its loot. Soldiers loot it through [Mission].

## Weight added to the looter's load.
var weight: float = 0.0
## Value counted when the looter is extracted.
var value: float = 0.0


## Builds the box and label at [param spot] (x, z). Call before adding to the tree.
func setup(spot: Vector2, p_weight: float, p_value: float) -> void:
	weight = p_weight
	value = p_value
	position = Vector3(spot.x, 0.0, spot.y)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.7, 0.9)
	box.mesh = mesh
	box.position.y = 0.35
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.65, 0.2)
	box.material_override = material
	add_child(box)
	var label := Label3D.new()
	label.text = "%.0f kg / %.0f" % [weight, value]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.font_size = 40
	label.outline_size = 10
	label.position.y = 1.3
	add_child(label)
