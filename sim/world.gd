class_name World
extends RefCounted
## The 2D simulation. Pure rules, no nodes. The mission switches mechanics on through `features`.

const RADAR_RANGE: float = 520.0
const SHIP_R: float = 20.0
const BULLET_SPEED: float = 340.0
const TRACTOR_RANGE: float = 150.0
const SCAN_TIME: float = 1.6

var t: float = 0.0
var ship: Ship = Ship.new()
var ents: Array = []
var shots: Array = []
var fx: Array = []                # short-lived visual events for renderers: {kind, pos, t}
var events: Array = []            # [type, data] drained by the host
var features: Dictionary = {}
var mission: Mission = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var next_id: int = 1
var stats: Dictionary = {}

# sensors
var scan_target: int = -1
var scanning: bool = false
var scan_prog: float = 0.0
# comms (mission 5+)
var comms_freq: float = 0.5
var freq_touched: bool = false
var hail: Dictionary = {}         # {from, text, freq, heard, lock_t, signal}
# grabber shake-off
var shake_t: float = 0.0
var bump_cd: float = 0.0
# glitches: the ship misbehaving (see Glitches)
var glitches: Array = []          # {id, sys, station, t, ask, fix, ...}
var radar_range: float = RADAR_RANGE
var next_ghost: int = 900001

func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	reset_stats()

func reset_stats() -> void:
	stats = {"shots": 0, "hits": 0, "blocked": 0, "hits_taken": 0, "repairs": 0, "scans": 0, "fires": 0, "breaks": 0, "dodges": 0,
		"friendly_fire": 0, "overloads": 0, "escapes": 0}

func clear() -> void:
	ents.clear()
	shots.clear()
	fx.clear()
	events.clear()
	scan_target = -1
	scanning = false
	scan_prog = 0.0
	hail = {}
	shake_t = 0.0
	glitches.clear()

func feat(f: String) -> bool:
	return bool(features.get(f, false))

func emit(type: String, d: Dictionary = {}) -> void:
	events.append([type, d])

func add_fx(kind: String, p: Vector2, extra: Dictionary = {}) -> void:
	var d: Dictionary = {"kind": kind, "x": p.x, "y": p.y, "t": t}
	d.merge(extra, true)
	fx.append(d)

# ---------------------------------------------------------------- entities

const KIND_INFO: Dictionary = {
	"ring": {"r": 34.0, "name": "Ring", "shootable": false},
	"buoy": {"r": 18.0, "name": "Buoy", "shootable": true, "hp": 10.0},
	"target": {"r": 22.0, "name": "Practice target", "shootable": true, "hp": 10.0, "hostile": true},
	"junk": {"r": 14.0, "name": "Junk", "shootable": true, "hp": 5.0},
	"skip": {"r": 30.0, "name": "A skip", "shootable": false, "tractor": true},
	"drone": {"r": 20.0, "name": "Hegemony drone", "shootable": true, "hp": 30.0, "hostile": true},
	"grabber": {"r": 20.0, "name": "Grabber drone", "shootable": true, "hp": 30.0, "hostile": true},
	"mine": {"r": 16.0, "name": "Mine", "shootable": true, "hp": 5.0, "hostile": true},
	"cruiser": {"r": 70.0, "name": "Hegemony cruiser", "shootable": true, "hp": 100.0, "hostile": true},
	"patrol": {"r": 30.0, "name": "Hegemony patrol", "shootable": true, "hp": 9999.0, "hostile": true},
	"customs": {"r": 70.0, "name": "Customs post", "shootable": false},
	"haven": {"r": 70.0, "name": "Haven", "shootable": false},
	"diner": {"r": 70.0, "name": "Ma Gristle's Diner", "shootable": false},
	"rock": {"r": 26.0, "name": "Space rock", "shootable": true, "hp": 20.0},
	"pod": {"r": 14.0, "name": "Cargo pod", "shootable": false, "tractor": true},
}

func spawn(kind: String, p: Vector2, opts: Dictionary = {}) -> Dictionary:
	var info: Dictionary = KIND_INFO.get(kind, {})
	var e: Dictionary = {
		"id": next_id, "kind": kind, "pos": p, "vel": Vector2.ZERO, "heading": -PI / 2.0, "r": float(info.get("r", 20.0)),
		"hp": float(info.get("hp", 10.0)), "hp_max": float(info.get("hp", 10.0)), "name": str(info.get("name", kind)),
		"hostile": bool(info.get("hostile", false)), "shootable": bool(info.get("shootable", false)),
		"tractor": bool(info.get("tractor", false)), "scanned": false, "alive": true, "ai": "none", "cd": rng.randf_range(2.0, 4.0),
		"latched": false, "rel": 0.0, "stun": 0.0, "charge": 0.0, "tag": "", "weak_known": false, "note": "",
	}
	e.merge(opts, true)
	next_id += 1
	ents.append(e)
	return e

