class_name Infectable
extends Node
## Infection state shared by every [Survivor] (design/game-brief.md MVP feature 4).
## Child of the unit it infects. A bite may infect it; an infected unit counts down
## and emits [signal turned] at zero unless [method cure] is called first.

## Emitted once when the countdown reaches zero.
signal turned(infectable: Infectable)
## Emitted when the unit becomes infected.
signal infected(infectable: Infectable)
## Emitted when an infection is stopped.
signal cured(infectable: Infectable)

## The unit this component belongs to.
var host: Survivor
## Seconds until the unit turns; meaningful while [method is_infected].
var remaining: float = 0.0
## True while a medic treats this unit: the countdown pauses and shows a "+".
var being_treated: bool = false

var _is_infected: bool = false
var _delay: float
var _bite_chance: float
var _rng: RandomNumberGenerator
var _countdown: InfectionCountdown
var _countdown_config: Dictionary


## Supplies the unit, the validated infection.json and a shared random generator.
## Call before adding the node to the tree.
func setup(p_host: Survivor, config: Dictionary, rng: RandomNumberGenerator) -> void:
	host = p_host
	_delay = config["infection"]["delay_seconds"]
	_bite_chance = config["infection"]["bite_chance"]
	_countdown_config = config["countdown"]
	_rng = rng


func _ready() -> void:
	set_process(false)


## True while the unit is infected and has not turned or been cured.
func is_infected() -> bool:
	return _is_infected


## Rolls the bite chance and infects on success. Does nothing if already infected.
func on_bitten() -> void:
	if _bite_chance >= 1.0 or _rng.randf() < _bite_chance:
		infect()


## Infects the unit and starts the countdown. No effect if already infected.
func infect() -> void:
	if _is_infected:
		return
	_is_infected = true
	remaining = _delay
	_countdown = InfectionCountdown.new()
	_countdown.setup(_countdown_config)
	host.add_child(_countdown)
	_refresh_countdown()
	set_process(true)
	infected.emit(self)


## Stops the infection and removes the countdown. No effect if not infected.
func cure() -> void:
	if not _is_infected:
		return
	_clear()
	cured.emit(self)


func _process(delta: float) -> void:
	# The countdown pauses while a medic treats the unit.
	if not being_treated:
		remaining -= delta
	if remaining <= 0.0:
		_clear()
		turned.emit(self)
		return
	_refresh_countdown()


func _refresh_countdown() -> void:
	_countdown.show_remaining(remaining, _delay, being_treated)


func _clear() -> void:
	_is_infected = false
	being_treated = false
	set_process(false)
	if is_instance_valid(_countdown):
		_countdown.queue_free()
	_countdown = null
