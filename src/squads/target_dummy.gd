class_name TargetDummy
extends Node3D
## Static stand-in for a zombie (story 001 only): has hit points and can be shot.
## Joins the "targets" group so soldiers can find it. Story 002 replaces it.

## Emitted when hit points change.
signal health_changed(current: float, maximum: float)
## Emitted once when hit points reach zero, just before the node is freed.
signal died(dummy: TargetDummy)

var health: float = 0.0
var max_health: float = 0.0
var _label: Label3D


func _ready() -> void:
	add_to_group(&"targets")
	var body := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.35
	shape.bottom_radius = 0.4
	shape.height = 1.6
	body.mesh = shape
	body.position.y = 0.8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.2, 0.2)
	body.material_override = material
	add_child(body)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.01
	_label.font_size = 48
	_label.position.y = 2.0
	add_child(_label)


## Sets full hit points. Call once after the node is in the tree.
func setup(hit_points: float) -> void:
	max_health = hit_points
	health = hit_points
	_label.text = str(ceili(health))


func is_alive() -> bool:
	return health > 0.0


## Applies [param amount] damage; frees the dummy at zero hit points.
func take_damage(amount: float) -> void:
	if not is_alive():
		return
	health -= amount
	_label.text = str(maxi(ceili(health), 0))
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit(self)
		queue_free()
