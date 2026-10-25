class_name NoiseSystem
extends RefCounted
## Noise events (design/game-brief.md MVP feature 3): anything loud calls
## [method emit_noise] with a position and a radius in metres; the radius is the
## loudness. Events live for a short data-driven time so overlays can show them.
## The horde listens to [signal noise_emitted]. No input or rendering code.
##
## Usage: var noise := NoiseSystem.new(data.noise);
## noise.emit_noise(Vector3(4, 0, 2), 40.0); noise.advance(delta).

## Emitted for every noise, at once; sound reaches [param radius] metres instantly.
signal noise_emitted(position: Vector3, radius: float)

## One live noise, kept until it has faded.
class NoiseEvent:
	extends RefCounted
	var position: Vector3
	var radius: float
	## Seconds since it was emitted.
	var age: float = 0.0

## Live events, oldest first.
var events: Array[NoiseEvent] = []
## Seconds an event stays alive (noise.json "fade_time").
var fade_time: float

var _emit_interval: float
var _base_radius: float
var _armor_radius_per_reduction: float
var _footstep_timer: float = 0.0


## Reads [param config], the validated contents of noise.json.
func _init(config: Dictionary) -> void:
	fade_time = config["fade_time"]
	var movement: Dictionary = config["movement"]
	_emit_interval = movement["emit_interval"]
	_base_radius = movement["base_radius"]
	_armor_radius_per_reduction = movement["armor_radius_per_reduction"]


## Creates a noise heard up to [param radius] metres from [param position].
## Later systems (explosions, call-ins) use this directly; silent (<= 0) noise is ignored.
func emit_noise(position: Vector3, radius: float) -> void:
	if radius <= 0.0:
		return
	var event := NoiseEvent.new()
	event.position = position
	event.radius = radius
	events.append(event)
	noise_emitted.emit(position, radius)


## Metres a walking soldier with [param stats] is heard: base radius plus an
## extra for armor (heavier armor is louder).
func movement_radius(stats: SoldierStats) -> float:
	return _base_radius + _armor_radius_per_reduction * stats.damage_reduction


## Ages events and drops faded ones. Call once per frame.
func advance(delta: float) -> void:
	for event in events:
		event.age += delta
	while not events.is_empty() and events[0].age >= fade_time:
		events.pop_front()


## Every [code]movement.emit_interval[/code] seconds, makes a footstep noise at each
## soldier in [param soldiers] that is walking. Call once per frame.
func emit_movement_noise(soldiers: Array[Soldier], delta: float) -> void:
	_footstep_timer += delta
	if _footstep_timer < _emit_interval:
		return
	_footstep_timer = 0.0
	for soldier in soldiers:
		if soldier.is_moving():
			emit_noise(soldier.global_position, movement_radius(soldier.stats))
