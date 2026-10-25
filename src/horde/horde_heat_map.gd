class_name HordeHeatMap
extends MeshInstance3D
## Debug overlay: zombie density per grid cell as a colour ramp on the ground
## (design/game-brief.md Look notes: "a horde heat map"). Shows every zombie,
## including those the fog hides. Hidden and idle until turned on.

## Height above the ground the map is drawn at.
const MAP_HEIGHT: float = 0.09

var _horde: HordeManager
var _origin: Vector2
var _size: Vector2i
var _inv_cell: float
var _refresh_interval: float
var _full_density: float
var _color_low: Color
var _color_high: Color
var _counts: PackedInt32Array = PackedInt32Array()
var _pixels: PackedByteArray = PackedByteArray()
var _texture: ImageTexture
var _timer: float = 0.0


## [param config] is the validated "heat_map" block of horde.json; [param bounds]
## the map rectangle (world x, z).
func setup(horde: HordeManager, bounds: Rect2, config: Dictionary) -> void:
	_horde = horde
	var cell: float = config["cell_size"]
	_inv_cell = 1.0 / cell
	_origin = bounds.position
	_size = Vector2i(ceili(bounds.size.x / cell), ceili(bounds.size.y / cell))
	_refresh_interval = config["refresh_interval"]
	_full_density = config["full_density"]
	_color_low = GameData.color_from(config["color_low"])
	_color_high = GameData.color_from(config["color_high"])
	_counts.resize(_size.x * _size.y)
	_pixels.resize(_size.x * _size.y * 4)
	var extent := Vector2(_size) * cell
	var plane := PlaneMesh.new()
	plane.size = extent
	mesh = plane
	position = Vector3(_origin.x + extent.x * 0.5, MAP_HEIGHT, _origin.y + extent.y * 0.5)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_texture = ImageTexture.create_from_image(Image.create_empty(_size.x, _size.y, false, Image.FORMAT_RGBA8))
	material.albedo_texture = _texture
	material_override = material
	set_enabled(false)


## Shows or hides the map; hidden, it does no counting.
func set_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	_timer = _refresh_interval


func _process(delta: float) -> void:
	_timer += delta
	if _timer < _refresh_interval:
		return
	_timer = 0.0
	_counts.fill(0)
	for i in _horde.count:
		var p := _horde.positions[i]
		var x := floori((p.x - _origin.x) * _inv_cell)
		var y := floori((p.y - _origin.y) * _inv_cell)
		if x >= 0 and y >= 0 and x < _size.x and y < _size.y:
			_counts[y * _size.x + x] += 1
	for i in _counts.size():
		var color := Color(0.0, 0.0, 0.0, 0.0)
		if _counts[i] > 0:
			color = _color_low.lerp(_color_high, clampf(_counts[i] / _full_density, 0.0, 1.0))
		var o := i * 4
		_pixels[o] = color.r8
		_pixels[o + 1] = color.g8
		_pixels[o + 2] = color.b8
		_pixels[o + 3] = color.a8
	_texture.update(Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBA8, _pixels))
