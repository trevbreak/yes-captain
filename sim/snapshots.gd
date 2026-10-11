class_name Snapshots
extends RefCounted
## What each seat is allowed to know. This is the game: the captain sees the big picture, each crew
## member sees their own thing in detail, and nobody sees both.

const WEAPON_CONE: float = 0.42   # half-angle of what Weapons sees down the barrel
const WEAPON_RANGE: float = 560.0

static func _v(p: Vector2) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]

static func _kind(e: Dictionary) -> String:
	return str(e.kind) if e.scanned else "unknown"

static func _name(e: Dictionary) -> String:
	return str(e.name) if e.scanned else "Unknown contact"

static func common(w: World, station: String) -> Dictionary:
	var m: Mission = w.mission
	return {
		"t": snappedf(w.t, 0.1), "hull": snappedf(w.ship.hull, 0.1), "hull_max": w.ship.hull_max, "features": w.features,
		"mission": {"title": m.title if m else "", "num": m.num if m else 0, "time": snappedf(m.t if m else 0.0, 0.1),
			"par": m.par if m else 0.0, "step": m.step if m else 0, "steps": m.steps.size() if m else 0},
		"hint": m.hint(station) if m else "", "blackout": w.ship.blackout_t > 0.0,
	}

# ---------------------------------------------------------------- crew

static func helm(w: World) -> Dictionary:
	var s: Ship = w.ship
	var pull: float = 0.0
	if s.throttle > 0.05:
		if not s.ok("engine_p") and s.ok("engine_s"):
			pull = -1.0
		elif not s.ok("engine_s") and s.ok("engine_p"):
			pull = 1.0
	return {"heading": K.bearing_deg(s.heading), "heading_rad": s.heading, "wheel": s.wheel, "spin": snappedf(s.angvel, 0.01),
		"steer_ok": s.ok("bridge"), "pull": pull, "roll_cd": snappedf(s.roll_cd, 0.1), "rolling": s.roll_t > 0.0,
		"shaking": w.shake_t > 0.2}

static func engines(w: World) -> Dictionary:
	var s: Ship = w.ship
	return {"throttle": s.throttle, "speed": snappedf(s.speed(), 0.1), "max": Ship.MAX_SPEED * (1.65 if w.feat("boost") else 1.0),
		"port": str(s.sys.engine_p.state), "star": str(s.sys.engine_s.state), "heat": snappedf(s.engine_heat, 0.1), "boost": s.boost}

static func weapons(w: World) -> Dictionary:
	var s: Ship = w.ship
	var view: Array = []
	var ta: float = s.turret_world()
	for e in w.ents:
		if not e.alive or e.kind == "ring":
			continue
		var to: Vector2 = e.pos - s.pos
		var d: float = to.length()
		if d > WEAPON_RANGE:
			continue
		var rel: float = K.wrap_pi(to.angle() - ta)
		var half: float = asin(clampf(e.r / maxf(d, 1.0), 0.0, 1.0))
		if absf(rel) > WEAPON_CONE + half:
			continue
		view.append({"id": e.id, "rel": snappedf(rel, 0.001), "dist": snappedf(d, 0.1), "kind": _kind(e), "r": e.r,
			"latched": e.latched, "heading": snappedf(K.wrap_pi(float(e.heading) - ta), 0.01), "weak": e.weak_known,
			"hp": e.hp / maxf(1.0, e.hp_max)})
	var bullets: Array = []
	for sh in w.shots:
		var to2: Vector2 = sh.pos - s.pos
		var rel2: float = K.wrap_pi(to2.angle() - ta)
		if absf(rel2) < WEAPON_CONE and to2.length() < WEAPON_RANGE:
			bullets.append({"rel": snappedf(rel2, 0.001), "dist": snappedf(to2.length(), 0.1), "from": sh.from, "kind": sh.kind})
	return {"aim": s.aim, "firing": s.firing, "gun": str(s.sys.gun.state), "heat": snappedf(s.gun_heat, 0.1), "torp": s.torp,
		"torp_load": snappedf(s.torp_load, 0.01), "view": view, "bullets": bullets, "cone": WEAPON_CONE, "range": WEAPON_RANGE}

