class_name GreyboxBlock
extends Node3D
## Greybox test block for story 001 (design/game-brief.md MVP feature 2, build
## order step 1): wires data, navigation, fog of war, loadout panel, squads,
## selection input and target dummies together. Zombies replace the dummies in story 002.

## Emitted when every deployed squad has been wiped (feeds the mission fail state in story 004).
signal all_squads_wiped

const HELP_TEXT := "LMB click / drag: select | 1-3: squad | RMB: move | WASD: pan | wheel: zoom | K: kill selected (debug)"

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
			soldier.position = spawn + Squad.formation_offset(soldier_index, squad_loadouts.size(), spacing)
			_soldiers_root.add_child(soldier)
			soldier.shot_fired.connect(_on_shot_fired)
			squad.add_soldier(soldier)
		squad.squad_wiped.connect(_on_squad_wiped)
		_squads.append(squad)
	_controller.set_squads(_squads)
	_refresh_fog()


func _refresh_fog() -> void:
	var positions: Array[Vector3] = []
	var ranges: Array[float] = []
	for squad in _squads:
		for soldier in squad.soldiers:
			positions.append(soldier.global_position)
			ranges.append(soldier.stats.sight_range)
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
func _on_shot_fired(from: Vector3, to: Vector3, _noise: float) -> void:
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
