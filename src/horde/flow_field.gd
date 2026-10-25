class_name FlowField
extends RefCounted
## One shared flow field over the map grid (design/game-brief.md MVP feature 3):
## every cell stores the path cost to the cheapest goal and a unit vector that
## points downhill toward it. A zombie reads its cell instead of pathfinding.
## Pure data, no nodes. [method compute] only touches this instance's own arrays,
## so it can run on a worker thread while another instance is being read.
##
## Usage: var field := FlowField.new(origin, size, 1.0); field.block_rect(rect, 0.3);
## field.compute(goal_cells, goal_costs); var heading := field.direction_at(position).

const NEIGHBOR_DX: PackedInt32Array = [1, -1, 0, 0, 1, 1, -1, -1]
const NEIGHBOR_DY: PackedInt32Array = [0, 0, 1, -1, 1, -1, 1, -1]
## Neighbours with an index below this are orthogonal, the rest diagonal.
const FIRST_DIAGONAL: int = 4
## Cost of a diagonal step relative to an orthogonal one: sqrt(2).
const DIAGONAL_FACTOR: float = 1.41421356
## A neighbour must be cheaper than the cell by more than this to be followed.
const COST_EPSILON: float = 0.0001

## World (x, z) of the grid's minimum corner.
var origin: Vector2
## Grid size in cells.
var size: Vector2i
## Cell edge in metres.
var cell_size: float
## Path cost in metres to the cheapest goal; INF where unreachable.
var cost: PackedFloat32Array = PackedFloat32Array()
## Unit step toward the cheapest goal per cell; zero at goals and unreachable cells.
var direction: PackedVector2Array = PackedVector2Array()
## 1 per cell a zombie cannot enter.
var blocked: PackedByteArray = PackedByteArray()

var _inv_cell: float
var _queue: PackedInt32Array = PackedInt32Array()
var _queued: PackedByteArray = PackedByteArray()


func _init(p_origin: Vector2, p_size: Vector2i, p_cell_size: float) -> void:
	origin = p_origin
	size = p_size
	cell_size = p_cell_size
	_inv_cell = 1.0 / p_cell_size
	var cells := size.x * size.y
	cost.resize(cells)
	direction.resize(cells)
	blocked.resize(cells)
	_queue.resize(cells)
	_queued.resize(cells)


## Marks the cells touched by [param rect] (world x, z) grown by [param margin] as blocked.
func block_rect(rect: Rect2, margin: float) -> void:
	var grown := rect.grow(margin)
	var x0 := maxi(floori((grown.position.x - origin.x) * _inv_cell), 0)
	var y0 := maxi(floori((grown.position.y - origin.y) * _inv_cell), 0)
	var x1 := mini(ceili((grown.end.x - origin.x) * _inv_cell), size.x)
	var y1 := mini(ceili((grown.end.y - origin.y) * _inv_cell), size.y)
	for y in range(y0, y1):
		for x in range(x0, x1):
			blocked[y * size.x + x] = 1


## Copies the blocked cells of [param other] (same grid size) so two fields can
## be built from one set of obstacles.
func copy_blocked_from(other: FlowField) -> void:
	blocked = other.blocked.duplicate()


## Index of the cell containing world position [param p], clamped onto the grid.
func cell_index(p: Vector2) -> int:
	var x := clampi(floori((p.x - origin.x) * _inv_cell), 0, size.x - 1)
	var y := clampi(floori((p.y - origin.y) * _inv_cell), 0, size.y - 1)
	return y * size.x + x


## True if [param p] (world x, z) is off the grid or inside a blocked cell.
func is_blocked(p: Vector2) -> bool:
	var x := floori((p.x - origin.x) * _inv_cell)
	var y := floori((p.y - origin.y) * _inv_cell)
	return x < 0 or y < 0 or x >= size.x or y >= size.y or blocked[y * size.x + x] == 1


## Unit vector toward the cheapest goal at world position [param p]; zero at a
## goal, where no goal is reachable, or off the grid.
func direction_at(p: Vector2) -> Vector2:
	var x := floori((p.x - origin.x) * _inv_cell)
	var y := floori((p.y - origin.y) * _inv_cell)
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return Vector2.ZERO
	return direction[y * size.x + x]


## Rebuilds the field from goals: [param goal_cells] are cell indices and
## [param goal_costs] the starting cost of each (a handicap: a goal with a
## higher start cost wins from fewer places). Uses a label-correcting queue over
## 8 neighbours with no corner cutting. A goal cell may itself be blocked.
@warning_ignore("integer_division")
func compute(goal_cells: PackedInt32Array, goal_costs: PackedFloat32Array) -> void:
	var w := size.x
	var h := size.y
	var cells := w * h
	cost.fill(INF)
	_queued.fill(0)
	var head := 0
	var tail := 0
	var pending := 0
	for g in goal_cells.size():
		var goal := goal_cells[g]
		if goal_costs[g] < cost[goal]:
			cost[goal] = goal_costs[g]
			if _queued[goal] == 0:
				_queued[goal] = 1
				_queue[tail] = goal
				tail = tail + 1 if tail + 1 < cells else 0
				pending += 1
	var diagonal := cell_size * DIAGONAL_FACTOR
	while pending > 0:
		var index := _queue[head]
		head = head + 1 if head + 1 < cells else 0
		pending -= 1
		_queued[index] = 0
		var x := index % w
		var y := index / w
		var here := cost[index]
		for k in 8:
			var nx := x + NEIGHBOR_DX[k]
			var ny := y + NEIGHBOR_DY[k]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var neighbor := ny * w + nx
			if blocked[neighbor] == 1:
				continue
			var step := cell_size
			if k >= FIRST_DIAGONAL:
				if blocked[y * w + nx] == 1 or blocked[ny * w + x] == 1:
					continue
				step = diagonal
			var candidate := here + step
			if candidate < cost[neighbor]:
				cost[neighbor] = candidate
				if _queued[neighbor] == 0:
					_queued[neighbor] = 1
					_queue[tail] = neighbor
					tail = tail + 1 if tail + 1 < cells else 0
					pending += 1
	_compute_directions()


@warning_ignore("integer_division")
func _compute_directions() -> void:
	var w := size.x
	var h := size.y
	for index in w * h:
		var here := cost[index]
		if blocked[index] == 1 or here == INF:
			direction[index] = Vector2.ZERO
			continue
		var x := index % w
		var y := index / w
		var best := here
		var step := Vector2.ZERO
		for k in 8:
			var nx := x + NEIGHBOR_DX[k]
			var ny := y + NEIGHBOR_DY[k]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var neighbor := ny * w + nx
			if blocked[neighbor] == 1:
				continue
			if k >= FIRST_DIAGONAL and (blocked[y * w + nx] == 1 or blocked[ny * w + x] == 1):
				continue
			if cost[neighbor] < best - COST_EPSILON:
				best = cost[neighbor]
				step = Vector2(NEIGHBOR_DX[k], NEIGHBOR_DY[k])
		direction[index] = step.normalized()