static func sensors(w: World) -> Dictionary:
	var s: Ship = w.ship
	var blips: Array = []
	var ok: bool = s.ok("sensors")
	for e in w.ents:
		if not e.alive or e.kind == "ring" or e.ai == "thrown":
			continue
		var to: Vector2 = (e.pos - s.pos).rotated(-s.heading - PI / 2.0)   # ship-up frame: nose is up
		if to.length() > World.RADAR_RANGE:
			continue
		blips.append({"id": e.id, "x": snappedf(to.x, 0.1), "y": snappedf(to.y, 0.1), "kind": _kind(e), "name": _name(e),
			"scanned": e.scanned, "hostile": e.hostile and e.scanned, "weak": e.weak_known, "dist": snappedf(to.length(), 0.1)})
	var comms: Dictionary = {}
	if w.feat("comms") and not w.hail.is_empty():
		comms = {"from": w.hail.from, "signal": snappedf(float(w.hail.get("signal", 0.0)), 0.01), "lock": snappedf(float(w.hail.lock_t), 0.01),
			"heard": w.hail.heard, "text": str(w.hail.text) if w.hail.heard else ""}
	return {"ok": ok, "range": World.RADAR_RANGE, "blips": blips if ok else [], "selected": w.scan_target, "scanning": w.scanning,
		"prog": snappedf(w.scan_prog, 0.01), "freq": w.comms_freq, "comms": comms}

static func shields(w: World) -> Dictionary:
	var s: Ship = w.ship
	var tr: Dictionary = {}
	if w.feat("tractor"):
		var best: Dictionary = {}
		var bd: float = 99999.0
		for e in w.ents:
			if e.alive and e.tractor:
				var d: float = e.pos.distance_to(s.pos)
				if d < bd:
					bd = d
					best = e
		tr = {"on": s.tractor_on, "ok": s.ok("tractor"), "range": World.TRACTOR_RANGE,
			"nearest": str(best.get("name", "")), "dist": snappedf(bd, 1.0) if not best.is_empty() else -1.0, "pulling": s.tractor_target >= 0}
	var pud: Dictionary = {}
	if w.feat("pudding"):
		pud = {"mood": snappedf(s.pud_mood, 0.1), "out": s.pud_out, "snacks": s.snacks, "tin": snappedf(s.tin_prog, 0.01), "petting": s.petting}
	var hits: Array = []
	for f in w.fx:
		if f.kind in ["block", "hit"] and w.t - float(f.t) < 0.8:
			var rel: float = K.wrap_pi((Vector2(f.x, f.y) - s.pos).angle() - s.heading)
			hits.append({"rel": snappedf(rel, 0.01), "blocked": f.kind == "block", "age": snappedf(w.t - float(f.t), 0.01)})
	var stuck: Array = []
	for e in w.ents:
		if e.alive and e.latched:
			stuck.append(snappedf(float(e.rel), 0.01))
	return {"dir": s.shield_dir, "ok": s.ok("shield"), "hits": hits, "tractor": tr, "pudding": pud, "stuck": stuck}

static func engineer(w: World) -> Dictionary:
	var s: Ship = w.ship
	var systems: Dictionary = {}
	for id in Ship.SYSTEMS:
		systems[id] = {"state": str(s.sys[id].state), "hp": snappedf(float(s.sys[id].hp), 0.1)}
	var stuck: Array = []
	for e in w.ents:
		if e.alive and e.latched:
			stuck.append(s.side_system(float(e.rel)))
	var pw: Dictionary = {}
	if w.feat("power"):
		pw = {"bars": s.power, "draw": snappedf(s.draw, 0.01), "cap": Ship.POWER_CAP, "overload": snappedf(s.overload, 0.1),
			"blackout": snappedf(s.blackout_t, 0.1)}
	return {"systems": systems, "selected": s.repair_target, "repairing": s.repairing, "prog": snappedf(s.repair_prog, 0.01),
		"power": pw, "pudding_room": s.pud_room if (w.feat("pudding") and s.pud_out) else "", "stuck": stuck, "stuck_rel": _stuck(w)}

