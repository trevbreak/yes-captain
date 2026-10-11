class_name Ship
extends RefCounted
## The player ship: a rigid body made of physical modules. Thrusters push from their real
## positions, so losing an engine produces real torque. Everything breaks, and everything can
## be repaired mid-flight.

const CELL: float = 2.5
const MAX_SPEED: float = 100.0
const ENG_FORCE: float = 600.0
const RCS_TORQUE: float = 2400.0
const RCS_STRAFE: float = 400.0

var rng: RandomNumberGenerator
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var heading: float = -PI / 2.0
var angvel: float = 0.0
var accel_mag: float = 0.0
var mass: float = 100.0
var inertia: float = 2400.0
var radius: float = 7.0

var hull: float = 100.0
var hull_max: float = 100.0
var modules: Dictionary = {}
var mod_order: Array = []
var conduits: Dictionary = {}

# controls
var thr_p: float = 0.0
var thr_s: float = 0.0
var link: bool = true
var boost: bool = false
var dampers: bool = true
var yaw: float = 0.0
var strafe: float = 0.0
var trim: float = 0.0
var roll_t: float = 0.0
var roll_dir: float = 1.0
var roll_cd: float = 0.0

# chores
var trim_bias: float = 0.0
var trim_vel: float = 0.0
var mix: float = 0.5
var mix_vel: float = 0.0
var eng_heat: float = 0.0
var thrust_bonus: float = 1.0
var cooler_bonus: float = 1.0
var rcs_bonus: float = 1.0
var pen_bonus: float = 1.0

# power
var alloc: Dictionary = {"engines": 2, "rcs": 2, "weapons": 2, "shields": 2, "sensors": 1, "ops": 1}
var tripped: Dictionary = {"engines": false, "rcs": false, "weapons": false, "shields": false, "sensors": false, "ops": false}
var trip_timer: Dictionary = {"engines": 0.0, "rcs": 0.0, "weapons": 0.0, "shields": 0.0, "sensors": 0.0, "ops": 0.0}
var reactor_heat: float = 30.0
var cool_p: float = 60.0
var pump: bool = false
var vent_cd: float = 0.0
var oc_sys: String = ""
var oc_t: float = 0.0
var scram_t: float = 0.0
var isolate: Dictionary = {"C_PORT": false, "C_STAR": false, "C_CORE": false, "C_UTIL": false}
var jump_charge: float = 0.0
var charging: bool = false
var avail: float = 12.0
var used: float = 10.0
var brown: float = 1.0
var coolant_leak: bool = false

# shields
var shield: Array = [40.0, 40.0, 40.0, 40.0]
var shield_w: Array = [1, 1, 1, 1]

# pudding
var pud: Dictionary = {"aboard": true, "mood": 25.0, "loose": false, "at": "PEN", "move_t": 0.0, "chew_t": 4.0,
	"warn": 0.0, "music": false, "pat_cd": 0.0, "snack_cd": 0.0, "return_t": 0.0}
var snacks: int = 5
var beacons: int = 2

# cargo
var cargo: Array = []
var cargo_secured: bool = false

# dispatched repair bot
var bot_job: String = ""
var bot_progress: float = 0.0

var leak_t: float = 0.0
var damage_mult: float = 1.0
var dampers_locked: bool = false
var shake: float = 0.0
var hit_flash: float = 0.0
var events: Array = []
var last_local_force: Vector2 = Vector2.ZERO
var last_torque: float = 0.0
var damage_taken: float = 0.0

func _init(r: RandomNumberGenerator = null) -> void:
	rng = r if r != null else RandomNumberGenerator.new()
	_build()

func _mk(id: String, type: String, gx: int, gy: int, conduit: String, owner: String, label: String) -> void:
	modules[id] = {"id": id, "type": type, "gx": gx, "gy": gy, "lx": (2 - gy) * CELL, "ly": (gx - 2) * CELL,
		"hp": 100.0, "fire": 0.0, "fire_t": 0.0, "breach": false, "conduit": conduit, "owner": owner,
		"label": label, "fault": "", "warn": 0.0, "warn_fault": "", "work": 0.0, "patched": 0, "ang": 0.0, "tgt": 0.0,
		"loaded": true, "heat": 0.0, "load_p": 0.0, "arm_p": 0.0, "tstate": "empty", "cd": 0.0}
	mod_order.append(id)

