class_name Bot
extends RefCounted
## An AI crew member. Just another client: it reads the same filtered station view a human would
## get and writes through the same intent API. Every bot is one of IGOR's relatives from the Foundry.

const PERSONALITIES: Dictionary = {
	"competent": {"name": "Competent Temp", "react": 0.2, "gain": 1.0, "miss": 0.0, "freeze": 0.0, "init": 1.0, "literal": false, "delay": 0.0,
		"ack": "Acknowledged.", "desc": "No quirks. For serious testing."},
	"eager": {"name": "Eager", "react": 0.12, "gain": 1.5, "miss": 0.0, "freeze": 0.0, "init": 1.0, "literal": false, "delay": 0.0,
		"ack": "ON IT!", "desc": "Acts instantly. Overshoots by 30%."},
	"literal": {"name": "Literal", "react": 0.25, "gain": 1.0, "miss": 0.0, "freeze": 0.0, "init": 0.8, "literal": true, "delay": 0.2,
		"ack": "Doing literally that.", "desc": "Turns until told to stop."},
	"nervous": {"name": "Nervous", "react": 0.45, "gain": 0.9, "miss": 0.05, "freeze": 1.8, "init": 0.9, "literal": false, "delay": 0.4,
		"ack": "Are you sure? Like, SURE sure?", "desc": "Freezes when hit."},
	"sleepy": {"name": "Sleepy", "react": 0.9, "gain": 0.8, "miss": 0.2, "freeze": 0.0, "init": 0.45, "literal": false, "delay": 0.6,
		"ack": "*snrk* Yes, Captain!", "desc": "Slow. Sometimes misses orders."},
	"knowitall": {"name": "Know-it-all", "react": 0.2, "gain": 1.0, "miss": 0.15, "freeze": 0.0, "init": 1.0, "literal": false, "delay": 0.0,
		"ack": "Actually...", "desc": "15% of the time does it their own way."},
	"grovelling": {"name": "Grovelling", "react": 0.3, "gain": 1.0, "miss": 0.0, "freeze": 0.0, "init": 1.0, "literal": false, "delay": 0.5,
		"ack": "Terribly sorry, Captain. Right away. Sorry.", "desc": "Thrupp's defected. Apologizes constantly."},
}

const PROFILES: Dictionary = {
	"balanced": {"engines": 2, "rcs": 2, "weapons": 2, "shields": 2, "sensors": 1, "ops": 1},
	"combat": {"engines": 2, "rcs": 2, "weapons": 3, "shields": 3, "sensors": 1, "ops": 1},
	"stealth": {"engines": 1, "rcs": 1, "weapons": 0, "shields": 1, "sensors": 1, "ops": 1},
	"precision": {"engines": 2, "rcs": 3, "weapons": 0, "shields": 1, "sensors": 2, "ops": 2},
	"ritual": {"engines": 2, "rcs": 1, "weapons": 0, "shields": 1, "sensors": 1, "ops": 4},
	"run": {"engines": 3, "rcs": 2, "weapons": 1, "shields": 3, "sensors": 1, "ops": 1},
	"bastion": {"engines": 2, "rcs": 2, "weapons": 2, "shields": 3, "sensors": 3, "ops": 0},
	"tractor": {"engines": 1, "rcs": 2, "weapons": 0, "shields": 1, "sensors": 2, "ops": 4},
}

var seat: String = ""
var kind: String = "competent"
var P: Dictionary = {}
var host: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var timer: float = 0.0
var queue: Array = []
var st: Dictionary = {}
var frozen: float = 0.0
var away_target: String = ""
var away_t: float = 0.0
var click_t: float = 0.0
var fixing: String = ""
var barks: Array = []
var last_hit: float = 0.0

