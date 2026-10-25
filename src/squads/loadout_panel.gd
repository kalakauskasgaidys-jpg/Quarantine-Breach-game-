class_name LoadoutPanel
extends PanelContainer
## Pre-mission screen: pick each soldier's class and six gear slots with the
## mouse, see the resulting stats and shot noise, then deploy
## (design/game-brief.md MVP feature 2).

## Emitted by the Deploy button. [param loadouts] is one Array[SoldierLoadout] per squad.
signal deploy_requested(loadouts: Array)

## UI controls and current choice for one soldier.
class SoldierRow extends RefCounted:
	var loadout: SoldierLoadout
	var class_button: OptionButton
	var gear_buttons: Dictionary = {}
	var stats_label: Label

var _data: GameData
var _squads: Array = []


## Builds the rows for the squads listed in squad_greybox.json "default_squads".
func setup(data: GameData) -> void:
	_data = data
	var root := VBoxContainer.new()
	add_child(root)
	var title := Label.new()
	title.text = "Loadout - choose class and gear for each soldier, then deploy"
	root.add_child(title)
	var squad_classes: Array = data.config["default_squads"]
	for squad_index in squad_classes.size():
		var header := Label.new()
		header.text = "Squad %d" % (squad_index + 1)
		root.add_child(header)
		var rows: Array[SoldierRow] = []
		for class_id: String in squad_classes[squad_index]:
			rows.append(_add_row(root, class_id))
		_squads.append(rows)
	var deploy := Button.new()
	deploy.text = "Deploy"
	deploy.pressed.connect(_on_deploy_pressed)
	root.add_child(deploy)


func _add_row(parent: Control, class_id: String) -> SoldierRow:
	var row := SoldierRow.new()
	row.loadout = SoldierLoadout.default_for(class_id, _data)
	var box := VBoxContainer.new()
	var line := HBoxContainer.new()
	row.class_button = OptionButton.new()
	for id: String in _data.classes:
		row.class_button.add_item(_data.classes[id]["display_name"])
		row.class_button.set_item_metadata(row.class_button.item_count - 1, id)
	_select_by_id(row.class_button, class_id)
	row.class_button.item_selected.connect(_on_class_selected.bind(row))
	line.add_child(row.class_button)
	for slot in _data.slots:
		var button := OptionButton.new()
		button.tooltip_text = slot.replace("_", " ")
		button.add_item("- " + slot.replace("_", " "))
		button.set_item_metadata(0, "")
		for id in _data.gear_ids_for_slot(slot):
			button.add_item(_data.gear_items[id]["display_name"])
			button.set_item_metadata(button.item_count - 1, id)
		_select_by_id(button, row.loadout.gear[slot])
		button.item_selected.connect(_on_gear_selected.bind(row, slot))
		row.gear_buttons[slot] = button
		line.add_child(button)
	row.stats_label = Label.new()
	row.stats_label.add_theme_font_size_override("font_size", 12)
	box.add_child(line)
	box.add_child(row.stats_label)
	parent.add_child(box)
	_refresh_row(row)
	return row


func _on_class_selected(_index: int, row: SoldierRow) -> void:
	row.loadout = SoldierLoadout.default_for(_selected_id(row.class_button), _data)
	for slot: String in row.gear_buttons:
		_select_by_id(row.gear_buttons[slot], row.loadout.gear[slot])
	_refresh_row(row)


func _on_gear_selected(_index: int, row: SoldierRow, slot: String) -> void:
	row.loadout.gear[slot] = _selected_id(row.gear_buttons[slot])
	_refresh_row(row)


func _on_deploy_pressed() -> void:
	var result: Array = []
	for rows: Array in _squads:
		var squad_loadouts: Array[SoldierLoadout] = []
		for row: SoldierRow in rows:
			squad_loadouts.append(row.loadout)
		result.append(squad_loadouts)
	deploy_requested.emit(result)


func _refresh_row(row: SoldierRow) -> void:
	var stats := SoldierStats.build(row.loadout, _data)
	var weapon := "Unarmed"
	if stats.has_weapon:
		weapon = "%s dmg %.0f rng %.0f rate %.1fs noise %.0f" % [
				stats.weapon_name, stats.weapon_damage, stats.weapon_range,
				stats.fire_interval, stats.noise]
	row.stats_label.text = "HP %.0f  speed %.1f  sight %.0f  armor %.0f%%  |  %s" % [
			stats.max_health, stats.move_speed, stats.sight_range,
			stats.damage_reduction * 100.0, weapon]


func _selected_id(button: OptionButton) -> String:
	return button.get_item_metadata(button.selected)


func _select_by_id(button: OptionButton, id: String) -> void:
	for i in button.item_count:
		if button.get_item_metadata(i) == id:
			button.select(i)
			return
