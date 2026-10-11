class_name World
extends RefCounted
## The authoritative simulation: one ship, a bag of entities, an encounter and a Chaos Director.
## Pure logic, no nodes, so it can run headless and be soak-tested.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var t: float = 0.0
var ship: Ship
var ents: Array = []
var next_id: int = 1
var enc: Encounter = null
var director: Director = null
var events: Array = []  # [type, data] consumed by the host

var temper: int = 1
var torp_bonus: float = 1.0
var sensor_bonus: float = 1.0
var thrupp_title: String = "Admiral"
var damages_billed: float = 0.0
var last_input: Dictionary = {}
var stats: Dictionary = {}

# sensors / comms
var scan: Dictionary = {"target": -1, "progress": 0.0, "on": false}
var comms: Dictionary = {"freq": 0.5, "vel": 0.0, "target": 0.5, "tuned_t": 0.0}
var hails: Array = []
var captain_comms: Array = []
var ping_t: float = 0.0
var ping_cd: float = 0.0
var reveal_t: float = 0.0
var iscan_cd: float = 0.0
var view_dir: String = "fwd"
var lock_id: int = -1
var lock_weak: bool = false
var track: Dictionary = {"TUR_A": false, "TUR_B": false}
var sel_turret: String = "TUR_A"
var tractor_id: int = -1
var paint: int = 0
var stowed: bool = false
var holds: Dictionary = {}  # actor -> {target, mode}
var mash: Dictionary = {}   # target -> progress
var shared_screen: String = ""
var inverted: Dictionary = {}
var last_actor: String = ""
var mods: Array = []
var dc_traces: Dictionary = {}
var zap_events: Array = []
var trace_prog: Dictionary = {}
var load_hold: Dictionary = {}
var arming: Dictionary = {}

func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	ship = Ship.new(rng)
	director = Director.new(self)
	reset_stats()

func reset_stats() -> void:
	stats = {"collisions": 0, "max_collision": 0.0, "spins": 0.0, "friendly_fire": 0, "near_miss": 0, "kills": 0,
		"torps": 0, "shots": 0, "orders": 0, "fires_put_out": 0, "repairs": 0, "misjump": 0,
		"inputs": {"helm": 0, "engines": 0, "power": 0, "weapons": 0, "sensors": 0, "ops": 0, "dc": 0},
		"idle_max": {"helm": 0.0, "engines": 0.0, "power": 0.0, "weapons": 0.0, "sensors": 0.0, "ops": 0.0},
		"blame": {"helm": 0, "engines": 0, "power": 0, "weapons": 0, "sensors": 0, "ops": 0}}

func emit(type: String, data: Dictionary = {}) -> void:
	events.append([type, data])

# ---------------------------------------------------------------- entities

func spawn(kind: String, p: Vector2, opts: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"id": next_id, "kind": kind, "pos": p, "vel": Vector2.ZERO, "ang": 0.0, "angvel": 0.0,
		"r": 5.0, "hp": 50.0, "hpmax": 50.0, "fac": "neu", "name": kind, "scan": -1000.0, "solid": false,
		"radar": true, "vis": true, "t": 0.0, "dead": false, "state": "", "st": 0.0}
	next_id += 1
	match kind:
		"asteroid":
			e.merge({"r": rng.randf_range(8.0, 20.0), "solid": true, "hp": 9999.0, "hpmax": 9999.0, "name": "Asteroid", "mass": 400.0}, true)
		"mine":
			e.merge({"r": 3.0, "vis": false, "hp": 10.0, "name": "Mine", "fac": "heg"}, true)
		"grabber":
			e.merge({"r": 3.5, "hp": 30.0, "hpmax": 30.0, "fac": "heg", "name": "Grabber Drone", "state": "chase", "mass": 10.0}, true)
		"snatch":
			e.merge({"r": 4.5, "hp": 45.0, "hpmax": 45.0, "fac": "heg", "name": "Snatch Pod", "state": "chase", "mass": 15.0}, true)
		"patrol":
			e.merge({"r": 18.0, "hp": 220.0, "hpmax": 220.0, "fac": "heg", "name": "Hegemony Patrol", "solid": true, "mass": 3000.0}, true)
		"bastion":
			e.merge({"r": 40.0, "hp": 300.0, "hpmax": 300.0, "fac": "heg", "name": "Bastion Cruiser", "solid": true, "mass": 20000.0, "state": "idle", "fire_t": 4.0, "weak_hp": 100.0}, true)
		"magnificence":
			e.merge({"r": 120.0, "hp": 99999.0, "hpmax": 99999.0, "fac": "heg", "name": "The Magnificence", "solid": true, "mass": 200000.0, "fire_t": 5.0}, true)
		"freighter":
			e.merge({"r": 14.0, "hp": 120.0, "hpmax": 120.0, "fac": "free", "name": "Freighter", "solid": true, "mass": 2500.0}, true)
		"diner":
			e.merge({"r": 42.0, "hp": 9999.0, "hpmax": 9999.0, "fac": "free", "name": "Ma Gristle's Diner", "solid": true, "mass": 90000.0}, true)
		"skip":
			e.merge({"r": 4.0, "hp": 20.0, "hpmax": 20.0, "name": "Skip", "mass": 30.0}, true)
		"pod":
			e.merge({"r": 3.0, "hp": 15.0, "hpmax": 15.0, "name": "Escape Pod", "mass": 10.0}, true)
		"debris":
			e.merge({"r": 1.5, "hp": 5.0, "hpmax": 5.0, "name": "Debris", "radar": false}, true)
		"waypoint":
			e.merge({"r": 25.0, "hp": 1.0, "name": "Waypoint"}, true)
		"beacon":
			e.merge({"r": 2.0, "hp": 5.0, "name": "Decoy Beacon"}, true)
		"bullet":
			e.merge({"r": 1.0, "hp": 1.0, "fac": "free", "radar": false, "name": "Shot", "dmg": 15.0, "life": 2.5}, true)
		"ebullet":
			e.merge({"r": 1.2, "hp": 1.0, "fac": "heg", "radar": true, "name": "Enemy Shot", "dmg": 12.0, "life": 5.0}, true)
		"eshell":
			e.merge({"r": 2.5, "hp": 1.0, "fac": "heg", "radar": true, "name": "Broadside", "dmg": 20.0, "life": 18.0}, true)
		"torp":
			e.merge({"r": 1.8, "hp": 1.0, "fac": "free", "radar": true, "name": "Torpedo", "life": 9.0, "armed": false}, true)
	e.merge(opts, true)
	ents.append(e)
	return e

