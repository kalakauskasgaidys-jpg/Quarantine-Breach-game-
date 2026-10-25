class_name FogOfWar
extends RefCounted
## Grid line-of-sight and fog of war (design/game-brief.md MVP feature 2, Look notes).
##
## The map is a grid on the XZ plane. Blocked cells (buildings) stop sight.
## Cells are "in view" now, "explored" once ever seen, otherwise unexplored.
## Pure data, no nodes, so it can be tested without a scene.

## Emitted after [method update] has recomputed what is in view.
signal fog_updated

## World (x, z) of the grid's minimum corner.
var origin: Vector2
## Grid size in cells.
var size: Vector2i
## Cell edge in metres.
var cell_size: float
## 1 per cell ever seen.
var explored: PackedByteArray = PackedByteArray()
## 1 per cell in view this update.
var in_view: PackedByteArray = PackedByteArray()
var _blocked: PackedByteArray = PackedByteArray()


func _init(p_origin: Vector2, p_size: Vector2i, p_cell_size: float) -> void:
	origin = p_origin
	size = p_size
	cell_size = p_cell_size
	explored.resize(size.x * size.y)
	in_view.resize(size.x * size.y)
	_blocked.resize(size.x * size.y)


## Grid cell containing world position [param p].
func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell_size), floori((p.z - origin.y) / cell_size))


## Marks every cell touched by [param rect] (world x, z) as opaque.
func block_rect(rect: Rect2) -> void:
	var cells := _rect_to_cells(rect)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			_blocked[y * size.x + x] = 1


## True if any cell of [param rect] has been seen.
func is_rect_explored(rect: Rect2) -> bool:
	var cells := _rect_to_cells(rect)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			if explored[y * size.x + x] == 1:
				return true
	return false


## True if world position [param p] is in view right now.
func is_visible_at(p: Vector3) -> bool:
	var cell := world_to_cell(p)
	return _in_bounds(cell) and in_view[cell.y * size.x + cell.x] == 1


## True if no blocked cell lies between the two world positions.
func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	return _trace(world_to_cell(from), world_to_cell(to), INF, false)


## Recomputes what is in view from the viewers' positions and sight ranges
## (metres), updates explored cells, then emits [signal fog_updated].
func update(positions: Array[Vector3], ranges: Array[float]) -> void:
	in_view.fill(0)
	for i in positions.size():
		var center := world_to_cell(positions[i])
		var radius := ceili(ranges[i] / cell_size)
		var max_sq := pow(ranges[i] / cell_size, 2.0)
		if _in_bounds(center):
			in_view[center.y * size.x + center.x] = 1
			explored[center.y * size.x + center.x] = 1
		# One ray to every cell of the square ring around the viewer.
		for t in range(-radius, radius + 1):
			_trace(center, center + Vector2i(t, -radius), max_sq, true)
			_trace(center, center + Vector2i(t, radius), max_sq, true)
			_trace(center, center + Vector2i(-radius, t), max_sq, true)
			_trace(center, center + Vector2i(radius, t), max_sq, true)
	fog_updated.emit()


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func _rect_to_cells(rect: Rect2) -> Rect2i:
	var x0 := floori((rect.position.x - origin.x) / cell_size)
	var y0 := floori((rect.position.y - origin.y) / cell_size)
	var x1 := ceili((rect.end.x - origin.x) / cell_size)
	var y1 := ceili((rect.end.y - origin.y) / cell_size)
	return Rect2i(x0, y0, x1 - x0, y1 - y0).intersection(Rect2i(Vector2i.ZERO, size))


## Walks a Bresenham line from [param a] to [param b]. A blocked cell stops the
## walk (the blocked cell itself is still seen). With [param mark] the cells
## reached are set in view and explored. Returns true if [param b] was reached.
func _trace(a: Vector2i, b: Vector2i, max_sq: float, mark: bool) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while x != b.x or y != b.y:
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		var cell := Vector2i(x, y)
		if not _in_bounds(cell) or (cell - a).length_squared() > max_sq:
			return false
		var index := y * size.x + x
		if mark:
			in_view[index] = 1
			explored[index] = 1
		if _blocked[index] == 1 and cell != b:
			return false
	return true