# ---------------------------------------------------------------- the captain

static func captain(w: World) -> Dictionary:
	var s: Ship = w.ship
	var m: Mission = w.mission
	var ents: Array = []
	for e in w.ents:
		if not e.alive or e.ai == "thrown" and false:
			continue
		ents.append({"id": e.id, "kind": _kind(e) if e.kind != "ring" else "ring", "name": _name(e), "pos": _v(e.pos),
			"heading": snappedf(float(e.heading), 0.01), "hostile": e.hostile and e.scanned, "note": e.note, "tag": e.tag,
			"charge": snappedf(float(e.charge), 0.01), "latched": e.latched, "weak": e.weak_known, "r": e.r,
			"thrown": e.ai == "thrown", "hp": snappedf(e.hp / maxf(1.0, e.hp_max), 0.01)})
	var shots: Array = []
	for sh in w.shots:
		shots.append({"pos": _v(sh.pos), "from": sh.from, "kind": sh.kind, "dir": snappedf(sh.vel.angle(), 0.01)})
	var systems: Dictionary = {}
	for id in Ship.SYSTEMS:
		systems[id] = {"state": str(s.sys[id].state), "hp": snappedf(float(s.sys[id].hp), 0.1)}
	var gp: Variant = m.goal_pos() if m != null else null
	return {
		"ship": {"pos": _v(s.pos), "heading": snappedf(s.heading, 0.001), "vel": _v(s.vel), "speed": snappedf(s.speed(), 0.1),
			"shield": s.shield_dir, "shield_ok": s.ok("shield"), "aim": s.aim, "tractor": s.tractor_target, "rolling": s.roll_t > 0.0},
		"ents": ents, "shots": shots, "fx": w.fx.duplicate(), "_t": w.t, "_feat_tractor": w.feat("tractor"),
		"goal": _v(gp) if gp != null else [],
		"steps": m.step_list() if m != null else [],
		"board": {"systems": systems, "engine_heat": snappedf(s.engine_heat, 0.1), "gun_heat": snappedf(s.gun_heat, 0.1),
			"overload": snappedf(s.overload, 0.1), "draw": snappedf(s.draw, 0.01), "cap": Ship.POWER_CAP, "blackout": s.blackout_t > 0.0,
			"pud_mood": snappedf(s.pud_mood, 0.1), "pud_out": s.pud_out, "pud_room": s.pud_room, "torp": s.torp,
			"stuck": _stuck(w)},
		"crew": crew_lines(w),
		"warnings": forecasts(w),
	}

static func _stuck(w: World) -> Array:
	var out: Array = []
	for e in w.ents:
		if e.alive and e.latched:
			out.append(snappedf(float(e.rel), 0.01))
	return out

static func _turn_words(v: float) -> String:
	if absf(v) < 0.08:
		return "Wheel centred: flying straight"
	var side: String = "left" if v < 0.0 else "right"
	if absf(v) > 0.8:
		return "Turning HARD %s" % side
	if absf(v) > 0.4:
		return "Turning %s" % side
	return "Turning gently %s" % side

