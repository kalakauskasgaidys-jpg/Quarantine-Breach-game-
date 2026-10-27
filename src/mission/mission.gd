class_name Mission
extends Node3D
## The extraction mission rules (design/game-brief.md MVP feature 5): civilians that
## follow their squad, supply caches to loot, an evac zone with a countdown, and the
## win / fail result. Holds no input code; [MissionControls] and [MissionHud] call
## its public methods.
##
## Rules:
## - Extraction removes every soldier and civilian inside the evac zone from the map.
##   It happens on [method request_extract], automatically when ALL living soldiers
##   stand in the zone, and when the timer expires.
## - The mission ends on any of those, or when no living soldier is left.
## - It succeeds if at least one unit was extracted, otherwise it fails.
## - Units still on the map at the end are "left behind", not "lost"; lost units were
##   killed or turned into zombies.

## Emitted once when the mission ends, with the outcome as plain data.
signal mission_finished(result: MissionResult)
## Short message for the player (orders given, extractions, loot).
signal feedback(text: String)

## Civilians still on the map, shared with the horde as extra survivors (read by
## reference; entries leave when a civilian dies, turns or is extracted).
var civilians: Array[Survivor] = []
## Caches not looted yet.
var caches: Array[SupplyCache] = []
## The evac zone.
var evac: EvacZone
## Seconds left on the evac countdown.
var time_remaining: float = 0.0
## True from [method start] until the mission ends.
var is_running: bool = false

var _started: bool = false

var _data: Dictionary
var _squad_colors: Array
var _fog: FogOfWar
var _squads: Array[Squad] = []
var _elapsed: float = 0.0
var _result: MissionResult = MissionResult.new()
## Loot jobs: { "soldier": Soldier, "cache": SupplyCache, "serial": int, "remaining": float }.
var _loot_jobs: Array[Dictionary] = []
var _loot_time: float
var _loot_range_sq: float


## Builds the evac zone, caches and civilians from the validated mission.json
## ([param data]). [param squad_colors] are the squad ring colours, [param time_limit]
## the countdown in seconds. Call once, after adding the node to the tree.
func setup(data: Dictionary, squad_colors: Array, time_limit: float, fog: FogOfWar, tracker: InfectionTracker) -> void:
	_data = data
	_squad_colors = squad_colors
	_fog = fog
	time_remaining = time_limit
	_loot_time = data["loot"]["loot_time"]
	_loot_range_sq = float(data["loot"]["loot_range"]) ** 2

	var evac_data: Dictionary = data["evac"]
	evac = EvacZone.new()
	evac.setup(Vector2(evac_data["position"][0], evac_data["position"][1]), evac_data["radius"],
			GameData.color_from(evac_data["color"]))
	add_child(evac)

	for entry: Dictionary in data["caches"]:
		var cache := SupplyCache.new()
		cache.setup(Vector2(entry["position"][0], entry["position"][1]), entry["weight"], entry["value"])
		add_child(cache)
		caches.append(cache)

	var settings: Dictionary = data["civilians"]
	var spots: Array = settings["spots"]
	for i in int(settings["count"]):
		var civilian := Civilian.new()
		civilian.setup(settings)
		civilian.position = Vector3(spots[i][0], 0.0, spots[i][1])
		add_child(civilian)
		civilians.append(civilian)
		tracker.register(civilian)
		civilian.tree_exiting.connect(_on_civilian_exiting.bind(civilian))


## Starts the countdown for the deployed [param squads] and assigns every civilian
## to a squad from the data's squad_assignment list.
## Does nothing if called again. With no squads the mission ends as SQUAD_LOST.
func start(squads: Array[Squad]) -> void:
	if _started:
		return
	_started = true
	_squads = squads
	var carry: Dictionary = _data["carry"]
	for squad in squads:
		for soldier in squad.soldiers:
			soldier.carry_slowdown = carry["slowdown"]
			soldier.carry_min_multiplier = carry["min_speed_multiplier"]
			soldier.died.connect(_on_soldier_died)
	is_running = true
	if squads.is_empty():
		return
	var assignment: Array = _data["civilians"]["squad_assignment"]
	for i in civilians.size():
		var number := int(assignment[i % assignment.size()])
		var squad := squads[(number - 1) % squads.size()]
		(civilians[i] as Civilian).assign(squad, _squad_color(squad))


## Total weight (x) and value (y) of the loot all living soldiers carry right now.
func carried_loot() -> Vector2:
	var total := Vector2.ZERO
	for squad in _squads:
		for soldier in squad.soldiers:
			total += Vector2(soldier.carried_weight, soldier.carried_value)
	return total


## Orders the soldiers of [param squads] to walk to [param cache] and loot it; the
## first to finish standing there takes the loot.
func order_loot(squads: Array[Squad], cache: SupplyCache) -> void:
	if not is_running:
		return
	var able := _unwiped(squads)
	if able.is_empty():
		feedback.emit("Select a squad first to loot a cache")
		return
	for squad in able:
		for soldier in squad.soldiers:
			soldier.order_move(cache.global_position)
			_loot_jobs = _loot_jobs.filter(func(job: Dictionary) -> bool: return job["soldier"] != soldier)
			_loot_jobs.append({ "soldier": soldier, "cache": cache, "serial": soldier.order_serial, "remaining": _loot_time })
	feedback.emit("Looting: %.0f kg / %.0f value" % [cache.weight, cache.value])


