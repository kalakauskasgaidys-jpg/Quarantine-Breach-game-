class_name MissionHud
extends Control
## On-screen pieces of the extraction mission (story 004): the evac countdown, the
## carried-loot counter, the Extract button, a message line and the results panel.
## Reads [Mission]; the Extract button calls [method Mission.request_extract].

var _mission: Mission
var _timer_label: Label
var _loot_label: Label
var _message_label: Label
var _extract_button: Button
var _results_panel: PanelContainer
var _results_label: Label


## Builds the widgets for [param mission]. Call after adding the control to the HUD layer.
func setup(mission: Mission) -> void:
	_mission = mission
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_timer_label = _make_label(Vector2(0.0, 46.0))
	_timer_label.anchor_left = 1.0
	_timer_label.anchor_right = 1.0
	_timer_label.offset_left = -300.0
	_timer_label.offset_right = -10.0
	_timer_label.offset_top = 46.0
	_timer_label.offset_bottom = 86.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.add_theme_font_size_override("font_size", 28)
	_loot_label = _make_label(Vector2(8.0, 200.0))
	_message_label = _make_label(Vector2(8.0, 224.0))

	_extract_button = Button.new()
	_extract_button.text = "Extract (X)"
	_extract_button.focus_mode = Control.FOCUS_NONE
	_extract_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_extract_button.offset_left = -150.0
	_extract_button.offset_right = -10.0
	_extract_button.offset_top = 8.0
	_extract_button.offset_bottom = 40.0
	_extract_button.pressed.connect(mission.request_extract)
	add_child(_extract_button)

	_results_panel = PanelContainer.new()
	_results_panel.set_anchors_preset(Control.PRESET_CENTER)
	_results_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results_label = Label.new()
	_results_panel.add_child(_results_label)
	_results_panel.hide()
	add_child(_results_panel)

	mission.feedback.connect(func(text: String) -> void: _message_label.text = text)
	mission.mission_finished.connect(_on_mission_finished)
	_set_active(false)


func _process(_delta: float) -> void:
	if _mission == null:
		return
	if _mission.is_running:
		_set_active(true)
		var seconds := ceili(_mission.time_remaining)
		_timer_label.text = "EVAC  %d:%02d" % [seconds / 60, seconds % 60]
		var loot := _mission.carried_loot()
		_loot_label.text = "Loot carried: %.0f kg, value %.0f | caches left %d" % [loot.x, loot.y, _mission.caches.size()]


func _set_active(active: bool) -> void:
	_timer_label.visible = active
	_loot_label.visible = active
	_extract_button.visible = active


func _on_mission_finished(result: MissionResult) -> void:
	_set_active(false)
	_timer_label.visible = true
	_timer_label.text = "EVAC  closed"
	_extract_button.hide()
	_results_label.text = result.summary_text()
	_results_panel.show()


func _make_label(at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
