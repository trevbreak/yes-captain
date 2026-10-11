class_name Director
extends RefCounted
## The Chaos Director: keeps the crew in the Overcooked sweet spot. It looks at how many problems
## are open, and either holds back (overloaded) or stirs things up (coasting).
## Hard rules: every failure telegraphs first, <=3 critical at once, every failure has an owner and a fix.

var w: World
var enabled: bool = true
var cooldown: float = 10.0
var timer: float = 0.0
var intensity: float = 1.0   # encounter can scale pacing
var overloaded: bool = false
var coasting: bool = false
var incidents_fired: int = 0
var quiet: bool = false      # encounter can silence it (e.g. docking)

func _init(world: World) -> void:
	w = world

func tick(dt: float) -> void:
	if not enabled or quiet:
		return
	timer += dt
	if timer < 0.5:
		return
	var step_dt: float = timer
	timer = 0.0
	cooldown -= step_dt
	var op: Dictionary = w.ship.open_problems()
	var critical: int = int(op["critical"])
	overloaded = critical >= 2 or w.ship.hit_flash > 0.2
	var busiest: int = 0
	for s in K.STATIONS:
		busiest = maxi(busiest, int(op["per"][s]))
	coasting = critical == 0
	if cooldown > 0.0:
		return
	if critical >= 3:
		cooldown = 6.0
		return
	if overloaded:
		cooldown = 5.0
		return
	fire_incident()
	var base: float = lerpf(34.0, 18.0, clampf(float(w.temper - 1) / 4.0, 0.0, 1.0))
	cooldown = (base if not coasting else base * 0.55) / maxf(0.3, intensity)

func fire_incident(kind: String = "") -> String:
	var s: Ship = w.ship
	var pool: Array = ["engine", "rcs", "conduit", "breach", "sensor", "turret", "reactor", "pudding", "coolant", "cargo", "fire"]
	if kind == "":
		kind = pool[w.rng.randi() % pool.size()]
		var tries: int = 0
		while not _viable(kind) and tries < 12:
			kind = pool[w.rng.randi() % pool.size()]
			tries += 1
		if not _viable(kind):
			return ""
	incidents_fired += 1
	match kind:
		"engine":
			var id: String = "ENG_P" if w.rng.randf() < 0.5 else "ENG_S"
			s.schedule_failure(id, "stuck_full" if w.rng.randf() < 0.35 else "", 4.0)
			w.emit("incident", {"kind": "engine", "id": id})
		"rcs":
			var ids: Array = ["RCS_FP", "RCS_FS", "RCS_AP", "RCS_AS"]
			var id2: String = ids[w.rng.randi() % ids.size()]
			s.schedule_failure(id2, "", 4.0)
			w.emit("incident", {"kind": "rcs", "id": id2})
		"conduit":
			var cids: Array = ["C_PORT", "C_STAR", "C_UTIL"]
			var cid: String = cids[w.rng.randi() % cids.size()]
			var mids: Array = []
			for mid in s.mod_order:
				if s.modules[mid].conduit == cid:
					mids.append(mid)
			var pick: String = mids[w.rng.randi() % mids.size()]
			s.schedule_failure(pick, "cut_conduit", 3.5)
			w.emit("incident", {"kind": "conduit", "id": cid})
		"breach":
			var ids2: Array = ["ENG_P", "ENG_S", "RCS_FP", "RCS_FS", "RCS_AP", "RCS_AS", "TUR_A", "TUR_B", "CARGO"]
			var id3: String = ids2[w.rng.randi() % ids2.size()]
			s.set_breach(id3)
			w.emit("incident", {"kind": "breach", "id": id3})
		"fire":
			var ids3: Array = s.mod_order.duplicate()
			var id4: String = ids3[w.rng.randi() % ids3.size()]
			s.set_fire(id4)
			w.emit("incident", {"kind": "fire", "id": id4})
		"sensor":
			s.schedule_failure("SENS", "mirror", 3.5)
			w.emit("incident", {"kind": "sensor", "id": "SENS"})
		"turret":
			var id5: String = "TUR_A" if w.rng.randf() < 0.5 else "TUR_B"
			s.schedule_failure(id5, "jam", 3.5)
			w.emit("incident", {"kind": "turret", "id": id5})
		"reactor":
			s.reactor_heat = minf(95.0, s.reactor_heat + 35.0)
			w.emit("incident", {"kind": "reactor", "id": "RCTR"})
		"pudding":
			s.pud["mood"] = minf(100.0, float(s.pud["mood"]) + 38.0)
			w.emit("incident", {"kind": "pudding", "id": "PEN"})
		"coolant":
			s.coolant_leak = true
			s.cool_p = maxf(0.0, s.cool_p - 40.0)
			w.emit("incident", {"kind": "coolant", "id": "COOL"})
		"cargo":
			s.schedule_failure("CARGO", "doors", 3.5)
			w.emit("incident", {"kind": "cargo", "id": "CARGO"})
	return kind

func _viable(kind: String) -> bool:
	var s: Ship = w.ship
	match kind:
		"engine":
			return s.mod_state("ENG_P") < 2 and s.mod_state("ENG_S") < 2
		"sensor":
			return s.mod_state("SENS") < 2
		"turret":
			return s.mod_state("TUR_A") < 2 and s.mod_state("TUR_B") < 2
		"pudding":
			return bool(s.pud["aboard"]) and not bool(s.pud["loose"])
		"coolant":
			return not s.coolant_leak
		"cargo":
			return s.cargo.size() > 0 and s.mod_state("CARGO") < 2
		"conduit":
			var cuts: int = 0
			for c in K.CONDUITS:
				if s.conduits[c].cut:
					cuts += 1
			return cuts == 0
		"fire":
			var f: int = 0
			for id in s.mod_order:
				if s.modules[id].fire > 0.0:
					f += 1
			return f == 0
	return true