func ent(id: int) -> Dictionary:
	for e in ents:
		if int(e.id) == id:
			return e
	return {}

func alive(kind: String = "", tag: String = "") -> Array:
	var out: Array = []
	for e in ents:
		if e.alive and (kind == "" or e.kind == kind) and (tag == "" or e.tag == tag):
			out.append(e)
	return out

func kill(e: Dictionary, why: String = "destroyed") -> void:
	if not e.alive:
		return
	e.alive = false
	add_fx("puff", e.pos, {"size": e.r})
	emit("ent_" + why, {"id": e.id, "kind": e.kind, "name": e.name, "tag": e.tag})

func shoot_at_ship(from: Vector2, speed: float = 130.0, dmg: float = 10.0, kind: String = "blob", spread: float = 0.0) -> void:
	var dir: Vector2 = (ship.pos - from).normalized().rotated(spread)
	shots.append({"pos": from, "vel": dir * speed, "from": "them", "dmg": dmg, "life": 9.0, "kind": kind})

# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	t += dt
	_ship_physics(dt)
	_heat(dt)
	_weapons(dt)
	_shots(dt)
	_ai(dt)
	_tractor(dt)
	_scan(dt)
	_comms(dt)
	_pudding(dt)
	_fires(dt)
	_repairs(dt)
	_power(dt)
	_bumps(dt)
	_glitch_tick(dt)
	ents = ents.filter(func(e): return e.alive or false)
	fx = fx.filter(func(f): return t - float(f.t) < 1.5)
	if mission != null:
		mission.tick(self, dt)

func _ship_physics(dt: float) -> void:
	var s: Ship = ship
	s.roll_t = maxf(0.0, s.roll_t - dt)
	s.roll_cd = maxf(0.0, s.roll_cd - dt)
	if s.blackout_t > 0.0:
		s.blackout_t = maxf(0.0, s.blackout_t - dt)
		if s.blackout_t <= 0.0:
			emit("power_back")
	# the ship turns tighter when it's slow: Helm needs Engines to ease off for a sharp corner
	var nimble: float = lerpf(1.3, 0.72, clampf(s.speed() / Ship.MAX_SPEED, 0.0, 1.0))
	var steer: float = s.wheel * Ship.TURN_RATE * nimble * (1.0 if s.ok("bridge") else 0.35)
	# one engine down: the other one shoves us round (Cosmoteer-style)
	var pull: float = 0.0
	if s.throttle > 0.05 and s.blackout_t <= 0.0:
		if not s.ok("engine_p") and s.ok("engine_s"):
			pull = -0.5 * s.throttle
		elif not s.ok("engine_s") and s.ok("engine_p"):
			pull = 0.5 * s.throttle
	var latched: int = 0
	for e in ents:
		if e.alive and e.latched:
			latched += 1
	if s.roll_t > 0.0:
		s.angvel = lerpf(s.angvel, 0.0, 1.0 - exp(-4.0 * dt))
	else:
		s.angvel = lerpf(s.angvel, steer + pull, 1.0 - exp(-3.2 * dt))
	s.heading = K.wrap_pi(s.heading + s.angvel * dt)
	var n: float = float(s.engines_working()) / 2.0
	var boost_k: float = 1.65 if (s.boost and feat("boost") and n > 0.0) else 1.0
	var max_v: float = Ship.MAX_SPEED * s.mod("speed") * n * s.power_factor("engines", features) * boost_k * (1.0 - 0.15 * latched)
	if has_glitch("engine_hiccup") and fmod(float(glitch("engine_hiccup").t), 4.5) < 1.3:
		max_v *= 0.12
	var target: Vector2 = s.fwd() * s.throttle * max_v
	var rate: float = 0.9 if s.blackout_t <= 0.0 else 0.25
	if s.blackout_t > 0.0:
		target = Vector2.ZERO
	s.vel = s.vel.lerp(target, 1.0 - exp(-rate * dt))
	if s.roll_t > 0.0:
		s.vel += s.fwd().orthogonal() * 60.0 * dt * signf(s.wheel if s.wheel != 0.0 else 1.0)
	s.pos += s.vel * dt

func _heat(dt: float) -> void:
	var s: Ship = ship
	if not feat("heat"):
		s.engine_heat = 0.0
		s.gun_heat = maxf(0.0, s.gun_heat - 30.0 * dt)
		return
	var hot: float = 0.0
	if s.engines_working() > 0 and s.blackout_t <= 0.0:
		if s.throttle > 0.72:
			hot = (s.throttle - 0.72) * 85.0
		if s.boost and feat("boost"):
			hot += 22.0
		hot *= s.mod("heat")
	s.engine_heat = clampf(s.engine_heat + (hot - (14.0 if hot <= 0.0 else 0.0)) * dt, 0.0, 100.0)
	if s.engine_heat >= 100.0:
		var opts: Array = []
		for e in ["engine_p", "engine_s"]:
			if s.ok(e):
				opts.append(e)
		if not opts.is_empty():
			break_system(opts[rng.randi() % opts.size()], "overheated", true)
		s.engine_heat = 55.0
	s.gun_heat = maxf(0.0, s.gun_heat - 13.0 * dt)