func find(id: int) -> Dictionary:
	for e in ents:
		if e.id == id and not e.dead:
			return e
	return {}

func of_kind(kind: String) -> Array:
	var out: Array = []
	for e in ents:
		if e.kind == kind and not e.dead:
			out.append(e)
	return out

func hostiles() -> Array:
	var out: Array = []
	for e in ents:
		if e.dead:
			continue
		if e.kind in ["grabber", "snatch", "patrol", "bastion", "magnificence"]:
			out.append(e)
	return out

func clear_entities() -> void:
	ents.clear()
	scan = {"target": -1, "progress": 0.0, "on": false}
	lock_id = -1
	tractor_id = -1
	hails.clear()
	captain_comms.clear()

func weak_pos(b: Dictionary) -> Vector2:
	return b.pos + Vector2(-float(b.r) * 0.85, 0.0).rotated(b.ang)

func sensor_range() -> float:
	var r: float = 300.0 + 450.0 * minf(ship.pf("sensors"), 1.5) * ship.eff("SENS")
	if ping_t > 0.0:
		r = maxf(r, 1500.0)
	return r * sensor_bonus

func is_scanned(e: Dictionary) -> bool:
	return t - float(e.scan) < 40.0

func hail(from: String, text: String, ttl: float = 40.0) -> void:
	from = from.replace("Admiral Thrupp", thrupp_title + " Thrupp")
	text = text.replace("Admiral Thrupp", thrupp_title + " Thrupp")
	var tf: float = rng.randf_range(0.15, 0.85)
	if absf(tf - float(comms["freq"])) < 0.2:
		tf = fposmod(tf + 0.35, 1.0)
	hails.append({"from": from, "text": text, "freq": tf, "ttl": ttl, "t": 0.0})
	comms["target"] = tf

# ---------------------------------------------------------------- stepping

func step(dt: float) -> void:
	t += dt
	for k in inverted.keys():
		inverted[k] = float(inverted[k]) - dt
		if inverted[k] <= 0.0:
			inverted.erase(k)
	ship.step(dt)
	for ev in ship.events:
		_ship_event(ev[0], ev[1])
	ship.events.clear()
	_ents_step(dt)
	_collide(dt)
	_sensors_step(dt)
	_work_step(dt)
	_tractor_step(dt)
	_weapons_step(dt)
	if enc != null:
		enc.tick(dt)
	director.tick(dt)
	stats["spins"] = float(stats["spins"]) + absf(ship.angvel) * dt
	for s in K.STATIONS:
		var li: Dictionary = last_input.get(s, {"t": 0.0})
		var idle: float = t - float(li.get("t", 0.0))
		stats["idle_max"][s] = maxf(float(stats["idle_max"][s]), idle)
	_cleanup()