func _init(seat_name: String, personality: String, h: Node) -> void:
	seat = seat_name
	kind = personality if PERSONALITIES.has(personality) else "competent"
	P = PERSONALITIES[kind]
	host = h
	rng.randomize()
	st = {"mode": "hold", "target": 0.0, "speed": 0.0, "gentle": false, "profile": "balanced", "engage": [], "scan_ids": [],
		"stealth": false, "calm": false, "dir": 1.0, "thr": 0.0, "last_q": 0.0, "fdir": 1.0, "nofire": false, "tract": -1,
		"shield_mode": "auto", "torp": -1, "weak": false, "stow": false, "secure": false, "settings": {}, "charge": false,
		"iso": [], "pending_set": [], "face_pt": Vector2.ZERO, "has_face_pt": false, "view": "fwd", "iscan_next": 30.0,
		"strafe": 0.0, "desired_alloc": {}, "boost": false, "dampers": true, "do_ping": false, "beacon": false}

func order(verb: String, args: Dictionary = {}, from_human: bool = false) -> String:
	## returns a bark for the captain's TV
	if P.miss > 0.0 and rng.randf() < float(P.miss) and from_human:
		return "%s: ...what?" % K.seat_name(seat)
	queue.append({"verb": verb, "args": args, "at": host.world.t + float(P.delay)})
	return "%s: %s" % [K.seat_name(seat), P.ack] if from_human else ""

func notify_hit() -> void:
	if float(P.freeze) > 0.0:
		frozen = float(P.freeze)

func _w() -> World:
	return host.world

func tick(dt: float) -> void:
	var w: World = _w()
	frozen = maxf(0.0, frozen - dt)
	timer -= dt
	# apply due orders
	var rest: Array = []
	for o in queue:
		if w.t >= float(o.at):
			_apply_order(o.verb, o.args)
		else:
			rest.append(o)
	queue = rest
	if frozen > 0.0:
		return
	# away on a damage-control job
	if away_target != "":
		away_t -= dt
		var task: Dictionary = w.target_task(away_target)
		if task.is_empty() or away_t <= 0.0:
			w.stop_hold("bot:" + seat)
			away_target = ""
		else:
			if task.mash:
				click_t -= dt
				if click_t <= 0.0:
					click_t = 0.16
					Intents.apply(w, "dc", "click", {"target": away_target, "quick": ""}, "bot:" + seat)
			else:
				Intents.apply(w, "dc", "hold", {"target": away_target, "on": true, "quick": ""}, "bot:" + seat)
		return
	if timer > 0.0:
		return
	timer = float(P.react) * rng.randf_range(0.8, 1.2)
	_quick_fix()
	match seat:
		"helm":
			_helm()
		"engines":
			_engines()
		"power":
			_power(dt)
		"weapons":
			_weapons()
		"sensors":
			_sensors()
		"ops":
			_ops()

# ---------------------------------------------------------------- orders