func _weapons(dt: float) -> void:
	var s: Ship = ship
	s.gun_cd = maxf(0.0, s.gun_cd - dt)
	if s.firing and s.ok("gun") and s.gun_cd <= 0.0:
		var dir: Vector2 = Vector2.from_angle(s.turret_world() + _gun_skew())
		shots.append({"pos": s.pos + dir * 22.0, "vel": dir * BULLET_SPEED + s.vel * 0.5, "from": "us", "dmg": 10.0, "life": 1.4, "kind": "bullet"})
		s.gun_cd = 0.3 / maxf(0.3, s.power_factor("weapons", features)) / s.mod("gun_rate")
		stats.shots += 1
		if feat("heat"):
			s.gun_heat += 9.0 * s.mod("gun_heat")
			if s.gun_heat >= 100.0:
				s.gun_heat = 45.0
				s.firing = false
				break_system("gun", "jammed (overheated)", false)
		if feat("pudding"):
			s.pud_mood -= 0.35
	if s.torp == "loading":
		s.torp_load += dt / 2.2 * s.mod("torp_load")
		if s.torp_load >= 1.0:
			s.torp = "ready"
			s.torp_load = 1.0
			emit("torp_ready")

func fire_torpedo() -> bool:
	var s: Ship = ship
	if s.torp != "ready" or not s.ok("gun"):
		return false
	var dir: Vector2 = Vector2.from_angle(s.turret_world() + _gun_skew())
	shots.append({"pos": s.pos + dir * 24.0, "vel": dir * 200.0 + s.vel * 0.5, "from": "us", "dmg": 45.0, "life": 4.0, "kind": "torpedo"})
	s.torp = "empty"
	s.torp_load = 0.0
	emit("torp_fired")
	return true

func _shots(dt: float) -> void:
	var s: Ship = ship
	for sh in shots:
		sh.pos += sh.vel * dt
		sh.life -= dt
		if sh.life <= 0.0:
			continue
		if sh.from == "us":
			for e in ents:
				if not e.alive or not e.shootable:
					continue
				if sh.pos.distance_to(e.pos) <= e.r + (6.0 if sh.kind == "torpedo" else 3.0):
					sh.life = 0.0
					_hit_ent(e, sh)
					break
		else:
			if sh.pos.distance_to(s.pos) <= SHIP_R + 6.0:
				sh.life = 0.0
				_hit_ship(sh)
	shots = shots.filter(func(x): return x.life > 0.0)

func _hit_ent(e: Dictionary, sh: Dictionary) -> void:
	var dmg: float = float(sh.dmg)
	if e.kind == "cruiser":
		# only the vent at the back really hurts
		var back: Vector2 = Vector2.from_angle(float(e.heading))
		var rear: bool = (sh.pos - e.pos).dot(back) < -e.r * 0.35
		if sh.kind == "torpedo":
			dmg = 50.0 if rear else 6.0
			emit("torp_hit", {"weak": rear})
		else:
			dmg = 2.0 if rear else 0.5
	if e.kind == "patrol":
		dmg = 0.0
	stats.hits += 1
	e.hp -= dmg
	add_fx("spark", sh.pos)
	if not e.hostile and e.kind in ["buoy"]:
		stats.friendly_fire += 1
		emit("friendly_fire", {"name": e.name, "id": e.id})
	if e.hp <= 0.0:
		kill(e, "destroyed")
		if e.kind == "mine":
			for o in ents:
				if o.alive and o.id != e.id and o.pos.distance_to(e.pos) < 60.0 and o.shootable:
					o.hp -= 15.0

func _hit_ship(sh: Dictionary) -> void:
	var s: Ship = ship
	var from_dir: float = (sh.pos - s.pos).angle()
	if s.roll_t > 0.0:
		stats.dodges += 1
		emit("dodged")
		return
	if s.shield_covers(from_dir):
		stats.blocked += 1
		add_fx("block", sh.pos)
		emit("blocked", {"kind": sh.kind})
		if feat("pudding"):
			s.pud_mood -= 1.5
		if feat("power"):
			s.overload += 4.0
		return
	damage_ship(float(sh.dmg), from_dir, str(sh.kind))

func damage_ship(dmg: float, from_dir: float, cause: String = "hit") -> void:
	var s: Ship = ship
	s.hull = maxf(0.0, s.hull - dmg)
	stats.hits_taken += 1
	add_fx("hit", s.pos + Vector2.from_angle(from_dir) * SHIP_R)
	var rel: float = K.wrap_pi(from_dir - s.heading)
	emit("hit", {"dmg": dmg, "rel": rel, "cause": cause})
	if feat("pudding"):
		s.pud_mood -= 7.0
	var sysid: String = s.side_system(rel)
	if feat("damage") and s.ok(sysid) and str(s.sys[sysid].state) == "ok":
		s.sys[sysid].hp -= dmg * 3.2
		if float(s.sys[sysid].hp) <= 0.0:
			break_system(sysid, "was hit", feat("fire") and rng.randf() < 0.45)

