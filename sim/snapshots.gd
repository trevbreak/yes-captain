class_name Snapshots
extends RefCounted
## Per-station filtered views of the world. A station only RECEIVES what that station may know:
## that is how the information asymmetry is enforced (not just hidden in the UI).

static func faults_for(w: World, st: String) -> Array:
	var out: Array = []
	var s: Ship = w.ship
	for id in s.mod_order:
		var m: Dictionary = s.modules[id]
		if m.owner != st:
			continue
		var state: int = s.mod_state(id)
		var nopower: bool = not s.conduit_ok(m.conduit)
		if state >= 1 or m.fire > 0.0 or m.breach or m.fault != "" or nopower or m.warn > 0.0:
			out.append({"id": id, "label": m.label, "state": state, "fire": m.fire > 0.0, "breach": m.breach,
				"fault": m.fault, "nopower": nopower, "work": m.work, "hp": m.hp, "warn": m.warn > 0.0,
				"task": w.target_task("mod:" + id), "mash": w.mash.get("mod:" + id, 0.0)})
	return out

static func rel_bearing(w: World, p: Vector2) -> float:
	return K.wrap_pi((p - w.ship.pos).angle() - w.ship.heading)

static func common(w: World) -> Dictionary:
	var s: Ship = w.ship
	var enc: Encounter = w.enc
	return {"t": w.t, "hull": s.hull, "hull_max": s.hull_max, "temper": w.temper, "scram": s.scram_t > 0.0,
		"obj": enc.objective_text if enc != null else "", "title": enc.title if enc != null else "",
		"mood": s.pud["mood"], "loose": s.pud["loose"], "shake": s.shake, "speed": s.speed(), "mods": w.mods,
		"enc_prog": enc.prog if enc != null else 0.0}

static func helm(w: World) -> Dictionary:
	var s: Ship = w.ship
	var d: Dictionary = {"heading": s.heading, "angvel": s.angvel, "yaw": s.yaw, "strafe": s.strafe, "trim": s.trim,
		"drift": s.trim_bias - s.trim, "rcs_pf": s.pf("rcs"), "auth_r": (s.eff("RCS_FP") + s.eff("RCS_AS")) * 0.5,
		"auth_l": (s.eff("RCS_FS") + s.eff("RCS_AP")) * 0.5, "roll_cd": s.roll_cd, "faults": faults_for(w, "helm")}
	if w.enc != null and not w.enc.done and w.enc.goal != Vector2.ZERO:
		d["wp_bearing"] = rel_bearing(w, w.enc.goal)
	d["enc"] = w.enc.station_data("helm") if w.enc != null else {}
	return d

static func engines(w: World) -> Dictionary:
	var s: Ship = w.ship
	return {"speed": s.speed(), "thr_p": s.thr_p, "thr_s": s.thr_s, "link": s.link, "boost": s.boost,
		"dampers": s.dampers, "dampers_ok": s.eff("DAMP") > 0.0 and not s.dampers_locked, "mix": s.mix, "heat": s.eng_heat, "accel": s.accel_mag,
		"st_p": s.mod_state("ENG_P"), "st_s": s.mod_state("ENG_S"), "on_p": s.online("ENG_P"), "on_s": s.online("ENG_S"),
		"stuck_p": s.modules["ENG_P"].fault == "stuck_full" and s.mod_state("ENG_P") >= 2,
		"stuck_s": s.modules["ENG_S"].fault == "stuck_full" and s.mod_state("ENG_S") >= 2,
		"pf": s.pf("engines"), "faults": faults_for(w, "engines"),
		"enc": w.enc.station_data("engines") if w.enc != null else {}}

static func power(w: World) -> Dictionary:
	var s: Ship = w.ship
	var cons: Dictionary = {}
	for c in K.CONDUITS:
		var cd: Dictionary = s.conduits[c]
		var known: bool = (not cd.hidden) or w.reveal_t > 0.0
		cons[c] = {"cut": cd.cut and known, "unknown": cd.cut and not known, "iso": s.isolate[c]}
	return {"alloc": s.alloc.duplicate(), "avail": s.avail, "used": s.used, "brown": s.brown, "heat": s.reactor_heat,
		"cool_p": s.cool_p, "pump": s.pump, "vent_cd": s.vent_cd, "oc_sys": s.oc_sys, "oc_t": s.oc_t,
		"scram_t": s.scram_t, "tripped": s.tripped.duplicate(), "cons": cons, "jump_charge": s.jump_charge,
		"charging": s.charging, "faults": faults_for(w, "power"), "leak": s.coolant_leak,
		"enc": w.enc.station_data("power") if w.enc != null else {}}