func _apply_order(verb: String, a: Dictionary) -> void:
	var w: World = _w()
	match verb:
		"face":
			st.mode = "face"
			st.target = float(a.get("heading", w.ship.heading))
			st.has_face_pt = false
		"face_point":
			st.mode = "face_point"
			st.face_pt = a.get("p", Vector2.ZERO)
		"turn":
			var dir: float = float(a.get("dir", 1.0))
			if bool(P.literal):
				st.mode = "spin"
				st.dir = dir
			else:
				st.mode = "face"
				st.target = K.wrap_pi(w.ship.heading + dir * float(a.get("amount", 0.5)) * (1.3 if kind == "eager" else 1.0))
		"hold":
			st.mode = "face"
			st.target = w.ship.heading
			st.speed = st.speed
		"strafe":
			st.strafe = float(a.get("dir", 0.0))
		"roll":
			Intents.apply(w, "helm", "roll", float(a.get("dir", 1.0)))
		"speed":
			st.speed = float(a.get("v", 0.0))
		"stop":
			if seat == "helm":
				st.mode = "face"
				st.target = w.ship.heading
				st.strafe = 0.0
			else:
				st.speed = 0.0
		"gentle":
			st.gentle = bool(a.get("on", true))
		"boost":
			st.boost = bool(a.get("on", false))
		"dampers":
			st.dampers = bool(a.get("on", true))
		"profile":
			st.profile = str(a.get("name", "balanced"))
		"alloc_shift":
			st.desired_alloc = a
		"vent":
			Intents.apply(w, "power", "vent", true)
		"charge":
			st.charge = bool(a.get("on", false))
		"isolate":
			st.iso = a.get("list", [])
		"engage":
			st.engage = a.get("ids", [])
			st.nofire = false
		"hold_fire":
			st.nofire = true
			st.engage = []
		"nofire":
			st.nofire = bool(a.get("on", true))
		"torp":
			st.torp = int(a.get("id", -1))
			st.weak = bool(a.get("weak", false))
		"stow":
			st.stow = bool(a.get("on", true))
			Intents.apply(w, "weapons", "stow", st.stow)
		"scan":
			st.scan_ids = a.get("ids", [])
			st["scan_auto"] = bool(a.get("auto", false))
		"ping":
			Intents.apply(w, "sensors", "ping", true)
		"iscan":
			Intents.apply(w, "sensors", "iscan", true)
		"view":
			Intents.apply(w, "sensors", "view", str(a.get("dir", "fwd")))
		"beacon":
			st.beacon = true
		"shield":
			st.shield_mode = str(a.get("mode", "auto"))
		"tractor":
			st.tract = int(a.get("id", -1))
			Intents.apply(w, "ops", "tractor", st.tract)
		"calm":
			st.calm = bool(a.get("on", true))
		"secure":
			st.secure = bool(a.get("on", true))
			Intents.apply(w, "ops", "secure", st.secure)
		"set":
			var sid: String = str(a.get("id", ""))
			if sid == "stow":
				Intents.apply(w, "weapons", "stow", bool(a.get("value", true)))
			elif w.enc != null:
				w.enc.on_intent(seat, "set", {"id": sid, "value": a.get("value")})
		"repair":
			away_target = str(a.get("target", ""))
			away_t = 26.0
			w.stop_hold("bot:" + seat)
		"repair_worst":
			var tgt: String = _worst_target()
			if tgt != "":
				away_target = tgt
				away_t = 26.0
				w.stop_hold("bot:" + seat)
		"botjob":
			Intents.apply(w, "ops", "bot", str(a.get("id", "")))
		"code":
			host.bot_code(str(a.get("code", "")))
		"say":
			pass

# ---------------------------------------------------------------- shared chores

func _quick_fix() -> void:
	var w: World = _w()
	if rng.randf() > float(P.init):
		return
	var faults: Array = Snapshots.faults_for(w, seat)
	var pick: Dictionary = {}
	for f in faults:
		var task: Dictionary = f.task
		if task.is_empty() or f.fire or f.breach or int(f.state) >= 3:
			continue
		pick = f
		break
	var actor: String = "q:" + seat
	if pick.is_empty():
		if fixing != "":
			w.stop_hold(actor)
			fixing = ""
		return
	var target: String = "mod:" + str(pick.id)
	if bool(pick.task.get("mash", false)):
		for i in 3:
			Intents.apply(w, "dc", "click", {"target": target, "quick": seat}, actor)
	else:
		Intents.apply(w, "dc", "hold", {"target": target, "on": true, "quick": seat}, actor)
	fixing = target

func _worst_target() -> String:
	var w: World = _w()
	var s: Ship = w.ship
	var best: String = ""
	var bs: float = 0.0
	for id in s.mod_order:
		var m: Dictionary = s.modules[id]
		if w.target_task("mod:" + id).is_empty():
			continue
		var score: float = (100.0 - float(m.hp))
		if m.fire > 0.0:
			score += 200.0
		if m.breach:
			score += 150.0
		if score > bs:
			bs = score
			best = "mod:" + id
	for c in K.CONDUITS:
		if s.conduits[c].cut and not s.conduits[c].hidden:
			if 180.0 > bs:
				bs = 180.0
				best = "con:" + c
	return best

func _stuff() -> Dictionary:
	return _w().enc.hint() if _w().enc != null else {}

# ---------------------------------------------------------------- Helm

