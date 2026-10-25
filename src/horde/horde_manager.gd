class_name HordeManager
extends Node3D
## The zombie horde (design/game-brief.md MVP feature 3). Zombies are rows in
## parallel packed arrays, not nodes: no physics body, no NavigationAgent. They
## are drawn in one MultiMesh and steered by ONE shared [FlowField] that points at
## the current attractors (the loudest noise, weighted against the nearest).
##
## States: IDLE (stands still) and ROAM (wanders) are a zombie's "home" state
## (roamers are born ROAM, the rest IDLE). A heard noise sets ALERTED: follow the
## flow field until it reaches the noise, then go home. A seen soldier sets CHASE:
## walk straight at it and bite in contact. Losing sight of it (or its death) sets
## SEARCH: the last-seen spot becomes a short-lived quiet attractor and the zombie
## follows the field there (around buildings), then goes home.
##
## Zombies face their walking direction and are pushed apart from close
## neighbours through a spatial hash (never all-pairs), refreshed over several steps.
##
## The flow field is rebuilt on a worker thread into a back buffer and swapped in
## when done, so recomputing never stalls a frame. No input code.

enum State { IDLE, ROAM, ALERTED, CHASE, SEARCH }

## Floats per MultiMesh instance: 12 transform + 4 colour.
const FLOATS_PER_INSTANCE: int = 16
## Zombie body height / 2: the origin height of every instance.
const BODY_CENTER_HEIGHT: float = 0.8
## Instance colour per State (presentation only): idle, roam, alerted, chase, search.
const STATE_COLORS: Array[Color] = [
	Color(0.4, 0.55, 0.4), Color(0.6, 0.6, 0.3), Color(0.95, 0.6, 0.1), Color(0.9, 0.12, 0.12),
	Color(0.75, 0.3, 0.9),
]
## Two zombies closer than this (squared metres) count as on the same spot and do not push.
const MIN_SEPARATION_SQ: float = 0.000001

## Living zombies; every per-zombie array is valid for indices below this.
var count: int = 0
## World (x, z) per zombie.
var positions: PackedVector2Array = PackedVector2Array()
## Current velocity per zombie in metres per second.
var velocities: PackedVector2Array = PackedVector2Array()
## [enum State] per zombie.
var states: PackedByteArray = PackedByteArray()
## Hit points left per zombie.
var health: PackedFloat32Array = PackedFloat32Array()
## Draw zombies even where the fog hides them (benchmarking and debugging).
var reveal_all: bool = false
## Microseconds the last simulation step took (AI budget: 2 ms).
var step_time_usec: int = 0

var _noise: NoiseSystem
var _fog: FogOfWar
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bounds: Rect2
var _squads: Array[Squad] = []
var _spawn_safe_points: Array[Vector2] = []
var _capacity: int = 0
var _tick: int = 0

# Per-zombie arrays that are not public.
var _timers: PackedFloat32Array = PackedFloat32Array()
## Instance id of the soldier a chasing zombie follows (stable when others die).
var _targets: PackedInt64Array = PackedInt64Array()
var _last_seen: PackedVector2Array = PackedVector2Array()
var _roam_heading: PackedVector2Array = PackedVector2Array()
## Facing per zombie as (sin yaw, cos yaw), i.e. minus the unit walking direction.
var _facing: PackedVector2Array = PackedVector2Array()
## Separation push per zombie, refreshed every _sep_stride steps.
var _push: PackedVector2Array = PackedVector2Array()
var _roamers: PackedByteArray = PackedByteArray()
var _roamer_count: int = 0

# Soldiers as seen this step.
var _soldiers: Array[Soldier] = []
var _soldier_pos: PackedVector2Array = PackedVector2Array()
var _soldier_ids: PackedInt64Array = PackedInt64Array()
var _soldier_index: Dictionary = {}

# Zombie tuning (horde.json "zombie").
var _hit_points: float
var _roam_speed: float
var _alert_speed: float
var _chase_speed: float
var _sight_range: float
var _sight_sq: float
var _contact_sq: float
var _attack_damage: float
var _attack_interval: float
var _perception_stride: int
var _roam_turn_min: float
var _roam_turn_max: float