func _build() -> void:
	_mk("SENS", "sensor", 1, 0, "C_CORE", "sensors", "Sensors")
	_mk("BRDG", "bridge", 2, 0, "C_UTIL", "", "Bridge")
	_mk("JUMP", "jump", 3, 0, "C_CORE", "power", "Jump Drive")
	_mk("RCS_FP", "rcs", 0, 1, "C_PORT", "helm", "RCS F-Port")
	_mk("TUR_A", "turret", 1, 1, "C_PORT", "weapons", "Port Gun")
	_mk("SHLD", "shield", 2, 1, "C_CORE", "ops", "Shields")
	_mk("TUR_B", "turret", 3, 1, "C_STAR", "weapons", "Star Gun")
	_mk("RCS_FS", "rcs", 4, 1, "C_STAR", "helm", "RCS F-Star")
	_mk("COOL", "coolant", 1, 2, "C_PORT", "power", "Coolant")
	_mk("RCTR", "reactor", 2, 2, "", "power", "Reactor")
	_mk("DAMP", "damper", 3, 2, "C_STAR", "engines", "Dampers")
	_mk("RCS_AP", "rcs", 0, 3, "C_PORT", "helm", "RCS A-Port")
	_mk("OPSB", "ops", 1, 3, "C_UTIL", "ops", "Ops Bay")
	_mk("CARGO", "cargo", 2, 3, "C_UTIL", "ops", "Cargo")
	_mk("PEN", "pen", 3, 3, "C_UTIL", "ops", "Pudding Pen")
	_mk("RCS_AS", "rcs", 4, 3, "C_STAR", "helm", "RCS A-Star")
	_mk("ENG_P", "engine", 1, 4, "C_PORT", "engines", "Port Engine")
	_mk("TUBE", "tube", 2, 4, "C_CORE", "weapons", "Torpedo")
	_mk("ENG_S", "engine", 3, 4, "C_STAR", "engines", "Star Engine")
	for c in K.CONDUITS:
		conduits[c] = {"cut": false, "hidden": false, "work": 0.0, "zap": 0.0}
	modules["TUR_A"]["ang"] = 0.0
	modules["TUR_B"]["ang"] = 0.0

func reset_for_encounter() -> void:
	# Between encounters: modules are free to fix, so everything is patched up except hull wear.
	for id in mod_order:
		var m: Dictionary = modules[id]
		if m.hp < 100.0 or m.fire > 0.0 or m.breach or m.fault != "":
			m.patched = int(m.patched) + 1
		m.hp = 100.0
		m.fire = 0.0
		m.breach = false
		m.fault = ""
		m.warn = 0.0
		m.work = 0.0
	for c in K.CONDUITS:
		conduits[c] = {"cut": false, "hidden": false, "work": 0.0, "zap": 0.0}
	scram_t = 0.0
	reactor_heat = 30.0
	cool_p = 60.0
	coolant_leak = false
	eng_heat = 0.0
	pud["loose"] = false
	pud["at"] = "PEN"
	pud["mood"] = minf(pud["mood"], 30.0)
	bot_job = ""
	for i in 4:
		shield[i] = 40.0
	for s in K.SYSTEMS:
		tripped[s] = false
		trip_timer[s] = 0.0
	oc_sys = ""
	oc_t = 0.0
	link = true
	boost = false
	trim = 0.0

# ---------------------------------------------------------------- queries

func mod_state(id: String) -> int:
	var hp: float = modules[id].hp
	if hp > 70.0:
		return 0
	if hp > 40.0:
		return 1
	if hp > 15.0:
		return 2
	return 3

func conduit_ok(cid: String) -> bool:
	if cid == "":
		return true
	return not conduits[cid].cut and not isolate[cid]

func online(id: String) -> bool:
	if scram_t > 0.0:
		return false
	var m: Dictionary = modules[id]
	if m.hp <= 15.0:
		return false
	return conduit_ok(m.conduit)

func eff(id: String) -> float:
	if not online(id):
		return 0.0
	var st: int = mod_state(id)
	if st == 0:
		return 1.0
	if st == 1:
		return 0.85
	return 0.5

func pf(sys: String) -> float:
	if scram_t > 0.0 or tripped[sys]:
		return 0.0
	var p: float = float(alloc[sys]) * brown
	if oc_sys == sys:
		p *= 1.5
	return clampf(p / 2.0, 0.0, 1.75)

