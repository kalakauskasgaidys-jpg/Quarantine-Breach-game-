class_name SelectionController
extends Control
## Mouse and keyboard input for squads: click, drag-box and number-key selection,
## right-click move orders, and the drag-box overlay. Contains no unit logic; it
## only calls Squad methods (design/game-brief.md MVP feature 2).
##
## Keys: 1-9 select that squad, Shift adds to the selection, K is a greybox
## debug key that kills the selected squads (to exercise the wipe-out rule).

## Emitted whenever the set of selected squads changes.
signal selection_changed(selected: Array[Squad])

## Optional hook for right-clicks: called with the screen position; returning true
## means the click was handled (loot, assign) and no move order is given.
var order_override: Callable = Callable()

var _camera: Camera3D
var _squads: Array[Squad] = []
var _selected: Array[Squad] = []
var _drag_threshold: float = 0.0
var _pick_radius: float = 0.0
var _pressed: bool = false
var _dragging: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _drag_rect: Rect2 = Rect2()


## Supplies the camera used to project soldiers and ground clicks, and input tuning.
func setup(camera: Camera3D, drag_threshold_px: float, pick_radius_px: float) -> void:
	_camera = camera
	_drag_threshold = drag_threshold_px
	_pick_radius = pick_radius_px


## Sets the controllable squads (index 0 = squad 1).
func set_squads(squads: Array[Squad]) -> void:
	_squads = squads
	for squad in _squads:
		squad.squad_wiped.connect(_on_squad_wiped)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_pressed = true
				_dragging = false
				_press_position = button.position
			elif _pressed:
				_finish_press(button.position, button.shift_pressed)
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_order_selected(button.position)
	elif event is InputEventMouseMotion and _pressed:
		var motion := event as InputEventMouseMotion
		if _dragging or motion.position.distance_to(_press_position) > _drag_threshold:
			_dragging = true
			_drag_rect = Rect2(_press_position, motion.position - _press_position).abs()
			queue_redraw()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		var index := key.keycode - KEY_1
		if index >= 0 and index < 9:
			if index < _squads.size() and not _squads[index].is_wiped():
				_select([_squads[index]], key.shift_pressed)
		elif key.keycode == KEY_K:
			for squad in _selected.duplicate():
				for soldier in squad.soldiers.duplicate():
					soldier.take_damage(INF)


func _draw() -> void:
	if _dragging:
		draw_rect(_drag_rect, Color(1.0, 1.0, 1.0, 0.15))
		draw_rect(_drag_rect, Color.WHITE, false, 1.0)


func _finish_press(release_position: Vector2, additive: bool) -> void:
	var hit: Array[Squad] = []
	if _dragging:
		for squad in _squads:
			for soldier in squad.soldiers:
				if _drag_rect.has_point(_screen_position(soldier)):
					hit.append(squad)
					break
	else:
		var nearest := _pick_radius
		for squad in _squads:
			for soldier in squad.soldiers:
				var distance := release_position.distance_to(_screen_position(soldier))
				if distance <= nearest:
					nearest = distance
					hit = [squad]
	_pressed = false
	_dragging = false
	queue_redraw()
	_select(hit, additive)


func _screen_position(soldier: Soldier) -> Vector2:
	return _camera.unproject_position(soldier.global_position + Vector3.UP * 0.8)


func _select(squads: Array[Squad], additive: bool) -> void:
	if not additive:
		for squad in _selected:
			squad.set_selected(false)
		_selected.clear()
	for squad in squads:
		if not _selected.has(squad):
			_selected.append(squad)
		squad.set_selected(true)
	selection_changed.emit(_selected)


func _order_selected(screen_position: Vector2) -> void:
	if order_override.is_valid() and order_override.call(screen_position, _selected):
		return
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
			_camera.project_ray_origin(screen_position), _camera.project_ray_normal(screen_position))
	if hit == null:
		return
	for squad in _selected:
		squad.order_move(hit)


func _on_squad_wiped(squad: Squad) -> void:
	_selected.erase(squad)
	selection_changed.emit(_selected)