# Separation (horde.json "separation") over a linked-list spatial hash.
var _sep_radius: float
var _sep_radius_sq: float
var _sep_strength: float
var _sep_max: int
var _sep_stride: int
var _sep_inv_cell: float
var _sep_size: Vector2i
var _cell_head: PackedInt32Array = PackedInt32Array()
var _cell_next: PackedInt32Array = PackedInt32Array()

# Attractors: places the horde is drawn to. Parallel arrays.
var _att_pos: PackedVector2Array = PackedVector2Array()
var _att_radius: PackedFloat32Array = PackedFloat32Array()
var _att_ttl: PackedFloat32Array = PackedFloat32Array()
var _att_memory: float
var _att_merge_sq: float
var _att_max: int
var _att_loudness_weight: float

# Last-seen search (horde.json "last_seen").
var _last_seen_pull: float
var _last_seen_lifetime: float
var _arrive_sq: float

# Shared flow field: _field is read by the simulation, _back is built by the task.
var _field: FlowField
var _back: FlowField
var _field_interval: float
var _field_timer: float = 0.0
var _version: int = 0
var _computed_version: int = 0
var _task_version: int = 0
var _task_id: int = -1

# Spawn tuning (horde.json "spawn").
var _safe_radius_sq: float
var _spawn_attempts: int

# Rendering.
var _multimesh: MultiMesh
var _buffer: PackedFloat32Array = PackedFloat32Array()
var _palette: PackedFloat32Array = PackedFloat32Array()


## Builds the horde for a map. [param config] is the validated horde.json,
## [param capacity] the most zombies that can ever be alive, [param obstacle_rects]
## the buildings (world x, z), [param safe_points] places kept free of spawns
## (player spawn markers). Call once, after adding the node to the tree.
func setup(config: Dictionary, noise: NoiseSystem, fog: FogOfWar, bounds: Rect2,
		obstacle_rects: Array[Rect2], capacity: int, safe_points: Array[Vector3]) -> void:
	_noise = noise
	_fog = fog
	_bounds = bounds
	_capacity = capacity
	_rng.seed = int(config["seed"])
	for point in safe_points:
		_spawn_safe_points.append(Vector2(point.x, point.z))

	var zombie: Dictionary = config["zombie"]
	_hit_points = zombie["hit_points"]
	_roam_speed = zombie["roam_speed"]
	_alert_speed = zombie["alert_speed"]
	_chase_speed = zombie["chase_speed"]
	_sight_range = zombie["sight_range"]
	set_sight_multiplier(1.0)
	_contact_sq = float(zombie["contact_range"]) ** 2
	_attack_damage = zombie["attack_damage"]
	_attack_interval = zombie["attack_interval"]
	_perception_stride = maxi(1, roundi(float(zombie["perception_interval"]) * Engine.physics_ticks_per_second))
	_roam_turn_min = zombie["roam_turn_min"]
	_roam_turn_max = zombie["roam_turn_max"]
	var separation: Dictionary = config["separation"]
	_sep_radius = separation["radius"]
	_sep_radius_sq = _sep_radius * _sep_radius
	_sep_strength = separation["strength"]
	_sep_max = int(separation["max_neighbors"])
	_sep_stride = maxi(1, roundi(float(separation["update_interval"]) * Engine.physics_ticks_per_second))
	_sep_inv_cell = 1.0 / _sep_radius
	_sep_size = Vector2i(ceili(bounds.size.x / _sep_radius), ceili(bounds.size.y / _sep_radius))
	_cell_head.resize(_sep_size.x * _sep_size.y)
	_cell_head.fill(-1)
	_cell_next.resize(capacity)
	var attractors: Dictionary = config["attractors"]
	_att_memory = attractors["memory_seconds"]
	_att_merge_sq = float(attractors["merge_distance"]) ** 2
	_att_max = int(attractors["max_count"])
	_att_loudness_weight = attractors["loudness_weight"]
	var last_seen: Dictionary = config["last_seen"]
	_last_seen_pull = last_seen["pull_strength"]
	_last_seen_lifetime = last_seen["lifetime"]
	_arrive_sq = float(last_seen["arrive_distance"]) ** 2
	var spawn: Dictionary = config["spawn"]
	_safe_radius_sq = float(spawn["safe_radius"]) ** 2
	_spawn_attempts = int(spawn["attempts"])
	_field_interval = config["field_recompute_interval"]

	positions.resize(capacity)
	velocities.resize(capacity)
	states.resize(capacity)
	health.resize(capacity)
	_timers.resize(capacity)
	_targets.resize(capacity)
	_last_seen.resize(capacity)
	_roam_heading.resize(capacity)
	_facing.resize(capacity)
	_push.resize(capacity)
	_roamers.resize(capacity)

	var cell: float = config["flow_cell_size"]
	var grid := Vector2i(ceili(bounds.size.x / cell), ceili(bounds.size.y / cell))
	_field = FlowField.new(bounds.position, grid, cell)
	_back = FlowField.new(bounds.position, grid, cell)
	for rect in obstacle_rects:
		_field.block_rect(rect, config["obstacle_margin"])
	_back.copy_blocked_from(_field)
	_field.compute(PackedInt32Array(), PackedFloat32Array())
	_back.compute(PackedInt32Array(), PackedFloat32Array())

	_build_renderer()
	_noise.noise_emitted.connect(_on_noise_emitted)