func _helm() -> void:
	var w: World = _w()
	var s: Ship = w.ship
	if not st.get("inited", false):
		st["inited"] = true
		st.target = s.heading
	var sn: Dictionary = Snapshots.helm(w)
	var gain: float = float(P.gain)
	Intents.apply(w, "helm", "trim", clampf(s.trim + clampf(float(sn.drift), -1.0, 1.0) * 0.5, -1.0, 1.0))
	var cmd: float = 0.0
	match st.mode:
		"spin":
			cmd = float(st.dir)
		"face_point":
			var tgt: float = (st.face_pt - s.pos).angle()
			cmd = _pd(tgt, gain)
		_:
			cmd = _pd(float(st.target), gain)
	Intents.apply(w, "helm", "yaw", cmd)
	Intents.apply(w, "helm", "strafe", float(st.strafe))

func _pd(target: float, gain: float) -> float:
	var s: Ship = _w().ship
	var err: float = K.wrap_pi(target - s.heading)
	if absf(err) < 0.02 and absf(s.angvel) < 0.04:
		return 0.0
	var kp: float = 1.4 * gain
	var kd: float = 1.9
	return clampf(err * kp - s.angvel * kd, -1.0, 1.0)

# ---------------------------------------------------------------- Engines

func _engines() -> void:
	var w: World = _w()
	var s: Ship = w.ship
	var sn: Dictionary = Snapshots.engines(w)
	if absf(s.mix - 0.5) > 0.07:
		Intents.apply(w, "engines", "mix", clampf(0.5 - s.mix, -0.06, 0.06))
	if bool(sn.dampers) != bool(st.dampers):
		Intents.apply(w, "engines", "dampers", bool(st.dampers))
	if bool(sn.boost) != bool(st.boost):
		Intents.apply(w, "engines", "boost", bool(st.boost))
	var target: float = float(st.speed)
	var h: Dictionary = _stuff()
	if not s.link and int(sn.st_p) < 2 and int(sn.st_s) < 2:
		Intents.apply(w, "engines", "link", true)
	if bool(h.get("gentle", false)) or bool(st.gentle):
		target = minf(target, 14.0)
	if s.eng_heat > 88.0:
		target *= 0.5
	var sp: float = s.speed()
	# only count speed along heading (we thrust forward)
	var along: float = s.vel.dot(s.fwd())
	var want: float = 0.0
	if target < 0.5:
		want = 0.0
	else:
		var ff: float = target / (48.0 * maxf(0.3, float(sn.pf)) * s.thrust_bonus)
		want = clampf(ff + (target - along) * 0.07 * float(P.gain), -0.6, 1.0)
		if sp > target + 4.0:
			want = 0.0 if along > 0.0 else want
	var gentle: bool = bool(h.get("gentle", false)) or bool(st.gentle)
	var max_rate: float = 0.25 if gentle else 3.0
	var cur: float = s.thr_p
	var nxt: float = cur + clampf(want - cur, -max_rate * 0.3, max_rate * 0.3 + 0.05)
	if gentle:
		nxt = clampf(nxt, -0.25, 0.3)
	if not s.link:
		# one engine is down: drive the healthy one; keep the stuck one alone
		var p_bad: bool = int(sn.st_p) >= 2
		var s_bad: bool = int(sn.st_s) >= 2
		if p_bad and not s_bad:
			Intents.apply(w, "engines", "thr_s", nxt)
		elif s_bad and not p_bad:
			Intents.apply(w, "engines", "thr_p", nxt)
		else:
			Intents.apply(w, "engines", "thr_p", nxt)
			Intents.apply(w, "engines", "thr_s", nxt)
	else:
		Intents.apply(w, "engines", "thr", nxt)

# ---------------------------------------------------------------- Power

