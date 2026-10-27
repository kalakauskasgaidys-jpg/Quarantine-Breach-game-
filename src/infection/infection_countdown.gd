class_name InfectionCountdown
extends Label3D
## Billboard text over an infected unit showing the seconds left until it turns.
## The colour fades from "color_start" to "color_urgent" as the time runs out.

var _color_start: Color
var _color_urgent: Color


## Applies the "countdown" part of infection.json. Call before adding to the tree.
func setup(config: Dictionary) -> void:
	_color_start = GameData.color_from(config["color_start"])
	_color_urgent = GameData.color_from(config["color_urgent"])
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	pixel_size = 0.01
	font_size = int(config["font_size"])
	outline_size = 12
	position.y = config["height"]


## Shows [param remaining] of [param total] seconds; a "+" marks a treatment under way.
func show_remaining(remaining: float, total: float, being_treated: bool) -> void:
	text = "%.1f%s" % [remaining, " +" if being_treated else ""]
	modulate = _color_urgent.lerp(_color_start, clampf(remaining / total, 0.0, 1.0))
