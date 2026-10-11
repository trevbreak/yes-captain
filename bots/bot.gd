class_name Bot
extends RefCounted
## A robot crew member (one of IGOR's relatives). It "hears" the captain by reading the mission directly,
## and works the same controls a human would. Good enough to finish every mission; not flawless.

var station: String = ""
var think_t: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var spin_t: float = 0.0
var aim_jitter: float = 0.0

func _init(st: String) -> void:
	station = st
	rng.randomize()

func tick(w: World, dt: float) -> void:
	think_t -= dt
	if think_t > 0.0:
		return
	think_t = rng.randf_range(0.14, 0.2)
	match station:
		"helm":
			_helm(w)
		"engines":
			_engines(w)
		"weapons":
			_weapons(w)
		"sensors":
			_sensors(w)
		"shields":
			_shields(w)
		"engineer":
			_engineer(w)

## how fast a robot can drag a dial (radians per second), so it isn't superhuman
const DIAL_RATE: float = 2.6

func act(w: World, key: String, val: Variant) -> void:
	Intents.apply(w, station, key, val)

func dial(w: World, key: String, current: float, target: float) -> void:
	## move a dial towards target at human speed (we tick about every 0.17 s)
	var step: float = DIAL_RATE * 0.17
	var d: float = K.wrap_pi(target - current)
	act(w, key, K.wrap_pi(current + clampf(d, -step, step)))

# ---------------------------------------------------------------- helpers

static func goal(w: World) -> Variant:
	var m: Mission = w.mission
	if m == null:
		return null
	# special cases a captain would call out
	if m.id == "bigone" and m.step == 1:
		var cr: Dictionary = m.tagged("cruiser")
		if not cr.is_empty():
			return cr.pos - Vector2.from_angle(float(cr.heading)) * 230.0
	if m.id == "lesson" and m.step in [3, 4]:
		var best: Variant = null
		var bd: float = 1e9
		for e in w.ents:
			if e.alive and e.kind in ["target", "buoy"] and (m.step == 3 and not e.scanned or m.step == 4 and e.kind == "target"):
				var d: float = e.pos.distance_to(w.ship.pos)
				if d < bd:
					bd = d
					best = e.pos
		if best != null:
			return best
	var g: Variant = m.goal_pos()
	if g != null:
		return g
	for e2 in w.ents:
		if e2.alive and e2.hostile and e2.shootable and e2.kind != "mine":
			return e2.pos
	return null

static func ask(w: World) -> String:
	## the customs officer's current demand, once Sensors has heard it
	var m: Mission = w.mission
	if m == null or m.id != "customs" or not bool(w.hail.get("heard", false)):
		return ""
	var c: Variant = m.get("current")
	return str(c.get("test", "")) if c is Dictionary else ""

static func threats(w: World) -> Array:
	var out: Array = []
	for e in w.ents:
		if e.alive and e.hostile and e.shootable and e.kind not in ["mine", "patrol"]:
			out.append(e)
	return out

func _nearest(w: World, list: Array) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = 1e9
	for e in list:
		var d: float = e.pos.distance_to(w.ship.pos)
		if d < bd:
			bd = d
			best = e
	return best

# ---------------------------------------------------------------- stations

func _helm(w: World) -> void:
	var s: Ship = w.ship
	var m: Mission = w.mission
	# shake off grabbers by spinning
	var stuck: int = 0
	for e in w.ents:
		if e.alive and e.latched:
			stuck += 1
	if stuck > 0:
		spin_t += 0.2
	else:
		spin_t = 0.0
	if spin_t > 1.0:
		act(w, "wheel", 1.0)
		return
	if w.feat("roll") and s.roll_cd <= 0.0:
		for i in w.incoming():
			if not i.covered and i.eta < 0.7:
				act(w, "roll", true)
				break
	var want: float = s.heading
	var g: Variant = goal(w)
	if ask(w) == "heading90":
		want = 0.0
	elif g != null:
		var to: Vector2 = g - s.pos
		want = to.angle()
		# steer round obstacles in the way
		for e in w.ents:
			if not e.alive or not (e.kind in ["rock", "mine", "customs", "haven", "diner", "cruiser"]):
				continue
			if e.kind in ["customs", "haven", "diner"] and g.distance_to(e.pos) < 260.0:
				continue
			var oe: Vector2 = e.pos - s.pos
			var d: float = oe.length()
			if d > 260.0 or d > to.length():
				continue
			var off: float = K.wrap_pi(oe.angle() - want)
			var clear: float = atan2(e.r + 50.0, d)
			if absf(off) < clear:
				want = oe.angle() + (clear + 0.15) * (-1.0 if off > 0.0 else 1.0)
	var diff: float = K.wrap_pi(want - s.heading)
	var wheel: float = clampf(diff * 1.8 - s.angvel * 0.6, -1.0, 1.0)
	if absf(diff) < 0.03:
		wheel = 0.0
	act(w, "wheel", snappedf(wheel, 0.05))

