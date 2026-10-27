class_name InfectionTreatment
extends Node
## Stops infections (design/game-brief.md MVP feature 4). Any soldier with an
## antidote use left cures the nearest infected friendly in range instantly; a
## medic treats for a set time (no antidote needed; the patient's countdown pauses
## meanwhile) and then waits out a cooldown.
## Only the configured medic class has the treat ability. Holds no input code.

## Emitted with a short message for the player after every request and job end.
signal feedback(text: String)

## What a treat request did.
enum Result { NO_TARGET, NO_ABILITY, BUSY, ANTIDOTE_USED, TREATMENT_STARTED }

var _survivors: Array[Survivor]
var _medic_class: String
var _treat_time: float
var _cooldown_time: float
var _medic_range_sq: float
var _antidote_range_sq: float
## User instance id -> { "user": Soldier, "target": Survivor, "remaining": float }.
var _active: Dictionary = {}
## User instance id -> seconds of cooldown left.
var _cooldowns: Dictionary = {}


## Supplies the "treatment" part of infection.json and the shared array of every
## registered survivor (soldiers and civilians).
func setup(config: Dictionary, survivors: Array[Survivor]) -> void:
	_survivors = survivors
	_medic_class = config["medic_class"]
	_treat_time = config["medic_treat_time"]
	_cooldown_time = config["medic_cooldown"]
	_medic_range_sq = float(config["medic_range"]) ** 2
	_antidote_range_sq = float(config["antidote_range"]) ** 2


## Lets [param user] treat the nearest infected friendly in range: a medic starts a
## timed treatment, anyone else spends one antidote use.
func try_treat(user: Soldier) -> Result:
	var result := _try_treat(user)
	feedback.emit(_message(user, result))
	return result


func _try_treat(user: Soldier) -> Result:
	var is_medic := user.stats.class_id == _medic_class
	var id := user.get_instance_id()
	if is_medic:
		if _active.has(id):
			return Result.BUSY
		if _cooldowns.get(id, 0.0) > 0.0:
			return Result.NO_ABILITY
	elif user.antidote_uses <= 0:
		return Result.NO_ABILITY
	var target := _nearest_infected(user, _medic_range_sq if is_medic else _antidote_range_sq)
	if target == null:
		return Result.NO_TARGET
	if is_medic:
		target.infectable.being_treated = true
		_active[id] = { "user": user, "target": target, "remaining": _treat_time }
		return Result.TREATMENT_STARTED
	user.antidote_uses -= 1
	target.infectable.cure()
	return Result.ANTIDOTE_USED


func _process(delta: float) -> void:
	for id: int in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	for id: int in _active.keys():
		var job: Dictionary = _active[id]
		if not _job_valid(job):
			_end_job(id, false)
			continue
		job["remaining"] -= delta
		if job["remaining"] <= 0.0:
			(job["target"] as Survivor).infectable.cure()
			_end_job(id, true)


## A job holds while both units exist and live, the target is still infected and
## in range. Checks validity before any cast: either unit may have been freed.
func _job_valid(job: Dictionary) -> bool:
	var user_ref: Variant = job["user"]
	var target_ref: Variant = job["target"]
	if not is_instance_valid(user_ref) or not is_instance_valid(target_ref):
		return false
	var user := user_ref as Soldier
	var target := target_ref as Survivor
	return user.health > 0.0 and target.health > 0.0 and target.is_infected() 			and _flat_distance_sq(user, target) <= _medic_range_sq


## Removes job [param id]; a success starts the medic's cooldown, an interruption does not.
func _end_job(id: int, succeeded: bool) -> void:
	var target_ref: Variant = _active[id]["target"]
	_active.erase(id)
	if is_instance_valid(target_ref):
		(target_ref as Survivor).infectable.being_treated = false
	if succeeded:
		_cooldowns[id] = _cooldown_time
		feedback.emit("Treatment succeeded")
	else:
		feedback.emit("Treatment interrupted")


## Nearest infected survivor (the user included) within [param range_sq] that no
## medic is already treating, or null.
func _nearest_infected(user: Soldier, range_sq: float) -> Survivor:
	var best: Survivor = null
	var best_sq := range_sq
	for survivor in _survivors:
		if not survivor.is_infected() or survivor.infectable.being_treated:
			continue
		var distance_sq := _flat_distance_sq(user, survivor)
		if distance_sq <= best_sq:
			best = survivor
			best_sq = distance_sq
	return best


func _flat_distance_sq(a: Node3D, b: Node3D) -> float:
	var delta := a.global_position - b.global_position
	return delta.x * delta.x + delta.z * delta.z


func _message(user: Soldier, result: Result) -> String:
	match result:
		Result.NO_TARGET:
			return "No infected unit in range"
		Result.NO_ABILITY:
			if user.stats.class_id == _medic_class:
				return "Medic is recovering (cooldown %.0f s)" % _cooldowns.get(user.get_instance_id(), 0.0)
			return "No antidote left"
		Result.BUSY:
			return "Medic is already treating"
		Result.ANTIDOTE_USED:
			return "Antidote used (%d left)" % user.antidote_uses
		_:
			return "Treating..."