func _power(dt: float) -> void:
	var w: World = _w()
	var s: Ship = w.ship
	var prof_name: String = str(st.profile)
	var h: Dictionary = _stuff()
	if bool(h.get("stealth", false)):
		prof_name = "stealth"
	elif bool(h.get("combat", false)) and prof_name == "balanced":
		prof_name = "combat"
	elif bool(h.get("calm", false)) and prof_name == "balanced":
		prof_name = "precision"
	var prof: Dictionary = PROFILES.get(prof_name, PROFILES["balanced"]).duplicate()
	# fit under available pips
	var total: int = 0
	for sys in K.SYSTEMS:
		total += int(prof[sys])
	var guard: int = 0
	while total > int(s.avail) and guard < 20:
		guard += 1
		var worst: String = ""
		var wv: int = 0
		for sys2 in K.SYSTEMS:
			if int(prof[sys2]) > wv:
				wv = int(prof[sys2])
				worst = sys2
		if worst == "":
			break
		prof[worst] = int(prof[worst]) - 1
		total -= 1
	for sys3 in K.SYSTEMS:
		if int(s.alloc[sys3]) != int(prof[sys3]):
			Intents.apply(w, "power", "alloc", {"sys": sys3, "n": int(prof[sys3])})
		if s.tripped[sys3]:
			Intents.apply(w, "power", "reset_breaker", sys3)
	# coolant chore
	var want_pump: bool = s.cool_p < 60.0 or s.reactor_heat > 68.0
	if s.pump and s.cool_p > 92.0 and s.reactor_heat < 60.0:
		want_pump = false
	Intents.apply(w, "power", "pump", want_pump)
	if s.reactor_heat > 94.0 and s.vent_cd <= 0.0:
		Intents.apply(w, "power", "vent", true)
	# jump charge
	if bool(st.charge):
		var band_hi: float = 0.58
		var band_lo: float = 0.48
		Intents.apply(w, "power", "charge", s.jump_charge < (band_lo + band_hi) * 0.5)
	else:
		Intents.apply(w, "power", "charge", false)
	# isolation orders
	for c in K.CONDUITS:
		var want_iso: bool = c in st.iso
		if bool(s.isolate[c]) != want_iso:
			Intents.apply(w, "power", "isolate", {"cid": c, "on": want_iso})
	# conduit repair (the power bot does its own conduit splices with isolation)
	if away_target == "":
		for c2 in K.CONDUITS:
			var cd: Dictionary = s.conduits[c2]
			if cd.cut and not (c2 in st.iso):
				if cd.hidden and w.reveal_t <= 0.0:
					# trace it: ask the world directly (bot has to hunt it too)
					away_target = "trc:" + c2
					away_t = 10.0
					return
				if cd.hidden:
					away_target = "trc:" + c2
					away_t = 10.0
					return
				st.iso = st.iso + [c2]
				Intents.apply(w, "power", "isolate", {"cid": c2, "on": true})
				away_target = "con:" + c2
				away_t = 20.0
				return
	for c3 in K.CONDUITS:
		if (c3 in st.iso) and not s.conduits[c3].cut and away_target == "":
			st.iso = st.iso.filter(func(x): return x != c3)
			Intents.apply(w, "power", "isolate", {"cid": c3, "on": false})

# ---------------------------------------------------------------- Weapons

func _hostile_kind(k: String) -> bool:
	return k in ["grabber", "snatch", "patrol", "bastion", "magnificence"]

