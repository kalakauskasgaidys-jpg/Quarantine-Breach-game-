class_name GreyboxBlock
extends Node3D
## Greybox test block for story 001 (design/game-brief.md MVP feature 2, build
## order step 1): wires data, navigation, fog of war, loadout panel, squads,
## selection input and target dummies together. Zombies replace the dummies in story 002.

## Emitted when every deployed squad has been wiped (feeds the mission fail state in story 004).
signal all_squads_wiped

const HELP_TEXT := "LMB click / drag: select | 1-3: squad | RMB: move | WASD: pan | wheel: zoom | K: kill selected (debug)\nN: noise rings | H: horde heat map | T: day / night (debug)"
## Seconds between refreshes of the debug readout.
const READOUT_INTERVAL: float = 0.25
## Launch arguments (after "--") that override the data files for testing and
## benchmarking: --difficulty=hard --time-of-day=night --horde-size=500
## --roaming-count=0 --reveal-zombies
const ARG_DIFFICULTY := "difficulty"
const ARG_TIME_OF_DAY := "time-of-day"
const ARG_HORDE_SIZE := "horde-size"
const ARG_ROAMING_COUNT := "roaming-count"
const ARG_REVEAL := "reveal-zombies"

@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var _ground: MeshInstance3D = $NavigationRegion3D/Ground
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _soldiers_root: Node3D = $Soldiers
@onready var _controller: SelectionController = $Hud/SelectionController
@onready var _status: Label = $Hud/StatusLabel
@onready var _panel: LoadoutPanel = $Hud/LoadoutPanel

var _data: GameData
var _fog: FogOfWar
var _squads: Array[Squad] = []
var _buildings: Array[MeshInstance3D] = []
var _building_rects: Array[Rect2] = []
var _fog_timer: float = 0.0
var _noise: NoiseSystem
var _horde: HordeManager
var _time_of_day: TimeOfDay
var _rings: NoiseRingsOverlay
var _heat_map: HordeHeatMap
var _readout: Label
var _readout_timer: float = 0.0
## Roaming zombies before the time-of-day multiplier.
var _base_roaming: int = 0


func _ready() -> void:
	_data = GameData.load_all()
	if _data == null:
		_status.text = "Data files failed to load - see the Output panel"
		_panel.hide()
		return
	var config := _data.config
	_panel.hide()

	_nav_region.bake_navigation_mesh(false)

	var ground_box := _ground.global_transform * _ground.get_aabb()
	var bounds := Rect2(ground_box.position.x, ground_box.position.z, ground_box.size.x, ground_box.size.z)
	var cell: float = config["cell_size"]
	_fog = FogOfWar.new(bounds.position, Vector2i(ceili(bounds.size.x / cell), ceili(bounds.size.y / cell)), cell)
	for node in get_tree().get_nodes_in_group(&"obstacles"):
		var building := node as MeshInstance3D
		var box := building.global_transform * building.get_aabb()
		var rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		_fog.block_rect(rect)
		_buildings.append(building)
		_building_rects.append(rect)
	var overlay := FogOverlay.new()
	add_child(overlay)
	overlay.setup(_fog, GameData.color_from(config["fog_unexplored_color"]), GameData.color_from(config["fog_explored_color"]))
	_fog.fog_updated.connect(_on_fog_updated)

	_camera_rig.setup(config["camera"], bounds)
	_controller.setup(_camera_rig.camera, config["drag_threshold_px"], config["pick_radius_px"])
	_controller.selection_changed.connect(_on_selection_changed)

	for node in get_tree().get_nodes_in_group(&"targets"):
		(node as TargetDummy).setup(config["target_dummy_health"])

	_setup_horde(bounds)

	# The navigation map only knows the baked mesh after the next physics frames.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_panel.setup(_data)
	_panel.deploy_requested.connect(_on_deploy_requested)
	_panel.show()
	_refresh_fog()
	_status.text = HELP_TEXT