static func crew_lines(w: World) -> Dictionary:
	## one live line per crew member, plus an alert level (0 fine, 1 heads-up, 2 trouble)
	var s: Ship = w.ship
	var out: Dictionary = {}
	var hl: String = "%s · heading %03d°" % [_turn_words(s.wheel), K.bearing_deg(s.heading)]
	var ha: int = 0
	if not s.ok("bridge"):
		hl = "Steering BROKEN (turns slowly)"
		ha = 2
	elif s.throttle > 0.05 and s.engines_working() == 1:
		hl += " · ship is pulling %s" % ("left" if not s.ok("engine_p") else "right")
		ha = 1
	out["helm"] = {"text": hl, "alert": ha}
	var el: String = "Throttle %d%% · %d m/s" % [int(round(s.throttle * 100.0)), int(s.speed())]
	var ea: int = 0
	if s.boost and w.feat("boost"):
		el += " · BOOSTING"
		ea = 1
	if w.feat("heat") and s.engine_heat > 60.0:
		el += " · engines %d%% hot" % int(s.engine_heat)
		ea = 2 if s.engine_heat > 80.0 else 1
	if s.engines_working() < 2:
		el += " · %s engine%s down" % ["one" if s.engines_working() == 1 else "both", "" if s.engines_working() == 1 else "s"]
		ea = 2
	out["engines"] = {"text": el, "alert": ea}
	var wl: String = "Turret at %d o'clock" % K.clock(s.aim)
	var wa: int = 0
	if s.firing:
		wl += " · FIRING"
	if not s.ok("gun"):
		wl = "Gun BROKEN"
		wa = 2
	elif w.feat("heat") and s.gun_heat > 60.0:
		wl += " · gun %d%% hot" % int(s.gun_heat)
		wa = 2 if s.gun_heat > 80.0 else 1
	if w.feat("torpedo") and s.torp != "empty":
		wl += " · torpedo %s" % ("READY" if s.torp == "ready" else "loading")
	out["weapons"] = {"text": wl, "alert": wa}
	var sl: String = "Idle"
	var sa: int = 0
	if w.scanning and w.scan_target >= 0:
		var e: Dictionary = w.ent(w.scan_target)
		sl = "Scanning %s · %d%%" % [_name(e) if not e.is_empty() else "?", int(w.scan_prog * 100.0)]
	var unknown: int = 0
	for e2 in w.ents:
		if e2.alive and not e2.scanned and e2.ai != "thrown":
			unknown += 1
	if unknown > 0 and not w.scanning:
		sl = "%d unknown contact%s to scan" % [unknown, "" if unknown == 1 else "s"]
		sa = 1
	if w.feat("comms") and not w.hail.is_empty():
		if w.hail.heard:
			sl = "Has a message from %s!" % w.hail.from
			sa = 1
		else:
			sl = "Tuning comms: signal %d%%" % int(float(w.hail.get("signal", 0.0)) * 100.0)
			sa = 1
	if not s.ok("sensors"):
		sl = "Sensors BROKEN (radar is blank)"
		sa = 2
	out["sensors"] = {"text": sl, "alert": sa}
	var shl: String = "Shield facing %d o'clock" % K.clock(s.shield_dir)
	var sha: int = 0
	if not s.ok("shield"):
		shl = "Shield BROKEN"
		sha = 2
	if s.tractor_on and w.feat("tractor"):
		shl += " · TRACTOR on"
	if w.feat("pudding"):
		if s.pud_out:
			shl += " · calling Pudding back" if s.tin else " · Pudding ESCAPED"
			sha = 2
		elif s.petting:
			shl += " · petting Pudding"
	out["shields"] = {"text": shl, "alert": sha}
	var gl: String = "Idle"
	var ga: int = 0
	if s.repair_target != "" and s.repairing:
		gl = "%s %s · %d%%" % ["Putting out fire in" if s.on_fire(s.repair_target) else "Fixing", Ship.SYS_NAME[s.repair_target],
			int(s.repair_prog * 100.0)]
	var broken: int = 0
	for id in Ship.SYSTEMS:
		if s.broken(id):
			broken += 1
	if broken > 0 and not s.repairing:
		gl = "%d thing%s broken" % [broken, "" if broken == 1 else "s"]
		ga = 2
	if w.feat("power"):
		gl += " · power %d/%d/%d" % [int(s.power.engines), int(s.power.weapons), int(s.power.shields)]
	out["engineer"] = {"text": gl, "alert": ga}
	return out