func local_to_world(l: Vector2) -> Vector2:
	return pos + l.rotated(heading)

func fwd() -> Vector2:
	return Vector2.from_angle(heading)

func speed() -> float:
	return vel.length()

func neighbors(id: String) -> Array:
	var m: Dictionary = modules[id]
	var out: Array = []
	for oid in mod_order:
		if oid == id:
			continue
		var o: Dictionary = modules[oid]
		if absi(int(o.gx) - int(m.gx)) + absi(int(o.gy) - int(m.gy)) == 1:
			out.append(oid)
	return out

func open_problems() -> Dictionary:
	# used by the Chaos Director and by tests
	var per: Dictionary = {}
	for s in K.STATIONS:
		per[s] = 0
	var critical: int = 0
	for id in mod_order:
		var m: Dictionary = modules[id]
		var st: int = mod_state(id)
		var o: String = m.owner
		if st >= 2 or m.fire > 0.0 or m.breach:
			critical += 1
			if o != "":
				per[o] += 1
	for c in K.CONDUITS:
		if conduits[c].cut:
			critical += 1
			per["power"] += 1
	if scram_t > 0.0:
		critical += 1
	return {"per": per, "critical": critical}

# ---------------------------------------------------------------- damage API

func damage_module(id: String, amt: float) -> void:
	var m: Dictionary = modules[id]
	var before: int = mod_state(id)
	m.hp = maxf(3.0, m.hp - amt * damage_mult)
	var after: int = mod_state(id)
	if after >= 3 and before < 3:
		if m.fault == "":
			m.fault = _default_fault(m.type)
		events.append(["module_fail", {"id": id, "label": m.label, "owner": m.owner}])
		if rng.randf() < 0.3 and m.conduit != "":
			cut_conduit(m.conduit, true)
	elif after >= 1 and before == 0:
		events.append(["module_rattle", {"id": id, "label": m.label, "owner": m.owner}])

func _default_fault(type: String) -> String:
	match type:
		"engine":
			return "stuck_full" if rng.randf() < 0.4 else ""
		"turret":
			return "jam" if rng.randf() < 0.5 else ""
		"sensor":
			return "mirror" if rng.randf() < 0.5 else ""
		"cargo":
			return "doors"
	return ""

func cut_conduit(cid: String, hidden: bool) -> void:
	if conduits[cid].cut:
		return
	conduits[cid].cut = true
	conduits[cid].hidden = hidden
	conduits[cid].work = 0.0
	events.append(["conduit_cut", {"id": cid, "hidden": hidden}])

func set_fire(id: String) -> void:
	var m: Dictionary = modules[id]
	if m.fire <= 0.0:
		m.fire = 1.0
		m.fire_t = 0.0
		events.append(["fire", {"id": id, "label": m.label, "owner": m.owner}])

func set_breach(id: String) -> void:
	var m: Dictionary = modules[id]
	if not m.breach:
		m.breach = true
		events.append(["breach", {"id": id, "label": m.label, "owner": m.owner}])

func schedule_failure(id: String, fault: String, warn_time: float = 4.0) -> void:
	var m: Dictionary = modules[id]
	if m.warn > 0.0 or mod_state(id) >= 2:
		return
	m.warn = warn_time
	m.warn_fault = fault
	m.hp = minf(m.hp, 60.0)
	events.append(["module_rattle", {"id": id, "label": m.label, "owner": m.owner}])

func repair_module(id: String) -> void:
	var m: Dictionary = modules[id]
	if id == "COOL":
		coolant_leak = false
	var was: bool = m.hp < 100.0 or m.fire > 0.0 or m.breach or m.fault != ""
	m.hp = 100.0
	m.fire = 0.0
	m.fire_t = 0.0
	m.breach = false
	m.fault = ""
	m.warn = 0.0
	m.work = 0.0
	if was:
		m.patched = int(m.patched) + 1
		events.append(["repaired", {"id": id, "label": m.label, "owner": m.owner}])

func repair_conduit(cid: String) -> void:
	conduits[cid].cut = false
	conduits[cid].hidden = false
	conduits[cid].work = 0.0
	events.append(["conduit_fixed", {"id": cid}])