## Sets the squads whose soldiers the horde sees, chases and bites.
func set_squads(squads: Array[Squad]) -> void:
	_squads = squads


## Scales zombie sight range (time of day: below 1.0 at night).
func set_sight_multiplier(multiplier: float) -> void:
	_sight_sq = (_sight_range * multiplier) ** 2


## Zombie sight range in metres after the time-of-day multiplier.
func current_sight_range() -> float:
	return sqrt(_sight_sq)


## Adds [param amount] standing (IDLE) zombies at random open places away from
## the player spawns. Returns how many were placed.
func spawn_idle(amount: int) -> int:
	var placed := 0
	for i in amount:
		if _spawn_one(false):
			placed += 1
	return placed


## Makes the number of wandering zombies equal [param target]: spawns new ones out
## of sight, or removes the most recently added. Capped by the horde capacity.
func set_roaming_count(target: int) -> void:
	while _roamer_count < target and _spawn_one(true):
		pass
	var i := count - 1
	while _roamer_count > target and i >= 0:
		if _roamers[i] == 1:
			_remove_at(i)
		i -= 1


## Number of wandering zombies.
func roamer_count() -> int:
	return _roamer_count


## Number of living zombies currently in [param state].
func count_in_state(state: State) -> int:
	var total := 0
	for i in count:
		if states[i] == state:
			total += 1
	return total


## World position of zombie [param index] on the ground.
func zombie_position(index: int) -> Vector3:
	return Vector3(positions[index].x, 0.0, positions[index].y)


## Index of the nearest zombie within [param reach] metres of [param from] with a
## clear line of sight in [param fog], or -1. Indices are valid until the next
## [method damage_zombie] call.
func find_target(from: Vector3, reach: float, fog: FogOfWar) -> int:
	var origin := Vector2(from.x, from.z)
	var best := -1
	var best_sq := reach * reach
	for i in count:
		var distance_sq := positions[i].distance_squared_to(origin)
		if distance_sq <= best_sq and fog.has_line_of_sight(from, zombie_position(i)):
			best = i
			best_sq = distance_sq
	return best


## Hurts zombie [param index]; at zero hit points it is removed from the horde.
func damage_zombie(index: int, amount: float) -> void:
	health[index] -= amount
	if health[index] <= 0.0:
		_remove_at(index)


func _exit_tree() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_tick += 1
	_refresh_soldiers()
	_update_attractors(delta)
	_update_field(delta)
	if _tick % _sep_stride == 0:
		_build_spatial_hash()
	_simulate(delta)
	_upload()
	step_time_usec = Time.get_ticks_usec() - started


func _build_renderer() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 1.6
	body.radial_segments = 6
	body.rings = 2
	_multimesh.mesh = body
	_multimesh.instance_count = _capacity
	_multimesh.visible_instance_count = 0
	_multimesh.custom_aabb = AABB(Vector3(_bounds.position.x, 0.0, _bounds.position.y),
			Vector3(_bounds.size.x, 2.0, _bounds.size.y))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	instance.material_override = material
	add_child(instance)

	# A yaw-only basis keeps the Y row, the height and the colour alpha constant:
	# write them once. Facing, position and colour are written every frame.
	_buffer.resize(_capacity * FLOATS_PER_INSTANCE)
	for i in _capacity:
		var o := i * FLOATS_PER_INSTANCE
		_buffer[o + 5] = 1.0
		_buffer[o + 7] = BODY_CENTER_HEIGHT
		_buffer[o + 15] = 1.0
	for color in STATE_COLORS:
		_palette.append_array(PackedFloat32Array([color.r, color.g, color.b]))