func _process(delta: float) -> void:
	if _fog == null:
		return
	_fog_timer += delta
	if _fog_timer >= float(_data.config["fog_update_interval"]):
		_fog_timer = 0.0
		_refresh_fog()
	_noise.advance(delta)
	_noise.emit_movement_noise(_living_soldiers(), delta)
	_readout_timer += delta
	if _readout_timer >= READOUT_INTERVAL:
		_readout_timer = 0.0
		_update_readout()


## Creates noise, horde, time of day and the debug overlays (story 002). Launch
## arguments override the difficulty, time of day and horde size for testing.
func _setup_horde(bounds: Rect2) -> void:
	var args := _launch_args()
	var presets: Dictionary = _data.difficulty["presets"]
	var preset_id := _choose(args.get(ARG_DIFFICULTY, ""), presets, _data.difficulty["default_preset"], ARG_DIFFICULTY)
	var preset: Dictionary = presets[preset_id]
	var horde_size := _int_arg(args, ARG_HORDE_SIZE, int(preset["horde_size"]))
	_base_roaming = _int_arg(args, ARG_ROAMING_COUNT, int(preset["roaming_count"]))

	_time_of_day = TimeOfDay.new()
	_time_of_day.name = "TimeOfDay"
	add_child(_time_of_day)
	var modes: Dictionary = _data.time_of_day["modes"]
	_time_of_day.setup(modes, ($WorldEnvironment as WorldEnvironment).environment, $Sun as DirectionalLight3D)
	var capacity := horde_size + ceili(_base_roaming * _time_of_day.max_roaming_multiplier())

	_noise = NoiseSystem.new(_data.noise)
	var safe_points: Array[Vector3] = []
	for marker in _spawn_points.get_children():
		safe_points.append((marker as Node3D).global_position)
	_horde = HordeManager.new()
	_horde.name = "Horde"
	_horde.reveal_all = args.has(ARG_REVEAL)
	add_child(_horde)
	_horde.setup(_data.horde, _noise, _fog, bounds, _building_rects, capacity, safe_points)
	_horde.spawn_idle(horde_size)

	_rings = NoiseRingsOverlay.new()
	add_child(_rings)
	_rings.setup(_noise, _data.noise["rings"])
	_heat_map = HordeHeatMap.new()
	add_child(_heat_map)
	_heat_map.setup(_horde, bounds, _data.horde["heat_map"])

	var controls := HordeDebugControls.new()
	add_child(controls)
	controls.noise_rings_toggled.connect(func() -> void: _rings.set_enabled(not _rings.visible))
	controls.heat_map_toggled.connect(func() -> void: _heat_map.set_enabled(not _heat_map.visible))
	controls.time_of_day_toggled.connect(_time_of_day.toggle)

	_readout = Label.new()
	_readout.position = Vector2(8, 56)
	$Hud.add_child(_readout)

	_time_of_day.time_of_day_changed.connect(_on_time_of_day_changed)
	_time_of_day.set_mode(_choose(args.get(ARG_TIME_OF_DAY, ""), modes, _data.time_of_day["default_mode"], ARG_TIME_OF_DAY))


## Launch arguments after "--" as { name: value }; a bare flag has the value "true".
func _launch_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return args


## [param wanted] if it is a key of [param options], else [param fallback]
## (with an error when [param wanted] was given but unknown).
func _choose(wanted: String, options: Dictionary, fallback: String, arg_name: String) -> String:
	if wanted == "" or options.has(wanted):
		return fallback if wanted == "" else wanted
	push_error("Launch argument --%s=%s is not one of %s; using '%s'" % [arg_name, wanted, options.keys(), fallback])
	return fallback


func _int_arg(args: Dictionary, arg_name: String, fallback: int) -> int:
	if not args.has(arg_name):
		return fallback
	var text: String = args[arg_name]
	if text.is_valid_int() and int(text) >= 0:
		return int(text)
	push_error("Launch argument --%s=%s is not a whole number >= 0; using %d" % [arg_name, text, fallback])
	return fallback


func _living_soldiers() -> Array[Soldier]:
	var soldiers: Array[Soldier] = []
	for squad in _squads:
		soldiers.append_array(squad.soldiers)
	return soldiers