func hit(dir: Vector2, dmg: float, kind: String) -> void:
	## dir: world-space unit vector pointing from the ship toward the damage source.
	var local_dir: Vector2 = dir.rotated(-heading)
	var ang: float = local_dir.angle()
	var facing: int = 0
	if ang > PI / 4.0 and ang <= 3.0 * PI / 4.0:
		facing = 1
	elif ang > -3.0 * PI / 4.0 and ang <= -PI / 4.0:
		facing = 3
	elif absf(ang) > 3.0 * PI / 4.0:
		facing = 2
	var absorbed: float = minf(float(shield[facing]), dmg)
	shield[facing] = float(shield[facing]) - absorbed
	var rem: float = dmg - absorbed
	damage_taken += dmg
	if absorbed > 0.0:
		events.append(["shield_hit", {"facing": facing, "amount": absorbed, "kind": kind}])
	shake = minf(1.5, shake + 0.25 + dmg / 40.0)
	hit_flash = 0.3
	pud["mood"] = minf(100.0, float(pud["mood"]) + dmg * 0.5)
	if rem <= 0.5:
		return
	hull -= rem * 0.35
	var pt: Vector2 = local_dir * 6.0
	var best: String = ""
	var bd: float = 1e9
	for id in mod_order:
		var m: Dictionary = modules[id]
		var d: float = pt.distance_to(Vector2(m.lx, m.ly))
		if d < bd:
			bd = d
			best = id
	damage_module(best, rem * 1.6)
	for nid in neighbors(best):
		damage_module(nid, rem * 0.5)
	if rem > 8.0 and rng.randf() < 0.28:
		set_fire(best)
	if rem > 10.0 and rng.randf() < 0.22:
		set_breach(best)
	events.append(["hull_hit", {"amount": rem, "id": best, "kind": kind}])

# ---------------------------------------------------------------- stepping

func step(dt: float) -> void:
	_power_step(dt)
	_chores_step(dt)
	_damage_step(dt)
	_pudding_step(dt)
	_physics_step(dt)
	_shield_step(dt)
	_cargo_step(dt)
	_turret_step(dt)
	shake = maxf(0.0, shake - dt * 1.2)
	hit_flash = maxf(0.0, hit_flash - dt)

func _power_step(dt: float) -> void:
	var total: float = 0.0
	for s in K.SYSTEMS:
		total += float(alloc[s])
	var rhp: float = clampf(float(modules["RCTR"].hp) / 100.0, 0.35, 1.0)
	var heatpen: float = maxf(0.0, reactor_heat - 60.0) / 12.0
	avail = maxf(3.0, floorf(12.0 * rhp - heatpen))
	used = total
	brown = 1.0 if total <= avail else avail / total
	var gain: float = 0.15 * minf(total, avail)
	if oc_sys != "":
		gain += 5.0
	var cool_eff: float = maxf(0.3, eff("COOL"))
	var cool: float = (0.8 + 4.0 * (cool_p / 100.0)) * cool_eff * cooler_bonus
	if scram_t > 0.0:
		gain = 0.0
		cool = 6.0
	reactor_heat = clampf(reactor_heat + (gain - cool) * dt, 0.0, 120.0)
	if pump:
		cool_p = minf(100.0, cool_p + 30.0 * dt)
	else:
		cool_p = maxf(0.0, cool_p - (1.5 + (6.0 if coolant_leak else 0.0)) * dt)
	vent_cd = maxf(0.0, vent_cd - dt)
	if reactor_heat >= 100.0 and scram_t <= 0.0:
		scram_t = 5.0
		reactor_heat = 60.0
		oc_sys = ""
		oc_t = 0.0
		events.append(["scram", {}])
	if scram_t > 0.0:
		scram_t = maxf(0.0, scram_t - dt)
		if scram_t == 0.0:
			events.append(["power_back", {}])
	if oc_sys != "":
		oc_t -= dt
		if oc_t <= 0.0:
			oc_sys = ""
	for s in K.SYSTEMS:
		if int(alloc[s]) > 4:
			trip_timer[s] = float(trip_timer[s]) + dt
			if float(trip_timer[s]) > 6.0 and not tripped[s]:
				tripped[s] = true
				trip_timer[s] = 0.0
				events.append(["breaker", {"sys": s}])
		else:
			trip_timer[s] = maxf(0.0, float(trip_timer[s]) - dt)
	# jump capacitor
	if charging and pf("ops") > 0.0 and eff("JUMP") > 0.0:
		jump_charge = minf(1.0, jump_charge + 0.12 * pf("ops") * eff("JUMP") * dt)
	else:
		jump_charge = maxf(0.0, jump_charge - 0.05 * dt)