static func forecasts(w: World) -> Array:
	## the captain's cues: [{text, level, who}] most urgent first
	var s: Ship = w.ship
	var out: Array = []
	if s.blackout_t > 0.0:
		out.append({"text": "BLACKOUT! Power back in %ds" % int(ceil(s.blackout_t)), "level": 3, "who": "engineer"})
	var inc: Array = w.incoming()
	var worst: Dictionary = {}
	for i in inc:
		if not i.covered and (worst.is_empty() or i.eta < worst.eta):
			worst = i
	if not worst.is_empty():
		out.append({"text": "Incoming from %d o'clock! Shield is at %d" % [K.clock(worst.rel), K.clock(s.shield_dir)], "level": 3, "who": "shields"})
	for e in w.ents:
		if e.alive and float(e.charge) > 0.0 and e.ai in ["patrol", "cruiser"]:
			var rel: float = K.wrap_pi((e.pos - s.pos).angle() - s.heading)
			out.append({"text": "%s charging at %d o'clock!%s" % [_name(e), K.clock(rel), " ROLL!" if w.feat("roll") else ""], "level": 3,
				"who": "helm" if w.feat("roll") else "shields"})
	var oe: float = w.overload_eta()
	if oe >= 0.0 and oe < 10.0:
		out.append({"text": "Reactor overload in %ds! (drawing %.1f of %d)" % [int(ceil(oe)), s.draw, int(Ship.POWER_CAP)], "level": 3, "who": "engineer"})
	var he: float = w.engine_heat_eta()
	if he >= 0.0 and he < 10.0:
		out.append({"text": "Engines overheat in %ds" % int(ceil(he)), "level": 2 if he > 4.0 else 3, "who": "engines"})
	if w.feat("heat") and s.gun_heat > 72.0 and s.firing:
		out.append({"text": "Gun about to jam (%d%% hot)" % int(s.gun_heat), "level": 2, "who": "weapons"})
	for id in Ship.SYSTEMS:
		if s.on_fire(id):
			out.append({"text": "FIRE in the %s!" % Ship.SYS_NAME[id].to_lower(), "level": 3, "who": "engineer"})
	for id2 in Ship.SYSTEMS:
		if str(s.sys[id2].state) == "broken":
			out.append({"text": "%s is broken" % Ship.SYS_NAME[id2], "level": 2, "who": "engineer"})
	for rel in _stuck(w):
		out.append({"text": "Grabber stuck on us at %d o'clock" % K.clock(float(rel)), "level": 2, "who": "helm"})
	if w.feat("pudding"):
		if s.pud_out:
			out.append({"text": "Pudding escaped! Now in the %s" % Ship.SYS_NAME[s.pud_room].to_lower(), "level": 2, "who": "shields"})
		elif s.pud_mood < 30.0:
			out.append({"text": "Pudding is upset (%d%%)" % int(s.pud_mood), "level": 1, "who": "shields"})
	if s.hull < 35.0:
		out.append({"text": "Hull critical: %d%%" % int(s.hull), "level": 2, "who": ""})
	for e2 in w.ents:
		if e2.alive and e2.kind == "mine" and e2.scanned and e2.pos.distance_to(s.pos) < 170.0:
			var rel2: float = K.wrap_pi((e2.pos - s.pos).angle() - s.heading)
			out.append({"text": "Mine close at %d o'clock!" % K.clock(rel2), "level": 2, "who": "helm"})
	if w.feat("comms") and not w.hail.is_empty() and not w.hail.heard:
		out.append({"text": "Incoming hail: Sensors, tune in!", "level": 1, "who": "sensors"})
	var unknown: int = 0
	for e3 in w.ents:
		if e3.alive and not e3.scanned and e3.ai != "thrown":
			unknown += 1
	if unknown > 0:
		out.append({"text": "%d unknown contact%s" % [unknown, "" if unknown == 1 else "s"], "level": 1, "who": "sensors"})
	out.sort_custom(func(a, b): return int(a.level) > int(b.level))
	return out.slice(0, 6)
