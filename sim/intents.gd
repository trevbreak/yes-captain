class_name Intents
extends RefCounted
## Every control a player (or bot) can touch. Clients send intents, the host applies them here.
## Returns true if something was handled.

static func apply(w: World, station: String, key: String, v: Variant, actor: String = "", human: bool = false) -> bool:
	var s: Ship = w.ship
	if human and w.inverted.has(station):
		v = _invert(station, key, v)
	if station in K.STATIONS or station == "dc":
		w.last_input[station] = {"t": w.t, "key": key}
		w.stats["inputs"][station] = int(w.stats["inputs"][station]) + 1
	match station:
		"helm":
			return _helm(w, s, key, v)
		"engines":
			return _engines(w, s, key, v)
		"power":
			return _power(w, s, key, v)
		"weapons":
			return _weapons(w, s, key, v)
		"sensors":
			return _sensors(w, s, key, v)
		"ops":
			return _ops(w, s, key, v)
		"dc":
			return _dc(w, s, key, v, actor)
	return false

static func _invert(station: String, key: String, v: Variant) -> Variant:
	## EMP: some controls come out backwards.
	match station:
		"helm":
			if key in ["yaw", "strafe", "trim"]:
				return -float(v)
		"engines":
			if key in ["thr", "thr_p", "thr_s"]:
				return -float(v)
		"weapons":
			if key == "aim":
				return {"id": v.get("id", "TUR_A"), "ang": -float(v.get("ang", 0.0))}
		"sensors":
			if key == "freq":
				return -float(v)
		"ops":
			if key == "shield_w":
				return {"i": v.get("i", 0), "d": -int(v.get("d", 0))}
	return v

static func _helm(w: World, s: Ship, key: String, v: Variant) -> bool:
	match key:
		"yaw":
			s.yaw = clampf(float(v), -1.0, 1.0)
		"strafe":
			s.strafe = clampf(float(v), -1.0, 1.0)
		"trim":
			s.trim = clampf(float(v), -1.0, 1.0)
		"roll":
			if s.roll_cd <= 0.0 and s.eff("RCS_FP") + s.eff("RCS_AS") + s.eff("RCS_FS") + s.eff("RCS_AP") > 0.0:
				s.roll_t = 1.2
				s.roll_dir = signf(float(v)) if float(v) != 0.0 else 1.0
				s.roll_cd = 8.0
				w.emit("roll", {})
		_:
			return false
	return true

static func _engines(w: World, s: Ship, key: String, v: Variant) -> bool:
	match key:
		"thr":
			var x: float = clampf(float(v), -1.0, 1.0)
			s.thr_p = x
			if s.link:
				s.thr_s = x
		"thr_p":
			s.thr_p = clampf(float(v), -1.0, 1.0)
			if s.link:
				s.thr_s = s.thr_p
		"thr_s":
			s.thr_s = clampf(float(v), -1.0, 1.0)
			if s.link:
				s.thr_p = s.thr_s
		"link":
			if bool(v):
				if s.mod_state("ENG_P") < 2 and s.mod_state("ENG_S") < 2:
					s.link = true
					s.thr_s = s.thr_p
			else:
				s.link = false
		"boost":
			s.boost = bool(v)
		"dampers":
			if s.dampers_locked:
				w.emit("toast_text", {"text": "The dampers are broken (modifier). Welcome to Newton."})
				return true
			s.dampers = bool(v)
			w.emit("dampers", {"on": s.dampers})
		"mix":
			s.mix = clampf(s.mix + float(v), 0.0, 1.0)
		_:
			return false
	return true

static func _power(w: World, s: Ship, key: String, v: Variant) -> bool:
	match key:
		"alloc":
			var sys: String = str(v.get("sys", ""))
			if s.alloc.has(sys):
				s.alloc[sys] = clampi(int(v.get("n", 0)), 0, 5)
		"pump":
			s.pump = bool(v)
		"vent":
			if s.vent_cd <= 0.0:
				s.reactor_heat = maxf(0.0, s.reactor_heat - 28.0)
				s.cool_p = 0.0
				s.vent_cd = 15.0
				w.emit("vent", {})
		"oc":
			var sys2: String = str(v)
			if s.oc_sys == "" and s.scram_t <= 0.0 and s.alloc.has(sys2):
				s.oc_sys = sys2
				s.oc_t = 20.0
				w.emit("overclock", {"sys": sys2})
		"reset_breaker":
			var sys3: String = str(v)
			if s.tripped.has(sys3):
				s.tripped[sys3] = false
				s.trip_timer[sys3] = 0.0
				if int(s.alloc[sys3]) > 4:
					s.alloc[sys3] = 4
		"isolate":
			var cid: String = str(v.get("cid", ""))
			if s.isolate.has(cid):
				s.isolate[cid] = bool(v.get("on", false))
		"charge":
			s.charging = bool(v)
		_:
			return false
	return true

