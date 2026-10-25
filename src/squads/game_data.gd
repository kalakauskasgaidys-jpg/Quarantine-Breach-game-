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

const CLASS_KEYS: Array[String] = [
	"display_name", "max_health", "move_speed", "sight_range",
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


## Reads and validates all data files. Returns null (after push_error) if any is invalid.
static func load_all() -> GameData:
	var class_doc: Dictionary = _read_json(CLASSES_PATH)
	var gear_doc: Dictionary = _read_json(GEAR_PATH)
	var config_doc: Dictionary = _read_json(CONFIG_PATH)
	if class_doc.is_empty() or gear_doc.is_empty() or config_doc.is_empty():
		return null
	var data := GameData.new()
	data.classes = class_doc.get("classes", {})
	data.gear_items = gear_doc.get("items", {})
	for slot: Variant in gear_doc.get("slots", []):
		data.slots.append(String(slot))
	data.config = config_doc
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


func _validate() -> bool:
	var ok := true
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
