class_name Survivor
extends Node3D
## Base for every unit the horde can bite and infect: soldiers and civilians
## (design/game-brief.md MVP feature 4). Holds the hit points and the optional
## [Infectable] component; subclasses implement [method take_damage].

## Hit points left; the horde ignores survivors at zero or below.
var health: float = 0.0
## Infection state, attached by [method InfectionTracker.register]; null until then.
var infectable: Infectable


## Applies [param amount] damage. Subclasses override this.
func take_damage(_amount: float) -> void:
	pass


## True while the survivor is infected; false if it has no [Infectable] (never registered).
func is_infected() -> bool:
	return infectable != null and infectable.is_infected()


## A zombie bite: damages, then (if the survivor lived) may infect.
func receive_bite(amount: float) -> void:
	take_damage(amount)
	if health > 0.0 and infectable != null:
		infectable.on_bitten()


## Takes the survivor out of play because it turned into a zombie.
func remove_from_play() -> void:
	health = 0.0
	queue_free()