func _chores_step(dt: float) -> void:
	trim_vel = trim_vel * (1.0 - 0.3 * dt) + (rng.randf() - 0.5) * 0.9 * dt
	trim_bias += trim_vel * dt
	if absf(trim_bias) > 1.0:
		trim_bias = signf(trim_bias)
		trim_vel = -trim_vel * 0.5
	mix_vel = mix_vel * (1.0 - 0.3 * dt) + (rng.randf() - 0.5) * 0.12 * dt
	mix += mix_vel * dt
	if mix < 0.0 or mix > 1.0:
		mix = clampf(mix, 0.0, 1.0)
		mix_vel = -mix_vel * 0.5
	# engine heat
	var avg: float = (absf(thr_p) + absf(thr_s)) * 0.5
	var mixbad: float = clampf(absf(mix - 0.5) - 0.15, 0.0, 0.35) / 0.35
	var g: float = avg * (2.6 if boost else 1.0) * 4.0 + mixbad * 1.5
	eng_heat = clampf(eng_heat + (g - 3.0) * dt, 0.0, 130.0)
	if eng_heat > 100.0:
		damage_module("ENG_P", 3.0 * dt)
		damage_module("ENG_S", 3.0 * dt)
	if modules["ENG_P"].fault == "stuck_full" and mod_state("ENG_P") < 2:
		modules["ENG_P"].fault = ""
	if modules["ENG_S"].fault == "stuck_full" and mod_state("ENG_S") < 2:
		modules["ENG_S"].fault = ""
	var any_down: bool = mod_state("ENG_P") >= 2 or mod_state("ENG_S") >= 2
	if any_down:
		link = false
	roll_t = maxf(0.0, roll_t - dt)
	roll_cd = maxf(0.0, roll_cd - dt)

func _damage_step(dt: float) -> void:
	var breaches: int = 0
	var fires: int = 0
	for id in mod_order:
		var m: Dictionary = modules[id]
		if m.warn > 0.0:
			m.warn -= dt
			if m.warn <= 0.0:
				m.warn = 0.0
				m.hp = 5.0
				m.fault = m.warn_fault
				events.append(["module_fail", {"id": id, "label": m.label, "owner": m.owner}])
				if m.warn_fault == "cut_conduit" and m.conduit != "":
					m.fault = ""
					cut_conduit(m.conduit, true)
		if m.fire > 0.0:
			fires += 1
			m.hp = maxf(5.0, m.hp - 4.0 * dt)
			m.fire_t += dt
			if m.fire_t > 20.0:
				m.fire_t = 0.0
				var ns: Array = neighbors(id)
				var cand: Array = []
				for n in ns:
					if modules[n].fire <= 0.0:
						cand.append(n)
				if not cand.is_empty():
					set_fire(cand[rng.randi() % cand.size()])
		if m.breach:
			breaches += 1
	hull -= (0.12 * breaches + 0.04 * fires) * dt
	hull = clampf(hull, -5.0, hull_max)
	# bot repair job
	if bot_job != "":
		var m2: Dictionary = modules.get(bot_job, {})
		if m2.is_empty() or (m2.hp >= 100.0 and m2.fire <= 0.0 and not m2.breach and m2.fault == ""):
			bot_job = ""
			bot_progress = 0.0
		elif m2.fire <= 0.0:
			bot_progress += dt * 0.1
			if bot_progress >= 1.0:
				repair_module(bot_job)
				bot_job = ""
				bot_progress = 0.0

