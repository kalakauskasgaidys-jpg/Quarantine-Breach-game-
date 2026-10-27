class_name EvacZone
extends Node3D
## The evac point (design/game-brief.md MVP feature 5): a flat translucent disc with
## a label. Holds no rules; [method contains] answers who stands inside.

## Disc radius in metres.
var radius: float = 1.0


## Builds the disc at [param centre] (x, z). Call before adding to the tree.
func setup(centre: Vector2, p_radius: float, color: Color) -> void:
	radius = p_radius
	position = Vector3(centre.x, 0.0, centre.y)
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	disc.mesh = mesh
	# Above the fog plane (y 0.06) so the exit is always readable.
	disc.position.y = 0.1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	disc.material_override = material
	add_child(disc)
	var label := Label3D.new()
	label.text = "EVAC"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.015
	label.font_size = 64
	label.outline_size = 12
	label.modulate = Color(color, 1.0)
	label.position.y = 1.5
	add_child(label)


## True if [param point] (world position) is inside the zone, ignoring height.
func contains(point: Vector3) -> bool:
	var offset := point - global_position
	return offset.x * offset.x + offset.z * offset.z <= radius * radius