func _weapons() -> void:
	var w: World = _w()
	var s: Ship = w.ship
	var h: Dictionary = _stuff()
	var sn: Dictionary = Snapshots.weapons(w)
	var want_stow: bool = bool(st.stow) or bool(h.get("stow", false))
	if want_stow != w.stowed:
		Intents.apply(w, "weapons", "stow", want_stow)
	# keep everything loaded
	for t in sn.turrets:
		var want_load: bool = (not t.loaded) and t.online
		if bool(w.load_hold.get(t.id, false)) != want_load:
			Intents.apply(w, "weapons", "load", {"id": t.id, "on": want_load})
	var nofire: bool = bool(st.nofire) or bool(h.get("no_fire", false)) or w.stowed
	# pick a target
	var ids: Array = h.get("fire", []) if not st.engage.is_empty() == false else st.engage
	if not st.engage.is_empty():
		ids = st.engage
	var best: Dictionary = {}
	var bd: float = 1e9
	for l in sn.locks:
		if not _hostile_kind(str(l.kind)):
			continue
		if not ids.is_empty() and not (l.id in ids):
			continue
		if l.d < bd:
			bd = l.d
			best = l
	if not best.is_empty() and not nofire:
		if w.lock_id != int(best.id):
			Intents.apply(w, "weapons", "lock", int(best.id))
		var tpos_e: Dictionary = w.find(int(best.id))
		var tid: String = "TUR_A"
		var other: String = "TUR_B"
		if not tpos_e.is_empty():
			var la: float = K.wrap_pi((tpos_e.pos - w.turret_pos("TUR_A")).angle() - s.heading)
			var lb: float = K.wrap_pi((tpos_e.pos - w.turret_pos("TUR_B")).angle() - s.heading)
			if s.arc_error("TUR_B", lb) < s.arc_error("TUR_A", la) - 0.001:
				tid = "TUR_B"
				other = "TUR_A"
		if w.sel_turret != tid:
			Intents.apply(w, "weapons", "sel", tid)
		for tt in sn.turrets:
			var want_track: bool = tt.id == tid
			if bool(w.track.get(tt.id, false)) != want_track and (tt.online):
				Intents.apply(w, "weapons", "track", {"id": tt.id, "on": want_track})
		var weak: bool = best.kind == "bastion"
		if w.lock_weak != weak:
			Intents.apply(w, "weapons", "weak", weak)
		for tt2 in sn.turrets:
			if tt2.id == tid and tt2.loaded and tt2.cd <= 0.0 and tt2.online and best.d < 650.0:
				if absf(float(tt2.ang) - float(tt2.tgt)) < 0.06:
					Intents.apply(w, "weapons", "fire", tid)
			if tt2.id == other and tt2.loaded and tt2.cd <= 0.0 and tt2.online and best.d < 650.0 and not tpos_e.is_empty():
				var lo2: float = K.wrap_pi((tpos_e.pos - w.turret_pos(other)).angle() - s.heading)
				if s.arc_error(other, lo2) < 0.01:
					Intents.apply(w, "weapons", "track", {"id": other, "on": true})
					if absf(float(tt2.ang) - float(tt2.tgt)) < 0.06:
						Intents.apply(w, "weapons", "fire", other)
	# torpedo
	var tp: int = int(st.torp)
	if tp == -2:
		tp = int(best.id) if not best.is_empty() else -1
	if tp < 0:
		tp = int(h.get("torp", -1))
	if tp >= 0 and not w.stowed:
		var te: Dictionary = w.find(tp)
		var tube: Dictionary = sn.tube
		if te.is_empty():
			return
		var scanned: bool = w.is_scanned(te)
		if bool(w.load_hold.get("TUBE", false)) != (tube.state == "empty" and tube.online):
			Intents.apply(w, "weapons", "load", {"id": "TUBE", "on": tube.state == "empty" and tube.online})
		if scanned and w.lock_id != tp:
			Intents.apply(w, "weapons", "lock", tp)
		if scanned and not w.lock_weak and bool(h.get("weak", st.weak)):
			Intents.apply(w, "weapons", "weak", true)
		if tube.state == "loaded":
			Intents.apply(w, "weapons", "torp_arm", true)
		if tube.state == "armed" and scanned and te.pos.distance_to(s.pos) < 520.0:
			Intents.apply(w, "weapons", "torp_fire", true)

# ---------------------------------------------------------------- Sensors

