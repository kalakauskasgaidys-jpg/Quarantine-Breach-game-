class_name GameData
extends RefCounted
## Loads and validates the squad data files (design/game-brief.md, MVP feature 2).
##
## Data boundary: every JSON file is checked here once, so the rest of the code
## can index the dictionaries without defensive checks.
## Usage: var data: GameData = GameData.load_all(); if data == null: ...

const CLASSES_PATH := "res://assets/data/soldier_classes.json"
const GEAR_PATH := "res://assets/data/gear.json"
const CONFIG_PATH := "res://assets/data/squad_greybox.json"

const NOISE_PATH := "res://assets/data/noise.json"
const HORDE_PATH := "res://assets/data/horde.json"
const DIFFICULTY_PATH := "res://assets/data/difficulty.json"
const TIME_OF_DAY_PATH := "res://assets/data/time_of_day.json"
const INFECTION_PATH := "res://assets/data/infection.json"
const MISSION_PATH := "res://assets/data/mission.json"

## Value shapes for the story 002 data files (see [method _check_schema]).
## INTEGER rules are written [Kind.INTEGER, minimum]: a whole number >= minimum.
enum Kind { NUMBER, POSITIVE, NON_NEGATIVE, STRING, COLOR, INTEGER, ARRAY }

const NOISE_SCHEMA := {
	"fade_time": Kind.POSITIVE,
	"movement": {
		"emit_interval": Kind.POSITIVE,
		"base_radius": Kind.NON_NEGATIVE,
		"armor_radius_per_reduction": Kind.NON_NEGATIVE,
	},
	"rings": {
		"segments": [Kind.INTEGER, 3],
		"color_quiet": Kind.COLOR,
		"color_loud": Kind.COLOR,
		"loud_radius": Kind.POSITIVE,
	},
}
const HORDE_SCHEMA := {
	"seed": [Kind.INTEGER, 0],
	"flow_cell_size": Kind.POSITIVE,
	"field_recompute_interval": Kind.POSITIVE,
	"obstacle_margin": Kind.NON_NEGATIVE,
	"zombie": {
		"hit_points": Kind.POSITIVE,
		"roam_speed": Kind.NON_NEGATIVE,
		"alert_speed": Kind.NON_NEGATIVE,
		"chase_speed": Kind.NON_NEGATIVE,
		"sight_range": Kind.POSITIVE,
		"contact_range": Kind.POSITIVE,
		"attack_damage": Kind.NON_NEGATIVE,
		"attack_interval": Kind.POSITIVE,
		"perception_interval": Kind.POSITIVE,
		"roam_turn_min": Kind.POSITIVE,
		"roam_turn_max": Kind.POSITIVE,
	},
	"separation": {
		"radius": Kind.POSITIVE,
		"strength": Kind.NON_NEGATIVE,
		"max_neighbors": [Kind.INTEGER, 1],
		"update_interval": Kind.POSITIVE,
	},
	"last_seen": {
		"pull_strength": Kind.POSITIVE,
		"lifetime": Kind.POSITIVE,
		"arrive_distance": Kind.POSITIVE,
	},
	"attractors": {
		"memory_seconds": Kind.POSITIVE,
		"merge_distance": Kind.NON_NEGATIVE,
		"max_count": [Kind.INTEGER, 1],
		"loudness_weight": Kind.NON_NEGATIVE,
	},
	"spawn": {
		"safe_radius": Kind.NON_NEGATIVE,
		"attempts": [Kind.INTEGER, 1],
	},
	"heat_map": {
		"cell_size": Kind.POSITIVE,
		"refresh_interval": Kind.POSITIVE,
		"full_density": Kind.POSITIVE,
		"color_low": Kind.COLOR,
		"color_high": Kind.COLOR,
	},
}
const INFECTION_SCHEMA := {
	"infection": {
		"delay_seconds": Kind.POSITIVE,
		"bite_chance": Kind.NON_NEGATIVE,
	},
	"countdown": {
		"color_start": Kind.COLOR,
		"color_urgent": Kind.COLOR,
		"height": Kind.NON_NEGATIVE,
		"font_size": [Kind.INTEGER, 1],
	},
	"treatment": {
		"medic_class": Kind.STRING,
		"medic_treat_time": Kind.POSITIVE,
		"medic_cooldown": Kind.NON_NEGATIVE,
		"medic_range": Kind.POSITIVE,
		"antidote_range": Kind.POSITIVE,
	},
	"debug": {
		"start_infected_count": [Kind.INTEGER, 0],
	},
}
const MISSION_SCHEMA := {
	"mission": {
		"time_limit_seconds": [Kind.INTEGER, 1],
	},
	"evac": {
		"position": Kind.ARRAY,
		"radius": Kind.POSITIVE,
		"color": Kind.COLOR,
	},
	"carry": {
		"slowdown": Kind.NON_NEGATIVE,
		"min_speed_multiplier": Kind.POSITIVE,
	},
	"loot": {
		"loot_time": Kind.NON_NEGATIVE,
		"loot_range": Kind.POSITIVE,
	},
	"caches": Kind.ARRAY,
	"civilians": {
		"count": [Kind.INTEGER, 0],
		"hit_points": Kind.POSITIVE,
		"walk_speed": Kind.POSITIVE,
		"follow_distance": Kind.NON_NEGATIVE,
		"repath_interval": Kind.POSITIVE,
		"color": Kind.COLOR,
		"unassigned_color": Kind.COLOR,
		"spots": Kind.ARRAY,
		"squad_assignment": Kind.ARRAY,
	},
}
const CACHE_SCHEMA := {
	"position": Kind.ARRAY,
	"weight": Kind.NON_NEGATIVE,
	"value": Kind.NON_NEGATIVE,
}
const PRESET_SCHEMA := {
	"display_name": Kind.STRING,
	"horde_size": [Kind.INTEGER, 0],
	"roaming_count": [Kind.INTEGER, 0],
}
const TIME_MODE_SCHEMA := {
	"display_name": Kind.STRING,
	"sight_range_multiplier": Kind.POSITIVE,
	"zombie_sight_multiplier": Kind.POSITIVE,
	"roaming_multiplier": Kind.NON_NEGATIVE,
	"ambient_color": Kind.COLOR,
	"ambient_energy": Kind.NON_NEGATIVE,
	"sun_energy": Kind.NON_NEGATIVE,
	"background_color": Kind.COLOR,
}
## Time-of-day modes every mission can use; the debug toggle switches between them.
const REQUIRED_TIME_MODES: Array[String] = ["day", "night"]

