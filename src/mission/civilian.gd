class_name Civilian
extends Survivor
## A civilian to escort (design/game-brief.md MVP feature 5). Follows the nearest
## soldier of the squad it is assigned to, loosely, along the navigation mesh. With
## no squad (never assigned, or the squad was wiped) it stands still. Can be bitten
## and infected like a soldier. Holds no input code.

## Squad being followed; null when unassigned. Squads are plain objects, so this
## reference never dangles; individual soldiers are checked with is_instance_valid.
var squad: Squad
## True once the mission took the civilian off the map alive.
var extracted: bool = false

var _body_color: Color
var _unassigned_color: Color
var _walk_speed: float
var _follow_distance: float
var _repath_interval: float
var _repath_timer: float = 0.0
var _agent: NavigationAgent3D
var _ring_material: StandardMaterial3D
var _label: Label3D
var _moving: bool = false


## Supplies tuning from the "civilians" part of mission.json. Call before adding to the tree.
func setup(settings: Dictionary) -> void:
	health = settings["hit_points"]
	_walk_speed = settings["walk_speed"]
	_follow_distance = settings["follow_distance"]
	_repath_interval = settings["repath_interval"]
	_body_color = GameData.color_from(settings["color"])
	_unassigned_color = GameData.color_from(settings["unassigned_color"])


func _ready() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.4
	body.mesh = capsule
	body.position.y = 0.7
	var material := StandardMaterial3D.new()
	material.albedo_color = _body_color
	body.material_override = material
	add_child(body)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.55
	ring.mesh = torus
	ring.position.y = 0.1
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = _unassigned_color
	ring.material_override = _ring_material
	add_child(ring)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.01
	_label.font_size = 48
	_label.outline_size = 10
	_label.position.y = 1.9
	add_child(_label)
	_show_assignment(null, _unassigned_color)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.5
	add_child(_agent)


## Assigns the civilian to [param new_squad] (null = unassigned); [param color] is
## the squad's colour, shown on the ring and label.
func assign(new_squad: Squad, color: Color) -> void:
	squad = new_squad
	_moving = false
	_repath_timer = 0.0
	_show_assignment(new_squad, color if new_squad != null else _unassigned_color)


## Applies [param amount] damage; frees the civilian at zero hit points.
func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	if squad != null and squad.is_wiped():
		assign(null, _unassigned_color)
	if squad == null:
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = _repath_interval
		_update_target()
	if _moving:
		_step_along_path(delta)


## Heads for the nearest soldier of the squad unless already within the follow distance.
func _update_target() -> void:
	var nearest: Soldier = null
	var nearest_sq := INF
	for soldier in squad.soldiers:
		if not is_instance_valid(soldier):
			continue
		var distance_sq := _flat_distance_sq(soldier)
		if distance_sq < nearest_sq:
			nearest = soldier
			nearest_sq = distance_sq
	if nearest == null or nearest_sq <= _follow_distance * _follow_distance:
		_moving = false
		return
	# Keep the current path while the soldier stays near its end: re-planning from a
	# new spot each time can flip between two equal routes round a building.
	if _moving and nearest.global_position.distance_squared_to(_agent.target_position) <= _follow_distance * _follow_distance:
		return
	_agent.target_position = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), nearest.global_position)
	_moving = true


func _step_along_path(delta: float) -> void:
	if _agent.is_navigation_finished():
		_moving = false
		return
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length() > 0.001:
		rotation.y = atan2(-to_next.x, -to_next.z)
	global_position += to_next.limit_length(_walk_speed * delta)


func _flat_distance_sq(other: Node3D) -> float:
	var offset := other.global_position - global_position
	return offset.x * offset.x + offset.z * offset.z


func _show_assignment(new_squad: Squad, color: Color) -> void:
	_ring_material.albedo_color = color
	_label.text = "-" if new_squad == null else "C%d" % new_squad.number
	_label.modulate = color