func _cleanup() -> void:
	var keep: Array = []
	for e in ents:
		if not e.dead:
			keep.append(e)
	ents = keep

func _ship_event(type: String, data: Dictionary) -> void:
	if type == "hull_hit":
		pass
	emit(type, data)

func _ents_step(dt: float) -> void:
	var sp: Vector2 = ship.pos
	for e in ents:
		if e.dead:
			continue
		e.t += dt
		match e.kind:
			"grabber", "snatch":
				_drone_ai(e, dt)
			"bullet", "ebullet", "eshell", "torp":
				_proj_ai(e, dt)
			"bastion":
				_bastion_ai(e, dt)
			"magnificence":
				_magnificence_ai(e, dt)
			"diner":
				e.ang += 0.12 * dt
				e.pos += e.vel * dt
			"patrol":
				_patrol_ai(e, dt)
			"mine":
				e.pos += e.vel * dt
				var d: float = e.pos.distance_to(sp)
				if d < ship.radius + e.r + 2.0:
					_explode_mine(e)
			_:
				e.pos += e.vel * dt
				e.ang += e.angvel * dt

func _explode_mine(e: Dictionary) -> void:
	e.dead = true
	var dir: Vector2 = (e.pos - ship.pos).normalized()
	ship.hit(dir, 30.0, "mine")
	damages_billed += 30.0
	emit("boom", {"pos": e.pos, "size": 12.0})
	emit("mine_hit", {})
	ship.vel -= dir * 6.0

func _drone_ai(e: Dictionary, dt: float) -> void:
	var is_snatch: bool = e.kind == "snatch"
	if e.state == "stunned":
		e.st -= dt
		e.pos += e.vel * dt
		e.vel *= 1.0 - 0.8 * dt
		if e.st <= 0.0:
			e.state = "chase"
		return
	if e.state == "chase":
		var to: Vector2 = ship.pos - e.pos
		var d: float = to.length()
		var maxs: float = (26.0 if not is_snatch else 30.0) + float(temper) * 1.5
		var want: Vector2 = to.normalized() * maxs
		# lead the target a little
		if d > 60.0:
			want = (to + ship.vel * (d / maxs) * 0.6).normalized() * maxs
		e.vel = e.vel.move_toward(want, 38.0 * dt)
		e.pos += e.vel * dt
		e.ang = e.vel.angle()
		if d < ship.radius + e.r + 1.5:
			e.state = "latched"
			e.st = 0.0
			e["off"] = (e.pos - ship.pos).rotated(-ship.heading)
			e["shake_t"] = 0.0
			# latch point on nearest module
			var best: String = ""
			var bd: float = 1e9
			for id in ship.mod_order:
				var m: Dictionary = ship.modules[id]
				var dd: float = e.off.distance_to(Vector2(m.lx, m.ly))
				if is_snatch and id == "PEN":
					dd = -1.0
				if dd < bd:
					bd = dd
					best = id
			e["mod"] = best
			emit("latched", {"kind": e.kind, "id": e.id, "mod": best})
		return
	if e.state == "latched":
		e.pos = ship.pos + Vector2(e.off).rotated(ship.heading)
		e.vel = ship.vel
		e.st += dt
		if is_snatch:
			if e.st > 14.0 and ship.pud["aboard"]:
				emit("pudding_snatched", {})
				e.dead = true
				return
			ship.pud["mood"] = minf(100.0, float(ship.pud["mood"]) + 3.0 * dt)
		else:
			ship.damage_module(e.mod, 5.0 * dt)
			ship.pud["mood"] = minf(100.0, float(ship.pud["mood"]) + 1.0 * dt)
		if absf(ship.angvel) > 2.0:
			e.shake_t += dt
		else:
			e.shake_t = maxf(0.0, float(e.shake_t) - dt)
		if float(e.shake_t) > 1.2 or ship.hit_flash > 0.25 and rng.randf() < 0.02:
			e.state = "stunned"
			e.st = 3.0
			e.vel = (e.pos - ship.pos).normalized() * 40.0
			emit("shaken_off", {"kind": e.kind})

func _patrol_ai(e: Dictionary, dt: float) -> void:
	e.pos += e.vel * dt
	e.ang = lerp_angle(float(e.ang), e.vel.angle(), 1.0 * dt) if e.vel.length() > 0.1 else float(e.ang)
	if e.state == "hostile":
		var to: Vector2 = ship.pos - e.pos
		e.vel = e.vel.move_toward(to.normalized() * 14.0, 6.0 * dt)
		e.fire_t = float(e.get("fire_t", 3.0)) - dt
		if e.fire_t <= 0.0 and to.length() < 500.0:
			e.fire_t = 2.2
			_enemy_shot(e.pos, ship.pos, "ebullet", 90.0)

