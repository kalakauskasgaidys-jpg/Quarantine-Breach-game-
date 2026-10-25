class_name FogOverlay
extends MeshInstance3D
## Draws a FogOfWar as a flat translucent plane just above the ground:
## black where unexplored, grey where explored but not in view, clear in view.

var _fog: FogOfWar
var _texture: ImageTexture
var _pixels: PackedByteArray = PackedByteArray()
var _unexplored: PackedByteArray = PackedByteArray()
var _explored: PackedByteArray = PackedByteArray()
var _clear: PackedByteArray = PackedByteArray([0, 0, 0, 0])


## Builds the plane for [param fog] and keeps it in sync via its fog_updated signal.
func setup(fog: FogOfWar, unexplored_color: Color, explored_color: Color) -> void:
	_fog = fog
	_unexplored = PackedByteArray([unexplored_color.r8, unexplored_color.g8, unexplored_color.b8, unexplored_color.a8])
	_explored = PackedByteArray([explored_color.r8, explored_color.g8, explored_color.b8, explored_color.a8])
	_pixels.resize(fog.size.x * fog.size.y * 4)
	var extent := Vector2(fog.size) * fog.cell_size
	var plane := PlaneMesh.new()
	plane.size = extent
	mesh = plane
	position = Vector3(fog.origin.x + extent.x * 0.5, 0.06, fog.origin.y + extent.y * 0.5)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_texture = ImageTexture.create_from_image(_make_image())
	material.albedo_texture = _texture
	material_override = material
	fog.fog_updated.connect(_on_fog_updated)


func _on_fog_updated() -> void:
	_texture.update(_make_image())


func _make_image() -> Image:
	for i in _fog.explored.size():
		var pixel := _clear
		if _fog.in_view[i] == 0:
			pixel = _explored if _fog.explored[i] == 1 else _unexplored
		var o := i * 4
		_pixels[o] = pixel[0]
		_pixels[o + 1] = pixel[1]
		_pixels[o + 2] = pixel[2]
		_pixels[o + 3] = pixel[3]
	return Image.create_from_data(_fog.size.x, _fog.size.y, false, Image.FORMAT_RGBA8, _pixels)