const CLASS_KEYS: Array[String] = [
	"display_name", "max_health", "carry_capacity", "move_speed", "sight_range",
	"damage_multiplier", "color", "default_gear",
]
const WEAPON_KEYS: Array[String] = ["damage", "range", "fire_interval", "noise"]
const CONFIG_KEYS: Array[String] = [
	"cell_size", "fog_update_interval", "fog_unexplored_color", "fog_explored_color",
	"retarget_interval", "formation_spacing", "target_dummy_health", "squad_colors",
	"default_squads", "drag_threshold_px", "pick_radius_px", "tracer_duration", "camera",
]

## Class id -> class definition (soldier_classes.json "classes").
var classes: Dictionary = {}
## Gear id -> gear definition (gear.json "items").
var gear_items: Dictionary = {}
## Gear slot ids in display order (gear.json "slots").
var slots: Array[String] = []
## Greybox tuning values (squad_greybox.json).
var config: Dictionary = {}
## Noise tuning (noise.json).
var noise: Dictionary = {}
## Horde and zombie tuning (horde.json).
var horde: Dictionary = {}
## Difficulty presets (difficulty.json): "default_preset" and "presets".
var difficulty: Dictionary = {}
## Time-of-day modes (time_of_day.json): "default_mode" and "modes".
var time_of_day: Dictionary = {}
## Infection and treatment tuning (infection.json).
var infection: Dictionary = {}
## Extraction mission tuning (mission.json): evac, carry, loot, caches, civilians.
var mission: Dictionary = {}