static func weapons(w: World) -> Dictionary:
	var s: Ship = w.ship
	var turrets: Array = []
	for id in ["TUR_A", "TUR_B"]:
		var m: Dictionary = s.modules[id]
		var arc: Array = s.turret_arc(id)
		turrets.append({"id": id, "ang": m.ang, "tgt": m.tgt, "lo": arc[0], "hi": arc[1], "loaded": m.loaded,
			"load_p": m.load_p, "heat": m.heat, "cd": m.cd, "state": s.mod_state(id), "online": s.online(id),
			"jam": m.fault == "jam" and s.mod_state(id) >= 2, "track": w.track.get(id, false), "label": m.label})
	var tube: Dictionary = s.modules["TUBE"]
	# scope: everything inside a narrow cone around the selected turret
	var sel: String = w.sel_turret
	var sm: Dictionary = s.modules[sel]
	var tdir: float = s.heading + float(sm.ang)
	var tpos: Vector2 = w.turret_pos(sel)
	var scope: Array = []
	var locks: Array = []
	for e in w.ents:
		if e.dead or e.kind in ["bullet", "waypoint", "debris", "ebullet", "eshell", "torp"] or not e.radar:
			continue
		var to: Vector2 = e.pos - tpos
		var d: float = to.length()
		var scanned: bool = w.is_scanned(e)
		if d < 900.0:
			var off: float = K.wrap_pi(to.angle() - tdir)
			if absf(off) < deg_to_rad(14.0) and d > 5.0:
				var item: Dictionary = {"id": e.id, "off": off, "d": d, "r": e.r, "kind": e.kind if scanned else "?",
					"scanned": scanned, "fac": e.fac if scanned else "?"}
				if scanned and e.kind == "bastion":
					item["weak_off"] = K.wrap_pi((w.weak_pos(e) - tpos).angle() - tdir)
				scope.append(item)
		if scanned and d < w.sensor_range() * 1.2:
			locks.append({"id": e.id, "name": e.name, "kind": e.kind, "d": d, "bearing": rel_bearing(w, e.pos),
				"hp": 100.0 * float(e.hp) / maxf(1.0, float(e.hpmax)) if float(e.hpmax) < 5000.0 else 100.0, "weak": e.kind == "bastion"})
	var lock_info: Dictionary = {}
	var le: Dictionary = w.find(w.lock_id)
	if not le.is_empty():
		lock_info = {"id": le.id, "name": le.name, "d": le.pos.distance_to(s.pos), "bearing": rel_bearing(w, le.pos)}
	return {"turrets": turrets, "sel": sel, "scope": scope, "locks": locks, "lock": lock_info, "lock_weak": w.lock_weak,
		"tube": {"state": tube.tstate, "load_p": tube.load_p, "arm_p": tube.arm_p, "online": s.online("TUBE")},
		"stowed": w.stowed, "pf": s.pf("weapons"), "faults": faults_for(w, "weapons"),
		"enc": w.enc.station_data("weapons") if w.enc != null else {}}