# --- spawning ---------------------------------------------------------------

## Adds one zombie at a random open place out of sight. False if it did not fit.
func _spawn_one(roamer: bool) -> bool:
	if count >= _capacity:
		return false
	var at := _random_spawn_position()
	if at == Vector2.INF:
		return false
	positions[count] = at
	velocities[count] = Vector2.ZERO
	states[count] = State.ROAM if roamer else State.IDLE
	health[count] = _hit_points
	_timers[count] = 0.0
	_targets[count] = 0
	_last_seen[count] = at
	_roam_heading[count] = Vector2.ZERO
	_facing[count] = Vector2.from_angle(_rng.randf() * TAU)
	_push[count] = Vector2.ZERO
	_roamers[count] = 1 if roamer else 0
	if roamer:
		_roamer_count += 1
	count += 1
	return true


func _random_spawn_position() -> Vector2:
	for attempt in _spawn_attempts:
		var at := Vector2(
				_rng.randf_range(_bounds.position.x, _bounds.end.x),
				_rng.randf_range(_bounds.position.y, _bounds.end.y))
		if _field.is_blocked(at) or _fog.is_visible_at(Vector3(at.x, 0.0, at.y)):
			continue
		var safe := true
		for point in _spawn_safe_points:
			if point.distance_squared_to(at) < _safe_radius_sq:
				safe = false
		for soldier_position in _soldier_pos:
			if soldier_position.distance_squared_to(at) < _safe_radius_sq:
				safe = false
		if safe:
			return at
	return Vector2.INF


## Removes zombie [param index] by moving the last zombie into its slot.
func _remove_at(index: int) -> void:
	if _roamers[index] == 1:
		_roamer_count -= 1
	var last := count - 1
	positions[index] = positions[last]
	velocities[index] = velocities[last]
	states[index] = states[last]
	health[index] = health[last]
	_timers[index] = _timers[last]
	_targets[index] = _targets[last]
	_last_seen[index] = _last_seen[last]
	_roam_heading[index] = _roam_heading[last]
	_facing[index] = _facing[last]
	_push[index] = _push[last]
	_roamers[index] = _roamers[last]
	count = last


# --- attractors and the shared flow field -------------------------------------

func _on_noise_emitted(noise_position: Vector3, radius: float) -> void:
	var at := Vector2(noise_position.x, noise_position.z)
	var radius_sq := radius * radius
	for i in count:
		if states[i] != State.CHASE and positions[i].distance_squared_to(at) <= radius_sq:
			states[i] = State.ALERTED
	_add_attractor(at, radius, _att_memory)


## Records a place the horde is drawn to for [param lifetime] seconds; one near an
## existing attractor refreshes it instead (keeping the louder radius and longer life).
## The flow field is marked stale only when an attractor is added, moves or gets louder.
func _add_attractor(at: Vector2, radius: float, lifetime: float) -> void:
	for i in _att_pos.size():
		if _att_pos[i].distance_squared_to(at) <= _att_merge_sq:
			# Only a change of place or loudness changes the field; a longer life does not.
			if _att_pos[i] != at or radius > _att_radius[i]:
				_version += 1
			_att_pos[i] = at
			_att_radius[i] = maxf(_att_radius[i], radius)
			_att_ttl[i] = maxf(_att_ttl[i], lifetime)
			return
	_version += 1
	if _att_pos.size() >= _att_max:
		var oldest := 0
		for i in _att_ttl.size():
			if _att_ttl[i] < _att_ttl[oldest]:
				oldest = i
		_att_pos.remove_at(oldest)
		_att_radius.remove_at(oldest)
		_att_ttl.remove_at(oldest)
	_att_pos.append(at)
	_att_radius.append(radius)
	_att_ttl.append(lifetime)


func _update_attractors(delta: float) -> void:
	var i := _att_pos.size() - 1
	while i >= 0:
		_att_ttl[i] -= delta
		if _att_ttl[i] <= 0.0:
			_att_pos.remove_at(i)
			_att_radius.remove_at(i)
			_att_ttl.remove_at(i)
			_version += 1
		i -= 1