func _sensors() -> void:
	var w: World = _w()
	var s: Ship = w.ship
	var h: Dictionary = _stuff()
	var sn: Dictionary = Snapshots.sensors(w)
	# comms hill-climb
	if not sn.hail.is_empty() and not sn.hail.tuned:
		var q: float = float(sn.hail.q)
		if q < float(st.last_q) - 0.001:
			st.fdir = -float(st.fdir)
		st.last_q = q
		Intents.apply(w, "sensors", "freq", float(st.fdir) * 0.03)
	else:
		st.last_q = 0.0
	# scan hostile contacts
	var ids: Array = st.scan_ids if not st.scan_ids.is_empty() else h.get("scan", [])
	var scan_target: int = -1
	var bd: float = 1e9
	for c in sn.contacts:
		if c.scanned and c.age < 30.0:
			continue
		var d: float = (c.p as Vector2).length()
		var want: bool = false
		if not ids.is_empty():
			want = c.id in ids
		elif bool(st.get("scan_auto", false)):
			want = str(c.kind) in ["?", "grabber", "snatch", "patrol", "bastion", "magnificence"]
		if want and d < bd and d < float(sn.range) * 0.9:
			bd = d
			scan_target = int(c.id)
	if scan_target >= 0:
		if int(w.scan["target"]) != scan_target or not bool(w.scan["on"]):
			Intents.apply(w, "sensors", "scan", {"id": scan_target, "on": true})
	elif bool(w.scan["on"]):
		Intents.apply(w, "sensors", "scan", {"id": -1, "on": false})
	if bool(st.beacon) and s.beacons > 0:
		st.beacon = false
		host.deploy_beacon()
	# periodic internal scan
	st.iscan_next = float(st.iscan_next) - float(P.react)
	if float(st.iscan_next) <= 0.0:
		st.iscan_next = 45.0
		Intents.apply(w, "sensors", "iscan", true)

# ---------------------------------------------------------------- Ops

func _ops() -> void:
	var w: World = _w()
	var s: Ship = w.ship
	var h: Dictionary = _stuff()
	var sn: Dictionary = Snapshots.ops(w)
	# shields toward the nearest threat
	var thr: int = int(sn.threat)
	var shield_sets: Array = [1, 1, 1, 1]
	if not w.hostiles().is_empty() or not w.of_kind("ebullet").is_empty() or not w.of_kind("eshell").is_empty():
		shield_sets = [1, 1, 1, 1]
		shield_sets[thr] = 4
	else:
		shield_sets = [2, 1, 1, 1]
	var mode: String = str(st.shield_mode)
	if mode != "auto":
		var fi: int = {"front": 0, "stbd": 1, "aft": 2, "port": 3}.get(mode, 0)
		shield_sets = [1, 1, 1, 1]
		shield_sets[fi] = 4
	var cur: Array = sn.shield_w
	if cur != shield_sets:
		Intents.apply(w, "ops", "shield_set", shield_sets)
	# Pudding care
	var pud: Dictionary = sn.pud
	if pud.aboard:
		var mood: float = float(pud.mood)
		var calm: bool = bool(st.calm) or bool(h.get("calm", false))
		var thresh_pat: float = 30.0 if calm else 55.0
		if pud.loose:
			if s.snacks > 0 and float(pud.snack_cd) <= 0.0:
				Intents.apply(w, "ops", "snack", true)
		else:
			if mood > thresh_pat and float(pud.pat_cd) <= 0.0:
				Intents.apply(w, "ops", "pat", true)
			if mood > (45.0 if calm else 72.0) and s.snacks > 0 and float(pud.snack_cd) <= 0.0:
				Intents.apply(w, "ops", "snack", true)
		var want_music: bool = mood > 30.0
		if bool(pud.music) != want_music:
			Intents.apply(w, "ops", "music", want_music)
	# tractor from hint
	var tr: int = int(st.tract)
	if tr == -2:
		tr = int(sn.tractables[0].id) if not sn.tractables.is_empty() else -1
	if tr < 0 and h.has("tractor"):
		tr = int(h.get("tractor"))
	if tr >= 0 and tr != w.tractor_id:
		Intents.apply(w, "ops", "tractor", tr)
	elif tr < 0 and w.tractor_id >= 0 and not h.has("tractor"):
		Intents.apply(w, "ops", "tractor", -1)
	# repair bot dispatch
	if s.bot_job == "":
		var worst: String = ""
		var wv: float = 100.0
		for id in s.mod_order:
			var m: Dictionary = s.modules[id]
			if m.fire > 0.0 or m.breach:
				continue
			if m.hp < wv and m.hp < 70.0:
				wv = m.hp
				worst = id
		if worst != "":
			Intents.apply(w, "ops", "bot", worst)
