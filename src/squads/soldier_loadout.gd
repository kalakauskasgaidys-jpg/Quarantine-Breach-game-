class_name SoldierLoadout
extends RefCounted
## One soldier's pre-mission choices: a class and one gear id (or "") per slot.
## Implements design/game-brief.md MVP feature 2 (classes and gear slots).

## Class id from soldier_classes.json.
var class_id: String = ""
## Slot id -> gear id; "" means the slot is empty.
var gear: Dictionary = {}


## Builds a loadout for [param p_class_id] filled with that class's default gear.
static func default_for(p_class_id: String, data: GameData) -> SoldierLoadout:
	var loadout := SoldierLoadout.new()
	loadout.class_id = p_class_id
	var defaults: Dictionary = data.classes[p_class_id]["default_gear"]
	for slot in data.slots:
		loadout.gear[slot] = defaults.get(slot, "")
	return loadout
