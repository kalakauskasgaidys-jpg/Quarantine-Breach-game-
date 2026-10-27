class_name MissionControls
extends Node
## Input for the extraction mission (story 004), kept out of [Mission]. Right-clicking
## a supply cache orders the selected squads to loot it, right-clicking a civilian
## assigns it to the selected squad, X asks the mission to extract. It hooks the
## selection controller's right-click, so a click on a cache or civilian gives no
## move order. Uses the physical key so the binding ignores keyboard layout.

var _mission: Mission
var _camera: Camera3D
var _pick_radius: float


## Wires the controls to [param mission]; [param controller] supplies the right-click
## hook, [param camera] projects units to the screen for picking.
func setup(mission: Mission, controller: SelectionController, camera: Camera3D, pick_radius_px: float) -> void:
	_mission = mission
	_camera = camera
	_pick_radius = pick_radius_px
	controller.order_override = _on_order_clicked


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_X:
		_mission.request_extract()


## Returns true if the click hit a cache or civilian (and was handled).
func _on_order_clicked(screen_position: Vector2, selected: Array[Squad]) -> bool:
	if not _mission.is_running:
		return false
	var nearest := _pick_radius
	var picked: Node3D = null
	for cache in _mission.caches:
		var distance := _screen_distance(cache, screen_position, 0.4)
		if cache.visible and distance <= nearest:
			nearest = distance
			picked = cache
	for civilian in _mission.civilians:
		var distance := _screen_distance(civilian, screen_position, 0.8)
		if civilian.visible and distance <= nearest:
			nearest = distance
			picked = civilian
	if picked == null:
		return false
	if picked is SupplyCache:
		_mission.order_loot(selected, picked as SupplyCache)
	else:
		_mission.assign_civilian(picked as Civilian, selected)
	return true


func _screen_distance(unit: Node3D, screen_position: Vector2, height: float) -> float:
	return screen_position.distance_to(_camera.unproject_position(unit.global_position + Vector3.UP * height))
