class_name InfectionTracker
extends Node
## Owns the infection rules for a mission (design/game-brief.md MVP feature 4):
## gives each registered [Survivor] an [Infectable], turns it into a zombie in the
## [HordeManager] when its countdown ends, and keeps the loss counters the mission
## story (004) reads. Holds no input code.

## Emitted after a unit turned and was replaced by a zombie.
signal unit_turned(was_soldier: bool)

## Soldiers that turned (removed from their squad).
var soldiers_lost: int = 0
## Civilians that turned (lost for the mission result).
var civilians_lost: int = 0
## Every unit that turned.
var turned_count: int = 0
## Every living registered survivor.
var survivors: Array[Survivor] = []
## The treatment rules; call [method InfectionTreatment.try_treat].
var treatment: InfectionTreatment

var _config: Dictionary
var _horde: HordeManager
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Supplies the validated infection.json and the horde turned units join.
func setup(config: Dictionary, horde: HordeManager) -> void:
	_config = config
	_horde = horde
	treatment = InfectionTreatment.new()
	treatment.setup(config["treatment"], survivors)
	add_child(treatment)


## Makes [param survivor] infectable and tracks it. Call once per unit.
func register(survivor: Survivor) -> void:
	var component := Infectable.new()
	component.setup(survivor, _config, _rng)
	survivor.infectable = component
	survivor.add_child(component)
	component.turned.connect(_on_turned)
	survivors.append(survivor)
	survivor.tree_exiting.connect(func() -> void: survivors.erase(survivor))


## Number of registered survivors that are infected right now.
func infected_count() -> int:
	var total := 0
	for survivor in survivors:
		if survivor.is_infected():
			total += 1
	return total


func _on_turned(infectable: Infectable) -> void:
	var host := infectable.host
	var was_soldier := host is Soldier
	if was_soldier:
		soldiers_lost += 1
	else:
		civilians_lost += 1
	turned_count += 1
	var at := host.global_position
	host.remove_from_play()
	_horde.add_zombie(at)
	unit_turned.emit(was_soldier)