static func sensors(w: World) -> Dictionary:
	var s: Ship = w.ship
	var rng_m: float = w.sensor_range()
	var mirror: bool = s.modules["SENS"].fault == "mirror" and s.mod_state("SENS") >= 2
	var contacts: Array = []
	var incoming: Array = []
	var tele: Array = []
	for e in w.ents:
		if e.dead or not e.radar:
			continue
		var rel: Vector2 = e.pos - s.pos
		var d: float = rel.length()
		if e.kind in ["ebullet", "eshell"]:
			if d < rng_m:
				incoming.append({"p": rel, "v": e.vel, "big": e.kind == "eshell"})
			continue
		if e.kind == "torp" or e.kind == "bullet":
			continue
		if d > rng_m + float(e.r):
			continue
		var scanned: bool = w.is_scanned(e)
		var item: Dictionary = {"id": e.id, "p": rel, "r": e.r, "vel": e.vel, "scanned": scanned, "ang": e.ang,
			"kind": e.kind if (scanned or e.kind in ["waypoint", "mine", "skip", "diner", "asteroid", "beacon"]) else "?",
			"name": e.name if scanned else "Unknown contact", "age": w.t - float(e.scan) if scanned else 0.0}
		if scanned:
			item["fac"] = e.fac
			item["hp"] = 100.0 * float(e.hp) / maxf(1.0, float(e.hpmax)) if float(e.hpmax) < 5000.0 else 100.0
			if e.kind == "bastion":
				item["weak"] = w.weak_pos(e) - s.pos
		if e.kind == "bastion" and e.state == "telegraph":
			tele.append({"p": rel, "ang": e.ang})
		contacts.append(item)
	var quality: float = 0.0
	var hail: Dictionary = {}
	if not w.hails.is_empty():
		var h: Dictionary = w.hails[0]
		quality = clampf(1.0 - absf(float(w.comms["freq"]) - float(h["freq"])) / 0.3, 0.0, 1.0)
		hail = {"from": h.from, "q": quality, "tuned": quality > 0.87, "ttl": float(h["ttl"]) - float(h.t)}
	var sc_e: Dictionary = w.find(int(w.scan["target"]))
	return {"range": rng_m, "heading": s.heading, "pos": s.pos, "contacts": contacts, "incoming": incoming, "tele": tele,
		"mirror": mirror, "scan": {"target": w.scan["target"], "progress": w.scan["progress"], "on": w.scan["on"],
			"name": sc_e.name if not sc_e.is_empty() else ""}, "freq": w.comms["freq"], "hail": hail,
		"ping_t": w.ping_t, "ping_cd": w.ping_cd, "iscan_cd": w.iscan_cd, "reveal_t": w.reveal_t, "view": w.view_dir,
		"lock": w.lock_id, "pf": s.pf("sensors"), "faults": faults_for(w, "sensors"), "beacons": s.beacons,
		"enc": w.enc.station_data("sensors") if w.enc != null else {}}

static func ops(w: World) -> Dictionary:
	var s: Ship = w.ship
	var trac: Array = []
	var tr_range: float = 70.0 + 30.0 * s.pf("ops") * s.eff("OPSB")
	for e in w.ents:
		if e.dead:
			continue
		if e.kind in ["skip", "pod", "debris", "freighter", "beacon"]:
			var d: float = e.pos.distance_to(s.pos)
			if d < 400.0:
				trac.append({"id": e.id, "name": e.name, "kind": e.kind, "d": d, "rel": (e.vel - s.vel).length(), "p": e.pos - s.pos})
	trac.sort_custom(func(a, b): return a.d < b.d)
	var cargo: Array = []
	for c in s.cargo:
		cargo.append({"name": c.name, "integrity": c.integrity, "lost": c.get("lost", 0)})
	var damaged: Array = []
	for mid in s.mod_order:
		var mm: Dictionary = s.modules[mid]
		if mm.hp < 90.0 and mm.fire <= 0.0:
			damaged.append({"id": mid, "label": mm.label, "hp": mm.hp})
	return {"damaged": damaged, "shield": s.shield.duplicate(), "shield_w": s.shield_w.duplicate(), "tractor": w.tractor_id, "tractor_range": tr_range,
		"pud": {"mood": s.pud["mood"], "loose": s.pud["loose"], "at": s.pud["at"], "music": s.pud["music"],
			"aboard": s.pud["aboard"], "pat_cd": s.pud["pat_cd"], "snack_cd": s.pud["snack_cd"], "warn": s.pud["warn"]},
		"snacks": s.snacks, "cargo": cargo, "secured": s.cargo_secured, "bot_job": s.bot_job, "bot_progress": s.bot_progress,
		"tractables": trac.slice(0, 8), "faults": faults_for(w, "ops"), "threat": w.weakest_threat_facing(),
		"pf": s.pf("shields"), "heading": s.heading, "has_threat": not w.hostiles().is_empty() or not w.of_kind("ebullet").is_empty() or not w.of_kind("eshell").is_empty(), "enc": w.enc.station_data("ops") if w.enc != null else {}}