func _engines(w: World) -> void:
	## a speed controller: throttle sets the speed the ship settles at
	var s: Ship = w.ship
	var m: Mission = w.mission
	var g: Variant = goal(w)
	var top: float = Ship.MAX_SPEED * maxf(0.5, float(s.engines_working()) / 2.0)
	var cruise: float = top * (0.7 if w.feat("heat") else 0.9)
	var want: float = cruise * 0.35
	var stop_at: float = -1.0   # metres from the goal to come to rest; -1 = fly through
	if m != null:
		match m.id:
			"lesson":
				if m.step == 2:
					stop_at = 1e6
				elif m.step == 4:
					cruise *= 0.35
			"binday":
				if m.step == 1:
					stop_at = 90.0
			"hot":
				if m.step == 4:
					stop_at = 110.0
			"customs":
				if m.step == 0:
					stop_at = 0.0
				elif m.step >= 1 and m.step <= 4:
					stop_at = 1e6
			"haven":
				if m.step == 2:
					stop_at = 120.0
	if g != null:
		var to: Vector2 = g - s.pos
		var d: float = to.length()
		var align: float = clampf(cos(K.wrap_pi(to.angle() - s.heading)) + 0.15, 0.1, 1.0)
		want = cruise * align * align
		if d < 220.0:
			want = minf(want, 12.0 + d * 0.2)
		if stop_at < 0.0:
			want = maxf(want, 8.0)
		if stop_at >= 0.0:
			want = minf(want, maxf(0.0, d - stop_at) * 0.3)
	elif stop_at >= 0.0:
		want = 0.0
	if stop_at >= 1e5:
		want = 0.0
	if w.feat("power") and s.overload > 35.0:
		want = minf(want, top * 0.45)
	var running: bool = (m != null and m.id == "pursuit") or not w.alive("patrol").is_empty()
	var hunting: bool = m != null and m.id == "bigone" and m.step == 1
	if not running and not hunting and not threats(w).is_empty() and stop_at < 0.0:
		want = minf(want, top * 0.45)
	act(w, "throttle", snappedf(clampf(want / top, 0.0, 1.0), 0.05))
	if w.feat("boost"):
		act(w, "boost", running and s.engine_heat < 45.0 and (not w.feat("power") or s.overload < 20.0))

func _weapons(w: World) -> void:
	var s: Ship = w.ship
	var m: Mission = w.mission
	var tgt: Dictionary = {}
	var latched: Array = []
	for e in w.ents:
		if e.alive and e.latched:
			latched.append(e)
	if not latched.is_empty():
		var l0: Dictionary = latched[0]
		dial(w, "aim", s.aim, float(l0.rel))
		act(w, "fire", s.gun_heat < 85.0)
		return
	if ask(w) == "gun_at":
		var cp: Variant = m.pos_of("customs")
		if cp != null:
			dial(w, "aim", s.aim, K.wrap_pi((cp - s.pos).angle() - s.heading))
		act(w, "fire", false)
		return
	var cands: Array = []
	for e2 in w.ents:
		if e2.alive and e2.shootable and e2.scanned and e2.hostile and e2.kind not in ["patrol"]:
			if e2.kind == "mine" and e2.pos.distance_to(s.pos) > 260.0:
				continue
			cands.append(e2)
		elif e2.alive and e2.ai == "thrown" and e2.kind == "rock":
			cands.append(e2)
	tgt = _nearest(w, cands)
	if tgt.is_empty():
		act(w, "fire", false)
		return
	var to: Vector2 = tgt.pos - s.pos
	var tt: float = to.length() / World.BULLET_SPEED
	var lead: Vector2 = tgt.pos + (tgt.vel - s.vel * 0.5) * tt
	var want: float = K.wrap_pi((lead - s.pos).angle() - s.heading)
	dial(w, "aim", s.aim, want)
	var ok_aim: bool = absf(K.wrap_pi(want - s.aim)) < 0.12
	var hot_ok: bool = (not w.feat("heat")) or s.gun_heat < 70.0 or (s.gun_heat < 88.0 and s.firing)
	if tgt.kind == "cruiser":
		# torpedoes for the big one, from behind
		if w.feat("torpedo"):
			if s.torp == "empty":
				act(w, "load", true)
			var back: Vector2 = -Vector2.from_angle(float(tgt.heading))
			var behind: bool = (s.pos - tgt.pos).normalized().dot(back) > 0.75
			if s.torp == "ready" and behind and ok_aim and to.length() < 380.0:
				act(w, "torpedo", true)
		act(w, "fire", false)
		return
	act(w, "fire", ok_aim and hot_ok and to.length() < 470.0)

