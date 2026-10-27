class_name Squad
extends RefCounted
## A numbered group of soldiers that is selected and ordered together
## (design/game-brief.md MVP feature 2). No input or UI code.

## Emitted when the last soldier dies; the squad can no longer be controlled.
signal squad_wiped(squad: Squad)

var number: int = 0
## Living soldiers; dead ones remove themselves.
var soldiers: Array[Soldier] = []
## Metres between soldiers around an order point.
var formation_spacing: float = 1.0


## Offset of soldier [param index] of [param count] around a squad's order point.
static func formation_offset(index: int, count: int, spacing: float) -> Vector3:
	if count == 1:
		return Vector3.ZERO
	var angle := TAU * index / count
	return Vector3(cos(angle), 0.0, sin(angle)) * spacing


## Adds a soldier and starts tracking its death.
func add_soldier(soldier: Soldier) -> void:
	soldiers.append(soldier)
	soldier.died.connect(_on_soldier_died)


## Removes [param soldier] because it was extracted, not killed: the squad is not
## reported as wiped (story 004).
func extract_soldier(soldier: Soldier) -> void:
	soldiers.erase(soldier)
	soldier.died.disconnect(_on_soldier_died)


func is_wiped() -> bool:
	return soldiers.is_empty()


## Shows or hides the selection highlight on every soldier.
func set_selected(selected: bool) -> void:
	for soldier in soldiers:
		soldier.set_selected(selected)


## Orders every soldier to walk to [param point], spread in formation.
func order_move(point: Vector3) -> void:
	for i in soldiers.size():
		soldiers[i].order_move(point + formation_offset(i, soldiers.size(), formation_spacing))


func _on_soldier_died(soldier: Soldier) -> void:
	soldiers.erase(soldier)
	if soldiers.is_empty():
		squad_wiped.emit(self)