## Swaps in a finished field and starts the next one when the attractors changed.
func _update_field(delta: float) -> void:
	_field_timer -= delta
	if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		var finished := _back
		_back = _field
		_field = finished
		_computed_version = _task_version
	if _task_id == -1 and _version != _computed_version and _field_timer <= 0.0:
		var loudest := 0.0
		for radius in _att_radius:
			loudest = maxf(loudest, radius)
		var cells := PackedInt32Array()
		var costs := PackedFloat32Array()
		for i in _att_pos.size():
			cells.append(_back.cell_index(_att_pos[i]))
			costs.append((loudest - _att_radius[i]) * _att_loudness_weight)
		_task_version = _version
		_field_timer = _field_interval
		_task_id = WorkerThreadPool.add_task(_back.compute.bind(cells, costs), false, "HordeManager flow field")


# --- simulation ----------------------------------------------------------------

func _refresh_soldiers() -> void:
	_soldiers.clear()
	_soldier_pos.clear()
	_soldier_ids.clear()
	_soldier_index.clear()
	for squad in _squads:
		for soldier in squad.soldiers:
			if soldier.health > 0.0:
				_soldier_index[soldier.get_instance_id()] = _soldiers.size()
				_soldiers.append(soldier)
				_soldier_ids.append(soldier.get_instance_id())
				_soldier_pos.append(Vector2(soldier.global_position.x, soldier.global_position.z))


## Buckets zombies by separation cell as linked lists (head per cell, next per zombie).
func _build_spatial_hash() -> void:
	_cell_head.fill(-1)
	var origin := _bounds.position
	for i in count:
		var p := positions[i]
		var cx := clampi(floori((p.x - origin.x) * _sep_inv_cell), 0, _sep_size.x - 1)
		var cy := clampi(floori((p.y - origin.y) * _sep_inv_cell), 0, _sep_size.y - 1)
		var c := cy * _sep_size.x + cx
		_cell_next[i] = _cell_head[c]
		_cell_head[c] = i


func _simulate(delta: float) -> void:
	var field := _field
	var field_current := _computed_version == _version
	var soldier_count := _soldier_pos.size()
	for i in count:
		var p := positions[i]
		var state: int = states[i]
		if soldier_count > 0 and (i + _tick) % _perception_stride == 0:
			state = _perceive(i, p, state)

		var v := Vector2.ZERO
		if state == State.CHASE:
			var target: int = _soldier_index.get(_targets[i], -1)
			if target < 0:
				state = _start_search(i)
			else:
				var to_soldier := _soldier_pos[target] - p
				var distance_sq := to_soldier.length_squared()
				if distance_sq <= _contact_sq:
					var wind_up := _timers[i] - delta
					if wind_up <= 0.0:
						wind_up = _attack_interval
						_soldiers[target].take_damage(_attack_damage)
					_timers[i] = wind_up
				else:
					v = to_soldier * (_chase_speed / sqrt(distance_sq))
		if state == State.SEARCH:
			var to_spot := _last_seen[i] - p
			if to_spot.length_squared() <= _arrive_sq:
				state = _home_state(i)
			else:
				var heading := field.direction_at(p)
				if heading.x != 0.0 or heading.y != 0.0:
					v = heading * _alert_speed
				elif field_current:
					state = _home_state(i)
				else:
					v = to_spot.normalized() * _alert_speed
		elif state == State.ALERTED:
			var heading := field.direction_at(p)
			if heading.x != 0.0 or heading.y != 0.0:
				v = heading * _alert_speed
			elif field_current:
				state = _home_state(i)
		elif state == State.ROAM:
			var turn := _timers[i] - delta
			if turn <= 0.0:
				turn = _rng.randf_range(_roam_turn_min, _roam_turn_max)
				_roam_heading[i] = Vector2.from_angle(_rng.randf() * TAU) * _roam_speed
			_timers[i] = turn
			v = _roam_heading[i]

		if v.x != 0.0 or v.y != 0.0:
			_facing[i] = -v.normalized()
		if (i + _tick) % _sep_stride == 0:
			_push[i] = _separation(i, p) * _sep_strength
		v += _push[i]

		if v.x != 0.0 or v.y != 0.0:
			var moved := p + v * delta
			if field.is_blocked(moved):
				var slide_x := Vector2(moved.x, p.y)
				var slide_z := Vector2(p.x, moved.y)
				if not field.is_blocked(slide_x):
					moved = slide_x
				elif not field.is_blocked(slide_z):
					moved = slide_z
				else:
					moved = p
				if state == State.ROAM:
					_timers[i] = 0.0
			positions[i] = moved
		velocities[i] = v
		states[i] = state