## Reads and validates all data files. Returns null (after push_error) if any is invalid.
static func load_all() -> GameData:
	var class_doc: Dictionary = _read_json(CLASSES_PATH)
	var gear_doc: Dictionary = _read_json(GEAR_PATH)
	var config_doc: Dictionary = _read_json(CONFIG_PATH)
	var noise_doc: Dictionary = _read_json(NOISE_PATH)
	var horde_doc: Dictionary = _read_json(HORDE_PATH)
	var difficulty_doc: Dictionary = _read_json(DIFFICULTY_PATH)
	var time_doc: Dictionary = _read_json(TIME_OF_DAY_PATH)
	var infection_doc: Dictionary = _read_json(INFECTION_PATH)
	var mission_doc: Dictionary = _read_json(MISSION_PATH)
	if class_doc.is_empty() or gear_doc.is_empty() or config_doc.is_empty() \
			or noise_doc.is_empty() or horde_doc.is_empty() or difficulty_doc.is_empty() or time_doc.is_empty() \
			or infection_doc.is_empty():
		return null
	var data := GameData.new()
	data.classes = class_doc.get("classes", {})
	data.gear_items = gear_doc.get("items", {})
	for slot: Variant in gear_doc.get("slots", []):
		data.slots.append(String(slot))
	data.config = config_doc
	data.noise = noise_doc
	data.horde = horde_doc
	data.difficulty = difficulty_doc
	data.time_of_day = time_doc
	data.infection = infection_doc
	data.mission = mission_doc
	if not data._validate():
		return null
	return data


## Converts a JSON [r, g, b] or [r, g, b, a] array to a Color.
static func color_from(values: Array) -> Color:
	var alpha: float = values[3] if values.size() > 3 else 1.0
	return Color(values[0], values[1], values[2], alpha)