func break_system(id: String, why: String = "broke", fire: bool = false) -> void:
	var st: Dictionary = ship.sys[id]
	if str(st.state) == "fire":
		return
	var was_ok: bool = str(st.state) == "ok"
	st.hp = 0.0
	st.state = "fire" if fire else "broken"
	st.fire_t = 0.0
	if fire:
		stats.fires += 1
	if was_ok:
		stats.breaks += 1
	emit("broke", {"sys": id, "why": why, "fire": fire, "name": Ship.SYS_NAME[id]})
	if id == "gun":
		ship.firing = false

# ---------------------------------------------------------------- enemies

func _ai(dt: float) -> void:
	var s: Ship = ship
	for e in ents:
		if not e.alive:
			continue
		e.stun = maxf(0.0, float(e.stun) - dt)
		match str(e.ai):
			"drift":
				e.pos += e.vel * dt
			"drone":
				_ai_drone(e, dt)
			"patrol":
				_ai_patrol(e, dt)
			"cruiser":
				_ai_cruiser(e, dt)
			"grabber":
				_ai_grabber(e, dt)
			"mine":
				if e.pos.distance_to(s.pos) < e.r + SHIP_R + 10.0:
					kill(e, "exploded")
					add_fx("puff", e.pos, {"size": 40.0})
					damage_ship(18.0, (e.pos - s.pos).angle(), "mine")
			"thrown":
				# practice junk: flies at the ship, counts as a shot when it arrives
				e.pos += e.vel * dt
				if e.pos.distance_to(s.pos) < SHIP_R + e.r:
					e.alive = false
					var from_dir: float = (e.pos - s.pos).angle()
					if s.shield_covers(from_dir):
						stats.blocked += 1
						add_fx("block", e.pos)
						emit("blocked", {"kind": "junk", "tag": e.tag})
					elif s.roll_t > 0.0:
						emit("dodged")
					else:
						damage_ship(6.0, from_dir, "junk")
					emit("junk_done", {"id": e.id})
				elif e.pos.distance_to(s.pos) > 900.0:
					e.alive = false
					emit("junk_done", {"id": e.id})
		if e.kind in ["drone", "grabber", "patrol"]:
			e.heading = lerp_angle(float(e.heading), (s.pos - e.pos).angle(), 1.0 - exp(-2.0 * dt))
		elif e.kind == "cruiser":
			# big and slow to turn: that's how you get behind it
			var dh: float = K.wrap_pi((s.pos - e.pos).angle() - float(e.heading))
			e.heading = K.wrap_pi(float(e.heading) + clampf(dh, -0.06 * dt, 0.06 * dt))

func _ai_drone(e: Dictionary, dt: float) -> void:
	var s: Ship = ship
	var to: Vector2 = s.pos - e.pos
	var d: float = to.length()
	var want: Vector2 = to.normalized() * (d - 230.0) * 0.6 + to.normalized().orthogonal() * 40.0
	e.vel = e.vel.lerp(want.limit_length(80.0), 1.0 - exp(-1.2 * dt))
	e.pos += e.vel * dt
	e.cd = float(e.cd) - dt
	if e.cd <= 0.0 and d < 480.0 and e.stun <= 0.0:
		e.cd = rng.randf_range(3.6, 5.2)
		shoot_at_ship(e.pos, 140.0, 8.0)

func _ai_patrol(e: Dictionary, dt: float) -> void:
	var s: Ship = ship
	var to: Vector2 = s.pos - e.pos
	var d: float = to.length()
	var spd: float = float(e.get("speed", 58.0))
	e.vel = e.vel.lerp(to.normalized() * (spd if d > 160.0 else 20.0), 1.0 - exp(-0.8 * dt))
	e.pos += e.vel * dt
	e.cd = float(e.cd) - dt
	if e.cd <= 1.2 and e.charge <= 0.0 and d < 520.0:
		e.charge = 1.2
		emit("charging", {"id": e.id})
	if e.charge > 0.0:
		e.charge = float(e.charge) - dt
		if e.charge <= 0.0:
			e.cd = rng.randf_range(5.0, 6.5)
			for k in [-0.18, 0.0, 0.18]:
				shoot_at_ship(e.pos, 170.0, 9.0, "blob", k)