static func _weapons(w: World, s: Ship, key: String, v: Variant) -> bool:
	match key:
		"sel":
			w.sel_turret = str(v)
		"aim":
			var id: String = str(v.get("id", "TUR_A"))
			if s.modules.has(id):
				s.modules[id].tgt = s.clamp_arc(id, float(v.get("ang", 0.0)))
				w.track[id] = false
		"track":
			w.track[str(v.get("id", "TUR_A"))] = bool(v.get("on", false))
		"fire":
			w.fire_turret(str(v))
		"load":
			w.load_hold[str(v.get("id", ""))] = bool(v.get("on", false))
		"torp_arm":
			if s.modules["TUBE"].tstate == "loaded":
				s.modules["TUBE"].tstate = "arming"
				s.modules["TUBE"].arm_p = 0.0
		"torp_fire":
			w.fire_torp()
		"lock":
			var e: Dictionary = w.find(int(v))
			if int(v) < 0 or (not e.is_empty() and w.is_scanned(e)):
				w.lock_id = int(v)
				w.lock_weak = false
		"weak":
			w.lock_weak = bool(v)
		"stow":
			w.stowed = bool(v)
			if w.stowed:
				for id2 in ["TUR_A", "TUR_B"]:
					s.modules[id2].tgt = 0.0
					w.track[id2] = false
		_:
			return false
	return true

static func _sensors(w: World, s: Ship, key: String, v: Variant) -> bool:
	match key:
		"scan":
			var id: int = int(v.get("id", -1))
			var on: bool = bool(v.get("on", false))
			if on:
				if int(w.scan["target"]) != id:
					w.scan["progress"] = 0.0
				w.scan["target"] = id
				w.scan["on"] = true
			else:
				w.scan["on"] = false
		"ping":
			if w.ping_cd <= 0.0 and s.eff("SENS") > 0.0:
				w.ping_t = 6.0
				w.ping_cd = 22.0
				w.emit("ping", {})
		"view":
			if str(v) in ["fwd", "aft", "port", "stbd", "target"]:
				w.view_dir = str(v)
		"freq":
			w.comms["freq"] = clampf(float(w.comms["freq"]) + float(v), 0.0, 1.0)
		"set_freq":
			w.comms["freq"] = clampf(float(v), 0.0, 1.0)
		"iscan":
			if w.iscan_cd <= 0.0 and s.eff("SENS") > 0.0:
				w.reveal_t = 30.0
				w.iscan_cd = 40.0
				w.emit("iscan", {})
		_:
			return false
	return true

static func _ops(w: World, s: Ship, key: String, v: Variant) -> bool:
	match key:
		"shield_w":
			var i: int = clampi(int(v.get("i", 0)), 0, 3)
			s.shield_w[i] = clampi(int(s.shield_w[i]) + int(v.get("d", 0)), 0, 4)
		"shield_set":
			var arr: Array = v
			for i2 in 4:
				s.shield_w[i2] = clampi(int(arr[i2]), 0, 4)
		"tractor":
			w.tractor_id = int(v)
		"pat":
			if s.pud["pat_cd"] <= 0.0 and s.pud["aboard"] and not s.pud["loose"]:
				s.pud["mood"] = maxf(0.0, float(s.pud["mood"]) - 12.0)
				s.pud["pat_cd"] = 5.0
				w.emit("pat", {})
		"snack":
			if s.snacks > 0 and s.pud["snack_cd"] <= 0.0 and s.pud["aboard"]:
				s.snacks -= 1
				s.pud["snack_cd"] = 4.0
				s.pud["mood"] = maxf(0.0, float(s.pud["mood"]) - 18.0)
				if s.pud["loose"] and float(s.pud["return_t"]) <= 0.0:
					s.pud["return_t"] = 3.0
					w.emit("pudding_lured", {})
				w.emit("snack", {})
		"music":
			s.pud["music"] = bool(v)
		"jettison":
			var idx: int = int(v)
			if idx >= 0 and idx < s.cargo.size():
				var c: Dictionary = s.cargo[idx]
				s.cargo.remove_at(idx)
				var back: Vector2 = -s.fwd()
				w.spawn("debris", s.pos + back * 10.0, {"vel": s.vel + back * 6.0, "angvel": 2.0, "name": str(c.name), "r": 3.0, "radar": true})
				w.emit("jettison", {"name": c.name, "data": c})
		"bot":
			var mid: String = str(v)
			if mid == "" or s.modules.has(mid):
				s.bot_job = mid
				s.bot_progress = 0.0
		"secure":
			s.cargo_secured = bool(v)
		"paint":
			w.paint = int(v)
		_:
			return false
	return true

static func _dc(w: World, s: Ship, key: String, v: Variant, actor: String) -> bool:
	match key:
		"hold":
			var target: String = str(v.get("target", ""))
			if bool(v.get("on", false)):
				w.start_hold(actor, target, str(v.get("quick", "")))
			else:
				w.stop_hold(actor)
		"click":
			w.click_work(str(v.get("target", "")), str(v.get("quick", "")), actor)
		_:
			return false
	return true
