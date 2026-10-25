class_name SoldierStats
extends RefCounted
## Final soldier stats: class base stats combined with the equipped gear.
## Implements design/game-brief.md MVP feature 2. Pure data, no nodes, so it can
## be tested without a scene.
##
## Rules (all numbers come from the data files):
## - max_health = class max_health + sum of max_health_bonus
## - move_speed = class move_speed * product of move_speed_multiplier
## - sight_range = class sight_range + sum of sight_range_bonus
## - damage_reduction = sum of damage_reduction
## - The active weapon is the first equipped item (in slot order) that has a
##   fire_interval. Its damage = weapon damage * class damage_multiplier *
##   product of gear damage_multiplier; range and noise scale the same way.

var max_health: float = 0.0
var move_speed: float = 0.0
var sight_range: float = 0.0
## Fraction of incoming damage ignored.
var damage_reduction: float = 0.0
var has_weapon: bool = false
var weapon_name: String = ""
var weapon_damage: float = 0.0
var weapon_range: float = 0.0
var fire_interval: float = 0.0
## Noise radius in metres of one shot; story 002 reads this to draw the horde.
var noise: float = 0.0


## Computes stats for [param loadout] from the loaded data.
static func build(loadout: SoldierLoadout, data: GameData) -> SoldierStats:
	var cls: Dictionary = data.classes[loadout.class_id]
	var stats := SoldierStats.new()
	stats.max_health = cls["max_health"]
	stats.move_speed = cls["move_speed"]
	stats.sight_range = cls["sight_range"]
	var damage_mult: float = cls["damage_multiplier"]
	var range_mult := 1.0
	var noise_mult := 1.0
	var weapon: Dictionary = {}
	for slot in data.slots:
		var gear_id: String = loadout.gear.get(slot, "")
		if gear_id == "":
			continue
		var item: Dictionary = data.gear_items[gear_id]
		stats.max_health += item.get("max_health_bonus", 0.0)
		stats.move_speed *= item.get("move_speed_multiplier", 1.0)
		stats.sight_range += item.get("sight_range_bonus", 0.0)
		stats.damage_reduction += item.get("damage_reduction", 0.0)
		damage_mult *= item.get("damage_multiplier", 1.0)
		range_mult *= item.get("range_multiplier", 1.0)
		noise_mult *= item.get("noise_multiplier", 1.0)
		if weapon.is_empty() and item.has("fire_interval"):
			weapon = item
	if not weapon.is_empty():
		stats.has_weapon = true
		stats.weapon_name = weapon["display_name"]
		stats.weapon_damage = float(weapon["damage"]) * damage_mult
		stats.weapon_range = float(weapon["range"]) * range_mult
		stats.fire_interval = weapon["fire_interval"]
		stats.noise = float(weapon["noise"]) * noise_mult
	return stats
