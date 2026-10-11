class_name BotCaptain
extends RefCounted
## An AI captain: reads the world (the captain sees everything visible) and gives the same
## orders a human captain would, to bot crew directly or as text cards to human crew.
## Also the backbone of the headless soak tests.

var host: Node
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var timer: float = 0.0
var last: Dictionary = {}
var settings_done: Dictionary = {}
var repair_assign: Dictionary = {}
var enc_id: String = ""
var phase_t: float = 0.0
var auto_continue: bool = true
var chosen_node: int = -1

func _init(h: Node) -> void:
	host = h
	rng.randomize()

func reset() -> void:
	last.clear()
	settings_done.clear()
	repair_assign.clear()
	chosen_node = -1

func say(seat: String, verb: String, args: Dictionary = {}) -> void:
	host.order(seat, verb, args, false)

func say_once(key: String, seat: String, verb: String, args: Dictionary, tol: float = 0.0) -> void:
	var sig: String = verb + ":" + str(args)
	if last.get(key, "") == sig:
		return
	last[key] = sig
	say(seat, verb, args)

func tick(dt: float) -> void:
	timer -= dt
	phase_t += dt
	if timer > 0.0:
		return
	timer = 0.4
	match host.phase:
		"encounter":
			_encounter()
		"staging":
			_staging()
		"debrief":
			if auto_continue and phase_t > 4.0:
				host.captain_continue()
		"pitstop":
			_pitstop()
		"ending", "gameover":
			pass

func on_phase_change() -> void:
	phase_t = 0.0
	reset()

# ---------------------------------------------------------------- encounter

func _encounter() -> void:
	var w: World = host.world
	if w.enc == null or w.enc.done:
		return
	var h: Dictionary = w.enc.hint()
	var s: Ship = w.ship
	if w.enc.id != enc_id:
		enc_id = w.enc.id
		reset()
	# power profile
	var prof: String = "balanced"
	if h.has("profile"):
		prof = str(h.profile)
	elif bool(h.get("combat", false)):
		prof = "run" if bool(h.get("shield_face", false)) and w.enc.id.begins_with("fin_") else "combat"
	elif bool(h.get("stealth", false)):
		prof = "stealth"
	elif h.has("tractor"):
		prof = "tractor"
	elif bool(h.get("dock", false)) or bool(h.get("calm", false)):
		prof = "precision"
	say_once("profile", "power", "profile", {"name": prof})
	# settings (customs etc.)
	if h.has("settings"):
		for seat in h.settings.keys():
			for k in h.settings[seat].keys():
				var key: String = seat + k
				if not settings_done.has(key):
					settings_done[key] = true
					say(seat, "set", {"id": k, "value": h.settings[seat][k]})
	say_once("stow", "weapons", "stow", {"on": bool(h.get("stow", false))})
	say_once("gentle", "engines", "gentle", {"on": bool(h.get("gentle", false))})
	say_once("calm", "ops", "calm", {"on": bool(h.get("calm", false))})
	# combat
	if h.has("fire"):
		var ids: Array = h.fire
		say_once("engage", "weapons", "engage", {"ids": ids})
		say_once("scan", "sensors", "scan", {"ids": ids})
	if h.has("scan") and not h.has("fire"):
		say_once("scan", "sensors", "scan", {"ids": h.scan})
	if h.has("scan") and h.has("torp"):
		say_once("scan2", "sensors", "scan", {"ids": h.scan})
	if h.has("torp"):
		say_once("torp", "weapons", "torp", {"id": h.torp, "weak": bool(h.get("weak", false))})
	if h.has("tractor"):
		var te: Dictionary = w.find(int(h.tractor))
		if not te.is_empty() and te.pos.distance_to(s.pos) < float(h.get("tractor_range", 80.0)):
			say_once("tractor", "ops", "tractor", {"id": h.tractor})
		else:
			say_once("tractor", "ops", "tractor", {"id": -1})
	# navigation
	_nav(h)
	# shake off drones that have been latched for a while
	if bool(h.get("combat", false)):
		for e in w.ents:
			if e.kind in ["grabber", "snatch"] and e.state == "latched" and float(e.st) > 7.0 and w.t - float(last.get("roll_t", -99.0)) > 9.0:
				last["roll_t"] = w.t
				say("helm", "roll", {"dir": 1.0})
	# repairs
	_repairs()

