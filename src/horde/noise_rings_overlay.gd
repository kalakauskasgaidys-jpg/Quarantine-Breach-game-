class_name NoiseRingsOverlay
extends MeshInstance3D
## Debug overlay: an expanding, fading circle for every live noise event, so the
## player can read how far a shot or a footstep carried (design/game-brief.md
## Look notes: "Noise rings ... make threats readable"). Quiet noises are tinted
## cool, loud ones warm. Hidden and idle until turned on.

## Height above the ground the rings are drawn at.
const RING_HEIGHT: float = 0.15

var _noise: NoiseSystem
var _immediate: ImmediateMesh = ImmediateMesh.new()
var _segments: int
var _color_quiet: Color
var _color_loud: Color
var _loud_radius: float


## [param config] is the validated "rings" block of noise.json.
func setup(noise: NoiseSystem, config: Dictionary) -> void:
	_noise = noise
	_segments = int(config["segments"])
	_color_quiet = GameData.color_from(config["color_quiet"])
	_color_loud = GameData.color_from(config["color_loud"])
	_loud_radius = config["loud_radius"]
	mesh = _immediate
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material_override = material
	set_enabled(false)


## Shows or hides the rings; hidden rings cost nothing.
func set_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	if not enabled:
		_immediate.clear_surfaces()


func _process(_delta: float) -> void:
	_immediate.clear_surfaces()
	for event in _noise.events:
		var progress := event.age / _noise.fade_time
		# Ease out: the ring races outward, then slows as it fades.
		var radius := event.radius * (1.0 - (1.0 - progress) * (1.0 - progress))
		var color := _color_quiet.lerp(_color_loud, clampf(event.radius / _loud_radius, 0.0, 1.0))
		color.a = 1.0 - progress
		_immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		_immediate.surface_set_color(color)
		for k in _segments + 1:
			var angle := TAU * k / _segments
			_immediate.surface_add_vertex(Vector3(
					event.position.x + cos(angle) * radius, RING_HEIGHT, event.position.z + sin(angle) * radius))
		_immediate.surface_end()