func _on_time_of_day_changed(_mode_id: String) -> void:
	for soldier in _living_soldiers():
		soldier.sight_multiplier = _time_of_day.sight_range_multiplier
	_horde.set_sight_multiplier(_time_of_day.zombie_sight_multiplier)
	_horde.set_roaming_count(roundi(_base_roaming * _time_of_day.roaming_multiplier))
	if not _squads.is_empty():
		_refresh_fog()


func _update_readout() -> void:
	_readout.text = "%s | zombies %d (roaming %d, alerted %d, chasing %d, searching %d) | noises %d | horde step %.2f ms" % [
			_time_of_day.display_name, _horde.count, _horde.roamer_count(),
			_horde.count_in_state(HordeManager.State.ALERTED), _horde.count_in_state(HordeManager.State.CHASE),
			_horde.count_in_state(HordeManager.State.SEARCH),
			_noise.events.size(), _horde.step_time_usec / 1000.0]


func _on_deploy_requested(loadouts: Array) -> void:
	_panel.hide()
	var config := _data.config
	var colors: Array = config["squad_colors"]
	var spacing: float = config["formation_spacing"]
	for squad_index in loadouts.size():
		var squad := Squad.new()
		squad.number = squad_index + 1
		squad.formation_spacing = spacing
		var squad_loadouts: Array = loadouts[squad_index]
		var spawn := (_spawn_points.get_child(squad_index) as Node3D).global_position
		var ring_color := GameData.color_from(colors[squad_index % colors.size()])
		for soldier_index in squad_loadouts.size():
			var loadout: SoldierLoadout = squad_loadouts[soldier_index]
			var class_color := GameData.color_from(_data.classes[loadout.class_id]["color"])
			var soldier := Soldier.new()
			soldier.setup(SoldierStats.build(loadout, _data), squad.number, class_color, ring_color,
					_fog, config["retarget_interval"])
			soldier.horde = _horde
			soldier.sight_multiplier = _time_of_day.sight_range_multiplier
			soldier.position = spawn + Squad.formation_offset(soldier_index, squad_loadouts.size(), spacing)
			_soldiers_root.add_child(soldier)
			soldier.shot_fired.connect(_on_shot_fired)
			squad.add_soldier(soldier)
		squad.squad_wiped.connect(_on_squad_wiped)
		_squads.append(squad)
	_horde.set_squads(_squads)
	_controller.set_squads(_squads)
	_refresh_fog()


func _refresh_fog() -> void:
	var positions: Array[Vector3] = []
	var ranges: Array[float] = []
	for squad in _squads:
		for soldier in squad.soldiers:
			positions.append(soldier.global_position)
			ranges.append(soldier.current_sight_range())
	_fog.update(positions, ranges)


## Hides enemies out of view and buildings never seen.
func _on_fog_updated() -> void:
	for node in get_tree().get_nodes_in_group(&"targets"):
		var dummy := node as TargetDummy
		dummy.visible = _fog.is_visible_at(dummy.global_position)
	for i in _buildings.size():
		_buildings[i].visible = _fog.is_rect_explored(_building_rects[i])


func _on_selection_changed(selected: Array[Squad]) -> void:
	if selected.is_empty():
		_status.text = HELP_TEXT
		return
	var numbers: Array[String] = []
	for squad in selected:
		numbers.append(str(squad.number))
	_status.text = "Selected squad %s | %s" % [", ".join(numbers), HELP_TEXT]


func _on_squad_wiped(squad: Squad) -> void:
	_status.text = "Squad %d wiped out - control lost" % squad.number
	for other in _squads:
		if not other.is_wiped():
			return
	all_squads_wiped.emit()


## Short-lived line from the shooter to the target.
func _on_shot_fired(from: Vector3, to: Vector3, noise_radius: float) -> void:
	_noise.emit_noise(from, noise_radius)
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, from.distance_to(to))
	tracer.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.4)
	tracer.material_override = material
	add_child(tracer)
	tracer.look_at_from_position(from.lerp(to, 0.5), to)
	get_tree().create_timer(float(_data.config["tracer_duration"])).timeout.connect(tracer.queue_free)
