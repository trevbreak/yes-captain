class_name Mission
extends RefCounted
## A mission is a list of steps. Each step has the captain's goal text, a short hint for each station,
## a check that completes it, and an optional setup that runs when the step starts.
## Each mission switches on the mechanics (`features`) taught so far, plus at most one new one.

var id: String = ""
var num: int = 0
var title: String = ""
var place: String = ""
var features: Dictionary = {}
var new_thing: Dictionary = {}      # {title, who: [stations], text}
var story: String = ""              # IGOR's opening, read aloud in the briefing
var narrator: String = "igor"
var par: float = 180.0
var steps: Array = []
var step: int = 0
var step_t: float = 0.0
var t: float = 0.0
var done: bool = false
var failed: bool = false
var reason: String = ""
var counters: Dictionary = {}
var w: World = null

const BASE_FEATURES: Dictionary = {"damage": true}

func add(text: String, hints: Dictionary, check: Callable, enter: Callable = Callable(), goal: Callable = Callable()) -> void:
	steps.append({"text": text, "hints": hints, "check": check, "enter": enter, "goal": goal})

func setup(world: World) -> void:
	w = world
	var f: Dictionary = BASE_FEATURES.duplicate()
	f.merge(features, true)
	world.features = f
	world.mission = self
	build()
	_enter(0)

func build() -> void:
	pass

func extra(_dt: float) -> void:
	pass

func _enter(i: int) -> void:
	step_t = 0.0
	if i < steps.size():
		var e: Callable = steps[i].enter
		if e.is_valid():
			e.call()
		w.emit("step", {"n": i, "text": steps[i].text})

func tick(_world: World, dt: float) -> void:
	t += dt
	step_t += dt
	if done or failed:
		return
	_rings()
	if w.ship.hull <= 0.0:
		fail("The ship fell apart.")
		return
	extra(dt)
	if failed or done or step >= steps.size():
		return
	var st: Dictionary = steps[step]
	if bool(st.check.call()):
		w.emit("step_done", {"n": step, "text": st.text})
		step += 1
		if step >= steps.size():
			done = true
			w.emit("mission_done")
		else:
			_enter(step)

func fail(why: String) -> void:
	if failed or done:
		return
	failed = true
	reason = why
	w.emit("mission_failed", {"reason": why})

func on_event(type: String, d: Dictionary) -> void:
	counters[type] = int(counters.get(type, 0)) + 1
	if type == "ent_destroyed":
		var k: String = "killed_" + str(d.get("kind", ""))
		counters[k] = int(counters.get(k, 0)) + 1
		if str(d.get("tag", "")) != "":
			counters["killed_tag_" + str(d.tag)] = int(counters.get("killed_tag_" + str(d.tag), 0)) + 1

func count(k: String) -> int:
	return int(counters.get(k, 0))

# ---------------------------------------------------------------- helpers for mission scripts

func ring(p: Vector2, tag: String, col: String = "red") -> Dictionary:
	return w.spawn("ring", p, {"tag": tag, "scanned": true, "note": col})

func _rings() -> void:
	for e in w.ents:
		if e.alive and e.kind == "ring" and e.note != "done" and e.pos.distance_to(w.ship.pos) < e.r + 12.0:
			e.note = "done"
			w.add_fx("star", e.pos)
			w.emit("ring", {"tag": e.tag})

func passed(tag: String) -> bool:
	for e in w.ents:
		if e.kind == "ring" and e.tag == tag:
			return e.note == "done"
	return false

func tagged(tag: String) -> Dictionary:
	for e in w.ents:
		if e.alive and e.tag == tag:
			return e
	return {}

func pos_of(tag: String) -> Variant:
	var e: Dictionary = tagged(tag)
	return null if e.is_empty() else e.pos

func ahead(dist: float, side: float = 0.0) -> Vector2:
	## a point `dist` ahead of the ship, swung `side` radians to starboard
	return w.ship.pos + Vector2.from_angle(w.ship.heading + side) * dist

func around(dist: float) -> Vector2:
	return w.ship.pos + Vector2.from_angle(w.rng.randf() * TAU) * dist

func throw_junk(kind: String = "junk", speed: float = 95.0, dist: float = 430.0, rel: float = 999.0) -> void:
	var a: float = w.ship.heading + (rel if rel < 99.0 else w.rng.randf_range(-PI, PI))
	var p: Vector2 = w.ship.pos + Vector2.from_angle(a) * dist
	var e: Dictionary = w.spawn(kind, p, {"ai": "thrown", "tag": "thrown", "scanned": true})
	e.vel = (w.ship.pos + w.ship.vel * (dist / speed) - p).normalized() * speed

func all_scanned(kind_list: Array) -> bool:
	for e in w.ents:
		if e.alive and e.kind in kind_list and not e.scanned:
			return false
	return true

func none_left(kind: String, tag: String = "") -> bool:
	return w.alive(kind, tag).is_empty()

func cur() -> Dictionary:
	return steps[mini(step, steps.size() - 1)] if not steps.is_empty() else {}

func hint(station: String) -> String:
	if done:
		return "Done! Well flown."
	var h: Dictionary = cur().get("hints", {})
	return str(h.get(station, h.get("*", "Nothing for you right now. Listen to the captain, and be ready.")))

func goal_pos() -> Variant:
	var g: Callable = cur().get("goal", Callable())
	if g.is_valid():
		return g.call()
	return null

func step_list() -> Array:
	var out: Array = []
	for i in steps.size():
		out.append({"text": steps[i].text, "done": i < step or done, "now": i == step and not done})
	return out

func stars() -> int:
	if not done:
		return 0
	var s: int = 1
	if w.ship.hull >= 60.0:
		s += 1
	if t <= par:
		s += 1
	return s

func briefing() -> Dictionary:
	var plan: Array = []
	for st in steps:
		plan.append(st.text)
	return {"id": id, "num": num, "title": title, "place": place, "story": story, "narrator": narrator, "plan": plan,
		"new": new_thing, "par": par}