## Gear ids that fit [param slot], sorted.
func gear_ids_for_slot(slot: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in gear_items:
		var item: Dictionary = gear_items[id]
		if item["slot"] == slot:
			ids.append(id)
	ids.sort()
	return ids


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("GameData: missing data file %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("GameData: %s is not a valid JSON object" % path)
		return {}
	return parsed


## Checks [param doc] against [param schema]: every key must exist with the right
## shape; nested dictionaries in the schema are checked recursively. Pushes one
## error per problem and returns false if there was any.
static func _check_schema(doc: Dictionary, schema: Dictionary, context: String) -> bool:
	var ok := true
	for key: String in schema:
		var where := "%s.%s" % [context, key]
		if not doc.has(key):
			push_error("GameData: %s missing key '%s'" % [context, key])
			ok = false
			continue
		var rule: Variant = schema[key]
		var value: Variant = doc[key]
		if rule is Dictionary:
			if not value is Dictionary:
				push_error("GameData: %s must be an object" % where)
				ok = false
			elif not _check_schema(value, rule, where):
				ok = false
		elif rule is Array:
			if not _check_integer(value, rule[1], where):
				ok = false
		elif not _check_value(value, rule, where):
			ok = false
	return ok


## True if [param value] is a whole number >= [param minimum] (JSON numbers parse as floats).
static func _check_integer(value: Variant, minimum: int, where: String) -> bool:
	var valid: bool = typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value) and value >= minimum
	if not valid:
		push_error("GameData: %s must be a whole number >= %d" % [where, minimum])
	return valid


static func _check_value(value: Variant, kind: int, where: String) -> bool:
	match kind:
		Kind.STRING:
			if value is String:
				return true
			push_error("GameData: %s must be a string" % where)
			return false
		Kind.ARRAY:
			if value is Array:
				return true
			push_error("GameData: %s must be an array" % where)
			return false
		Kind.COLOR:
			var valid: bool = value is Array and (value.size() == 3 or value.size() == 4)
			if valid:
				for channel: Variant in value:
					valid = valid and typeof(channel) == TYPE_FLOAT and channel >= 0.0 and channel <= 1.0
			if not valid:
				push_error("GameData: %s must be [r, g, b] or [r, g, b, a], each a number 0..1" % where)
			return valid
		_:
			var valid: bool = typeof(value) == TYPE_FLOAT and is_finite(value)
			if valid and kind == Kind.POSITIVE:
				valid = value > 0.0
			elif valid and kind == Kind.NON_NEGATIVE:
				valid = value >= 0.0
			if not valid:
				push_error("GameData: %s must be a %snumber" % [where, ["", "positive ", "non-negative "][clampi(kind, 0, 2)]])
			return valid


## Validates noise, horde, difficulty and time-of-day files (story 002).
func _validate_horde_files() -> bool:
	var ok := _check_schema(noise, NOISE_SCHEMA, NOISE_PATH)
	ok = _check_schema(horde, HORDE_SCHEMA, HORDE_PATH) and ok
	if horde.get("zombie") is Dictionary:
		var zombie: Dictionary = horde["zombie"]
		if zombie.has("roam_turn_min") and zombie.has("roam_turn_max") \
				and typeof(zombie["roam_turn_min"]) == TYPE_FLOAT and typeof(zombie["roam_turn_max"]) == TYPE_FLOAT \
				and zombie["roam_turn_min"] > zombie["roam_turn_max"]:
			push_error("GameData: %s zombie.roam_turn_min must not exceed roam_turn_max" % HORDE_PATH)
			ok = false
	ok = _check_catalog(difficulty, "default_preset", "presets", PRESET_SCHEMA, [], DIFFICULTY_PATH) and ok
	ok = _check_catalog(time_of_day, "default_mode", "modes", TIME_MODE_SCHEMA, REQUIRED_TIME_MODES, TIME_OF_DAY_PATH) and ok
	return ok


## Checks a file shaped { default_key: id, entries_key: { id: entry } }.
func _check_catalog(doc: Dictionary, default_key: String, entries_key: String, schema: Dictionary,
		required_ids: Array[String], path: String) -> bool:
	if not doc.get(default_key) is String or not doc.get(entries_key) is Dictionary:
		push_error("GameData: %s needs a string '%s' and an object '%s'" % [path, default_key, entries_key])
		return false
	var ok := true
	var entries: Dictionary = doc[entries_key]
	if not entries.has(doc[default_key]):
		push_error("GameData: %s %s '%s' is not in '%s'" % [path, default_key, doc[default_key], entries_key])
		ok = false
	for id in required_ids:
		if not entries.has(id):
			push_error("GameData: %s '%s' needs an entry '%s'" % [path, entries_key, id])
			ok = false
	for id: String in entries:
		if not entries[id] is Dictionary:
			push_error("GameData: %s %s.%s must be an object" % [path, entries_key, id])
			ok = false
		elif not _check_schema(entries[id], schema, "%s %s.%s" % [path, entries_key, id]):
			ok = false
	return ok


## Validates infection.json (story 003), including values that depend on other files.
func _validate_infection_file() -> bool:
	var ok := _check_schema(infection, INFECTION_SCHEMA, INFECTION_PATH)
	if not ok:
		return false
	if float(infection["infection"]["bite_chance"]) > 1.0:
		push_error("GameData: %s infection.bite_chance must be between 0 and 1" % INFECTION_PATH)
		ok = false
	if not classes.has(infection["treatment"]["medic_class"]):
		push_error("GameData: %s treatment.medic_class '%s' is not a class in %s" % [INFECTION_PATH, infection["treatment"]["medic_class"], CLASSES_PATH])
		ok = false
	return ok


## True if [param value] is an [x, z] pair of numbers.
static func _check_point(value: Variant, where: String) -> bool:
	var valid: bool = value is Array and value.size() == 2 and typeof(value[0]) == TYPE_FLOAT and typeof(value[1]) == TYPE_FLOAT
	if not valid:
		push_error("GameData: %s must be [x, z] numbers" % where)
	return valid


## Validates mission.json (story 004): shapes, point lists and cross-key limits.
func _validate_mission_file() -> bool:
	if not _check_schema(mission, MISSION_SCHEMA, MISSION_PATH):
		return false
	var ok := _check_point(mission["evac"]["position"], "%s evac.position" % MISSION_PATH)
	if float(mission["carry"]["min_speed_multiplier"]) > 1.0:
		push_error("GameData: %s carry.min_speed_multiplier must be at most 1" % MISSION_PATH)
		ok = false
	var caches: Array = mission["caches"]
	for i in caches.size():
		if not caches[i] is Dictionary:
			push_error("GameData: %s caches[%d] must be an object" % [MISSION_PATH, i])
			ok = false
			continue
		var where := "%s caches[%d]" % [MISSION_PATH, i]
		ok = _check_schema(caches[i], CACHE_SCHEMA, where) and ok
		if caches[i].has("position"):
			ok = _check_point(caches[i]["position"], where + ".position") and ok
	var civilian: Dictionary = mission["civilians"]
	var spots: Array = civilian["spots"]
	for i in spots.size():
		ok = _check_point(spots[i], "%s civilians.spots[%d]" % [MISSION_PATH, i]) and ok
	if civilian["count"] > spots.size():
		push_error("GameData: %s civilians.count (%d) exceeds the %d spots" % [MISSION_PATH, civilian["count"], spots.size()])
		ok = false
	var assignment: Array = civilian["squad_assignment"]
	if assignment.is_empty():
		push_error("GameData: %s civilians.squad_assignment must not be empty" % MISSION_PATH)
		ok = false
	for i in assignment.size():
		ok = _check_integer(assignment[i], 1, "%s civilians.squad_assignment[%d]" % [MISSION_PATH, i]) and ok
	return ok


func _validate() -> bool:
	var ok := _validate_horde_files()
	ok = _validate_mission_file() and ok
	if not classes.is_empty():
		ok = _validate_infection_file() and ok
	if slots.is_empty() or classes.is_empty() or gear_items.is_empty():
		push_error("GameData: slots, classes and items must not be empty")
		return false
	for key in CONFIG_KEYS:
		if not config.has(key):
			push_error("GameData: %s missing key '%s'" % [CONFIG_PATH, key])
			ok = false
	for id: String in gear_items:
		var item: Dictionary = gear_items[id]
		if not item.has("display_name") or not slots.has(item.get("slot", "")):
			push_error("GameData: gear '%s' needs display_name and a known slot" % id)
			ok = false
		if item.has("antidote_uses") and not _check_integer(item["antidote_uses"], 1, "%s item '%s'.antidote_uses" % [GEAR_PATH, id]):
			ok = false
		if item.has("damage"):
			for key in WEAPON_KEYS:
				if not item.has(key):
					push_error("GameData: weapon '%s' missing '%s'" % [id, key])
					ok = false
	for id: String in classes:
		var cls: Dictionary = classes[id]
		var class_ok := true
		for key in CLASS_KEYS:
			if not cls.has(key):
				push_error("GameData: class '%s' missing '%s'" % [id, key])
				class_ok = false
		if not class_ok:
			ok = false
			continue
		if not _check_value(cls["carry_capacity"], Kind.POSITIVE, "%s class '%s'.carry_capacity" % [CLASSES_PATH, id]):
			ok = false
		var defaults: Dictionary = cls["default_gear"]
		for slot in slots:
			var gear_id: String = defaults.get(slot, "")
			if gear_id != "" and (not gear_items.has(gear_id) or gear_items[gear_id]["slot"] != slot):
				push_error("GameData: class '%s' default gear '%s' invalid for slot '%s'" % [id, gear_id, slot])
				ok = false
	if config.has("default_squads"):
		for squad: Array in config["default_squads"]:
			for class_id: String in squad:
				if not classes.has(class_id):
					push_error("GameData: default_squads uses unknown class '%s'" % class_id)
					ok = false
	return ok