func _ai_cruiser(e: Dictionary, dt: float) -> void:
	var s: Ship = ship
	var to: Vector2 = s.pos - e.pos
	var d: float = to.length()
	# lumbers forward along its heading, slowly turning towards us
	e.vel = e.vel.lerp(Vector2.from_angle(float(e.heading)) * (16.0 if d > 200.0 else 4.0), 1.0 - exp(-0.4 * dt))
	e.pos += e.vel * dt
	e.cd = float(e.cd) - dt
	if e.cd <= 2.0 and e.charge <= 0.0:
		e.charge = 2.0
		emit("charging", {"id": e.id, "big": true})
	if e.charge > 0.0:
		e.charge = float(e.charge) - dt
		if e.charge <= 0.0:
			e.cd = rng.randf_range(6.0, 7.5)
			for k in [-0.3, -0.15, 0.0, 0.15, 0.3]:
				shoot_at_ship(e.pos + Vector2.from_angle(float(e.heading)) * 40.0, 150.0, 8.0, "blob", k)

func _ai_grabber(e: Dictionary, dt: float) -> void:
	var s: Ship = ship
	if e.latched:
		e.pos = s.pos + Vector2.from_angle(s.heading + float(e.rel)) * (SHIP_R + 10.0)
		e.cd = float(e.cd) - dt
		if e.cd <= 0.0:
			e.cd = 1.0
			s.hull = maxf(0.0, s.hull - 1.2)
			var sysid: String = s.side_system(float(e.rel))
			if feat("damage") and s.ok(sysid):
				s.sys[sysid].hp -= 7.0
				if float(s.sys[sysid].hp) <= 0.0:
					break_system(sysid, "was chewed by a grabber", false)
			if feat("pudding"):
				s.pud_mood -= 2.0
		# shield bash: point the shield at it for a moment
		if s.ok("shield") and absf(K.wrap_pi(float(e.rel) - s.shield_dir)) < Ship.SHIELD_HALF_ARC:
			e.charge = float(e.charge) + dt
		else:
			e.charge = maxf(0.0, float(e.charge) - dt)
		# shoot it off: aim the turret at it
		if s.firing and s.ok("gun") and absf(K.wrap_pi(float(e.rel) - s.aim)) < 0.4:
			e.hp -= 9.0 * dt
			if e.hp <= 0.0:
				kill(e, "destroyed")
				return
		if shake_t > 1.4 or float(e.charge) > 1.8:
			e.latched = false
			e.stun = 4.0
			e.hp -= 12.0
			e.charge = 0.0
			e.vel = Vector2.from_angle(s.heading + float(e.rel)) * 160.0
			emit("unlatched", {"id": e.id, "how": "shaken" if shake_t > 1.4 else "shield"})
			if e.hp <= 0.0:
				kill(e, "destroyed")
		return
	var to: Vector2 = s.pos - e.pos
	if e.stun > 0.0:
		e.pos += e.vel * dt
		e.vel *= exp(-1.0 * dt)
		return
	e.vel = e.vel.lerp(to.normalized() * 95.0, 1.0 - exp(-1.0 * dt))
	e.pos += e.vel * dt
	if to.length() < SHIP_R + e.r + 4.0:
		e.latched = true
		e.rel = K.wrap_pi((e.pos - s.pos).angle() - s.heading)
		e.cd = 1.0
		emit("latched", {"id": e.id, "rel": e.rel})

func _bumps(dt: float) -> void:
	var s: Ship = ship
	bump_cd = maxf(0.0, bump_cd - dt)
	if absf(s.angvel) > 1.1:
		shake_t += dt
	else:
		shake_t = maxf(0.0, shake_t - dt * 0.5)
	for e in ents:
		if not e.alive or not (e.kind in ["rock", "customs", "haven", "diner", "cruiser", "skip"]):
			continue
		var to: Vector2 = s.pos - e.pos
		var d: float = to.length()
		var min_d: float = e.r + SHIP_R * 0.8
		if d < min_d and d > 0.01:
			s.pos = e.pos + to / d * min_d
			var vn: float = s.vel.dot(to / d)
			if vn < 0.0:
				s.vel -= to / d * vn * 1.4
			if bump_cd <= 0.0 and s.speed() > 12.0:
				bump_cd = 1.0
				damage_ship(4.0 + s.speed() * 0.08, (e.pos - s.pos).angle(), "bump")
				emit("bump", {"name": e.name})

# ---------------------------------------------------------------- stations

func _tractor(dt: float) -> void:
	var s: Ship = ship
	s.tractor_target = -1
	if not feat("tractor") or not s.tractor_on or not s.ok("tractor"):
		return
	var best: Dictionary = {}
	var bd: float = TRACTOR_RANGE * s.mod("tractor")
	for e in ents:
		if e.alive and e.tractor:
			var d: float = e.pos.distance_to(s.pos)
			if d < bd:
				bd = d
				best = e
	if best.is_empty():
		return
	s.tractor_target = int(best.id)
	var to: Vector2 = s.pos - best.pos
	best.vel = best.vel.lerp(to.normalized() * 70.0 + s.vel, 1.0 - exp(-2.0 * dt))
	best.pos += best.vel * dt
	if to.length() < SHIP_R + best.r + 6.0:
		best.alive = false
		emit("collected", {"id": best.id, "kind": best.kind, "name": best.name, "tag": best.tag})
	if feat("power"):
		pass