func _enemy_shot(from: Vector2, to: Vector2, kind: String, speed: float) -> void:
	var dir: Vector2 = (to - from).normalized()
	# lead the ship a bit
	var d: float = from.distance_to(to)
	var lead: Vector2 = to + ship.vel * (d / speed) * 0.5
	dir = (lead - from).normalized()
	spawn(kind, from + dir * 6.0, {"vel": dir * speed, "ang": dir.angle()})

func _bastion_ai(e: Dictionary, dt: float) -> void:
	e.pos += e.vel * dt
	var to: Vector2 = ship.pos - e.pos
	if e.state != "dead" and e.state != "ignore":
		var want: float = to.angle()
		var diff: float = K.wrap_pi(want - float(e.ang))
		e.ang += clampf(diff, -0.12 * dt, 0.12 * dt)
		e.fire_t -= dt
		var d: float = to.length()
		if e.state == "idle" and e.fire_t <= 0.0 and d < 900.0:
			e.state = "telegraph"
			e.st = 3.0
			emit("bastion_telegraph", {"id": e.id})
		elif e.state == "telegraph":
			e.st -= dt
			if e.st <= 0.0:
				e.state = "idle"
				e.fire_t = maxf(5.0, 9.0 - float(temper) * 0.7)
				for i in 3:
					var off: Vector2 = Vector2.from_angle(float(e.ang) + PI / 2.0) * (float(i) - 1.0) * 16.0
					_enemy_shot(e.pos + off, ship.pos, "eshell", 62.0)
				emit("bastion_fire", {"id": e.id})
		if e.get("tractor", false):
			var pull: float = 3.5 + 7.0 * maxf(0.0, sin(t * 2.2))
			ship.vel -= to.normalized() * pull * dt
			emit_throttled("tractor_pull", 6.0)

var _throttle: Dictionary = {}
func emit_throttled(type: String, gap: float, data: Dictionary = {}) -> void:
	if t - float(_throttle.get(type, -999.0)) >= gap:
		_throttle[type] = t
		emit(type, data)

func _magnificence_ai(e: Dictionary, dt: float) -> void:
	e.pos += e.vel * dt
	e.fire_t -= dt
	if e.fire_t <= 0.0 and e.pos.distance_to(ship.pos) < 1200.0:
		e.fire_t = 5.0
		emit("bastion_telegraph", {"id": e.id})
		for i in 5:
			var off: Vector2 = Vector2.from_angle(float(e.ang) + PI / 2.0) * (float(i) - 2.0) * 40.0
			_enemy_shot(e.pos + off, ship.pos + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)), "eshell", 70.0)

func _proj_ai(e: Dictionary, dt: float) -> void:
	e.life = float(e.get("life", 3.0)) - dt
	if e.life <= 0.0:
		e.dead = true
		if e.kind == "torp":
			_torp_blast(e)
		return
	if e.kind == "torp":
		var tgt: Dictionary = find(int(e.get("target", -1)))
		if not tgt.is_empty():
			var aim: Vector2 = tgt.pos
			if tgt.kind == "bastion" and e.get("weak", false):
				aim = weak_pos(tgt)
			var want: float = (aim - e.pos).angle()
			var cur: float = e.vel.angle()
			var diff: float = K.wrap_pi(want - cur)
			cur += clampf(diff, -1.4 * dt, 1.4 * dt)
			e.vel = Vector2.from_angle(cur) * 75.0
		e.ang = e.vel.angle()
		if not e.armed and e.t > 1.5:
			e.armed = true
	if e.kind == "bullet" or e.kind == "torp":
		for step_i in 3:
			e.pos += e.vel * (dt / 3.0)
			for o in ents:
				if o.dead or o.id == e.id or o.kind in ["bullet", "torp", "ebullet", "eshell", "waypoint", "debris", "beacon"]:
					continue
				var rad: float = float(o.r) + float(e.r)
				if e.pos.distance_to(o.pos) < rad:
					if e.kind == "torp":
						if not e.armed:
							continue
						e.dead = true
						_torp_blast(e)
						return
					_bullet_hit(e, o)
					return
			if e.kind == "torp" and e.armed and e.pos.distance_to(ship.pos) < ship.radius + 2.0 and e.t > 2.0:
				e.dead = true
				_torp_blast(e)
				return
	else:
		e.pos += e.vel * dt
		if e.pos.distance_to(ship.pos) < ship.radius + float(e.r):
			e.dead = true
			ship.hit((e.pos - ship.pos).normalized(), float(e.dmg), "shot")
			damages_billed += float(e.dmg) * 0.5
			emit("boom", {"pos": e.pos, "size": 6.0})
		elif e.t > 0.2:
			# near miss detector
			var d: float = e.pos.distance_to(ship.pos)
			if d < ship.radius + 6.0 and not e.get("nm", false):
				e.nm = true
				stats["near_miss"] = int(stats["near_miss"]) + 1
				emit("near_miss", {})