func _pudding_step(dt: float) -> void:
	if not pud["aboard"]:
		return
	var mood: float = pud["mood"]
	var open: Dictionary = open_problems()
	mood += (-0.6 + (minf(4, int(open["critical"])) * 0.5 + maxf(0.0, absf(angvel) - 1.0) * 3.0) * pen_bonus) * dt
	if pud["music"] and eff("OPSB") > 0.0:
		mood -= 2.5 * dt
	if scram_t > 0.0:
		mood += 6.0 * dt
	pud["pat_cd"] = maxf(0.0, pud["pat_cd"] - dt)
	pud["snack_cd"] = maxf(0.0, pud["snack_cd"] - dt)
	mood = clampf(mood, 0.0, 100.0)
	pud["mood"] = mood
	if not pud["loose"]:
		if mood >= 88.0:
			pud["warn"] = pud["warn"] + dt
			if pud["warn"] > 3.0 and online("PEN") or (pud["warn"] > 6.0):
				pud["loose"] = true
				pud["at"] = "PEN"
				pud["chew_t"] = 4.0
				pud["warn"] = 0.0
				events.append(["pudding_loose", {}])
		else:
			pud["warn"] = maxf(0.0, pud["warn"] - dt)
	else:
		if pud["return_t"] > 0.0:
			pud["return_t"] = pud["return_t"] - dt
			if pud["return_t"] <= 0.0:
				pud["loose"] = false
				pud["at"] = "PEN"
				pud["mood"] = maxf(0.0, pud["mood"] - 15.0)
				events.append(["pudding_back", {}])
			return
		pud["chew_t"] = pud["chew_t"] - dt
		if pud["chew_t"] <= 0.0:
			pud["chew_t"] = 5.5
			var ns: Array = neighbors(pud["at"])
			if not ns.is_empty():
				pud["at"] = ns[rng.randi() % ns.size()]
			var m: Dictionary = modules[pud["at"]]
			if m.conduit != "" and not conduits[m.conduit].cut and rng.randf() < 0.65:
				cut_conduit(m.conduit, true)
				events.append(["pudding_chew", {"id": pud["at"], "label": m.label}])
			else:
				damage_module(pud["at"], 22.0)
				events.append(["pudding_chew", {"id": pud["at"], "label": m.label}])

func _physics_step(dt: float) -> void:
	var f: Vector2 = Vector2.ZERO
	var tau: float = 0.0
	var pfe: float = pf("engines")
	var mixf: float = 1.0 - clampf(absf(mix - 0.5) - 0.15, 0.0, 0.35) / 0.35 * 0.4
	var t_now: float = Time.get_ticks_msec() / 1000.0
	for side in [-1, 1]:
		var id: String = "ENG_P" if side < 0 else "ENG_S"
		var m: Dictionary = modules[id]
		var thr: float = thr_p if side < 0 else thr_s
		if m.fault == "stuck_full" and mod_state(id) >= 2:
			thr = 1.0
		var e: float = eff(id)
		if m.fault == "stuck_full" and mod_state(id) >= 2:
			e = 1.0 if online(id) else 0.0
		if mod_state(id) == 1:
			thr *= 1.0 + 0.15 * sin(t_now * 9.0 + side)
		var mag: float = thr * ENG_FORCE * e * pfe * mixf * thrust_bonus
		if thr > 0.0 and boost:
			mag *= 1.6
		if thr < 0.0:
			mag *= 0.5
		f.x += mag
		tau += -float(m.ly) * mag
		# torque from a force along +x at (lx, ly): tau = x*Fy - y*Fx
	# RCS
	var rp: float = pf("rcs")
	var yaw_auth_pos: float = (eff("RCS_FP") + eff("RCS_AS")) * 0.5
	var yaw_auth_neg: float = (eff("RCS_FS") + eff("RCS_AP")) * 0.5
	var y: float = clampf(yaw, -1.0, 1.0)
	tau += y * RCS_TORQUE * rcs_bonus * rp * (yaw_auth_pos if y > 0.0 else yaw_auth_neg)
	var sa_pos: float = (eff("RCS_FP") + eff("RCS_AP")) * 0.5
	var sa_neg: float = (eff("RCS_FS") + eff("RCS_AS")) * 0.5
	var s: float = clampf(strafe, -1.0, 1.0)
	f.y += s * RCS_STRAFE * rp * (sa_pos if s > 0.0 else sa_neg)
	# trim drift chore
	tau += (trim_bias - trim) * 600.0
	# emergency roll
	if roll_t > 0.0:
		tau += roll_dir * 7000.0
	# breaches vent as thrusters
	for id in mod_order:
		var m2: Dictionary = modules[id]
		if m2.breach:
			var out: Vector2 = Vector2(m2.lx, m2.ly)
			if out.length() < 0.1:
				out = Vector2(0, 1)
			var fv: Vector2 = out.normalized() * 90.0
			f += fv
			tau += float(m2.lx) * fv.y - float(m2.ly) * fv.x
	last_local_force = f
	last_torque = tau
	var fw: Vector2 = f.rotated(heading)
	var old_v: Vector2 = vel
	var acc: Vector2 = fw / mass
	var damp_eff: float = eff("DAMP") if dampers else 0.0
	if damp_eff > 0.0:
		acc -= vel * 0.25 * damp_eff
		if absf(thr_p) + absf(thr_s) < 0.06 and vel.length() > 0.05:
			var brake: float = minf(vel.length() / dt, 4.0 * damp_eff)
			acc -= vel.normalized() * brake
	vel += acc * dt
	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED
	var alpha: float = tau / inertia
	if damp_eff > 0.0:
		alpha -= angvel * 1.0 * damp_eff
	angvel += alpha * dt
	angvel = clampf(angvel, -8.0, 8.0)
	pos += vel * dt
	heading = wrapf(heading + angvel * dt, -PI, PI)
	accel_mag = (vel - old_v).length() / dt

