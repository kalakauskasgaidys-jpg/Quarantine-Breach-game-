class_name Mission
extends Node3D
## The extraction mission rules (design/game-brief.md MVP feature 5): civilians hiding
## in buildings, supply caches to loot, an evac zone with a countdown, and the win /
## fail result. Holds no input code; [MissionControls] and [MissionHud] call its
## public methods.
##
## Rules:
## - A civilian shelters unseen until a soldier comes within discover_range, then
##   stands at the building's door, unassigned, until the player assigns it a squad.
## - [method call_evac] (once) cuts the countdown to evac_call_seconds if more remains.
## - Extraction removes every soldier and civilian inside the evac zone from the map.
##   It happens when the timer ends, and at once when ALL living soldiers stand in the
##   zone, whether or not the evac was called.
## - The mission ends on either of those, or when no living soldier is left.
## - It succeeds if at least one unit was extracted, otherwise it fails.
## - Units still on the map at the end, and civilians never found, are "left behind",
##   not "lost"; lost units were killed or turned into zombies.

## Emitted once when the mission ends, with the outcome as plain data.
signal mission_finished(result: MissionResult)
## Short message for the player (orders given, extractions, loot).
signal feedback(text: String)

## Discovered civilians still on the map, shared with the horde as extra survivors
## (read by reference; entries leave when a civilian dies, turns or is extracted).
var civilians: Array[Survivor] = []
## Shelters whose civilian has not been found yet.
var shelters: Array[CivilianShelter] = []
## Caches not looted yet.
var caches: Array[SupplyCache] = []
## The evac zone.
var evac: EvacZone
## Seconds left on the evac countdown.
var time_remaining: float = 0.0
## True from [method start] until the mission ends.
var is_running: bool = false
## True once the player called the evac.
var evac_called: bool = false

var _started: bool = false
var _data: Dictionary
var _tracker: InfectionTracker
var _squad_colors: Array
var _fog: FogOfWar
var _squads: Array[Squad] = []
var _elapsed: float = 0.0
var _result: MissionResult = MissionResult.new()
## Loot jobs: { "soldier": Soldier, "cache": SupplyCache, "serial": int, "remaining": float }.
var _loot_jobs: Array[Dictionary] = []
var _loot_time: float
var _loot_range_sq: float
var _evac_call_seconds: float
var _discover_range_sq: float


## Builds the evac zone, caches and shelters from the validated mission.json
## ([param data]). [param squad_colors] are the squad ring colours, [param time_limit]
## the countdown in seconds, [param building_rects] the building footprints (world
## x, z). Call once, after adding the node to the tree.
func setup(data: Dictionary, squad_colors: Array, time_limit: float, fog: FogOfWar, tracker: InfectionTracker,
		building_rects: Array[Rect2]) -> void:
	_data = data
	_squad_colors = squad_colors
	_fog = fog
	_tracker = tracker
	time_remaining = time_limit
	_evac_call_seconds = data["mission"]["evac_call_seconds"]
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
	_discover_range_sq = float(settings["discover_range"]) ** 2
	var entries: Array = settings["shelters"]
	for i in int(settings["count"]):
		var spot := Vector2(entries[i]["position"][0], entries[i]["position"][1])
		var area := Rect2(spot - Vector2.ONE, Vector2.ONE * 2.0)
		for rect in building_rects:
			if rect.has_point(spot):
				area = rect
		var shelter := CivilianShelter.new()
		shelter.setup(spot, Vector2(entries[i]["door"][0], entries[i]["door"][1]), area,
				GameData.color_from(settings["marker_color"]))
		add_child(shelter)
		shelters.append(shelter)


## Starts the countdown for the deployed [param squads]. Does nothing if called
## again. With no squads the mission ends as SQUAD_LOST.
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


## Calls the evac (the button / key): the countdown drops to evac_call_seconds if more
## remains, otherwise it is left as it is. Works once.
func call_evac() -> void:
	if not is_running:
		return
	if evac_called:
		feedback.emit("Evac already called")
		return
	evac_called = true
	time_remaining = minf(time_remaining, _evac_call_seconds)
	feedback.emit("Evac called: inbound in %d s" % ceili(time_remaining))


## Shows caches and shelter markers only once their surroundings were explored (call
## after a fog update).
func refresh_visibility() -> void:
	for shelter in shelters:
		shelter.visible = _fog.is_rect_explored(shelter.area)
	for cache in caches:
		cache.visible = _fog.is_rect_explored(Rect2(cache.position.x - 1.0, cache.position.z - 1.0, 2.0, 2.0))


func _physics_process(delta: float) -> void:
	if not is_running:
		return
	_elapsed += delta
	time_remaining -= delta
	_update_loot_jobs(delta)
	_discover_civilians()
	if time_remaining <= 0.0:
		time_remaining = 0.0
		_extract_zone()
		_finish(MissionResult.Reason.TIMER_EXPIRED)
		return
	_check_end()


## Replaces every shelter with a soldier in range by its civilian, standing at the door.
func _discover_civilians() -> void:
	for shelter in shelters.duplicate():
		if _soldier_in_range(shelter.global_position):
			shelters.erase(shelter)
			var civilian := Civilian.new()
			civilian.setup(_data["civilians"])
			civilian.position = shelter.door
			add_child(civilian)
			civilian.visible = _fog.is_visible_at(civilian.global_position)
			civilians.append(civilian)
			_tracker.register(civilian)
			civilian.tree_exiting.connect(_on_civilian_exiting.bind(civilian))
			shelter.queue_free()
			feedback.emit("Civilian found: select a squad and right-click it")


func _soldier_in_range(point: Vector3) -> bool:
	for squad in _squads:
		for soldier in squad.soldiers:
			var offset := soldier.global_position - point
			if offset.x * offset.x + offset.z * offset.z <= _discover_range_sq:
				return true
	return false


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


## Ends the mission when every living soldier and every civilian assigned to a squad
## is in the evac zone (then everyone in it is extracted) or when no living soldier
## is left. Unassigned civilians do not hold the extraction up.
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
	elif inside == living and _assigned_civilians_in_zone():
		_extract_zone()
		_finish(MissionResult.Reason.ALL_AT_EVAC)


func _assigned_civilians_in_zone() -> bool:
	for civilian in civilians:
		if civilian.health > 0.0 and (civilian as Civilian).squad != null and not evac.contains(civilian.global_position):
			return false
	return true


## Extracts every soldier and civilian inside the zone.
func _extract_zone() -> void:
	for squad in _squads:
		for soldier in squad.soldiers.duplicate():
			if evac.contains(soldier.global_position):
				squad.extract_soldier(soldier)
				_result.soldiers_extracted += 1
				_result.loot_weight += soldier.carried_weight
				_result.loot_value += soldier.carried_value
				_remove_from_map(soldier)
	for civilian in civilians.duplicate():
		if civilian.health > 0.0 and evac.contains(civilian.global_position):
			(civilian as Civilian).extracted = true
			civilians.erase(civilian)
			_result.civilians_extracted += 1
			_remove_from_map(civilian)


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
	# Civilians never found were left behind too.
	_result.civilians_left_behind = shelters.size()
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