func _bullet_hit(b: Dictionary, o: Dictionary) -> void:
	b.dead = true
	emit("boom", {"pos": b.pos, "size": 3.0})
	if o.kind == "asteroid":
		return
	if o.kind == "bastion":
		var wp: Vector2 = weak_pos(o)
		o.hp -= 1.0
		if b.pos.distance_to(wp) < 9.0:
			o.weak_hp = float(o.weak_hp) - 8.0
			if float(o.weak_hp) <= 0.0:
				o.hp = 0.0
				o.state = "dead"
				_kill(o)
		return
	if o.fac == "free" or o.kind in ["skip", "pod"] or (o.fac == "neu" and o.kind != "mine"):
		stats["friendly_fire"] = int(stats["friendly_fire"]) + 1
		emit("friendly_fire", {"name": o.name, "id": o.id, "kind": o.kind})
	o.hp -= float(b.get("dmg", 15.0))
	if o.hp <= 0.0 and o.kind != "mine":
		_kill(o)
	elif o.kind == "mine":
		o.dead = true
		emit("boom", {"pos": o.pos, "size": 10.0})

func _kill(o: Dictionary) -> void:
	o.dead = true
	stats["kills"] = int(stats["kills"]) + 1
	emit("boom", {"pos": o.pos, "size": clampf(float(o.r) * 1.4, 4.0, 40.0)})
	emit("kill", {"kind": o.kind, "id": o.id, "name": o.name})
	if o.kind == "grabber" and o.state == "latched":
		pass

func _torp_blast(e: Dictionary) -> void:
	emit("boom", {"pos": e.pos, "size": 22.0})
	var blast: float = 16.0
	for o in ents:
		if o.dead or o.kind in ["bullet", "torp", "ebullet", "eshell", "waypoint"]:
			continue
		var d: float = o.pos.distance_to(e.pos)
		if d > blast + float(o.r):
			continue
		if o.kind == "asteroid":
			continue
		if o.kind == "bastion":
			var wp: Vector2 = weak_pos(o)
			if e.pos.distance_to(wp) < 12.0:
				o.weak_hp = float(o.weak_hp) - 60.0 * torp_bonus
				o.hp -= 120.0 * torp_bonus
				emit("weak_hit", {"id": o.id})
			else:
				o.hp -= 6.0
			if o.hp <= 0.0 or float(o.weak_hp) <= 0.0:
				o.hp = 0.0
				o.state = "dead"
				_kill(o)
			continue
		if o.fac == "free" or o.kind in ["skip", "pod", "diner", "freighter"] or o.kind == "debris":
			if o.kind != "debris":
				stats["friendly_fire"] = int(stats["friendly_fire"]) + 1
				emit("friendly_fire", {"name": o.name, "id": o.id, "kind": o.kind})
		o.hp -= 45.0 * torp_bonus
		if o.hp <= 0.0:
			if o.kind == "mine":
				o.dead = true
			else:
				_kill(o)
	if e.pos.distance_to(ship.pos) < blast + ship.radius:
		ship.hit((e.pos - ship.pos).normalized(), 35.0, "own_torp")
		damages_billed += 35.0
		emit("friendly_fire", {"name": "your own ship", "id": 0, "kind": "ship"})

func _collide(dt: float) -> void:
	for e in ents:
		if e.dead or not e.solid:
			continue
		var d_vec: Vector2 = ship.pos - e.pos
		var d: float = d_vec.length()
		var rad: float = ship.radius + float(e.r)
		if d < rad and d > 0.001:
			var n: Vector2 = d_vec / d
			var rel: Vector2 = ship.vel - e.vel
			var vn: float = rel.dot(n)
			# separate
			ship.pos += n * (rad - d)
			if vn < 0.0:
				var m_e: float = float(e.get("mass", 1000.0))
				var j: float = -(1.0 + 0.45) * vn / (1.0 / ship.mass + 1.0 / m_e)
				ship.vel += n * (j / ship.mass)
				e.vel -= n * (j / m_e)
				var impact: float = -vn
				ship.angvel += (rng.randf() - 0.5) * impact * 0.08
				if impact > 3.0:
					var dmg: float = (impact - 3.0) * 1.6
					ship.hit(-n, dmg, "collision")
					damages_billed += dmg
					stats["collisions"] = int(stats["collisions"]) + 1
					stats["max_collision"] = maxf(float(stats["max_collision"]), impact)
					emit("collision", {"speed": impact, "name": e.name, "kind": e.kind})
					emit("boom", {"pos": ship.pos - n * ship.radius, "size": clampf(impact * 0.5, 3.0, 14.0)})