func _shield_step(dt: float) -> void:
	var pfs: float = pf("shields") * eff("SHLD")
	var wsum: float = 0.0
	for i in 4:
		wsum += float(shield_w[i])
	if wsum <= 0.0:
		wsum = 1.0
	var total_cap: float = 120.0 * pfs
	for i in 4:
		var cap: float = total_cap * float(shield_w[i]) / wsum
		var s: float = shield[i]
		if s > cap:
			s = maxf(cap, s - 10.0 * dt)
		else:
			s = minf(cap, s + 2.5 * pfs * dt * (1.0 + float(shield_w[i]) * 0.15))
		shield[i] = s

func _cargo_step(dt: float) -> void:
	for c in cargo:
		if c.get("secured", false) or cargo_secured:
			continue
		var lim: float = float(c.get("limit", 99.0))
		if accel_mag > lim:
			c["integrity"] = maxf(0.0, float(c["integrity"]) - (accel_mag - lim) * float(c.get("fragility", 1.0)) * dt * 2.0)
	leak_t = maxf(0.0, leak_t - dt)
	if modules["CARGO"].fault == "doors" and mod_state("CARGO") >= 2 and accel_mag > 3.0 and leak_t <= 0.0:
		leak_t = 0.25
		for c in cargo:
			if c.get("leaks", false):
				var n: int = int(accel_mag * 1.6)
				c["lost"] = int(c.get("lost", 0)) + n
				c["integrity"] = maxf(0.0, float(c["integrity"]) - n * 0.4)
				events.append(["cargo_leak", {"name": c.name, "n": n}])

func _turret_step(dt: float) -> void:
	for id in ["TUR_A", "TUR_B"]:
		var m: Dictionary = modules[id]
		var arc: Array = turret_arc(id)
		var lo: float = arc[0]
		var hi: float = arc[1]
		var rate: float = 1.5 * maxf(0.2, eff(id)) * maxf(0.3, pf("weapons"))
		if m.fault == "jam" and mod_state(id) >= 2:
			m.tgt = lo + (hi - lo) * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 700.0 + (1.0 if id == "TUR_A" else 3.0)))
		m.tgt = clamp_arc(id, m.tgt)
		var d: float = m.tgt - m.ang
		m.ang = m.ang + clampf(d, -rate * dt, rate * dt)
		m.heat = maxf(0.0, m.heat - 12.0 * dt)
		m.cd = maxf(0.0, m.cd - dt)
		if m.heat > 100.0:
			m.heat = 100.0
			m.cd = maxf(m.cd, 3.0)

func turret_arc(id: String) -> Array:
	if id == "TUR_A":
		return [deg_to_rad(-180.0), deg_to_rad(25.0)]
	return [deg_to_rad(-25.0), deg_to_rad(180.0)]

func clamp_arc(id: String, ang: float) -> float:
	## Clamp a turret angle into its arc, respecting the wrap at +/-180 degrees.
	var arc: Array = turret_arc(id)
	var lo: float = arc[0]
	var hi: float = arc[1]
	var a2: float = lo + fposmod(ang - lo, TAU)
	if a2 <= hi:
		return a2
	var d_hi: float = absf(K.wrap_pi(ang - hi))
	var d_lo: float = absf(K.wrap_pi(ang - lo))
	return hi if d_hi < d_lo else lo

func arc_error(id: String, ang: float) -> float:
	return absf(K.wrap_pi(ang - clamp_arc(id, ang)))