## Push away from neighbours closer than the separation radius, stronger when
## closer; reads at most max_neighbors of them from the 3x3 hash cells around [param p].
func _separation(i: int, p: Vector2) -> Vector2:
	var cx := clampi(floori((p.x - _bounds.position.x) * _sep_inv_cell), 0, _sep_size.x - 1)
	var cy := clampi(floori((p.y - _bounds.position.y) * _sep_inv_cell), 0, _sep_size.y - 1)
	var push := Vector2.ZERO
	var found := 0
	for gy in range(maxi(cy - 1, 0), mini(cy + 2, _sep_size.y)):
		for gx in range(maxi(cx - 1, 0), mini(cx + 2, _sep_size.x)):
			var j := _cell_head[gy * _sep_size.x + gx]
			while j != -1:
				if j != i and j < count:
					var away := p - positions[j]
					var distance_sq := away.length_squared()
					if distance_sq < _sep_radius_sq and distance_sq > MIN_SEPARATION_SQ:
						var distance := sqrt(distance_sq)
						push += away * ((_sep_radius - distance) / (distance * _sep_radius))
						found += 1
						if found >= _sep_max:
							return push
				j = _cell_next[j]
	return push


## Looks for the nearest soldier in sight range with a clear line of sight. A zombie
## that finds one chases it and remembers where it saw it; a chasing zombie that
## finds none starts searching the last-seen spot. Returns the new state.
func _perceive(i: int, p: Vector2, state: int) -> int:
	var best := -1
	var best_sq := _sight_sq
	for s in _soldier_pos.size():
		var distance_sq := _soldier_pos[s].distance_squared_to(p)
		if distance_sq <= best_sq and _fog.has_line_of_sight(
				Vector3(p.x, 0.0, p.y), Vector3(_soldier_pos[s].x, 0.0, _soldier_pos[s].y)):
			best = s
			best_sq = distance_sq
	if best < 0:
		return _start_search(i) if state == State.CHASE else state
	if state != State.CHASE:
		_timers[i] = _attack_interval
	_targets[i] = _soldier_ids[best]
	_last_seen[i] = _soldier_pos[best]
	return State.CHASE


## Turns the zombie's last-seen spot into a short-lived quiet attractor (it pulls
## only zombies already following the field nearby) and returns SEARCH.
func _start_search(i: int) -> int:
	_add_attractor(_last_seen[i], _last_seen_pull, _last_seen_lifetime)
	return State.SEARCH


## State a zombie settles into when it has nothing to follow or chase.
func _home_state(i: int) -> int:
	_timers[i] = 0.0
	return State.ROAM if _roamers[i] == 1 else State.IDLE


# --- drawing -------------------------------------------------------------------

## Writes the visible zombies into the MultiMesh buffer: a yaw rotation that faces
## the walking direction, the position and the state colour.
func _upload() -> void:
	var visible_count := 0
	var fog_origin := _fog.origin
	var inv_cell := 1.0 / _fog.cell_size
	var width := _fog.size.x
	var height := _fog.size.y
	var in_view := _fog.in_view
	for i in count:
		var p := positions[i]
		if not reveal_all:
			var fog_x := floori((p.x - fog_origin.x) * inv_cell)
			var fog_y := floori((p.y - fog_origin.y) * inv_cell)
			if fog_x < 0 or fog_y < 0 or fog_x >= width or fog_y >= height or in_view[fog_y * width + fog_x] == 0:
				continue
		# Rotation about Y: rows (cos, 0, sin), (0, 1, 0), (-sin, 0, cos).
		var facing := _facing[i]
		var o := visible_count * FLOATS_PER_INSTANCE
		_buffer[o] = facing.y
		_buffer[o + 2] = facing.x
		_buffer[o + 3] = p.x
		_buffer[o + 8] = -facing.x
		_buffer[o + 10] = facing.y
		_buffer[o + 11] = p.y
		var c: int = states[i] * 3
		_buffer[o + 12] = _palette[c]
		_buffer[o + 13] = _palette[c + 1]
		_buffer[o + 14] = _palette[c + 2]
		visible_count += 1
	_multimesh.buffer = _buffer
	_multimesh.visible_instance_count = visible_count