func _sensors_step(dt: float) -> void:
	ping_t = maxf(0.0, ping_t - dt)
	ping_cd = maxf(0.0, ping_cd - dt)
	reveal_t = maxf(0.0, reveal_t - dt)
	iscan_cd = maxf(0.0, iscan_cd - dt)
	# comms drift chore
	comms["vel"] = float(comms["vel"]) * (1.0 - 0.4 * dt) + (rng.randf() - 0.5) * 0.04 * dt
	comms["freq"] = clampf(float(comms["freq"]) + float(comms["vel"]) * dt, 0.0, 1.0)
	if comms["freq"] <= 0.0 or comms["freq"] >= 1.0:
		comms["vel"] = -float(comms["vel"])
	# scanning
	if scan["on"]:
		var e: Dictionary = find(int(scan["target"]))
		if e.is_empty() or e.pos.distance_to(ship.pos) > sensor_range() * 0.95:
			scan["progress"] = maxf(0.0, float(scan["progress"]) - dt * 0.5)
		else:
			var rate: float = maxf(0.3, ship.pf("sensors") * ship.eff("SENS"))
			scan["progress"] = float(scan["progress"]) + dt * rate / 2.5
			if scan["progress"] >= 1.0:
				e.scan = t
				scan["progress"] = 0.0
				scan["on"] = false
				emit("scanned", {"id": e.id, "kind": e.kind, "name": e.name})
	# hails
	if not hails.is_empty():
		var h: Dictionary = hails[0]
		h.t += dt
		var q: float = absf(float(comms["freq"]) - float(h["freq"]))
		comms["target"] = h["freq"]
		var sens_ok: bool = ship.eff("SENS") > 0.0 and ship.pf("sensors") > 0.0
		if q < 0.04 and sens_ok:
			comms["tuned_t"] = float(comms["tuned_t"]) + dt
			if comms["tuned_t"] >= 1.2:
				captain_comms.append({"from": h.from, "text": h.text, "t": t})
				emit("hail", {"from": h.from, "text": h.text})
				hails.pop_front()
				comms["tuned_t"] = 0.0
		else:
			comms["tuned_t"] = 0.0
		if not hails.is_empty() and hails[0] == h and h.t > float(h["ttl"]):
			hails.pop_front()
			emit("hail_lost", {"from": h.from})
	var keep: Array = []
	for c in captain_comms:
		if t - float(c.t) < 12.0:
			keep.append(c)
	captain_comms = keep

func _tractor_step(dt: float) -> void:
	if tractor_id < 0:
		return
	var e: Dictionary = find(tractor_id)
	if e.is_empty():
		tractor_id = -1
		return
	var p: float = ship.pf("ops") * ship.eff("OPSB")
	if p <= 0.0:
		return
	var d: float = e.pos.distance_to(ship.pos)
	var rng_t: float = 70.0 + 30.0 * p
	if d > rng_t:
		return
	if e.get("solid", false) and e.kind != "skip":
		return
	var rel: Vector2 = e.vel - ship.vel
	e.vel -= rel * minf(1.0, 1.4 * p * dt)
	var to: Vector2 = (ship.pos - e.pos).normalized()
	e.vel += to * (3.0 + 4.0 * p) * dt
	if d < ship.radius + float(e.r) + 6.0 and rel.length() < 9.0:
		e.dead = true
		tractor_id = -1
		emit("collected", {"id": e.id, "kind": e.kind, "name": e.name, "data": e.get("data", {})})

# ---------------------------------------------------------------- repair work

func target_task(target: String) -> Dictionary:
	## Describes the next repair task for a target ("mod:ID" or "con:CID"): kind, rate (progress/sec), mash.
	if target.begins_with("trc:"):
		var tcid: String = target.substr(4)
		var tc: Dictionary = ship.conduits.get(tcid, {})
		if tc.is_empty() or not tc.cut or not tc.hidden:
			return {}
		return {"kind": "trace", "rate": 0.5, "mash": false, "label": "Trace the break"}
	if target.begins_with("con:"):
		var cid: String = target.substr(4)
		var c: Dictionary = ship.conduits.get(cid, {})
		if c.is_empty() or not c.cut:
			return {}
		return {"kind": "splice", "rate": 0.25, "mash": false, "label": "Splice conduit"}
	if target.begins_with("mod:"):
		var id: String = target.substr(4)
		if not ship.modules.has(id):
			return {}
		var m: Dictionary = ship.modules[id]
		if m.fire > 0.0:
			return {"kind": "fire", "rate": 0.33, "mash": false, "label": "Put out fire"}
		if m.breach:
			return {"kind": "breach", "rate": 0.33, "mash": false, "label": "Weld breach"}
		if m.fault != "" and ship.mod_state(id) >= 2:
			return {"kind": "unjam", "rate": 0.0, "mash": true, "label": "Kick it until it works"}
		if m.hp < 99.0:
			var hard: bool = ship.mod_state(id) >= 3
			return {"kind": "repair", "rate": 0.29 if hard else 0.5, "mash": false, "label": "Repair module", "hard": hard}
	return {}