func _nav(h: Dictionary) -> void:
	var w: World = host.world
	var s: Ship = w.ship
	var goal: Vector2 = h.get("goal", s.pos)
	var arrive: float = float(h.get("arrive", 20.0))
	var cruise: float = float(h.get("speed", 0.0))
	var match_v: Vector2 = h.get("match", Vector2.ZERO)
	var to: Vector2 = goal - s.pos
	var d: float = to.length()
	if bool(h.get("stop", false)) and d < 140.0 or cruise <= 0.0:
		say_once("speed", "engines", "speed", {"v": 0.0})
		say_once("face", "helm", "hold", {})
		return
	# docking: face the centre, strafe to match the spin
	if bool(h.get("dock", false)) and d < 100.0:
		var center: Vector2 = h.get("face", goal)
		say_once("fp", "helm", "face_point", {"p": center})
		var fwd: Vector2 = s.fwd()
		var right: Vector2 = Vector2(-fwd.y, fwd.x)
		var des_rel: Vector2 = to.normalized() * minf(5.0, maxf(0.0, d - 3.0) * 0.3)
		var des_v: Vector2 = match_v + des_rel
		var fwd_speed: float = clampf(des_v.dot(fwd), 0.0, 10.0)
		var lat_err: float = des_v.dot(right) - s.vel.dot(right)
		var strafe: float = clampf(lat_err * 0.6, -1.0, 1.0)
		if absf(strafe) < 0.08:
			strafe = 0.0
		say_once("strafe", "helm", "strafe", {"dir": snappedf(strafe, 0.25)})
		say_once("speed", "engines", "speed", {"v": snappedf(fwd_speed, 1.0)})
		return
	var dirv: Vector2 = to.normalized()
	var slow: float = 1.0
	if h.has("avoid"):
		var near: float = 1e9
		for a in h.avoid:
			near = minf(near, s.pos.distance_to(a[0]))
		var goal_ang: float = dirv.angle()
		var best_ang: float = goal_ang
		var best_score: float = 1e9
		for i in range(-14, 15):
			var ang: float = goal_ang + float(i) * deg_to_rad(8.0)
			var ray: Vector2 = Vector2.from_angle(ang)
			var clear: float = 1e9
			for a2 in h.avoid:
				var rel2: Vector2 = a2[0] - s.pos
				var along: float = clampf(rel2.dot(ray), 0.0, 90.0)
				var dd: float = (rel2 - ray * along).length()
				clear = minf(clear, dd)
			var score: float = absf(float(i)) * 0.35
			if clear < 22.0:
				score += (22.0 - clear) * 4.0 + 40.0
			elif clear < 36.0:
				score += (36.0 - clear) * 0.4
			if score < best_score:
				best_score = score
				best_ang = ang
		dirv = Vector2.from_angle(best_ang)
		if near < 100.0:
			slow = 0.6
		if near < 55.0:
			slow = 0.4
	var spd: float = minf(cruise * slow, maxf(0.0, (d - arrive) * 0.3 + 2.0))
	if bool(h.get("dock", false)):
		spd = minf(cruise, maxf(0.0, (d - arrive) * 0.1 + 3.0))
	if d < arrive:
		spd = 0.0
	var dv: Vector2 = match_v + dirv * spd
	var want_heading: float = dv.angle() if dv.length() > 1.0 else (s.heading if not h.has("face") else (h.face - s.pos).angle())
	if h.has("face") and d < 120.0 and not bool(h.get("dock", false)):
		want_heading = (h.face - s.pos).angle()
	var herr: float = absf(K.wrap_pi(want_heading - s.heading))
	var v_cmd: float = dv.length()
	if herr > 0.5:
		v_cmd = minf(v_cmd, 3.0)
	if herr > 1.2:
		v_cmd = 0.0
	if not last.has("hv") or absf(K.wrap_pi(want_heading - float(last["hv"]))) > 0.06:
		last["hv"] = want_heading
		say("helm", "face", {"heading": want_heading})
	say_once("strafe", "helm", "strafe", {"dir": 0.0})
	say_once("speed", "engines", "speed", {"v": snappedf(v_cmd, 1.0)})