func _sensors(w: World) -> void:
	var s: Ship = w.ship
	var m: Mission = w.mission
	if w.feat("comms") and not w.hail.is_empty() and not w.hail.heard:
		var f: float = move_toward(w.comms_freq, float(w.hail.freq), 0.04)
		act(w, "freq", f)
	# customs asks for a scan
	if ask(w) == "scan":
		var ce: Dictionary = m.tagged("customs")
		if not ce.is_empty():
			act(w, "select", int(ce.id))
			act(w, "scan", true)
			return
	var best: Dictionary = {}
	var bd: float = 1e9
	for e in w.ents:
		if not e.alive or e.ai == "thrown" or e.kind == "ring":
			continue
		var want: bool = not e.scanned or (e.kind == "cruiser" and w.feat("weakspot") and not e.weak_known)
		if not want:
			continue
		var d: float = e.pos.distance_to(s.pos)
		if d < World.RADAR_RANGE and d < bd:
			bd = d
			best = e
	if best.is_empty():
		act(w, "scan", false)
		return
	act(w, "select", int(best.id))
	act(w, "scan", true)

func _shields(w: World) -> void:
	var s: Ship = w.ship
	var m: Mission = w.mission
	var want: Variant = null
	if ask(w) == "shield_back":
		want = PI
	var soonest: float = 99.0
	for i in w.incoming():
		if i.eta < soonest:
			soonest = i.eta
			want = i.rel
	if want == null:
		for e in w.ents:
			if e.alive and e.latched:
				want = float(e.rel)
				break
	if want == null:
		for e2 in w.ents:
			if e2.alive and float(e2.charge) > 0.0:
				want = K.wrap_pi((e2.pos - s.pos).angle() - s.heading)
	if want == null:
		var th: Dictionary = _nearest(w, threats(w))
		if not th.is_empty():
			want = K.wrap_pi((th.pos - s.pos).angle() - s.heading)
	if want != null:
		dial(w, "dir", s.shield_dir, float(want))
	if w.feat("tractor"):
		var any: bool = false
		for e3 in w.ents:
			if e3.alive and e3.tractor and e3.pos.distance_to(s.pos) < World.TRACTOR_RANGE:
				any = true
		act(w, "tractor", any and (not w.feat("power") or s.overload < 40.0))
	if w.feat("pudding"):
		if s.pud_out:
			act(w, "tin", true)
			act(w, "pet", false)
		else:
			act(w, "tin", false)
			if s.pud_mood < 25.0 and s.snacks > 0:
				act(w, "snack", true)
			act(w, "pet", s.pud_mood < 70.0 and soonest > 2.5)

func _engineer(w: World) -> void:
	var s: Ship = w.ship
	var pick: String = ""
	var best: int = -1
	var prio: Dictionary = {"gun": 6, "shield": 6, "engine_p": 5, "engine_s": 5, "sensors": 5, "bridge": 4, "tractor": 3, "reactor": 4, "pen": 1}
	for id in Ship.SYSTEMS:
		var st: Dictionary = s.sys[id]
		var score: int = -1
		if str(st.state) == "fire":
			score = 20 + int(prio.get(id, 1))
		elif str(st.state) == "broken":
			score = 10 + int(prio.get(id, 1))
		elif float(st.hp) < 55.0:
			score = int(prio.get(id, 1))
		if score > best:
			best = score
			pick = id
	if pick != "":
		act(w, "select", pick)
		act(w, "repair", true)
	else:
		act(w, "repair", false)
	if w.feat("power"):
		var fighting: bool = not threats(w).is_empty()
		var e: int = 2
		var wp: int = 2
		var sh: int = 2
		if fighting:
			e = 1 if s.throttle < 0.5 else 2
			wp = 3
			sh = 2
		else:
			e = 3
			wp = 1
			sh = 2
		if s.overload > 30.0:
			e = maxi(1, e - 1)
			wp = maxi(1, wp - 1)
		for pair in [["engines", e], ["weapons", wp], ["shields", sh]]:
			if int(s.power[pair[0]]) != int(pair[1]):
				act(w, "power", {"group": pair[0], "bars": pair[1]})