func start_hold(actor: String, target: String, quick_station: String = "") -> void:
	holds[actor] = {"target": target, "quick": quick_station}

func stop_hold(actor: String) -> void:
	holds.erase(actor)

func click_work(target: String, quick_station: String = "", actor: String = "") -> void:
	var task: Dictionary = target_task(target)
	if task.is_empty() or not task.mash:
		return
	if not _can_work(target, task, quick_station):
		return
	mash[target] = minf(1.0, float(mash.get(target, 0.0)) + 0.13)
	if mash[target] >= 1.0:
		last_actor = actor
		_finish(target, task)

func _can_work(target: String, task: Dictionary, quick_station: String) -> bool:
	if quick_station == "":
		return true
	# Quick fixes at your own post: only your own modules, and only soft faults (not failed, not fire/breach).
	if not target.begins_with("mod:"):
		return false
	var id: String = target.substr(4)
	var m: Dictionary = ship.modules[id]
	if m.owner != quick_station:
		return false
	if task.kind in ["fire", "breach"]:
		return false
	if ship.mod_state(id) >= 3:
		return false
	return true

func _finish(target: String, task: Dictionary) -> void:
	mash.erase(target)
	if target.begins_with("trc:"):
		var tcid: String = target.substr(4)
		ship.conduits[tcid].hidden = false
		trace_prog.erase(tcid)
		return
	stats["repairs"] = int(stats["repairs"]) + 1
	if target.begins_with("con:"):
		ship.repair_conduit(target.substr(4))
		return
	var id: String = target.substr(4)
	var m: Dictionary = ship.modules[id]
	match task.kind:
		"fire":
			m.fire = 0.0
			m.fire_t = 0.0
			m.work = 0.0
			stats["fires_put_out"] = int(stats["fires_put_out"]) + 1
			emit("fire_out", {"id": id, "label": m.label})
		"breach":
			m.breach = false
			m.work = 0.0
			emit("breach_sealed", {"id": id, "label": m.label})
		_:
			ship.repair_module(id)

func _work_step(dt: float) -> void:
	for actor in holds.keys():
		var h: Dictionary = holds[actor]
		var target: String = h.target
		var task: Dictionary = target_task(target)
		if task.is_empty() or task.mash:
			continue
		if not _can_work(target, task, h.quick):
			continue
		var rate: float = float(task.rate) * (1.5 if h.quick != "" else 1.0)
		if target.begins_with("trc:"):
			var tcid2: String = target.substr(4)
			trace_prog[tcid2] = float(trace_prog.get(tcid2, 0.0)) + rate * dt
			if trace_prog[tcid2] >= 1.0:
				last_actor = actor
				_finish(target, task)
				holds.erase(actor)
			continue
		if target.begins_with("con:"):
			var cid: String = target.substr(4)
			var c: Dictionary = ship.conduits[cid]
			if not ship.isolate[cid]:
				c.zap = float(c.zap) + dt
				if c.zap > 2.5:
					c.zap = 0.0
					c.work = 0.0
					zap_events.append(cid)
					emit("zap", {"id": cid})
					continue
			c.work = float(c.work) + rate * dt
			if c.work >= 1.0:
				last_actor = actor
				_finish(target, task)
				holds.erase(actor)
			continue
		var id: String = target.substr(4)
		var m: Dictionary = ship.modules[id]
		m.work = float(m.work) + rate * dt
		if m.work >= 1.0:
			last_actor = actor
			_finish(target, task)
			holds.erase(actor)
	# mash decay
	for k in mash.keys():
		mash[k] = float(mash[k]) - 0.25 * dt
		if mash[k] <= 0.0:
			mash.erase(k)
	# work decays when nobody holds
	for id in ship.mod_order:
		var m2: Dictionary = ship.modules[id]
		if m2.work > 0.0 and not _held("mod:" + id):
			m2.work = maxf(0.0, float(m2.work) - 0.2 * dt)
	for cid in K.CONDUITS:
		var c2: Dictionary = ship.conduits[cid]
		if c2.work > 0.0 and not _held("con:" + cid):
			c2.work = maxf(0.0, float(c2.work) - 0.2 * dt)
		if c2.zap > 0.0 and not _held("con:" + cid):
			c2.zap = 0.0