func _scan(dt: float) -> void:
	if not scanning or scan_target < 0:
		scan_prog = maxf(0.0, scan_prog - dt)
		return
	if scan_target >= 900000:
		_scan_ghost(dt)
		return
	var e: Dictionary = ent(scan_target)
	if e.is_empty() or not e.alive:
		scan_prog = 0.0
		return
	if not ship.ok("sensors") or e.pos.distance_to(ship.pos) > radar_range:
		return
	scan_prog += dt / SCAN_TIME * ship.mod("scan")
	if scan_prog >= 1.0:
		scan_prog = 0.0
		if not e.scanned:
			e.scanned = true
			stats.scans += 1
			emit("scanned", {"id": e.id, "name": e.name, "kind": e.kind, "hostile": e.hostile})
		elif e.kind == "cruiser" and feat("weakspot") and not e.weak_known:
			e.weak_known = true
			emit("weak_found", {"id": e.id})
		else:
			emit("rescanned", {"id": e.id, "kind": e.kind})

func _comms(dt: float) -> void:
	if hail.is_empty() or not feat("comms"):
		return
	hail.freq = clampf(float(hail.base) + sin(t * 0.25 + float(hail.base) * 9.0) * 0.08, 0.05, 0.95)
	var sig: float = clampf(1.0 - absf(comms_freq - float(hail.freq)) * 7.0, 0.0, 1.0)
	if not ship.ok("sensors"):
		sig *= 0.3
	hail.signal = sig
	if sig > 0.8:
		hail.lock_t = float(hail.lock_t) + dt
	else:
		hail.lock_t = maxf(0.0, float(hail.lock_t) - dt * 0.5)
	if not hail.heard and float(hail.lock_t) > 1.0:
		hail.heard = true
		emit("hail_heard", {"from": hail.from, "text": hail.text})

func send_hail(from: String, text: String) -> void:
	hail = {"from": from, "text": text, "base": rng.randf_range(0.15, 0.85), "freq": 0.5, "heard": false, "lock_t": 0.0, "signal": 0.0,
		"t": t}
	emit("hail", {"from": from})

func _pudding(dt: float) -> void:
	var s: Ship = ship
	if not feat("pudding"):
		return
	if s.boost and feat("boost"):
		s.pud_mood -= 2.5 * dt
	for id in Ship.SYSTEMS:
		if s.on_fire(id):
			s.pud_mood -= 1.0 * dt
	if not s.pud_out:
		s.pud_mood += (14.0 if s.petting else 0.5) * dt
		s.pud_mood = clampf(s.pud_mood, 0.0, 100.0)
		if s.pud_mood <= 0.0:
			s.pud_out = true
			s.pud_room = "pen"
			s.pud_hop_t = 2.0
			s.pud_chew_t = 7.0
			s.tin_prog = 0.0
			stats.escapes += 1
			emit("pudding_out")
		return
	s.pud_mood = 0.0
	s.pud_hop_t -= dt
	if s.pud_hop_t <= 0.0:
		s.pud_hop_t = rng.randf_range(4.0, 6.0)
		var nb: Array = Ship.NEIGHBOURS[s.pud_room]
		s.pud_room = nb[rng.randi() % nb.size()]
		emit("pudding_moved", {"room": s.pud_room})
	s.pud_chew_t -= dt
	if s.pud_chew_t <= 0.0:
		s.pud_chew_t = rng.randf_range(8.0, 11.0)
		if s.ok(s.pud_room):
			break_system(s.pud_room, "was chewed by Pudding", false)
	if s.tin:
		s.tin_prog += dt / 2.5
		if s.tin_prog >= 1.0:
			s.pud_out = false
			s.pud_mood = 55.0
			s.tin_prog = 0.0
			emit("pudding_back")
	else:
		s.tin_prog = maxf(0.0, s.tin_prog - dt)

func _fires(dt: float) -> void:
	var s: Ship = ship
	for id in Ship.SYSTEMS:
		var st: Dictionary = s.sys[id]
		if str(st.state) != "fire":
			continue
		st.fire_t = float(st.fire_t) + dt
		s.hull = maxf(0.0, s.hull - 0.35 * dt)
		if float(st.fire_t) > 11.0:
			st.fire_t = 0.0
			var nb: Array = Ship.NEIGHBOURS[id]
			var to: String = nb[rng.randi() % nb.size()]
			if str(s.sys[to].state) != "fire":
				break_system(to, "caught fire", true)