static func dc(w: World) -> Dictionary:
	var s: Ship = w.ship
	var mods: Array = []
	for id in s.mod_order:
		var m: Dictionary = s.modules[id]
		mods.append({"id": id, "label": m.label, "gx": m.gx, "gy": m.gy, "state": s.mod_state(id), "hp": m.hp,
			"fire": m.fire > 0.0, "breach": m.breach, "fault": m.fault, "nopower": not s.conduit_ok(m.conduit),
			"work": m.work, "task": w.target_task("mod:" + id), "owner": m.owner, "conduit": m.conduit,
			"mash": w.mash.get("mod:" + id, 0.0), "patched": m.patched, "warn": m.warn > 0.0})
	var cons: Dictionary = {}
	for c in K.CONDUITS:
		var cd: Dictionary = s.conduits[c]
		var known: bool = (not cd.hidden) or w.reveal_t > 0.0
		cons[c] = {"cut": cd.cut and known, "unknown": cd.cut and not known, "work": cd.work, "iso": s.isolate[c], "zap": cd.zap,
			"task": w.target_task("con:" + c), "trace": w.target_task("trc:" + c), "tprog": w.trace_prog.get(c, 0.0),
			"hidden_cut": cd.cut and cd.hidden}
	return {"mods": mods, "cons": cons, "pud_at": s.pud["at"] if s.pud["loose"] else "", "scram": s.scram_t > 0.0}

static func captain(w: World) -> Dictionary:
	var s: Ship = w.ship
	var ents: Array = []
	var view_ang: float = s.heading
	match w.view_dir:
		"aft":
			view_ang = s.heading + PI
		"port":
			view_ang = s.heading - PI / 2.0
		"stbd":
			view_ang = s.heading + PI / 2.0
		"target":
			var le: Dictionary = w.find(w.lock_id)
			if not le.is_empty():
				view_ang = (le.pos - s.pos).angle()
	for e in w.ents:
		if e.dead:
			continue
		var d: float = e.pos.distance_to(s.pos)
		if e.kind == "mine":
			if d > 60.0:
				continue
		elif d > 3200.0 and e.kind not in ["magnificence", "bastion", "diner", "waypoint"]:
			continue
		var item: Dictionary = {"id": e.id, "k": e.kind, "x": e.pos.x, "y": e.pos.y, "a": e.ang, "r": e.r, "n": e.name}
		if e.kind in ["grabber", "snatch"]:
			item["st"] = e.state
		if e.kind == "bastion":
			item["st"] = e.state
		if e.kind == "skip" and e.name == "Warm Skip":
			item["special"] = true
		if e.kind == "torp":
			item["armed"] = e.armed
		ents.append(item)
	var smoke: Array = []
	var fire_n: int = 0
	for id in s.mod_order:
		var m: Dictionary = s.modules[id]
		if m.fire > 0.0 or s.mod_state(id) >= 2:
			smoke.append([m.lx, m.ly, 1.0 if m.fire > 0.0 else 0.5])
		if m.fire > 0.0:
			fire_n += 1
	var meters: Array = []
	var sheet: Array = []
	if w.enc != null:
		var cd: Dictionary = w.enc.captain_data()
		meters = cd.get("meters", [])
		sheet = cd.get("sheet", [])
	return {"x": s.pos.x, "y": s.pos.y, "h": s.heading, "vx": s.vel.x, "vy": s.vel.y, "av": s.angvel, "view_ang": view_ang,
		"view": w.view_dir, "ents": ents, "shake": s.shake, "flash": s.hit_flash, "smoke": smoke, "fires": fire_n,
		"note": w.enc.captain_note() if w.enc != null else "", "meters": meters, "sheet": sheet,
		"comms": w.captain_comms.duplicate(), "fog": s.coolant_leak, "bridge_hp": s.modules["BRDG"].hp,
		"hail_wait": not w.hails.is_empty(), "accel": s.accel_mag, "lock": w.lock_id,
		"crew": {"pud_mood": s.pud["mood"], "loose": s.pud["loose"]}, "speed": s.speed(),
		"shield": s.shield.duplicate(), "dock": w.enc.station_data("helm").get("dock", {}) if w.enc != null else {}}