func _held(target: String) -> bool:
	for a in holds.keys():
		if holds[a].target == target:
			return true
	return false

func weakest_threat_facing() -> int:
	var best: int = 0
	var bd: float = 1e9
	for e in ents:
		if e.dead or not (e.kind in ["grabber", "snatch", "patrol", "bastion", "magnificence", "ebullet", "eshell"]):
			continue
		var d: float = e.pos.distance_to(ship.pos) - float(e.r)
		if d < bd:
			bd = d
			var a: float = (e.pos - ship.pos).angle() - ship.heading
			a = K.wrap_pi(a)
			if a > PI / 4.0 and a <= 3.0 * PI / 4.0:
				best = 1
			elif a > -3.0 * PI / 4.0 and a <= -PI / 4.0:
				best = 3
			elif absf(a) > 3.0 * PI / 4.0:
				best = 2
			else:
				best = 0
	return best

# ---------------------------------------------------------------- weapons rules

func _weapons_step(dt: float) -> void:
	var pw: float = ship.pf("weapons")
	for id in ["TUR_A", "TUR_B"]:
		var m: Dictionary = ship.modules[id]
		if load_hold.get(id, false) and not m.loaded and ship.online(id) and pw > 0.0:
			m.load_p += dt / 1.2 * maxf(0.5, pw)
			if m.load_p >= 1.0:
				m.loaded = true
				m.load_p = 0.0
		# tracking assist
		if track.get(id, false) and ship.online(id):
			var tgt: Dictionary = find(lock_id)
			if not tgt.is_empty():
				var aim: Vector2 = _lead_point(tgt, 220.0)
				if lock_weak and tgt.kind == "bastion":
					aim = weak_pos(tgt)
				var local_ang: float = K.wrap_pi((aim - turret_pos(id)).angle() - ship.heading)
				m.tgt = ship.clamp_arc(id, local_ang)
		# jammed turret fires on its own
		if m.fault == "jam" and ship.mod_state(id) >= 2 and m.loaded and m.cd <= 0.0 and rng.randf() < 0.01:
			fire_turret(id, true)
		if m.loaded == false and m.fault == "jam" and ship.mod_state(id) >= 2:
			m.loaded = true
	var tube: Dictionary = ship.modules["TUBE"]
	if load_hold.get("TUBE", false) and tube.tstate == "empty" and ship.online("TUBE") and pw > 0.0:
		tube.load_p += dt / 3.0 * maxf(0.5, pw)
		if tube.load_p >= 1.0:
			tube.tstate = "loaded"
			tube.load_p = 0.0
	if tube.tstate == "arming":
		tube.arm_p += dt / 1.6
		if tube.arm_p >= 1.0:
			tube.tstate = "armed"
			tube.arm_p = 0.0

func turret_pos(id: String) -> Vector2:
	var m: Dictionary = ship.modules[id]
	return ship.local_to_world(Vector2(m.lx, m.ly))

func _lead_point(tgt: Dictionary, speed: float) -> Vector2:
	var d: float = tgt.pos.distance_to(ship.pos)
	var tof: float = d / speed
	return tgt.pos + (tgt.vel - ship.vel) * tof

func fire_turret(id: String, forced: bool = false) -> bool:
	var m: Dictionary = ship.modules[id]
	if stowed and not forced:
		return false
	if not ship.online(id) or not m.loaded or m.cd > 0.0 or ship.pf("weapons") <= 0.0:
		return false
	var dir: Vector2 = Vector2.from_angle(ship.heading + float(m.ang))
	var o: Vector2 = turret_pos(id) + dir * 3.0
	spawn("bullet", o, {"vel": dir * 220.0 + ship.vel, "ang": dir.angle()})
	m.loaded = false
	m.load_p = 0.0
	m.heat += 18.0
	m.cd = 0.35 / maxf(0.4, ship.pf("weapons"))
	stats["shots"] = int(stats["shots"]) + 1
	emit("shot", {"id": id})
	return true

func fire_torp() -> bool:
	var tube: Dictionary = ship.modules["TUBE"]
	if tube.tstate != "armed" or not ship.online("TUBE") or stowed:
		return false
	var dir: Vector2 = ship.fwd()
	var tgt: Dictionary = find(lock_id)
	spawn("torp", ship.pos + dir * 10.0, {"vel": dir * 75.0 + ship.vel * 0.5, "ang": dir.angle(), "target": lock_id if not tgt.is_empty() else -1, "weak": lock_weak})
	tube.tstate = "empty"
	tube.load_p = 0.0
	stats["torps"] = int(stats["torps"]) + 1
	emit("torp_fired", {})
	return true
