class_name BlackBox
extends RefCounted
## Records what happened, who did it, and turns the best disasters into a replay + awards.

var events: Array = []
var trail: Array = []
var frames: Array = []
var marks: Array = []
var t0: float = 0.0
var _acc: float = 0.0
var _facc: float = 0.0
var recent_modules_failed: Array = []
var counts: Dictionary = {}

func reset(start_t: float) -> void:
	events.clear()
	trail.clear()
	frames.clear()
	marks.clear()
	t0 = start_t
	_acc = 0.0
	_facc = 0.0
	recent_modules_failed.clear()
	counts.clear()

func log_event(t: float, who: String, text: String, kind: String = "info") -> void:
	events.append({"t": t - t0, "who": who, "text": text, "kind": kind})
	if events.size() > 400:
		events.pop_front()

func mark(w: World, text: String) -> void:
	marks.append({"t": w.t - t0, "x": w.ship.pos.x, "y": w.ship.pos.y, "text": text})

func record(w: World, dt: float) -> void:
	_acc += dt
	_facc += dt
	if _acc >= 0.5:
		_acc = 0.0
		trail.append([w.t - t0, w.ship.pos.x, w.ship.pos.y, w.ship.heading])
		if trail.size() > 1200:
			trail.pop_front()
	if _facc >= 0.5:
		_facc = 0.0
		var es: Array = []
		for e in w.ents:
			if e.kind in ["bullet", "ebullet", "debris", "waypoint"]:
				continue
			es.append([e.kind, e.pos.x, e.pos.y, e.r])
			if es.size() > 40:
				break
		frames.append({"t": w.t - t0, "s": [w.ship.pos.x, w.ship.pos.y, w.ship.heading], "e": es})
		if frames.size() > 900:
			frames.pop_front()

func blame(w: World, candidates: Array = ["helm", "engines"]) -> String:
	var best: String = ""
	var bt: float = -1.0
	for c in candidates:
		var li: Dictionary = w.last_input.get(c, {})
		var lt: float = float(li.get("t", -999.0))
		if w.t - lt < 5.0 and lt > bt:
			bt = lt
			best = c
	return best

func downsample(arr: Array, n: int) -> Array:
	if arr.size() <= n:
		return arr
	var out: Array = []
	var step: float = float(arr.size()) / float(n)
	for i in n:
		out.append(arr[int(i * step)])
	return out

func awards(w: World, bots_present: Array) -> Array:
	var out: Array = []
	var st: Dictionary = w.stats
	var inputs: Dictionary = st["inputs"]
	if float(st["spins"]) > 9.0:
		var who: String = blame(w, ["helm", "engines"])
		out.append({"title": "Most Confident Wrong Turn", "who": who if who != "" else "helm", "desc": "%.0f radians of spinning" % float(st["spins"])})
	if int(st["collisions"]) >= 1:
		var who2: String = counts.get("collide_blame", "helm")
		out.append({"title": "Insurance Fraud", "who": who2, "desc": "%d collisions, worst at %.0f m/s" % [int(st["collisions"]), float(st["max_collision"])]})
	if int(st["friendly_fire"]) >= 1:
		out.append({"title": "Friendly Fire Enthusiast", "who": "weapons", "desc": "%d things that were not the enemy" % int(st["friendly_fire"])})
	if int(st["fires_put_out"]) == 0 and int(counts.get("fires", 0)) > 0:
		out.append({"title": "Who Fixed The Fire?", "who": "", "desc": "Nobody. The fire fixed itself, eventually."})
	elif int(st["fires_put_out"]) >= 2:
		out.append({"title": "Fire Marshal", "who": "dc", "desc": "%d fires put out" % int(st["fires_put_out"])})
	var idle_who: String = ""
	var idle_v: float = 0.0
	for s in K.STATIONS:
		var iv: float = float(st["idle_max"][s])
		if iv > idle_v:
			idle_v = iv
			idle_who = s
	if idle_v > 45.0 and idle_who != "":
		out.append({"title": "Silent But Deadly", "who": idle_who, "desc": "%ds without touching a thing" % int(idle_v)})
	var busy_who: String = ""
	var busy_v: int = 0
	for s2 in K.STATIONS:
		if int(inputs[s2]) > busy_v:
			busy_v = int(inputs[s2])
			busy_who = s2
	if busy_v > 30:
		out.append({"title": "Busiest Bee", "who": busy_who, "desc": "%d inputs. Take a nap." % busy_v})
	if int(st["near_miss"]) >= 3:
		out.append({"title": "Close Shave", "who": "helm", "desc": "%d near misses" % int(st["near_miss"])})
	if int(st["kills"]) >= 3:
		out.append({"title": "Drone Whisperer", "who": "weapons", "desc": "%d enemies discouraged" % int(st["kills"])})
	if int(st["misjump"]) > 0:
		out.append({"title": "Navigator of the Year", "who": "helm", "desc": "Went somewhere else entirely"})
	if int(st["orders"]) >= 6:
		out.append({"title": "Captain Who Said \"Left\" The Most", "who": "captain", "desc": "%d orders shouted" % int(st["orders"])})
	if float(w.ship.pud["mood"]) < 25.0:
		out.append({"title": "Pudding Whisperer", "who": "ops", "desc": "Pudding is perfectly calm"})
	if out.is_empty():
		out.append({"title": "Participation Trophy", "who": "", "desc": "You were here. IGOR checked."})
	return out.slice(0, 5)