func _repairs(dt: float) -> void:
	var s: Ship = ship
	if not s.repairing or s.repair_target == "" or not s.sys.has(s.repair_target):
		s.repair_prog = maxf(0.0, s.repair_prog - dt * 0.5)
		return
	var st: Dictionary = s.sys[s.repair_target]
	var needs: bool = str(st.state) != "ok" or float(st.hp) < 100.0
	if not needs:
		s.repair_prog = 0.0
		_fix_glitch(dt)
		return
	var fire: bool = str(st.state) == "fire"
	# a part mends twice as fast while nobody is using it: the Engineer has to ask for a breather
	var k: float = (2.0 if (not fire and resting(s.repair_target)) else 1.0) * s.mod("repair")
	s.repair_prog += dt * k / (Ship.FIRE_TIME if fire else (Ship.REPAIR_TIME if str(st.state) == "broken" else 1.5))
	if s.repair_prog >= 1.0:
		s.repair_prog = 0.0
		if fire:
			st.state = "broken"
			emit("fire_out", {"sys": s.repair_target, "name": Ship.SYS_NAME[s.repair_target]})
		else:
			st.state = "ok"
			st.hp = 100.0
			stats.repairs += 1
			emit("repaired", {"sys": s.repair_target, "name": Ship.SYS_NAME[s.repair_target]})

func _power(dt: float) -> void:
	var s: Ship = ship
	if not feat("power"):
		s.draw = 0.0
		s.overload = 0.0
		return
	var boost_k: float = 1.5 if (s.boost and feat("boost")) else 1.0
	s.draw = float(s.power.engines) * s.throttle * boost_k + float(s.power.weapons) * (1.0 if s.firing else 0.15) \
		+ float(s.power.shields) * 0.6 + (1.2 if s.tractor_on else 0.0) + (0.4 if scanning else 0.0)
	if s.blackout_t > 0.0:
		s.draw = 0.0
		s.overload = 0.0
		return
	if s.draw > s.power_cap + 0.01:
		s.overload += (s.draw - s.power_cap) * 16.0 * dt
	else:
		s.overload -= 12.0 * dt
	s.overload = clampf(s.overload, 0.0, 100.0)
	if s.overload >= 100.0:
		s.overload = 0.0
		s.blackout_t = 5.0
		s.firing = false
		stats.overloads += 1
		s.sys.reactor.hp = float(s.sys.reactor.hp) - 45.0
		emit("blackout")
		if float(s.sys.reactor.hp) <= 0.0:
			break_system("reactor", "blew its breaker", false)

func resting(sysid: String) -> bool:
	## is nobody leaning on this part right now?
	var s: Ship = ship
	match sysid:
		"engine_p", "engine_s":
			return s.throttle < 0.08
		"gun":
			return not s.firing and s.torp != "loading"
		"sensors":
			return not scanning
		"tractor":
			return not s.tractor_on
		"bridge":
			return absf(s.wheel) < 0.1
		"reactor":
			return feat("power") and s.draw < s.power_cap * 0.5
	return false

static func rest_tip(sysid: String) -> String:
	match sysid:
		"engine_p", "engine_s":
			return "Twice as fast if Engines cuts the throttle to zero."
		"gun":
			return "Twice as fast while Weapons stops firing."
		"sensors":
			return "Twice as fast while Sensors stops scanning."
		"tractor":
			return "Twice as fast with the tractor beam off."
		"bridge":
			return "Twice as fast while Helm holds the wheel centred."
		"reactor":
			return "Twice as fast while the ship draws under half power."
	return ""

# ---------------------------------------------------------------- glitches

func has_glitch(id: String) -> bool:
	for g in glitches:
		if str(g.id) == id:
			return true
	return false

func glitch(id: String) -> Dictionary:
	for g in glitches:
		if str(g.id) == id:
			return g
	return {}

func glitch_in(sysid: String) -> Dictionary:
	for g in glitches:
		if str(g.sys) == sysid:
			return g
	return {}

func add_glitch(id: String) -> bool:
	if not Glitches.can_have(self, id):
		return false
	var def: Dictionary = Glitches.DEFS[id]
	var g: Dictionary = {"id": id, "sys": str(def.sys), "station": str(def.station), "t": 0.0, "fix": 0.0, "hinted": false,
		"ask": Glitches.pick_ask(self, def)}
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	match id:
		"drunk_compass":
			g["off"] = [PI / 2.0, -PI / 2.0, PI][rng.randi() % 3]
		"shield_slip":
			g["off"] = side * [PI / 3.0, PI / 2.0][rng.randi() % 2]
		"gun_pull":
			g["off"] = side * 0.24
		"wheel_drift":
			g["off"] = side
		"radar_ghosts":
			g["ghosts"] = []
			g["spawn_t"] = 0.0
	glitches.append(g)
	stats["glitches"] = int(stats.get("glitches", 0)) + 1
	emit("glitch", {"id": id, "sys": g.sys, "station": g.station, "name": def.name})
	return true

func remove_glitch(id: String, fixed: bool = true) -> void:
	for g in glitches:
		if str(g.id) == id:
			glitches.erase(g)
			if id == "radar_ghosts" and scan_target >= 900000:
				scan_target = -1
				scan_prog = 0.0
			if fixed:
				stats["glitches_fixed"] = int(stats.get("glitches_fixed", 0)) + 1
				emit("glitch_fixed", {"id": id, "sys": g.sys, "station": g.station, "name": Glitches.DEFS[id].name, "t": g.t})
			return