## Assigns [param civilian] to the lowest-numbered of [param squads] (the selected ones).
func assign_civilian(civilian: Civilian, squads: Array[Squad]) -> void:
	if not is_running:
		return
	var chosen: Squad = null
	for squad in _unwiped(squads):
		if chosen == null or squad.number < chosen.number:
			chosen = squad
	if chosen == null:
		feedback.emit("Select a squad first to assign a civilian")
		return
	civilian.assign(chosen, _squad_color(chosen))
	var note := "" if squads.size() == 1 else " (several squads selected: lowest number used)"
	feedback.emit("Civilian assigned to squad %d%s" % [chosen.number, note])


## Extracts everyone inside the evac zone now (the Extract button / key). The
## mission ends if no living soldier remains on the map afterwards.
func request_extract() -> void:
	if not is_running:
		return
	var count := _extract_zone()
	feedback.emit("%d unit(s) extracted" % count if count > 0 else "Nobody is inside the evac zone")
	_check_end()


## Shows caches only once their surroundings were explored (call after a fog update).
func refresh_visibility() -> void:
	for cache in caches:
		cache.visible = _fog.is_rect_explored(Rect2(cache.position.x - 1.0, cache.position.z - 1.0, 2.0, 2.0))


func _physics_process(delta: float) -> void:
	if not is_running:
		return
	_elapsed += delta
	time_remaining -= delta
	_update_loot_jobs(delta)
	if time_remaining <= 0.0:
		time_remaining = 0.0
		_extract_zone()
		_finish(MissionResult.Reason.TIMER_EXPIRED)
		return
	_check_end()


func _update_loot_jobs(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for job in _loot_jobs:
		var soldier_ref: Variant = job["soldier"]
		var cache_ref: Variant = job["cache"]
		if not is_instance_valid(soldier_ref) or not is_instance_valid(cache_ref):
			continue
		var soldier := soldier_ref as Soldier
		var cache := cache_ref as SupplyCache
		# A cache leaves the list the moment it is looted (it is freed only at frame
		# end), so a second soldier finishing in the same frame gets nothing.
		if soldier.order_serial != job["serial"] or not caches.has(cache):
			continue
		var offset := cache.global_position - soldier.global_position
		if offset.x * offset.x + offset.z * offset.z <= _loot_range_sq:
			job["remaining"] -= delta
			if job["remaining"] <= 0.0:
				soldier.add_loot(cache.weight, cache.value)
				feedback.emit("Looted %.0f kg / %.0f value (carrying %.0f kg)" % [cache.weight, cache.value, soldier.carried_weight])
				caches.erase(cache)
				cache.queue_free()
				continue
		elif not soldier.is_moving():
			continue
		kept.append(job)
	_loot_jobs = kept


## Ends the mission when every living soldier is in the evac zone (then everyone in
## it is extracted) or when no living soldier is left.
func _check_end() -> void:
	if not is_running:
		return
	var living := 0
	var inside := 0
	for squad in _squads:
		for soldier in squad.soldiers:
			living += 1
			if evac.contains(soldier.global_position):
				inside += 1
	if living == 0:
		_finish(MissionResult.Reason.SQUAD_LOST)
	elif inside == living:
		_extract_zone()
		_finish(MissionResult.Reason.ALL_AT_EVAC)


## Extracts every soldier and civilian inside the zone; returns how many.
func _extract_zone() -> int:
	var count := 0
	for squad in _squads:
		for soldier in squad.soldiers.duplicate():
			if evac.contains(soldier.global_position):
				squad.extract_soldier(soldier)
				_result.soldiers_extracted += 1
				_result.loot_weight += soldier.carried_weight
				_result.loot_value += soldier.carried_value
				_remove_from_map(soldier)
				count += 1
	for civilian in civilians.duplicate():
		if civilian.health > 0.0 and evac.contains(civilian.global_position):
			(civilian as Civilian).extracted = true
			civilians.erase(civilian)
			_result.civilians_extracted += 1
			_remove_from_map(civilian)
			count += 1
	return count


## Takes an extracted unit out of play at once, so the horde and infection ignore it.
func _remove_from_map(unit: Survivor) -> void:
	unit.health = 0.0
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.hide()
	unit.queue_free()


func _finish(reason: MissionResult.Reason) -> void:
	is_running = false
	_loot_jobs.clear()
	_result.reason = reason
	_result.success = _result.soldiers_extracted + _result.civilians_extracted > 0
	_result.time_taken = _elapsed
	# Civilians that died or turned this frame are still listed (freed at frame end)
	# and their tree_exiting comes after the mission stopped counting: count them here.
	_result.civilians_left_behind = 0
	for civilian in civilians:
		if civilian.health > 0.0:
			_result.civilians_left_behind += 1
		else:
			_result.civilians_lost += 1
	_result.soldiers_left_behind = 0
	for squad in _squads:
		_result.soldiers_left_behind += squad.soldiers.size()
	mission_finished.emit(_result)


func _on_soldier_died(_soldier: Soldier) -> void:
	if is_running:
		_result.soldiers_lost += 1
		_check_end()


func _on_civilian_exiting(civilian: Civilian) -> void:
	civilians.erase(civilian)
	if is_running and not civilian.extracted:
		_result.civilians_lost += 1


## The squads of [param squads] that still have soldiers.
func _unwiped(squads: Array[Squad]) -> Array[Squad]:
	var able: Array[Squad] = []
	for squad in squads:
		if not squad.is_wiped():
			able.append(squad)
	return able


func _squad_color(squad: Squad) -> Color:
	return GameData.color_from(_squad_colors[(squad.number - 1) % _squad_colors.size()])
