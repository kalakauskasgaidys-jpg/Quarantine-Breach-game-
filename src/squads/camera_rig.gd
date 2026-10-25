class_name CameraRig
extends Node3D
## Top-down 3/4 orthographic camera with WASD/arrow pan and mouse-wheel zoom.
## No rotation yet (the 360-degree camera is a post-MVP item in the game brief).
## Scene layout: CameraRig > Pivot (tilted) > Camera3D.

@onready var camera: Camera3D = $Pivot/Camera3D
@onready var _pivot: Node3D = $Pivot

var _pan_speed: float = 0.0
var _zoom_min: float = 0.0
var _zoom_max: float = 0.0
var _zoom_step: float = 0.0
var _bounds: Rect2 = Rect2()


## Applies the "camera" block of squad_greybox.json; the rig stays inside [param bounds] (world x, z).
func setup(config: Dictionary, bounds: Rect2) -> void:
	_pivot.rotation_degrees.x = -float(config["pitch_degrees"])
	camera.size = config["start_zoom"]
	_zoom_min = config["zoom_min"]
	_zoom_max = config["zoom_max"]
	_zoom_step = config["zoom_step"]
	_pan_speed = config["pan_speed"]
	_bounds = bounds


func _process(delta: float) -> void:
	var direction := Vector3(
			int(Input.is_key_pressed(KEY_D)) + int(Input.is_key_pressed(KEY_RIGHT))
			- int(Input.is_key_pressed(KEY_A)) - int(Input.is_key_pressed(KEY_LEFT)),
			0.0,
			int(Input.is_key_pressed(KEY_S)) + int(Input.is_key_pressed(KEY_DOWN))
			- int(Input.is_key_pressed(KEY_W)) - int(Input.is_key_pressed(KEY_UP)))
	position += direction.limit_length(1.0) * _pan_speed * delta
	position.x = clampf(position.x, _bounds.position.x, _bounds.end.x)
	position.z = clampf(position.z, _bounds.position.y, _bounds.end.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = clampf(camera.size - _zoom_step, _zoom_min, _zoom_max)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = clampf(camera.size + _zoom_step, _zoom_min, _zoom_max)