func _gun_skew() -> float:
	return float(glitch("gun_pull").get("off", 0.0)) if has_glitch("gun_pull") else 0.0

func _fix_glitch(dt: float) -> void:
	## the Engineer is holding REPAIR on a healthy room: if a glitch lives there, work through IGOR's manual
	var g: Dictionary = glitch_in(ship.repair_target)
	if g.is_empty():
		return
	if Glitches.ask_met(self, g):
		g.fix = float(g.fix) + dt / Glitches.FIX_TIME * ship.mod("repair")
		if float(g.fix) >= 1.0:
			remove_glitch(str(g.id), true)
	else:
		g.fix = maxf(0.0, float(g.fix) - dt * 0.6)

func _glitch_tick(dt: float) -> void:
	var s: Ship = ship
	for g in glitches.duplicate():
		g.t = float(g.t) + dt
		if not s.repairing or s.repair_target != str(g.sys):
			g.fix = maxf(0.0, float(g.fix) - dt * 0.4)
		if not bool(g.hinted) and float(g.t) > Glitches.HINT_AFTER:
			g.hinted = true
			emit("glitch_hint", {"id": g.id})
		match str(g.id):
			"sticky_throttle":
				if s.throttle > 0.05:
					s.throttle = minf(1.0, s.throttle + 0.07 * dt)
			"wheel_drift":
				s.wheel = clampf(s.wheel + float(g.off) * 0.11 * dt, -1.0, 1.0)
			"igor_reboot":
				if float(g.t) > 20.0:
					remove_glitch("igor_reboot", true)
			"pudding_sat":
				s.firing = false
				if s.petting or s.pud_out:
					g.fix = float(g.fix) + dt / 2.0
					if float(g.fix) >= 1.0 or s.pud_out:
						remove_glitch("pudding_sat", true)
			"radar_ghosts":
				g.spawn_t = float(g.spawn_t) - dt
				if float(g.spawn_t) <= 0.0 and (g.ghosts as Array).size() < 3:
					g.spawn_t = 7.0
					(g.ghosts as Array).append({"id": next_ghost, "a": rng.randf() * TAU, "d": rng.randf_range(160.0, radar_range * 0.85),
						"spin": rng.randf_range(-0.05, 0.05)})
					next_ghost += 1
		# a room that breaks takes its glitch with it: one problem at a time per room
		if s.broken(str(g.sys)) and str(g.id) != "igor_reboot":
			remove_glitch(str(g.id), false)

func _scan_ghost(dt: float) -> void:
	var g: Dictionary = glitch("radar_ghosts")
	var found: Dictionary = {}
	for gh in g.get("ghosts", []):
		if int(gh.id) == scan_target:
			found = gh
	if found.is_empty() or not ship.ok("sensors"):
		scan_prog = 0.0
		return
	scan_prog += dt / SCAN_TIME
	if scan_prog >= 1.0:
		scan_prog = 0.0
		scan_target = -1
		(g.ghosts as Array).erase(found)
		emit("ghost_scanned")

# ---------------------------------------------------------------- forecasts (the captain's cues)

func overload_eta() -> float:
	var s: Ship = ship
	if not feat("power") or s.draw <= s.power_cap + 0.01:
		return -1.0
	return (100.0 - s.overload) / maxf(0.01, (s.draw - s.power_cap) * 16.0)

func engine_heat_eta() -> float:
	var s: Ship = ship
	if not feat("heat"):
		return -1.0
	var hot: float = 0.0
	if s.throttle > 0.72:
		hot = (s.throttle - 0.72) * 85.0
	if s.boost and feat("boost"):
		hot += 22.0
	if hot <= 0.0:
		return -1.0
	return (100.0 - s.engine_heat) / hot

func incoming() -> Array:
	## enemy shots that will reach us in the next ~3 seconds: [{rel, eta, covered}]
	var out: Array = []
	var s: Ship = ship
	for sh in shots:
		if sh.from != "them":
			continue
		var to: Vector2 = s.pos - sh.pos
		var closing: float = sh.vel.dot(to.normalized())
		if closing <= 0.0:
			continue
		var eta: float = to.length() / closing
		if eta < 3.0:
			var from_dir: float = (sh.pos - s.pos).angle()
			out.append({"rel": K.wrap_pi(from_dir - s.heading), "eta": eta, "covered": s.shield_covers(from_dir)})
	for e in ents:
		if e.alive and e.ai == "thrown":
			var to2: Vector2 = s.pos - e.pos
			var cl: float = e.vel.dot(to2.normalized())
			if cl > 0.0 and to2.length() / cl < 4.0:
				var fd: float = (e.pos - s.pos).angle()
				out.append({"rel": K.wrap_pi(fd - s.heading), "eta": to2.length() / cl, "covered": s.shield_covers(fd)})
	return out
