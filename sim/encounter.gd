class_name Encounter
extends RefCounted
## Base class for one "hole": a 2-6 minute challenge with a brief, a goal, a par time and a way to fail loudly.

var w: World
var id: String = "enc"
var title: String = "Encounter"
var family: String = "Precision"
var brief: String = ""
var objective_text: String = ""
var done: bool = false
var success: bool = false
var fail_reason: String = ""
var t: float = 0.0
var par: float = 180.0
var spoils: Dictionary = {"scrap": 25, "fuel": 0, "snacks": 0, "beacons": 0}
var temper_delta: int = 0
var goal: Vector2 = Vector2.ZERO
var prog: float = 0.0
var intro_hail: Array = []   # [from, text]
var dock_request: bool = false  # set when a pit stop dock completes

func setup(world: World) -> void:
	w = world
	_setup()

func _setup() -> void:
	pass

func tick(dt: float) -> void:
	if done:
		return
	t += dt
	_tick(dt)
	if not done and w.ship.hull <= 0.0:
		finish(false, "The ship was destroyed.")

func _tick(_dt: float) -> void:
	pass

func finish(ok: bool, reason: String = "") -> void:
	if done:
		return
	done = true
	success = ok
	fail_reason = reason
	w.emit("encounter_done", {"ok": ok, "reason": reason})

func on_event(_type: String, _data: Dictionary) -> void:
	pass

func on_intent(_station: String, _key: String, _v: Variant) -> bool:
	return false

func captain_note() -> String:
	return brief

func captain_data() -> Dictionary:
	return {}

func station_data(_st: String) -> Dictionary:
	return {}

func hint() -> Dictionary:
	return {"goal": goal, "speed": 0.0}

# ---------------------------------------------------------------- helpers

func polar(center: Vector2, ang: float, dist: float) -> Vector2:
	return center + Vector2.from_angle(ang) * dist

func rand_ang(c: float = 0.0, spread: float = PI) -> float:
	return c + w.rng.randf_range(-spread, spread)

func place_goal(dist: float, spread: float = 0.5, radius: float = 28.0) -> Dictionary:
	var a: float = -PI / 2.0 + w.rng.randf_range(-spread, spread)
	goal = Vector2.from_angle(a) * dist
	return w.spawn("waypoint", goal, {"r": radius, "name": "Waypoint"})

func at_goal(radius: float = 28.0) -> bool:
	return w.ship.pos.distance_to(goal) < radius + w.ship.radius

func goal_hint(speed: float, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"goal": goal, "speed": speed, "arrive": 18.0}
	d.merge(extra, true)
	return d

func hostile_count() -> int:
	return w.hostiles().size()

func spawn_wave(kind: String, n: int, dist: float, center_ang: float = 0.0, spread: float = PI) -> void:
	for i in n:
		var a: float = center_ang + w.rng.randf_range(-spread, spread)
		w.spawn(kind, w.ship.pos + Vector2.from_angle(a) * (dist + w.rng.randf_range(0.0, 120.0)))
