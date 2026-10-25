class_name Soldier
extends Node3D
## One soldier: placeholder body, squad number, selection ring, navigation
## movement and auto-fire at targets in range (design/game-brief.md MVP feature 2).
## Holds no input code; orders arrive through [method order_move].

## Emitted when hit points change.
signal health_changed(current: float, maximum: float)
## Emitted once when hit points reach zero, just before the node is freed.
signal died(soldier: Soldier)
## Emitted for every shot. [param noise] is the shot's noise radius in metres
## (story 002 reads it to attract the horde).
signal shot_fired(from: Vector3, to: Vector3, noise: float)

## Safety cap on armor: keeps damage positive whatever gear stacks up to.
## A guard, not a tuning value; tune armor in assets/data/gear.json.
const MAX_DAMAGE_REDUCTION: float = 0.95

var stats: SoldierStats
var squad_number: int = 0
var health: float = 0.0
## Shared fog/line-of-sight grid used to check shots.
var fog: FogOfWar
## Seconds between target scans while nothing is in range.
var retarget_interval: float = 0.25
## Horde the soldier can shoot at (story 002); null when the mission has none.
var horde: HordeManager
## Multiplies sight range; time of day sets it below 1.0 at night.
var sight_multiplier: float = 1.0

var _body_color: Color
var _ring_color: Color
var _agent: NavigationAgent3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _moving: bool = false
var _cooldown: float = 0.0


## Supplies everything the soldier needs. Call before adding it to the tree.
func setup(p_stats: SoldierStats, p_squad_number: int, p_body_color: Color,
		p_ring_color: Color, p_fog: FogOfWar, p_retarget_interval: float) -> void:
	stats = p_stats
	squad_number = p_squad_number
	_body_color = p_body_color
	_ring_color = p_ring_color
	fog = p_fog
	retarget_interval = p_retarget_interval
	health = stats.max_health


func _ready() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	body.mesh = capsule
	body.position.y = 0.8
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = _body_color
	body.material_override = body_material
	add_child(body)

	# Small box on the front (-Z) so facing is readable.
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.15, 0.15, 0.4)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 1.1, -0.3)
	nose.material_override = body_material
	add_child(nose)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	_ring.mesh = torus
	_ring.position.y = 0.1
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = _ring_color
	_ring.material_override = _ring_material
	add_child(_ring)

	var label := Label3D.new()
	label.text = str(squad_number)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.font_size = 64
	label.outline_size = 12
	label.modulate = _ring_color
	label.position.y = 2.1
	add_child(label)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.5
	add_child(_agent)


## Highlights the selection ring (white and larger) when [param selected].
func set_selected(selected: bool) -> void:
	_ring_material.albedo_color = Color.WHITE if selected else _ring_color
	_ring.scale = Vector3.ONE * (1.3 if selected else 1.0)


## Walks to the nearest reachable point to [param target] along the navigation mesh.
func order_move(target: Vector3) -> void:
	_agent.target_position = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), target)
	_moving = true


## True while the soldier is walking an order (moving soldiers make noise).
func is_moving() -> bool:
	return _moving


## Sight range in metres after the time-of-day multiplier.
func current_sight_range() -> float:
	return stats.sight_range * sight_multiplier


## Applies [param amount] damage after armor; frees the soldier at zero hit points.
## Hits on an already-dead soldier are ignored, so [signal died] fires once.
func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount * (1.0 - clampf(stats.damage_reduction, 0.0, MAX_DAMAGE_REDUCTION))
	health_changed.emit(health, stats.max_health)
	if health <= 0.0:
		died.emit(self)
		queue_free()


func _physics_process(delta: float) -> void:
	if _moving:
		_step_along_path(delta)
	_cooldown -= delta
	if stats.has_weapon and _cooldown <= 0.0:
		_try_fire()


func _step_along_path(delta: float) -> void:
	if _agent.is_navigation_finished():
		_moving = false
		return
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	var step := stats.move_speed * delta
	if to_next.length() > 0.001:
		rotation.y = atan2(-to_next.x, -to_next.z)
	global_position += to_next.limit_length(step)


## Shoots the nearer of the best dummy and the best zombie in reach, if any.
func _try_fire() -> void:
	var reach := minf(stats.weapon_range, current_sight_range())
	var dummy := _find_target(reach)
	var zombie := -1
	if horde != null:
		zombie = horde.find_target(global_position, reach, fog)
	if dummy == null and zombie < 0:
		_cooldown = retarget_interval
		return
	_cooldown = stats.fire_interval
	var aim_point: Vector3
	if zombie >= 0 and (dummy == null or global_position.distance_squared_to(horde.zombie_position(zombie))
			<= global_position.distance_squared_to(dummy.global_position)):
		aim_point = horde.zombie_position(zombie)
		horde.damage_zombie(zombie, stats.weapon_damage)
	else:
		aim_point = dummy.global_position
		dummy.take_damage(stats.weapon_damage)
	shot_fired.emit(global_position + Vector3.UP * 1.2, aim_point + Vector3.UP, stats.noise)


## Nearest living target inside [param reach] metres with a clear line of sight.
func _find_target(reach: float) -> TargetDummy:
	var best: TargetDummy = null
	var best_sq := reach ** 2
	for node in get_tree().get_nodes_in_group(&"targets"):
		var candidate := node as TargetDummy
		if candidate == null or not candidate.is_alive():
			continue
		var distance_sq := global_position.distance_squared_to(candidate.global_position)
		if distance_sq <= best_sq and fog.has_line_of_sight(global_position, candidate.global_position):
			best = candidate
			best_sq = distance_sq
	return best