# ---------------------------------------------------------------- repairs

func _repairs() -> void:
	var w: World = host.world
	var s: Ship = w.ship
	var targets: Array = []
	for id in s.mod_order:
		var m: Dictionary = s.modules[id]
		var t: Dictionary = w.target_task("mod:" + id)
		if t.is_empty():
			continue
		if m.fire > 0.0 or m.breach or s.mod_state(id) >= 3 or (s.mod_state(id) >= 2 and m.fault != "") :
			targets.append("mod:" + id)
	# prune assignments that are done
	for tgt in repair_assign.keys():
		if w.target_task(tgt).is_empty():
			repair_assign.erase(tgt)
	var busy: Array = repair_assign.values()
	var order_pref: Array = ["sensors", "ops", "weapons", "helm", "engines"]
	for tgt2 in targets:
		if repair_assign.has(tgt2) or busy.size() >= 2:
			continue
		for seat in order_pref:
			if seat in busy:
				continue
			if not host.seat_is_bot(seat):
				continue
			repair_assign[tgt2] = seat
			busy.append(seat)
			say(seat, "repair", {"target": tgt2})
			break

# ---------------------------------------------------------------- staging / ritual

func _staging() -> void:
	var run: RunState = host.run
	var rit: Dictionary = host.ritual
	if run == null:
		return
	_repairs()
	if rit.get("node", -1) < 0:
		if phase_t < 2.0:
			return
		var opts: Array = run.options()
		if opts.is_empty():
			return
		var pick: Dictionary = opts[0]
		var best: float = -1e9
		for n in opts:
			var score: float = -float(n.threat) * (0.0 if str(n.kind).begins_with("fin_") else 1.0) + rng.randf() * 1.2
			if n.pit and (host.world.ship.hull < 70.0 or run.fuel < 2 or run.scrap >= 40):
				score += 3.0
			if score > best:
				best = score
				pick = n
		say("helm", "code", {"code": pick.code})
		return
	_repairs()
	say_once("gentle", "engines", "gentle", {"on": false})
	say_once("stow", "weapons", "stow", {"on": false})
	say_once("calm", "ops", "calm", {"on": false})
	say_once("profile", "power", "profile", {"name": "ritual"})
	say_once("charge", "power", "charge", {"on": true})
	say_once("secure", "ops", "secure", {"on": true})
	say_once("speed", "engines", "speed", {"v": float(rit.get("target_speed", 35.0))})
	say_once("face", "helm", "hold", {})
	var ok: Dictionary = rit.get("ok", {})
	if ok.get("helm", false) and ok.get("power", false) and ok.get("engines", false) and ok.get("ops", false):
		host.captain_punch()

func _pitstop() -> void:
	var run: RunState = host.run
	if phase_t < 2.0:
		return
	var buy_order: Array = ["hull", "fuel", "snacks", "cooler", "antenna", "rcs", "turbo", "torp", "pen", "beacon"]
	var want_hull: bool = host.world.ship.hull < 80.0
	for id in buy_order:
		if id == "hull" and not want_hull:
			continue
		for it in RunState.ITEMS:
			if it.id == id and run.scrap >= int(it.cost) and int(run.upgrades.get(id, 0)) < (3 if id in ["hull", "fuel", "snacks"] else 1):
				host.pit_buy(id)
				return
	host.pit_done()
